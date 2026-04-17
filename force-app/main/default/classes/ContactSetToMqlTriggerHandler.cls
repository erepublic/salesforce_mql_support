public with sharing class ContactSetToMqlTriggerHandler {
  @TestVisible
  private static final String THRESHOLD_LEAD_SOURCE = 'Fit and Behavior Threshold Reached';
  @TestVisible
  private static final String EVENTS_PORTAL_LEAD_SOURCE = 'Events Portal';
  @TestVisible
  private static final String CMS_HAND_RAISER_SOURCE = 'EF3';
  @TestVisible
  private static final String CMS_HAND_RAISER_LEAD_SOURCE = 'Submitted a Form';
  @TestVisible
  private static final String NEW_STATUS = 'New';
  @TestVisible
  private static final String CONVERTED_STATUS = 'Converted';
  @TestVisible
  private static final String CONVERSION_TYPE_NEW_OPP = 'Created Opportunity';
  @TestVisible
  private static final String CONVERTED_BY_AUTOMATION = 'Automation';
  @TestVisible
  private static final String THRESHOLD_PRODUCT_NAME = 'Lead Opportunity - MQL Threshold';
  @TestVisible
  private static final Integer RECENT_MQL_DEDUPE_DAYS = 30;

  public static void handleAfterInsert(List<Contact> newContacts) {
    if (newContacts == null || newContacts.isEmpty()) {
      return;
    }

    Set<Id> contactIdsToProcess = new Set<Id>();
    for (Contact c : newContacts) {
      if (c != null && c.Set_to_MQL__c == true) {
        contactIdsToProcess.add(c.Id);
      }
    }

    createMqlsForContacts(contactIdsToProcess);
  }

  public static void handleAfterUpdate(
    List<Contact> newContacts,
    Map<Id, Contact> oldMap
  ) {
    if (newContacts == null || newContacts.isEmpty() || oldMap == null) {
      return;
    }

    Set<Id> contactIdsToProcess = new Set<Id>();
    for (Contact c : newContacts) {
      if (c == null) {
        continue;
      }

      Contact oldContact = oldMap.get(c.Id);
      Boolean wasSetToMql = oldContact != null && oldContact.Set_to_MQL__c;
      if (c.Set_to_MQL__c == true && !wasSetToMql) {
        contactIdsToProcess.add(c.Id);
      }
    }

    createMqlsForContacts(contactIdsToProcess);
  }

  private static void createMqlsForContacts(Set<Id> contactIdsToProcess) {
    if (contactIdsToProcess == null || contactIdsToProcess.isEmpty()) {
      return;
    }

    // Re-query contacts to get the hand-raiser transit fields.
    // Trigger context records may not carry fields set by the same DML that
    // fired the trigger, so we query fresh values here.
    Map<Id, String> handRaiserOppIds = new Map<Id, String>();
    Map<Id, String> handRaiserProductIds = new Map<Id, String>();
    Map<Id, Boolean> handRaiserOppIsNew = new Map<Id, Boolean>();
    Map<Id, String> handRaiserSources = new Map<Id, String>();
    Map<Id, String> handRaiserLeadSourceDetails = new Map<Id, String>();
    Map<Id, String> handRaiserLeadDetail1s = new Map<Id, String>();
    Map<Id, String> handRaiserLeadDetail2s = new Map<Id, String>();
    Map<Id, String> handRaiserLeadDetail3s = new Map<Id, String>();
    Map<Id, String> handRaiserLeadDetail4s = new Map<Id, String>();
    Map<Id, String> handRaiserCampaignIds = new Map<Id, String>();
    Set<Id> thresholdContactIds = new Set<Id>();
    for (Contact c : [
      SELECT
        Id,
        Hand_Raiser_Source__c,
        Hand_Raiser_Opportunity_Id__c,
        Hand_Raiser_Product_Id__c,
        Hand_Raiser_Opp_Is_New__c,
        Hand_Raiser_Lead_Source_Detail__c,
        Hand_Raiser_Lead_Detail_1__c,
        Hand_Raiser_Lead_Detail_2__c,
        Hand_Raiser_Lead_Detail_3__c,
        Hand_Raiser_Lead_Detail_4__c,
        Hand_Raiser_Campaign_Id__c,
        Hand_Raiser_Payload_Version__c
      FROM Contact
      WHERE Id IN :contactIdsToProcess
    ]) {
      Boolean hasExplicitHandRaiserSource = String.isNotBlank(
        c.Hand_Raiser_Source__c
      );
      Boolean hasExplicitHandRaiserOpp = String.isNotBlank(
        c.Hand_Raiser_Opportunity_Id__c
      );
      Boolean hasExplicitHandRaiserProduct = String.isNotBlank(
        c.Hand_Raiser_Product_Id__c
      );
      Boolean hasExplicitHandRaiserDetails =
        String.isNotBlank(c.Hand_Raiser_Lead_Source_Detail__c) ||
        String.isNotBlank(c.Hand_Raiser_Lead_Detail_1__c) ||
        String.isNotBlank(c.Hand_Raiser_Lead_Detail_2__c) ||
        String.isNotBlank(c.Hand_Raiser_Lead_Detail_3__c) ||
        String.isNotBlank(c.Hand_Raiser_Lead_Detail_4__c) ||
        String.isNotBlank(c.Hand_Raiser_Campaign_Id__c) ||
        String.isNotBlank(c.Hand_Raiser_Payload_Version__c);
      if (
        hasExplicitHandRaiserSource ||
        hasExplicitHandRaiserOpp ||
        hasExplicitHandRaiserProduct ||
        hasExplicitHandRaiserDetails
      ) {
        handRaiserSources.put(c.Id, c.Hand_Raiser_Source__c);
        handRaiserOppIds.put(c.Id, c.Hand_Raiser_Opportunity_Id__c);
        handRaiserProductIds.put(c.Id, c.Hand_Raiser_Product_Id__c);
        handRaiserOppIsNew.put(c.Id, c.Hand_Raiser_Opp_Is_New__c == true);
        handRaiserLeadSourceDetails.put(
          c.Id,
          c.Hand_Raiser_Lead_Source_Detail__c
        );
        handRaiserLeadDetail1s.put(c.Id, c.Hand_Raiser_Lead_Detail_1__c);
        handRaiserLeadDetail2s.put(c.Id, c.Hand_Raiser_Lead_Detail_2__c);
        handRaiserLeadDetail3s.put(c.Id, c.Hand_Raiser_Lead_Detail_3__c);
        handRaiserLeadDetail4s.put(c.Id, c.Hand_Raiser_Lead_Detail_4__c);
        handRaiserCampaignIds.put(c.Id, c.Hand_Raiser_Campaign_Id__c);
      } else {
        thresholdContactIds.add(c.Id);
      }
    }

    // --- Hand-raiser path ---
    // Route A (Hand_Raiser_Opp_Is_New__c = true + opp id present): an upstream
    //   system already created a fresh Opp. Create the MQL as Converted so it
    //   bypasses the sales queue and the rep can start working it immediately.
    // Route B (no new opp, reused opp, or mql-only handoff): create the MQL as
    //   New so the sales team reviews and routes the lead.
    // Dedup is intentionally skipped for both routes because the transit fields
    // are an explicit hand-raiser signal from an upstream system.
    List<MQL__c> handRaiserMqls = new List<MQL__c>();
    for (Id contactId : handRaiserSources.keySet()) {
      String handRaiserSource = handRaiserSources.get(contactId);
      String mqlLeadSource = handRaiserSource == CMS_HAND_RAISER_SOURCE
        ? CMS_HAND_RAISER_LEAD_SOURCE
        : EVENTS_PORTAL_LEAD_SOURCE;
      String handRaiserOppId = handRaiserOppIds.get(contactId);
      Id handRaiserProductId;
      String rawHandRaiserProductId = handRaiserProductIds.get(contactId);
      if (String.isNotBlank(rawHandRaiserProductId)) {
        handRaiserProductId = (Id) rawHandRaiserProductId;
      }
      Boolean isNewOpp = handRaiserOppIsNew.get(contactId) == true;
      MQL__c mql = new MQL__c(
        Contact__c = contactId,
        Lead_Source__c = mqlLeadSource,
        MQL_Date__c = Date.today(),
        Opportunity__c = handRaiserOppId,
        Product__c = handRaiserProductId,
        Lead_Source_Detail__c = handRaiserLeadSourceDetails.get(contactId),
        Lead_Detail_1__c = handRaiserLeadDetail1s.get(contactId),
        Lead_Detail_2__c = handRaiserLeadDetail2s.get(contactId),
        Lead_Detail_3__c = handRaiserLeadDetail3s.get(contactId),
        Lead_Detail_4__c = handRaiserLeadDetail4s.get(contactId)
      );
      String rawCampaignId = handRaiserCampaignIds.get(contactId);
      if (String.isNotBlank(rawCampaignId)) {
        try {
          mql.Campaign__c = (Id) rawCampaignId;
        } catch (Exception e) {
          // Ignore malformed campaign ids from transit fields.
        }
      }
      if (isNewOpp && String.isNotBlank(handRaiserOppId)) {
        // Route A: auto-convert only when a fresh Opp already exists.
        mql.MQL_Status__c = CONVERTED_STATUS;
        mql.Conversion_Type__c = CONVERSION_TYPE_NEW_OPP;
        mql.Conversion_Date__c = Date.today();
        mql.Converted_By__c = CONVERTED_BY_AUTOMATION;
      } else {
        // Route B: queue for sales review.
        mql.MQL_Status__c = NEW_STATUS;
      }
      handRaiserMqls.add(mql);
    }
    if (!handRaiserMqls.isEmpty()) {
      insert handRaiserMqls;
    }

    // --- Threshold path (unchanged) ---
    if (!thresholdContactIds.isEmpty()) {
      Id thresholdProductId;
      List<Product2> thresholdProducts = [
        SELECT Id
        FROM Product2
        WHERE Name = :THRESHOLD_PRODUCT_NAME
        LIMIT 1
      ];
      if (!thresholdProducts.isEmpty()) {
        thresholdProductId = thresholdProducts[0].Id;
      }

      Set<Id> contactsWithExistingNewThresholdMql = new Set<Id>();
      Set<Id> contactsWithRecentNonThresholdMql = new Set<Id>();
      for (MQL__c mql : [
        SELECT Id, Contact__c, Lead_Source__c, CreatedDate
        FROM MQL__c
        WHERE
          Contact__c IN :thresholdContactIds
          AND MQL_Status__c = :NEW_STATUS
          AND CreatedDate = LAST_N_DAYS:30
      ]) {
        if (mql.Lead_Source__c == THRESHOLD_LEAD_SOURCE) {
          contactsWithExistingNewThresholdMql.add(mql.Contact__c);
        } else {
          contactsWithRecentNonThresholdMql.add(mql.Contact__c);
        }
      }

      List<MQL__c> mqlsToInsert = new List<MQL__c>();
      for (Id contactId : thresholdContactIds) {
        if (contactsWithExistingNewThresholdMql.contains(contactId)) {
          continue;
        }
        if (contactsWithRecentNonThresholdMql.contains(contactId)) {
          continue;
        }

        mqlsToInsert.add(
          new MQL__c(
            Contact__c = contactId,
            Lead_Source__c = THRESHOLD_LEAD_SOURCE,
            MQL_Status__c = NEW_STATUS,
            MQL_Date__c = Date.today(),
            Product__c = thresholdProductId
          )
        );
      }

      if (!mqlsToInsert.isEmpty()) {
        insert mqlsToInsert;
      }
    }

    // Reset Set_to_MQL__c on all processed contacts.
    // For hand-raisers, also clear the transit fields.
    List<Contact> contactsToReset = new List<Contact>();
    for (Id contactId : contactIdsToProcess) {
      Contact resetContact = new Contact(Id = contactId, Set_to_MQL__c = false);
      if (handRaiserSources.containsKey(contactId)) {
        resetContact.Hand_Raiser_Source__c = null;
        resetContact.Hand_Raiser_Opportunity_Id__c = null;
        resetContact.Hand_Raiser_Product_Id__c = null;
        resetContact.Hand_Raiser_Opp_Is_New__c = false;
        resetContact.Hand_Raiser_Lead_Source_Detail__c = null;
        resetContact.Hand_Raiser_Lead_Detail_1__c = null;
        resetContact.Hand_Raiser_Lead_Detail_2__c = null;
        resetContact.Hand_Raiser_Lead_Detail_3__c = null;
        resetContact.Hand_Raiser_Lead_Detail_4__c = null;
        resetContact.Hand_Raiser_Campaign_Id__c = null;
        resetContact.Hand_Raiser_Payload_Version__c = null;
      }
      contactsToReset.add(resetContact);
    }
    if (!contactsToReset.isEmpty()) {
      update contactsToReset;
    }
  }
}

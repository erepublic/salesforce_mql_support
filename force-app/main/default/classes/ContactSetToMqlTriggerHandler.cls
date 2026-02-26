public with sharing class ContactSetToMqlTriggerHandler {
  @TestVisible
  private static final String THRESHOLD_LEAD_SOURCE = 'Fit and Behavior Threshold Reached';
  @TestVisible
  private static final String NEW_STATUS = 'New';

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

    Set<Id> contactsWithExistingNewThresholdMql = new Set<Id>();
    for (MQL__c mql : [
      SELECT Id, Contact__c
      FROM MQL__c
      WHERE
        Contact__c IN :contactIdsToProcess
        AND Lead_Source__c = :THRESHOLD_LEAD_SOURCE
        AND MQL_Status__c = :NEW_STATUS
    ]) {
      contactsWithExistingNewThresholdMql.add(mql.Contact__c);
    }

    List<MQL__c> mqlsToInsert = new List<MQL__c>();
    for (Id contactId : contactIdsToProcess) {
      if (contactsWithExistingNewThresholdMql.contains(contactId)) {
        continue;
      }

      mqlsToInsert.add(
        new MQL__c(
          Contact__c = contactId,
          Lead_Source__c = THRESHOLD_LEAD_SOURCE,
          MQL_Status__c = NEW_STATUS,
          MQL_Date__c = Date.today()
        )
      );
    }

    if (!mqlsToInsert.isEmpty()) {
      insert mqlsToInsert;
    }
  }
}

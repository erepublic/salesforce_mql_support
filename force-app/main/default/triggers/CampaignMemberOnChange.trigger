trigger CampaignMemberOnChange on CampaignMember(after insert, after delete) {
  /**
   * When a contact is added to a campaign, we update a corresponding field on the Contact
   * object which is responsible for indicating if the contact is part of a campaign.
   **/
  List<Contact> updateContacts = new List<Contact>();
  Map<ID, Campaign> campaignList = new Map<ID, Campaign>();
  /**
   * On insert of a CampaignMember, we check the corresponding checkbox on the contact object.
   **/
  if (Trigger.isInsert) {
    for (CampaignMember cm : Trigger.new) {
      Campaign cp;
      if (campaignList.containsKey(cm.CampaignId)) {
        cp = campaignList.get(cm.CampaignId);
      } else {
        cp = [
            SELECT Id, Contact_Campaign_API_Reference__c
            FROM Campaign
            WHERE Id = :cm.CampaignId
          ]
          .get(0);
        campaignList.put(cp.Id, cp);
      }
      if (!String.isBlank(cp.Contact_Campaign_API_Reference__c)) {
        Contact ct = new Contact(Id = cm.ContactId);
        ct.put(cp.Contact_Campaign_API_Reference__c, true);
        updateContacts.add(ct);
      }
    }
  }
  /**
   * On deletion of a CampaignMember, we uncheck the corresponding checkbox on the Contact object.
   **/
  if (Trigger.isDelete) {
    for (CampaignMember cm : Trigger.old) {
      Campaign cp;
      if (campaignList.containsKey(cm.CampaignId)) {
        cp = campaignList.get(cm.CampaignId);
      } else {
        cp = [
            SELECT Id, Contact_Campaign_API_Reference__c
            FROM Campaign
            WHERE Id = :cm.CampaignId
          ]
          .get(0);
        campaignList.put(cp.Id, cp);
      }
      if (!String.isBlank(cp.Contact_Campaign_API_Reference__c)) {
        Contact ct = new Contact(Id = cm.ContactId);
        ct.put(cp.Contact_Campaign_API_Reference__c, false);
        updateContacts.add(ct);
      }
    }
  }
  if (updateContacts.size() > 0) {
    update updateContacts;
  }
}

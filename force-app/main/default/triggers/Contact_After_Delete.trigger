/**
 * After a contact is deleted we insert a history record so that external systems
 * using the Contact.Id can track down a record that was merged or deleted for
 * whatever reason.
 *
 * Looking up a deleted contact by ID example:
 *
 * SELECT Email,
 * Id
 * FROM Contact
 * WHERE Id IN (SELECT Contact_Reference__c FROM Contact_Durable_History__c WHERE Contact_Deleted_Id__c IN ('00314000029M6qn'))
 *
 * */
trigger Contact_After_Delete on Contact(after delete) {
  Map<Id, List<Id>> mergedContactUpdates = new Map<Id, List<Id>>();
  for (Contact ct : Trigger.old) {
    Contact_Durable_History__c ct_hist = new Contact_Durable_History__c(
      Contact_Deleted_Id__c = String.valueOf(ct.Id).substring(0, 15)
    );
    if (ct.CMS_Contact_Id__c != null && ct.CMS_Contact_Id__c.isNumeric()) {
      ct_hist.Contact_Deleted_CMS_Id__c = decimal.valueOf(ct.CMS_Contact_Id__c);
    }
    if (ct.MasterRecordId != null && ct.MasterRecordId != ct.Id) {
      ct_hist.Contact_Reference__c = ct.MasterRecordId;
    }
    insert ct_hist;
  }
}

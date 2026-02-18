@isTest
public class Contact_After_Delete_Test {
  static testMethod void testDeleteContact() {
    Test.startTest();
    Contact ct = testData.createContact(true);
    String ctid = String.valueOf(ct.Id).substring(0, 15);
    delete ct;
    Contact_Durable_History__c cdh = [
      SELECT
        Id,
        Contact_Deleted_CMS_Id__c,
        Contact_Reference__c,
        Contact_Deleted_Id__c
      FROM Contact_Durable_History__c
      WHERE Contact_Deleted_Id__c = :ctid
    ];
    System.assertEquals(cdh.Contact_Deleted_Id__c, ctid);
    System.assertEquals(cdh.Contact_Reference__c, null);
    System.assertEquals(cdh.Contact_Deleted_CMS_Id__c, null);
    Test.stopTest();
  }
  static testMethod void testMergeContact() {
    Test.startTest();
    Contact ct = testData.createContact(true);
    Id master = ct.Id;
    Contact losingCt = testData.createContact(true);
    losingCt.CMS_Contact_Id__c = '12342333';
    update losingCt;
    String losingId = String.valueOf(losingCt.Id).substring(0, 15);
    merge ct losingCt;
    Contact_Durable_History__c cdh = [
      SELECT
        Id,
        Contact_Deleted_CMS_Id__c,
        Contact_Reference__c,
        Contact_Deleted_Id__c
      FROM Contact_Durable_History__c
      WHERE Contact_Reference__c = :master
    ];
    System.assertEquals(cdh.Contact_Deleted_Id__c, losingId);
    System.assertEquals(cdh.Contact_Reference__c, master);
    System.assertEquals(cdh.Contact_Deleted_CMS_Id__c, 12342333);
    Test.stopTest();
  }
}

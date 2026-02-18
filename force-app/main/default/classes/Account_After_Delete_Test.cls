@isTest
public class Account_After_Delete_Test {
  static testMethod void testDeleteAccount() {
    Test.startTest();
    Account act = testData.createAccount(true);
    String actid = String.valueOf(act.Id).substring(0, 15);
    delete act;
    Account_Durable_History__c acdh = [
      SELECT Id, Account_Reference__c, Account_Deleted_Id__c
      FROM Account_Durable_History__c
      WHERE Account_Deleted_Id__c = :actid
    ];
    System.assertEquals(acdh.Account_Deleted_Id__c, actid);
    System.assertEquals(acdh.Account_Reference__c, null);
    Test.stopTest();
  }
  static testMethod void testMergeAccount() {
    Test.startTest();
    Account act = testData.createAccount(true);
    Id master = act.Id;
    Account losingAct = testData.createAccount(true);
    update losingAct;
    String losingId = String.valueOf(losingAct.Id).substring(0, 15);
    merge act losingAct;
    Account_Durable_History__c acdh = [
      SELECT Id, Account_Reference__c, Account_Deleted_Id__c
      FROM Account_Durable_History__c
      WHERE Account_Reference__c = :master
    ];
    System.assertEquals(acdh.Account_Deleted_Id__c, losingId);
    System.assertEquals(acdh.Account_Reference__c, master);
    Test.stopTest();
  }
}

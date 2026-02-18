@isTest
public with sharing class Account_Controller_test {
  static testMethod void TestAuraFunctions() {
    Account a1 = testData.createAccount(true);
    System.assertEquals(null, a1.Account_Priority_Notes__c);
    Account_Controller.saveAccountNote(a1.Id, 'Some random note', null);
    Account ar1 = [
      SELECT Id, Account_Priority_Notes__c
      FROM Account
      WHERE Id = :a1.Id
    ];
    System.assertEquals('Some random note', ar1.Account_Priority_Notes__c);
    String noteRes = Account_Controller.getAccountNote(a1.Id);
    System.assertEquals('Some random note', noteRes);
    try {
      Account_Controller.saveAccountNote(
        a1.Id,
        'Some random note overwrite',
        null
      );
    } catch (Exception e) {
      System.assertEquals('prevented overwriting a note', e.getMessage());
    }
  }
}

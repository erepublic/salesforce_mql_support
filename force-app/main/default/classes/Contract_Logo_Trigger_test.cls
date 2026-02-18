@isTest(seeAllData=true)
public class Contract_Logo_Trigger_test {
  static testMethod void testTheTrig() {
    Account a = testData.createAccount();
    Contract event_contract = testData.createContract('012a0000001RKA9', a.Id);
    event_contract.Website_Manual__c = 'https://www.google.com';
    update event_contract;
    event_contract.Website_Manual__c = 'https://www.yahoo.com';
    update event_contract;
  }
}

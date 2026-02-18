@isTest
public with sharing class Papers_Update_Trigger_test {
  static testMethod void paperTriggerTest() {
    Paper__c p = testData.createPaper('GOVERNING');
    Account a = testData.createAccount();
    DmlException expectedException;
    try {
      p.Client__c = a.Id;
      update p;
    } catch (DmlException dmx) {
      expectedException = dmx;
    }
    System.assertEquals(
      'FIELD_CUSTOM_VALIDATION_EXCEPTION',
      expectedException.getDmlStatusCode(0)
    );
  }
}

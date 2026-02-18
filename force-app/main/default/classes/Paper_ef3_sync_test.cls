@isTest
public class Paper_ef3_sync_test {
  static testMethod void paperTriggerTest() {
    Paper__c p = testData.createPaper('GOVERNING');
    p.Status__c = 'Completed';
    update p;
  }
}

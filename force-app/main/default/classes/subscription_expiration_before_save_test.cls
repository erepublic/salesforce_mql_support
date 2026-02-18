@isTest
private class subscription_expiration_before_save_test {
  // this method tests both subscribtion triggers

  // CDE: 'a0Qa000000J4s63EAB'  GOV: a0Qa000000J4q7BEAR      GT: a0Qa000000J4s5tEAB    no more  EM: a0Qa000000J4s5yEAB

  static testMethod void test_this() {
    Contact c1 = testData.createContact();
    // create subscription
    List<Subscription__c> subs = new List<Subscription__c>();
    List<Id> publications = new List<ID>{
      'a0Qa000000J4q7BEAR',
      'a0Qa000000J4s5tEAB'
    }; //'a0Qa000000J4s63EAB',
    for (Id pub_id : publications) {
      Subscription__c sub1 = new Subscription__c(
        Batch__c = '',
        Cancellation_Reason__c = '',
        PIQ__c = '',
        Promo_Code__c = '1401WEB',
        Publication__c = pub_id, // GT
        Qual__c = 'Requestor',
        Qual_Date__c = Date.today(),
        Source__c = '1C',
        Status__c = 'Active',
        Subscriber__c = c1.Id,
        Version__c = 'Print'
      );
      subs.add(sub1);
    }
    Subscription__c subExp = new Subscription__c(
      Batch__c = '',
      Cancellation_Reason__c = '',
      PIQ__c = '',
      Promo_Code__c = '1401WEB',
      Publication__c = 'a0Qa000000J4s5tEAB', // GT
      Qual__c = 'Requestor',
      Qual_Date__c = Date.today(),
      Source__c = '1C',
      Status__c = 'Expired',
      Subscriber__c = c1.Id,
      Version__c = 'Print'
    );
    subs.add(subExp);
    List<Subscription__c> subs2 = new List<Subscription__c>();
    for (Id pub_id : publications) {
      Subscription__c sub2 = new Subscription__c(
        Batch__c = '',
        Cancellation_Reason__c = '',
        PIQ__c = '',
        Promo_Code__c = '1401WEB',
        Publication__c = pub_id, // GT
        Qual__c = 'Requestor',
        Qual_Date__c = Date.today(),
        Source__c = '1C',
        Status__c = 'Active',
        Subscriber__c = c1.Id,
        Version__c = 'Print'
      );
      subs2.add(sub2);
    }
    Test.startTest();
    insert subs;
    insert subs2;
    Test.stopTest();
  }
}

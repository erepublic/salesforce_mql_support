@isTest
public class product_trigger_test {
  static testMethod void myUnitTest() {
    Test.startTest();
    Events__c e = new Events__c(
      Name = 'test event',
      status__c = 'Planned',
      RecordTypeId = '01230000000ueuw'
    );
    insert e;

    Product2 p = new Product2(
      Name = 'test attendee product',
      EE_Event__c = e.Id,
      Sponsorship__c = 'Attendee'
    );
    insert p;
    Test.stopTest();
  }
}

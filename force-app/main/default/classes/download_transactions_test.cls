@isTest(SeeAllData=true)
public with sharing class download_transactions_test {
  static testMethod void test() {
    System.debug('testing cash entry');
    c2g__codaCashEntry__c c = new c2g__codaCashEntry__c();
    c.c2g__Status__c = 'In Progress';
    c.c2g__Description__c = 'test';
    c.c2g__Type__c = 'Payment';
    c.c2g__OwnerCompany__c = 'a1a5Y00001PPyonQAD';
    insert c;
    System.debug(c.Id);
    download_transactions.getCashEntry(c.Id);
  }
}

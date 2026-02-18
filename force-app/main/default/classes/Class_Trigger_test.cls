@isTest
public with sharing class Class_Trigger_test {
  public static testMethod void testCreate() {
    Class__c cl1 = new Class__c(
      Name = 'Test Insert Class',
      Lead_Guarantee__c = 100
    );
    insert cl1;
    cl1.Name = 'Test Update Class';
    update cl1;
  }
}

@isTest
public with sharing class contact_from_role_apexcontroller_test {
  static testMethod void test() {
    Contact c = testData.createContact();
    Job_Role__c r = testData.createRole(c);
    contact_from_role_apexcontroller.getRole(r.Id);
    Contact c2 = contact_from_role_apexcontroller.getContact(r.Id);
    c2.email = r.Contact_Email__c;
    String result = contact_from_role_apexcontroller.saveContact(c2);
    System.Debug(' ------DONE ----- ' + result);
  }
}

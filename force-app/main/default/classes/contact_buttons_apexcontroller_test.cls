@isTest
public with sharing class contact_buttons_apexcontroller_test {
  static testMethod void test() {
    Contact c = testData.createContact();
    c.Email_Opt_Out_Removal_Needed__c = true;
    update c;
    Integer ret = contact_buttons_apexcontroller.remove_optouts();
    System.Debug(String.valueOf(ret) + ' Opt outs removed');
  }
}

@isTest
private class navTrialUserChecker_test {
  static testMethod void test() {
    Test.startTest();

    // test the nav_trial_contact_trigger
    Contact c1 = testdata.createContact(true);
    c1.Navigator_Trial_Status__c = 'Requested';
    c1.Navigator_Trial_Expiration__c = date.parse('11/24/2030');

    c1.TW_Trial_Status__c = 'Requested';
    c1.TW_User_Expired__c = date.parse('11/24/2030');
    update c1;

    c1.Navigator_Trial_Status__c = 'In progress';
    c1.TW_Trial_Status__c = 'In progress';
    update c1;
    delete c1;

    Contact c = testdata.createContact(true);
    c.TW_Trial_Status__c = 'Cancel';
    c.TW_User_Expired__c = date.parse('11/24/2009');
    update c;

    Contact d = testdata.createContact(true);
    d.Navigator_Trial_Status__c = 'Cancel';
    d.Navigator_Trial_Expiration__c = date.parse('11/24/2009');
    update d;

    System.debug('contact info: ' + c);

    Contact c2 = testdata.createContact(true);
    c2.Navigator_Trial_Status__c = 'In Progress';
    c2.Navigator_Trial_Expiration__c = date.parse('11/24/2020');
    update c2;

    navTrialUserChecker tuc = new navTrialUserChecker();
    tuc.checkContacts();

    Test.stopTest();
  }
}

@isTest
public with sharing class navAccountChecker_test {
  public static testMethod void myTest() {
    Test.startTest();

    //navAccountChecker c = new navAccountChecker();

    //	navigator_test.createTestData();
    User u = testData.createUser();
    u.IsActive = true;
    update u;
    Account a = testData.createAccount(false);
    a.DGN_Contract_Status__c = 'Active';
    Date expiry = Date.today();
    expiry.addDays(10);
    a.DGN_Contract_Expiration__c = expiry;
    a.DGN_Account_Rep__c = u.Id;
    a.OwnerId = u.Id;
    insert a;
    navAccountChecker c = new navAccountChecker();
    c.checkAccounts();

    User u2 = testData.createUser();
    u2.IsActive = true;
    update u2;
    Account a2 = testData.createAccount(false);
    a2.DEN_Contract_Status__c = 'Active';
    Date expiry2 = Date.today();
    expiry2.addDays(10);
    a2.DEN_Contract_Expiration__c = expiry;
    a2.DEN_Account_Rep__c = u2.Id;
    a2.OwnerId = u2.Id;
    insert a2;
    navAccountChecker c2 = new navAccountChecker();
    c2.checkAccounts();

    User u3 = testData.createUser();
    u3.IsActive = true;
    update u3;
    Account a3 = testData.createAccount(false);
    a3.EMN_Contract_Status__c = 'Active';
    Date expiry3 = Date.today();
    expiry3.addDays(10);
    a3.EMN_Contract_Expiration__c = expiry;
    a3.EMN_Account_Rep__c = u3.Id;
    a3.OwnerId = u3.Id;
    insert a3;
    c.sendEmail(a2, 'Renewal', 'EMN');

    User u4 = testData.createUser();
    u4.IsActive = true;
    update u4;
    Account a4 = testData.createAccount(false);
    a4.DGN_Contract_Status__c = 'Renewal';
    Date expiry4 = Date.today();
    expiry4.addDays(-10);
    a4.DGN_Contract_Expiration__c = expiry;
    a4.DGN_Account_Rep__c = u4.Id;
    a4.OwnerId = u4.Id;
    insert a4;
    c.sendEmail(a4, 'Expired', 'DGN');

    User u5 = testData.createUser();
    u5.IsActive = true;
    update u5;
    Account a5 = testData.createAccount(false);
    a5.DEN_Contract_Status__c = 'Renewal';
    Date expiry5 = Date.today();
    expiry5.addDays(-10);
    a5.DEN_Contract_Expiration__c = expiry;
    a5.DEN_Account_Rep__c = u5.Id;
    a5.OwnerId = u5.Id;
    insert a5;
    c.sendEmail(a5, 'Expired', 'DEN');

    User u6 = testData.createUser();
    u6.IsActive = true;
    update u6;
    Account a6 = testData.createAccount(false);
    a6.EMN_Contract_Status__c = 'Renewal';
    Date expiry6 = Date.today();
    expiry6.addDays(-10);
    a6.EMN_Contract_Expiration__c = expiry;
    a6.EMN_Account_Rep__c = u6.Id;
    a6.OwnerId = u6.Id;
    insert a6;
    c.sendEmail(a6, 'Expired', 'EMN');

    Test.stopTest();
  }
}

@isTest
public class RegistrationOnUpdateTest {
  @isTest
  static void testInsertRegistration() {
    Test.startTest();
    Contact c1 = testData.createContact(false);
    c1.email = 'test@afdskajsdfkjfd.com';
    insert c1;
    Events__c ev = testData.createEvent(true);
    Account acc = testData.createAccount(true);
    Contract ct = testData.createContract('012a0000001RKA9', acc.Id);
    ct.Event_Passes__c = 4;
    ct.Sponsorship_Name__c = 'Test Sponsor';
    ct.Event__c = ev.Id;
    update ct;

    Database.SaveResult res = Database.insert(
      new Registration__c(
        Reg_Type__c = 'Sponsor',
        Reg_Date__c = DateTime.now().date(),
        Reg_Source__c = 'O Online',
        Registrant_Name__c = c1.Id,
        Event__c = ev.Id,
        Temporary_Id__c = 'asasas'
      ),
      false
    );
    Test.stopTest();
    System.assert(!res.isSuccess());
    System.assert(res.getErrors().size() > 0);
    //        System.assertEquals(' Please supply Sponsor Company that matches one of these contracts , Test Sponsor' ,res.getErrors()[0].getMessage());
  }

  @isTest
  static void testUpdateRegistration() {
    Test.startTest();
    Contact c1 = testData.createContact(false);
    c1.email = 'test@afdskajsdfkjfd3233.com';
    insert c1;

    Account acc = testData.createAccount(true);
    Events__c ev = testData.createEvent(true);
    Contract ct = testData.createContract('012a0000001RKA9', acc.Id);
    ct.Event_Passes__c = 4;
    ct.Sponsorship_Name__c = 'Test Sponsor';
    ct.Event__c = ev.Id;
    update ct;

    Registration__c r2 = new Registration__c(
      Reg_Type__c = 'Sponsor',
      Reg_Date__c = DateTime.now().date(),
      Reg_Source__c = 'O Online',
      Registrant_Name__c = c1.Id,
      Sponsor_Company__c = 'Test Sponsor',
      Event__c = ev.Id,
      Temporary_Id__c = 'asasas2'
    );

    insert r2;
    //Test.startTest();
    r2.Sponsor_Company__c = 'Test';
    Database.SaveResult res2 = Database.update(r2, false);
    Test.stopTest();
    System.assert(res2.isSuccess());
    System.assert(res2.getErrors().size() == 0);
    //System.assertEquals(' Please supply Sponsor Company that matches one of these contracts , Test Sponsor' ,res2.getErrors()[0].getMessage());
  }

  @isTest
  static void testDeleteReg() {
    Contact c1 = testData.createContact(false);
    c1.email = 'test@afdskajsdfkjfd3233.com';
    insert c1;

    Account acc = testData.createAccount(true);
    Events__c ev = testData.createEvent(true);
    Contract ct = testData.createContract('012a0000001RKA9', acc.Id);
    ct.Event_Passes__c = 4;
    ct.Sponsorship_Name__c = 'Test Sponsor';
    ct.Event__c = ev.Id;
    update ct;

    Registration__c r2 = new Registration__c(
      Reg_Type__c = 'Sponsor',
      Reg_Date__c = DateTime.now().date(),
      Reg_Source__c = 'O Online',
      Registrant_Name__c = c1.Id,
      Sponsor_Company__c = 'Test Sponsor',
      Event__c = ev.Id
    );

    insert r2;
    Test.startTest();
    r2.Sponsor_Company__c = 'Test';
    Database.SaveResult res2 = Database.update(r2, false);
    Database.delete(r2);
    Test.stopTest();
  }

  @isTest
  static void testDeleteRegContact() {
    Contact c1 = testData.createContact(false);
    c1.email = 'test@afdskajsdfkjfd3233.com';
    insert c1;

    Account acc = testData.createAccount(true);
    Events__c ev = testData.createEvent(true);
    Contract ct = testData.createContract('012a0000001RKA9', acc.Id);
    ct.Event_Passes__c = 4;
    ct.Sponsorship_Name__c = 'Test Sponsor';
    ct.Event__c = ev.Id;
    update ct;

    Registration__c r2 = new Registration__c(
      Reg_Type__c = 'Sponsor',
      Reg_Date__c = DateTime.now().date(),
      Reg_Source__c = 'O Online',
      Registrant_Name__c = c1.Id,
      Sponsor_Company__c = 'Test Sponsor',
      Event__c = ev.Id
    );

    insert r2;
    Test.startTest();
    r2.Sponsor_Company__c = 'Test';
    Database.SaveResult res2 = Database.update(r2, false);
    r2.Registrant_Name__c = null;
    Database.update(r2, false);
    Test.stopTest();
  }
}

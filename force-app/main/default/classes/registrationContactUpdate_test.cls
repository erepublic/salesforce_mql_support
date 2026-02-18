@isTest
private class registrationContactUpdate_test {
  static testMethod void myUnitTest() {
    Account a = new Account(
      Name = 'e.Republic - Subscriptions',
      type = 'Customer'
    );
    insert a;

    Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];

    User u = new User(
      alias = 'u1',
      email = 'foo@test.com',
      lastname = 'Smith',
      firstname = 'John',
      username = 'testuser1@erepublic.com',
      emailencodingkey = 'UTF-8',
      languagelocalekey = 'en_US',
      localesidkey = 'en_US',
      TimeZoneSidKey = 'America/Los_Angeles',
      ProfileId = p.Id
    );
    insert u;

    Events__c event = new Events__c(
      Brand__c = 'CDE',
      Name = 'Paid Event',
      Display_Name__c = 'Paid Event',
      OwnerId = u.Id,
      Public_Reg_Fee__c = 200,
      Event_Start_Date__c = date.Today(),
      Event_End_Date__c = date.Today(),
      Banner_URL__c = 'http://www.test.com',
      Web_Status__c = 'live',
      Venue_State__c = 'CA'
    );
    insert event;

    Contact contact = testData.createContact();

    Registration__c reg = new Registration__c(
      Registrant_Name__c = contact.Id,
      Event__c = event.Id,
      Reg_Type__c = 'Govt Attendee',
      Reg_Date__c = date.Today(),
      Reg_Source__c = 'O Online'
    );
    insert reg;

    Contact c2 = [
      SELECT EE_Tracking_Interested__c, EE_Tracking_Past_Participant__c
      FROM Contact
      WHERE Id = :contact.Id
    ];

    System.assert(c2.EE_Tracking_Interested__c == 'CA');
    System.assert(c2.EE_Tracking_Past_Participant__c == 'CA');
  }

  static testMethod void contactWithValuesTest() {
    Account a = new Account(
      Name = 'e.Republic - Subscriptions',
      type = 'Customer'
    );
    insert a;

    Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];

    User u = new User(
      alias = 'u1',
      email = 'foo@test.com',
      lastname = 'Smith',
      firstname = 'John',
      username = 'testuser1@erepublic.com',
      emailencodingkey = 'UTF-8',
      languagelocalekey = 'en_US',
      localesidkey = 'en_US',
      TimeZoneSidKey = 'America/Los_Angeles',
      ProfileId = p.Id
    );
    insert u;

    Events__c event = new Events__c(
      Brand__c = 'GOVERNING',
      Name = 'Paid Event',
      Display_Name__c = 'Paid Event',
      OwnerId = u.Id,
      Public_Reg_Fee__c = 200,
      Event_Start_Date__c = date.Today(),
      Event_End_Date__c = date.Today(),
      Banner_URL__c = 'http://www.test.com',
      Web_Status__c = 'live',
      Venue_State__c = 'CA'
    );
    insert event;

    Contact contact = testData.createContact(false);
    contact.EE_Tracking_Interested__c = 'Test';
    contact.EE_Tracking_Past_Participant__c = 'Test';
    insert contact;

    Registration__c reg = new Registration__c(
      Registrant_Name__c = contact.Id,
      Event__c = event.Id,
      Reg_Type__c = 'Govt Attendee',
      Reg_Date__c = date.Today(),
      Reg_Source__c = 'O Online'
    );
    insert reg;

    Contact c2 = [
      SELECT EE_Tracking_Interested__c, EE_Tracking_Past_Participant__c
      FROM Contact
      WHERE Id = :contact.Id
    ];

    System.assert(c2.EE_Tracking_Interested__c == 'CA;Test');
    System.assert(c2.EE_Tracking_Past_Participant__c == 'CA;Test');
  }
}

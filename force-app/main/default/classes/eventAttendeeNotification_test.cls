@isTest
private class eventAttendeeNotification_test {
  static testMethod void triggerTest1() {
    Events__c evt = new Events__c(
      Name = 'Test Event',
      Brand__c = 'Exec Events'
    );
    insert evt;
    Contact contact = testData.createContact();

    Registration__c reg = new Registration__c(
      Event__c = evt.Id,
      Registrant_Name__c = contact.Id,
      Transaction_ID__c = 4593659217L
    );
    insert reg;

    // the following lines are to test the 'registration' trigger
    reg.Exclude_From_Mailing_List__c = true;
    update reg;
    delete reg;
  }

  static testMethod void triggerTest2() {
    Events__c evt = new Events__c(
      Name = 'Test Event',
      Brand__c = 'Exec Events'
    );
    insert evt;
    Contact contact = testData.createContact();

    Registration__c reg = new Registration__c(
      Event__c = evt.Id,
      Registrant_Name__c = contact.Id,
      Reg_Type__c = 'Sponsor'
    );
    insert reg;
  }

  static testMethod void triggerTest3() {
    Events__c evt = new Events__c(Name = 'Test Event', Brand__c = 'EM');
    insert evt;
    Contact contact = testData.createContact();

    Registration__c reg = new Registration__c(
      Event__c = evt.Id,
      Registrant_Name__c = contact.Id,
      Reg_Type__c = 'Govt Attendee'
    );
    insert reg;
  }

  static testMethod void triggerTest4() {
    Events__c evt = new Events__c(Name = 'Test Event', Brand__c = 'EM');
    insert evt;
    Contact contact = testData.createContact();

    Registration__c reg = new Registration__c(
      Event__c = evt.Id,
      Registrant_Name__c = contact.Id,
      Reg_Type__c = 'Govt Attendee',
      Reg_Source__c = 'P Phone'
    );
    insert reg;
  }
}

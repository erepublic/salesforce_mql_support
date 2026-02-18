@isTest
public class Contact_Interest_Topics_test {
  public static testMethod void testAddTopics() {
    Contact c = TestData.createContact();
    c.Topics_Interested_In__c = 'Cloud;Education Technology';
    Contact_Interest_Topics.addTopics(c, 'Education Technology;Infrastructure');
    String expect = 'Cloud;Education Technology;Infrastructure';
    System.assertEquals(expect, c.Topics_Interested_In__c);
    update c;
    Contact c2 = [SELECT Topics_Interested_In__c FROM Contact WHERE Id = :c.Id];
    System.assertEquals(expect, c2.Topics_Interested_In__c);
  }

  public static testMethod void testEventReg() {
    Events__c e = TestData.createEvent(true);
    e.Contact_Interest_Topics__c = 'Education Technology;Infrastructure';
    update e;
    Contact c = TestData.createContact(false);
    c.AB_First_Name__c = 'joe';
    c.AB_Last_Name__c = 'Tester3';
    c.AB_Type__c = 'Industry';
    c.AB_Title__c = 'CEO';
    c.AB_Organization__c = 'Fancy Widgets Inc.';
    c.AB_Email__c = 'e34343@widgetsinc.com';
    c.AB_Department__c = 'office of the CEO';
    c.AB_Organization__c = 'Fancy Widgets Inc.';
    c.Topics_Interested_In__c = 'Cloud;Education Technology';
    insert c;

    Registration__c reg = new Registration__c(
      Registrant_Name__c = c.Id,
      Event__c = e.Id,
      Reg_Type__c = 'Govt Attendee',
      Reg_Date__c = date.Today(),
      Reg_Source__c = 'O Online',
      Temporary_Id__c = '_T1234567890AB'
    );
    insert reg;
    String expect = 'Cloud;Education Technology;Infrastructure';
    Contact c2 = [SELECT Topics_Interested_In__c FROM Contact WHERE Id = :c.Id];
    System.assertEquals(expect, c2.Topics_Interested_In__c);
  }

  public static testMethod void testSubscription() {
    Publication__c pub = TestData.createPublication();
    String topics = 'Cloud;Education Technology';
    pub.Contact_Interest_Topics__c = topics;
    update pub;
    Subscription__c sub = TestData.createSubscription(pub.Id);
    Contact c = [
      SELECT Id, Topics_Interested_In__c
      FROM Contact
      WHERE Id = :sub.Subscriber__c
    ];
    System.assertEquals(topics, c.Topics_Interested_In__c);
  }
}

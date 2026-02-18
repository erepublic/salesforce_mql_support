@isTest
public with sharing class contact_prevent_dup_email_test {
  public static testMethod void testDupe() {
    Account a = testData.createAccount(true);
    String randomEmail = testData.randomStr() + '_tester@test.com';
    Contact contact1 = new Contact(
      FirstName = 'Gerard T.',
      LastName = 'Tester',
      Email = randomEmail,
      AccountId = a.Id,
      MailingPostalCode = '95816',
      MailingState = 'CA',
      MailingCity = 'Folsom'
    );
    insert contact1;

    Contact contact2 = new Contact(
      FirstName = 'Gerardo F.',
      LastName = 'Tester',
      Email = randomEmail,
      AccountId = a.Id,
      MailingPostalCode = '95816',
      MailingState = 'CA',
      MailingCity = 'Folsom'
    );
    DmlException expectedException;
    try {
      insert contact2;
    } catch (DmlException dmx) {
      expectedException = dmx;
    }

    System.assertEquals(
      true,
      expectedException.getMessage()
        .contains('A Contact with this email address already exists')
    );

    String randomEmail2 = testData.randomStr() + '_tester@test.com';
    Contact contact3 = new Contact(
      FirstName = 'Gerardo F.',
      LastName = 'Tester',
      Email = randomEmail2,
      AccountId = a.Id,
      MailingPostalCode = '95816',
      MailingState = 'CA',
      MailingCity = 'Folsom'
    );
    insert contact3;
    contact3.Email = randomEmail;
    DmlException expectedException2;
    try {
      update contact3;
    } catch (DmlException dmx) {
      expectedException2 = dmx;
    }

    System.assertEquals(
      true,
      expectedException2.getMessage()
        .contains('A Contact with this email address already exists')
    );
  }
}

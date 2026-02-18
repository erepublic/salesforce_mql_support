@isTest
public class contact_before_insert_update_delete_test {
  static testMethod void test_contact_clear_subscribed_on_optout_trigger() {
    Contact c = testData.createContact(true);

    c.Email_Group_News_GT_GovTech_Daily__c = 'Subscribed (Customer)';
    c.HasOptedOutOfEmail = true;
    update c;
    c = [
      SELECT Id, Email_Group_News_GT_GovTech_Daily__c
      FROM Contact
      WHERE Id = :c.Id
    ];
    System.assertEquals(null, c.Email_Group_News_GT_GovTech_Daily__c);

    c.Email_Group_News_GT_GovTech_Daily__c = 'Subscribed (Customer)';
    update c;
    c = [
      SELECT Id, Email_Group_News_GT_GovTech_Daily__c
      FROM Contact
      WHERE Id = :c.Id
    ];
    System.assertEquals(
      'Subscribed (Customer)',
      c.Email_Group_News_GT_GovTech_Daily__c
    );
  }

  static testMethod void test() {
    // test duplicate email
    Contact c1 = testData.createContact(false);
    c1.email = 'dupemail@test.com';
    insert c1;

    Test.startTest();
    Contact c2 = testData.createContact(false);
    c2.email = 'dupemail@test.com';
    try {
      insert c2;
    } catch (DmlException e) {
      //Assert Status Code     email is not unique
      System.assertEquals(
        'FIELD_CUSTOM_VALIDATION_EXCEPTION',
        e.getDmlStatusCode(0)
      );
    } //catch

    c2.email = 'nodupemail@test.com';
    c2.AccountId = null;
    try {
      insert c2;
    } catch (DmlException e) {
      //Assert Status Code    needs  account
      System.assertEquals(
        'FIELD_CUSTOM_VALIDATION_EXCEPTION',
        e.getDmlStatusCode(0)
      );
    } //catch

    c2.AccountId = c1.AccountId;
    insert c2; // now it works

    //   test the update
    c2.email = 'dupemail@test.com';
    try {
      update c2;
    } catch (DmlException e) {
      System.assertEquals(
        'FIELD_CUSTOM_VALIDATION_EXCEPTION',
        e.getDmlStatusCode(0)
      );
    } //catch

    c2.email = 'nodupemail@test.com';
    c2.AccountId = null;
    try {
      update c2;
    } catch (DmlException e) {
      System.assertEquals(
        'FIELD_CUSTOM_VALIDATION_EXCEPTION',
        e.getDmlStatusCode(0)
      );
    } //catch

    Contact c3 = testData.createContact();
    c3.email = 'testmerge1@test.com';
    //c3.absorblms__Sync_with_Absorb__c = true;
    //c3.Absorb_Department__c = 'test';
    update c3;

    Contact c4 = testData.createContact();
    c4.email = 'testmerge2@test.com';
    update c4;

    try {
      merge c3 c4;
    } catch (DmlException dmx) {
      System.assertEquals(
        'deleting for this contact is prevented because Sync with Absorb is checked',
        dmx.getMessage()
      );
    }

    Test.stopTest();
  }
}

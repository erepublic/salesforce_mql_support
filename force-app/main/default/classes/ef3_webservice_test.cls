@isTest
public class ef3_webservice_test {
  public static testMethod void test() {
    ef3_webservice.getMagazineRenewals('!', 'a0Qa000000J4s63EAB');
  }

  public static testMethod void test2() {
    datetime myDateTime = datetime.now();
    Contact c = testData.createContact(false);
    c.CMS_Needs_to_Sync__c = myDateTime;
    insert c;
    Contact[] c2 = [
      SELECT Id, CMS_Needs_to_Sync__c
      FROM Contact
      WHERE Id = :c.Id
      LIMIT 1
    ];
    ef3_webservice.resetSyncFlag(
      'Contact',
      c.Id,
      '123',
      c2[0].CMS_Needs_to_Sync__c
    );
  }
  public static testMethod void test3() {
    datetime myDateTime = datetime.now();
    Account c = testData.createAccount(false);
    c.CMS_Needs_to_Sync__c = myDateTime;

    insert c;
    ef3_webservice.resetSyncFlag('Account', c.Id, '123', myDateTime);
  }
}

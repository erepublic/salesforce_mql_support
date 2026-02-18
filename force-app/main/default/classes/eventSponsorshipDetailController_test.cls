/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an organization are executed whenever Apex code is deployed
 * to a production organization to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production organization. In addition, all triggers must have some code coverage.
 *
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the organization size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest(seeAllData=true)
private class eventSponsorshipDetailController_test {
  static testMethod void myUnitTest() {
    Test.setCurrentPage(new PageReference('/apex/event_sp_report'));

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

    Events__c evt = new Events__c(
      Name = 'Paid Event',
      Registration_Open__c = true,
      Display_Name__c = 'Paid Event',
      OwnerId = u.Id,
      Public_Reg_Fee__c = 200,
      Event_Start_Date__c = date.Today(),
      Event_End_Date__c = date.Today(),
      Banner_URL__c = 'http://www.test.com',
      Web_Status__c = 'live'
    );
    insert evt;

    ApexPages.currentPage().getParameters().put('id', evt.Id);
    eventSponsorshipDetailController controller = new eventSponsorshipDetailController();
  }
}

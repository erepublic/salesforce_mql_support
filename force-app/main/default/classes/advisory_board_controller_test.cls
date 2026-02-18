@isTest(seeAllData=true)
public with sharing class advisory_board_controller_test {
  static testMethod void test() {
    Events__c event = testData.createEventWithRegistrations(); // this method also add 2 adboard members
    event.Advisory_Board_1__c = System.today();
    event.Advisory_Board_2__c = System.today();
    event.Advisory_Board_3__c = System.today();
    event.Advisory_Board_4__c = System.today();
    update event;

    Contact contact3 = testData.createContact(false);
    contact3.AB_Salutation__c = 'Dr.';
    contact3.AB_First_Name__c = 'joe';
    contact3.AB_Middle_Name__c = 'J.';
    contact3.AB_Last_Name__c = 'Tester';
    contact3.AB_Suffix__c = 'III';
    contact3.AB_Type__c = 'Industry';
    contact3.AB_Title__c = 'CEO';
    contact3.AB_Phone__c = '9161234567';
    contact3.AB_Email__c = 'CEO@widgetsinc.com';
    contact3.AB_Department__c = 'office of the CEO';
    contact3.AB_Organization__c = 'Fancy Widgets Inc.';
    insert contact3;

    Advisory_Board_Member__c a1 = new Advisory_Board_Member__c(
      Event__c = event.Id,
      Contact__c = contact3.Id
    );
    insert a1;

    ApexPages.currentPage().getParameters().put('id', event.Id);
    ApexPages.currentPage().getParameters().put('member_type', 'Industry');

    ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(
      Database.getQueryLocator([SELECT Id FROM Events__c LIMIT 2])
    );

    ApexPages.StandardController sc = new ApexPages.StandardController(event);
    //advisory_board_controller c =  new advisory_board_controller(  ssc );
    advisory_board_controller c = new advisory_board_controller();

    System.debug(
      'testting: id_to_be_deleted: ' + contact3.Id + ' ab_id: ' + a1.Id
    );

    c.init();

    c.getMembers();
    c.getIndustryMembers();
    c.getGovernmentMembers();
    //c.getPages();
    c.getCoverSheets();
    c.makePages();
    c.makePageHeader('GOVERNMENT');
    c.makePageHeader('INDUSTRY');
    c.makePageFooter(1);

    //c.getGovernmentPages();
    //c.getIndustryPages();

    c.save();
    c.cancel();
    c.id_to_be_deleted = contact3.Id;
    c.delete_ab();

    ApexPages.currentPage().getParameters().put('roster', '1');
    c.init();

    ApexPages.currentPage().getParameters().put('coverSheet', '2');
    c.init();
    c.getCoverSheets();

    ApexPages.currentPage().getParameters().put('coverSheet', '3');
    c.init();
    c.getCoverSheets();

    ApexPages.currentPage().getParameters().put('coverSheet', '4');
    c.init();
    c.getCoverSheets();
  }
}

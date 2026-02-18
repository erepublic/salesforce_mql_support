@isTest(seeAllData=true)
public class eventPages_test {
  static testMethod void eventPages2_test() {
    PageReference pageRef = Page.events_by_quarter;
    Test.setCurrentPage(pageRef);
    eventData_test dataPopulator = new eventData_test();
    ApexPages.currentPage().getParameters().put('year', '2020');
    eventHotPacketController controller1;

    ApexPages.currentPage().getParameters().put('quarter', '1');
    controller1 = new eventHotPacketController();

    System.assert(controller1.HotSheets != null);
    System.assert(controller1.Quarter != null);
    System.assert(controller1.Year != null);
    System.assert(controller1.startDate != null);
    System.assert(controller1.endDate != null);
    System.assert(controller1.WonTotal != null);
    System.assert(controller1.HotTotal != null);
    System.assert(controller1.WarmTotal != null);
    System.assert(controller1.MissingTotal != null);
    System.assert(controller1.TargetTotal != null);
    System.assert(controller1.RevenueDifference != null);
    System.assert(controller1.UpdateDate != null);
  }

  static testMethod void eventPages3_test() {
    PageReference pageRef = Page.events_by_quarter;
    Test.setCurrentPage(pageRef);
    eventData_test dataPopulator = new eventData_test();
    ApexPages.currentPage().getParameters().put('year', '2020');
    eventHotPacketController controller1;

    ApexPages.currentPage().getParameters().put('quarter', '2');
    controller1 = new eventHotPacketController();
  }

  static testMethod void eventPages4_test() {
    PageReference pageRef = Page.events_by_quarter;
    Test.setCurrentPage(pageRef);
    eventData_test dataPopulator = new eventData_test();
    ApexPages.currentPage().getParameters().put('year', '2020');
    eventHotPacketController controller1;

    ApexPages.currentPage().getParameters().put('quarter', '3');
    controller1 = new eventHotPacketController();
  }

  static testMethod void eventPages5_test() {
    PageReference pageRef = Page.events_by_quarter;
    Test.setCurrentPage(pageRef);
    eventData_test dataPopulator = new eventData_test();
    ApexPages.currentPage().getParameters().put('year', '2020');
    eventHotPacketController controller1;

    ApexPages.currentPage().getParameters().put('quarter', '4');
    controller1 = new eventHotPacketController();
  }

  static testMethod void eventPages6_test() {
    PageReference pageRef = Page.events_by_quarter;
    Test.setCurrentPage(pageRef);
    eventData_test dataPopulator = new eventData_test();
    ApexPages.currentPage().getParameters().put('year', '2020');
    eventSponsorshipController controller2;
    // eventSponsorshipController

    ApexPages.currentPage().getParameters().put('quarter', '0');
    controller2 = new eventSponsorshipController();
    /*
		System.assert(controller2.getQEvents(0) != null);
		System.assert(controller2.getQEvents(1) != null);
		System.assert(controller2.getQEvents(2) != null);
		System.assert(controller2.getQEvents(3) != null);
		*/
  }

  static testMethod void eventPages7_test() {
    PageReference pageRef = Page.events_by_quarter;
    Test.setCurrentPage(pageRef);
    eventData_test dataPopulator = new eventData_test();
    ApexPages.currentPage().getParameters().put('year', '2020');
    eventSponsorshipController controller2;

    ApexPages.currentPage().getParameters().put('quarter', '1');
    controller2 = new eventSponsorshipController();
    //System.assert(controller2.getQEvents(1) != null);
  }

  static testMethod void eventPages8_test() {
    PageReference pageRef = Page.events_by_quarter;
    Test.setCurrentPage(pageRef);
    eventData_test dataPopulator = new eventData_test();
    ApexPages.currentPage().getParameters().put('year', '2020');
    eventSponsorshipController controller2;

    ApexPages.currentPage().getParameters().put('quarter', '2');
    controller2 = new eventSponsorshipController();
    /*
		System.assert(controller2.getQEvents(0) != null);
		System.assert(controller2.getQEvents(1) != null);
		System.assert(controller2.getQEvents(2) != null);
		System.assert(controller2.getQEvents(3) != null);
		*/
  }

  static testMethod void eventPages9_test() {
    PageReference pageRef = Page.events_by_quarter;
    Test.setCurrentPage(pageRef);
    eventData_test dataPopulator = new eventData_test();
    ApexPages.currentPage().getParameters().put('year', '2020');
    eventSponsorshipController controller2;

    ApexPages.currentPage().getParameters().put('quarter', '3');
    controller2 = new eventSponsorshipController();
    /*
		System.assert(controller2.getQEvents(0) != null);
		System.assert(controller2.getQEvents(1) != null);
		System.assert(controller2.getQEvents(2) != null);
		System.assert(controller2.getQEvents(3) != null);
		*/
  }

  static testMethod void eventPages10_test() {
    PageReference pageRef = Page.events_by_quarter;
    Test.setCurrentPage(pageRef);
    eventData_test dataPopulator = new eventData_test();
    ApexPages.currentPage().getParameters().put('year', '2020');
    eventSponsorshipController controller2;

    ApexPages.currentPage().getParameters().put('quarter', '4');
    controller2 = new eventSponsorshipController();
    /*
		System.assert(controller2.getQEvents(0) != null);
		System.assert(controller2.getQEvents(1) != null);
		System.assert(controller2.getQEvents(2) != null);
		System.assert(controller2.getQEvents(3) != null);
		*/
  }

  static testMethod void eventPages11_test() {
    PageReference pageRef = Page.events_by_quarter;
    Test.setCurrentPage(pageRef);
    eventData_test dataPopulator = new eventData_test();
    ApexPages.currentPage().getParameters().put('year', '2020');
    eventSponsorshipController controller2;

    // eventSponsorshipDetailController
    // 2011 Event
    Events__c e1 = new Events__c(
      Name = 'Test Event 2011',
      Nickname__c = 'TE2011',
      Event_Start_Date__c = date.newInstance(2011, 1, 1),
      Event_End_Date__c = date.newInstance(2011, 1, 1),
      Sponsorship_Revenue_Target__c = 2000
    );
    insert e1;
    Events__c event = [SELECT Id FROM Events__c WHERE Name = 'Test Event 2011'];
    ApexPages.currentPage().getParameters().put('id', event.id);
    eventSponsorshipDetailController controller3;
    controller3 = new eventSponsorshipDetailController();
    //System.assert(controller3.HotSheet != null);
  }

  static testMethod void QuarterListing_test() {
    EventSponsorshipController esp = new EventSponsorshipController();
    List<Events__c> e = esp.getEvents(2020, 4);
    EventSponsorshipController.QuarterListing escql = new EventSponsorshipController.QuarterListing(
      4,
      2020,
      e
    );
  }
}

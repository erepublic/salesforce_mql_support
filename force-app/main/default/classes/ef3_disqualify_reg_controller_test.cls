@isTest(seeAllData=true)
public with sharing class ef3_disqualify_reg_controller_test {
  static testMethod void test() {
    Events__c event = testData.createEventWithRegistrations();
    ApexPages.currentPage().getParameters().put('id', event.Id);

    ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(
      Database.getQueryLocator([SELECT Id FROM Events__c LIMIT 2])
    );

    ApexPages.StandardController sc = new ApexPages.StandardController(event);
    ef3_disqualify_registrations_controller c = new ef3_disqualify_registrations_controller(
      ssc
    );

    String name = c.getEventName();
    c.getEventId();
    c.save();
    c.getRegistrations();
  }
}

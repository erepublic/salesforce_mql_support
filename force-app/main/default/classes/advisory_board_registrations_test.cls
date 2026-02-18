@isTest(seeAllData=true)
public with sharing class advisory_board_registrations_test {
  static testMethod void test() {
    Events__c event = testData.createEventWithRegistrations(); // this method also add 2 adboard members
    System.debug('eventid: ' + event.Id);
    String response = advisory_board_registrations.createRegistrations(
      event.Id
    );
    System.debug(response);
  }
}

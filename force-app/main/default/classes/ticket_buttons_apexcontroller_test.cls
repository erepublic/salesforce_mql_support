@isTest
public with sharing class ticket_buttons_apexcontroller_test {
  static testMethod void test() {
    Ticket__c t = testData.createTicket();
    ticket_buttons_apexcontroller.close_ticket(t.Id);
  }
}

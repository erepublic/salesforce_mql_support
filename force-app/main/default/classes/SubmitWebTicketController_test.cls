/*
Michael Tel 7/8/2015
finally created a test class for this controller
*/
@isTest
public with sharing class SubmitWebTicketController_test {
  static testMethod void test() {
    ID oneformAdminId = '005a000000B8cGM'; //user

    //ApexPages.currentPage().getParameters().put('id', webinar.Id);

    SubmitWebTicketController ctr = new SubmitWebTicketController();

    Ticket__c ticket = (Ticket__c) ctr.getTheDarnTicket();
    ctr.getUser();
    ctr.getErepublicUsers();
    ctr.getDevelopers();
    ctr.checkForm();
  }
}

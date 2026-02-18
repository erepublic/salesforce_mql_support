@isTest
public with sharing class SubmitRFPTicketController_test {
  static testMethod void test() {
    ID oneformAdminId = '005a000000B8cGM'; //user

    //ApexPages.currentPage().getParameters().put('id', webinar.Id);

    SubmitRFPTicketController ctr = new SubmitRFPTicketController();

    Ticket__c ticket = (Ticket__c) ctr.getTheRFPTicket();
    ctr.getUser();
    ctr.getErepublicUsers();
    ctr.getAccount();
    ctr.getRFPAssignee();
    ctr.checkForm();
  }
}

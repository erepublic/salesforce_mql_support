@isTest
public class eventExpenseController_test {
  public static testMethod void testMyController() {
    Test.setCurrentPage(new PageReference('apex/event_expenses_xl_download'));
    ApexPages.currentPage().getParameters().put('id', 'a0m14000007NqF0'); //'a1u14000003bYCz'

    eventExpenseController c = new eventExpenseController();
    //c.getcs();
    List<c2g__codaTransactionLineItem__c> cs = c.cs;
    System.Assert(cs.size() > 0);

    System.Assert(c.testHelper(6) > 0);
  }
}

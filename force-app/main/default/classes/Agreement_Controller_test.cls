@isTest(SeeAllData=true)
public class Agreement_Controller_test {
  static testMethod void test() {
    Agreement__c a = testData.createAgreement();
    Agreement_Controller.sendEmail(a.Id);
    Agreement_Controller.sendEmail(a.Id);
    Agreement_Controller.createLink(a.Id);
  }
}

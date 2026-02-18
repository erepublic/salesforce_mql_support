@isTest(SeeAllData=true)
public class contractUpdateRoles_test {
  static testMethod void contractUpdateRoles() {
    Account a = testData.createAccount();
    Opportunity o = testData.createOpportunity();
    Contract c1 = testData.createContract(testData.EVENT_CONTRACT, a.Id);
    c1.Primary_Opportunity__c = o.Id;
    update c1;

    // c2 is the master Contract with an attached file
    Contract c2 = testData.createContract(testData.EVENT_CONTRACT, a.Id);
    c2.Master_Contract__c = true;
    c2.Primary_Opportunity__c = o.Id;
    update c2;
    testData.attachFile(c2.Id);

    String result = contractUpdateRoles.updateRolesAndAttachments(c1.Id, o.Id);
    System.debug('result:::' + result);
  }
}

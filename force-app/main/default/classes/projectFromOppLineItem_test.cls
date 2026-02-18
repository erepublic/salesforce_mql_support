@isTest(SeeAllData=true)
public with sharing class projectFromOppLineItem_test {
  static testMethod void testProjectFromOppLineItem() {
    Account a = testData.createAccount();
    testData.Retvals res = testData.createOpportunityForAccount(a.Id, 1);
    Id itemId = res.lineItem.Id;
    Boolean exceptionOccured = false;

    // we call the funcion but account name is missing, should throw an error
    try {
      projectFromOppLineItem.createProject(itemId);
    } catch (AuraHandledException e) {
      exceptionOccured = true;
    }
    System.assert(
      exceptionOccured,
      'Didnt throw exception saying account name was missing'
    );

    // now we set te account name
    res.lineItem.Project_Name_Text__c = 'Some Project Name';
    update res.lineItem;

    // and we try a second time, this time it sould succeed
    String res2 = projectFromOppLineItem.createProject(itemId);
    OpportunityLineItem l = [
      SELECT Id, Project_Name__c
      FROM OpportunityLineItem
      WHERE Id = :itemId
    ];
    System.assertEquals(
      false,
      String.isBlank(l.Project_Name__c),
      'Project Not Created'
    );

    // now we try a third time but the project is already created so it should fail
    Boolean alreadyCreatedException = false;
    try {
      projectFromOppLineItem.createProject(itemId); // itemId '00k5Y00001VcH0PQAV'
    } catch (AuraHandledException e) {
      alreadyCreatedException = true;
    }
    System.assert(
      alreadyCreatedException,
      'Expected already created exception occured.'
    );
  }
}

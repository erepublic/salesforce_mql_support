@isTest(SeeAllData=true)
public class OpportunityMergeController_test {
  static testMethod void testGetOpportunity() {
    Opportunity opp = testData.createOpportunity();
    Opportunity testOpp = OpportunityMergeController.getOpportunity(opp.Id);
    System.assertEquals(testOpp.Id, opp.Id);
    System.assertEquals(testOpp.Name, opp.Name);
  }
  static testMethod void testSearchOpportunities() {
    testData.createOpportunity();
    testData.createOpportunity();
    testData.createOpportunity();
    List<Opportunity> searchResults = OpportunityMergeController.searchOpportunities(
      'michael test opportunity'
    );
    System.assertEquals(searchResults.size(), 3);
  }
  static testMethod void testMergeOpportunities() {
    Opportunity winnerOpp = testData.createOpportunity();
    Opportunity loserOpp = testData.createOpportunity();

    // Add agreements, contracts, files and contact roles
    Agreement__c ag = new Agreement__c(
      Opportunity__c = loserOpp.Id,
      Description__c = 'Losing Agreement',
      Status__c = 'Draft'
    );

    insert ag;

    Account ac = testData.createAccount();

    Contract ct = new Contract(
      Name = 'Test Losing Contract',
      Status = 'Draft',
      Primary_Opportunity__c = loserOpp.Id,
      AccountId = ac.Id
    );

    insert ct;

    testData.attachFile(loserOpp.Id);

    List<Id> losers = new List<Id>{ loserOpp.Id };
    String loserIds = String.join(losers, ',');
    OpportunityMergeController.mergeOpportunities(winnerOpp.Id, loserIds);

    // check files
    System.assertEquals(
      1,
      database.countQuery(
        'SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId =\'' +
          winnerOpp.Id +
          '\''
      )
    );
    // check contract
    System.assertEquals(
      false,
      [SELECT Id FROM Contract WHERE Primary_Opportunity__c = :winnerOpp.Id]
        .isEmpty()
    );
    // check that agreements were moved over
    System.assertEquals(
      false,
      [SELECT Id FROM Agreement__c WHERE Opportunity__c = :winnerOpp.Id]
        .isEmpty()
    );
    // check that the OpportunityLineItems have been added.
    System.assertEquals(
      10,
      database.countQuery(
        'SELECT COUNT() FROM OpportunityLineItem WHERE OpportunityId =\'' +
          winnerOpp.Id +
          '\''
      )
    );
    // check that the Opportunity has been deleted.
    System.assertEquals(
      true,
      [SELECT Id FROM Opportunity WHERE Id = :loserOpp.Id].isEmpty()
    );
  }
}

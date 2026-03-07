@isTest
private class MqlSummaryRegenerationDeployTest {
  private class MockAccepted implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(202);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"accepted":true,"jobId":"job-123"}');
      return res;
    }
  }

  private static void upsertTestSecrets() {
    upsert new MqlSecrets__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      ApiGatewayApiKey__c = 'test-apigw-key'
    );
  }

  private static Id createContactId() {
    Account a = new Account(Name = 'MQL Summary Deploy Test Account');
    insert a;
    Contact c = new Contact(LastName = 'Deploy Test Contact', AccountId = a.Id);
    insert c;
    return c.Id;
  }

  @isTest
  static void flowStyleForceOverwrite_EnqueuesForExistingSummary() {
    upsertTestSecrets();
    Test.setMock(HttpCalloutMock.class, new MockAccepted());

    MQL__c mql = new MQL__c(
      Contact__c = createContactId(),
      Lead_Source__c = 'Email',
      Engagement_AI_Summary__c = '<p>existing</p>'
    );
    insert mql;

    MqlSummarizerAdmin.Request req = new MqlSummarizerAdmin.Request();
    req.mqlId = mql.Id;
    req.forceOverwrite = true;

    Test.startTest();
    MqlSummarizerAdmin.regenerateFromFlow(
      new List<MqlSummarizerAdmin.Request>{ req }
    );
    Test.stopTest();

    MQL__c reloaded = [
      SELECT Engagement_AI_Summary__c
      FROM MQL__c
      WHERE Id = :mql.Id
      LIMIT 1
    ];
    System.assertEquals('<p>existing</p>', reloaded.Engagement_AI_Summary__c);
  }
}

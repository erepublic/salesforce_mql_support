@isTest
public class MqlSummarizerCalloutTest {
  private static void upsertTestSecrets() {
    upsert new MqlSecrets__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      ApiGatewayApiKey__c = 'test-apigw-key'
    );
  }

  private static Id createContactId() {
    Account a = new Account(Name = 'Test Account');
    insert a;
    Contact c = new Contact(LastName = 'Test Contact', AccountId = a.Id);
    insert c;
    return c.Id;
  }

  private class MockAccepted implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      // Basic contract checks: POST JSON + API key header.
      System.assertEquals('POST', req.getMethod());
      System.assertEquals('application/json', req.getHeader('Content-Type'));
      System.assert(
        String.isNotBlank(req.getHeader('x-api-key')),
        'Expected x-api-key header'
      );
      System.assertEquals('test-apigw-key', req.getHeader('x-api-key'));
      System.assert(
        req.getEndpoint().contains('/summarize'),
        'Expected /summarize endpoint'
      );

      HttpResponse res = new HttpResponse();
      res.setStatusCode(202);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"accepted":true,"jobId":"job-123"}');
      return res;
    }
  }

  @isTest
  static void insertsThresholdMql_WritesSummary() {
    upsertTestSecrets();
    Test.setMock(HttpCalloutMock.class, new MockAccepted());

    Id contactId = createContactId();

    MQL__c m = new MQL__c(
      Contact__c = contactId,
      Lead_Source__c = 'Fit and Behavior Threshold Reached'
    );
    insert m;

    Test.startTest();
    MqlSummarizerCallout.triggerSummarization(new Set<Id>{ m.Id });
    Test.stopTest();

    MQL__c mql = [
      SELECT Engagement_AI_Summary__c
      FROM MQL__c
      WHERE Id = :m.Id
    ];
    System.assertEquals(
      null,
      mql.Engagement_AI_Summary__c,
      'Summaries are now written asynchronously via Lambda callback'
    );
  }

  @isTest
  static void insertNonThresholdMql_DoesNotCallout() {
    // If a callout happens, the test will fail because no mock is registered.
    Id contactId = createContactId();
    MQL__c m = new MQL__c(Contact__c = contactId, Lead_Source__c = 'Email');
    insert m;

    Test.startTest();
    MqlSummarizerCallout.triggerSummarization(new Set<Id>{ m.Id });
    Test.stopTest();

    MQL__c mql = [
      SELECT Engagement_AI_Summary__c
      FROM MQL__c
      WHERE Id = :m.Id
    ];
    System.assertEquals(null, mql.Engagement_AI_Summary__c);
  }

  @isTest
  static void forceOverwrite_OverwritesExistingSummary() {
    upsertTestSecrets();
    Test.setMock(HttpCalloutMock.class, new MockAccepted());
    Id contactId = createContactId();

    // Create threshold MQL with existing summary.
    MQL__c m = new MQL__c(
      Contact__c = contactId,
      Lead_Source__c = 'Fit and Behavior Threshold Reached',
      Engagement_AI_Summary__c = '<p>existing</p>'
    );
    insert m;

    Test.startTest();
    MqlSummarizerCallout.triggerSummarizationForce(new Set<Id>{ m.Id });
    Test.stopTest();

    MQL__c reloaded = [
      SELECT Engagement_AI_Summary__c
      FROM MQL__c
      WHERE Id = :m.Id
      LIMIT 1
    ];
    System.assertEquals(
      '<p>existing</p>',
      reloaded.Engagement_AI_Summary__c,
      'Existing summary remains until async callback writes back'
    );
  }

  @isTest
  static void adminInvocable_ForceOverwrite_WritesSummary() {
    upsertTestSecrets();
    Test.setMock(HttpCalloutMock.class, new MockAccepted());
    Id contactId = createContactId();

    MQL__c m = new MQL__c(
      Contact__c = contactId,
      Lead_Source__c = 'Fit and Behavior Threshold Reached',
      Engagement_AI_Summary__c = '<p>existing</p>'
    );
    insert m;

    MqlSummarizerAdmin.Request req = new MqlSummarizerAdmin.Request();
    req.mqlId = m.Id;
    req.forceOverwrite = true;

    Test.startTest();
    MqlSummarizerAdmin.regenerateFromFlow(
      new List<MqlSummarizerAdmin.Request>{ req }
    );
    Test.stopTest();

    MQL__c reloaded = [
      SELECT Engagement_AI_Summary__c
      FROM MQL__c
      WHERE Id = :m.Id
      LIMIT 1
    ];
    System.assertEquals('<p>existing</p>', reloaded.Engagement_AI_Summary__c);
  }

  @isTest
  static void adminInvocable_NonForce_WritesWhenBlank() {
    upsertTestSecrets();
    Test.setMock(HttpCalloutMock.class, new MockAccepted());
    Id contactId = createContactId();

    MQL__c m = new MQL__c(
      Contact__c = contactId,
      Lead_Source__c = 'Fit and Behavior Threshold Reached'
    );
    insert m;

    MqlSummarizerAdmin.Request req = new MqlSummarizerAdmin.Request();
    req.mqlId = m.Id;
    req.forceOverwrite = false;

    Test.startTest();
    MqlSummarizerAdmin.regenerateFromFlow(
      new List<MqlSummarizerAdmin.Request>{ req }
    );
    Test.stopTest();

    MQL__c reloaded = [
      SELECT Engagement_AI_Summary__c
      FROM MQL__c
      WHERE Id = :m.Id
      LIMIT 1
    ];
    System.assertEquals(null, reloaded.Engagement_AI_Summary__c);
  }

  @isTest
  static void adminHelper_RegenerateForce_Overwrites() {
    upsertTestSecrets();
    Test.setMock(HttpCalloutMock.class, new MockAccepted());
    Id contactId = createContactId();

    MQL__c m = new MQL__c(
      Contact__c = contactId,
      Lead_Source__c = 'Fit and Behavior Threshold Reached',
      Engagement_AI_Summary__c = '<p>existing</p>'
    );
    insert m;

    Test.startTest();
    MqlSummarizerAdmin.regenerateForce(new Set<Id>{ m.Id });
    Test.stopTest();

    MQL__c reloaded = [
      SELECT Engagement_AI_Summary__c
      FROM MQL__c
      WHERE Id = :m.Id
      LIMIT 1
    ];
    System.assertEquals('<p>existing</p>', reloaded.Engagement_AI_Summary__c);
  }

  @isTest
  static void adminInvocable_ForceOverwrite_AllowsNonThresholdMql() {
    upsertTestSecrets();
    Test.setMock(HttpCalloutMock.class, new MockAccepted());
    Id contactId = createContactId();

    MQL__c m = new MQL__c(
      Contact__c = contactId,
      Lead_Source__c = 'Email',
      Engagement_AI_Summary__c = '<p>existing</p>'
    );
    insert m;

    MqlSummarizerAdmin.Request req = new MqlSummarizerAdmin.Request();
    req.mqlId = m.Id;
    req.forceOverwrite = true;

    Test.startTest();
    MqlSummarizerAdmin.regenerateFromFlow(
      new List<MqlSummarizerAdmin.Request>{ req }
    );
    Test.stopTest();

    MQL__c reloaded = [
      SELECT Engagement_AI_Summary__c
      FROM MQL__c
      WHERE Id = :m.Id
      LIMIT 1
    ];
    System.assertEquals(
      '<p>existing</p>',
      reloaded.Engagement_AI_Summary__c,
      'Flow-driven force overwrite should enqueue even for non-threshold MQLs'
    );
  }

  @isTest
  static void forceOverwrite_AllowsNonThresholdMql_ForTesting() {
    upsertTestSecrets();
    Test.setMock(HttpCalloutMock.class, new MockAccepted());
    Id contactId = createContactId();

    MQL__c m = new MQL__c(
      Contact__c = contactId,
      Lead_Source__c = 'Email',
      Engagement_AI_Summary__c = '<p>existing</p>'
    );
    insert m;

    Test.startTest();
    MqlSummarizerCallout.triggerSummarizationForce(new Set<Id>{ m.Id });
    Test.stopTest();

    MQL__c reloaded = [
      SELECT Engagement_AI_Summary__c
      FROM MQL__c
      WHERE Id = :m.Id
      LIMIT 1
    ];
    System.assertEquals('<p>existing</p>', reloaded.Engagement_AI_Summary__c);
  }
}

@isTest(SeeAllData=true)
public class MqlSummarizerCalloutTest {
  private static Id anyContactWithAccountId() {
    List<Contact> cs = [SELECT Id FROM Contact WHERE AccountId != NULL LIMIT 1];
    System.assert(
      !cs.isEmpty(),
      'Expected at least one Contact with an Account in org data'
    );
    return cs[0].Id;
  }

  private class MockOk implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      // Basic contract checks: POST JSON + API key header.
      System.assertEquals('POST', req.getMethod());
      System.assertEquals('application/json', req.getHeader('Content-Type'));
      System.assert(
        String.isNotBlank(req.getHeader('x-api-key')),
        'Expected x-api-key header'
      );
      System.assert(
        req.getEndpoint().contains('/summarize'),
        'Expected /summarize endpoint'
      );

      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"summaryHtml":"<p>ok</p>"}');
      return res;
    }
  }

  @isTest
  static void insertsThresholdMql_WritesSummary() {
    Test.setMock(HttpCalloutMock.class, new MockOk());

    Id contactId = anyContactWithAccountId();

    Test.startTest();
    insert new MQL__c(
      Contact__c = contactId,
      Lead_Source__c = 'Fit and Behavior Threshold Reached'
    );
    Test.stopTest();

    MQL__c mql = [
      SELECT Engagement_AI_Summary__c
      FROM MQL__c
      WHERE Contact__c = :contactId
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    System.assertEquals('<p>ok</p>', mql.Engagement_AI_Summary__c);
  }

  @isTest
  static void insertNonThresholdMql_DoesNotCallout() {
    // If a callout happens, the test will fail because no mock is registered.
    Id contactId = anyContactWithAccountId();

    Test.startTest();
    insert new MQL__c(Contact__c = contactId, Lead_Source__c = 'Email');
    Test.stopTest();

    MQL__c mql = [
      SELECT Engagement_AI_Summary__c
      FROM MQL__c
      WHERE Contact__c = :contactId
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    System.assertEquals(null, mql.Engagement_AI_Summary__c);
  }

  @isTest
  static void forceOverwrite_OverwritesExistingSummary() {
    Test.setMock(HttpCalloutMock.class, new MockOk());
    Id contactId = anyContactWithAccountId();

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
    System.assertEquals('<p>ok</p>', reloaded.Engagement_AI_Summary__c);
  }

  @isTest
  static void adminInvocable_ForceOverwrite_WritesSummary() {
    Test.setMock(HttpCalloutMock.class, new MockOk());
    Id contactId = anyContactWithAccountId();

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
    System.assertEquals('<p>ok</p>', reloaded.Engagement_AI_Summary__c);
  }

  @isTest
  static void adminInvocable_NonForce_WritesWhenBlank() {
    Test.setMock(HttpCalloutMock.class, new MockOk());
    Id contactId = anyContactWithAccountId();

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
    System.assertEquals('<p>ok</p>', reloaded.Engagement_AI_Summary__c);
  }

  @isTest
  static void adminHelper_RegenerateForce_Overwrites() {
    Test.setMock(HttpCalloutMock.class, new MockOk());
    Id contactId = anyContactWithAccountId();

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
    System.assertEquals('<p>ok</p>', reloaded.Engagement_AI_Summary__c);
  }

  @isTest
  static void forceOverwrite_AllowsNonThresholdMql_ForTesting() {
    Test.setMock(HttpCalloutMock.class, new MockOk());
    Id contactId = anyContactWithAccountId();

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
    System.assertEquals('<p>ok</p>', reloaded.Engagement_AI_Summary__c);
  }
}

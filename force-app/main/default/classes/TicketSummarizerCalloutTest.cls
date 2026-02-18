@isTest
public class TicketSummarizerCalloutTest {
  private static void upsertTestSecrets() {
    upsert new MqlSecrets__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      ApiGatewayApiKey__c = 'test-apigw-key'
    );
  }

  @isTest
  static void testTriggerSummarization_Success() {
    upsertTestSecrets();
    // Create test data
    Ticket__c testTicket = createTestTicket();
    insert testTicket;

    // Set up successful mock response
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());

    Test.startTest();
    Set<Id> ticketIds = new Set<Id>{ testTicket.Id };
    TicketSummarizerCallout.triggerSummarization(ticketIds);
    Test.stopTest();

    // Verify no exceptions thrown (success scenario)
    // In a real implementation, you might verify database changes or logs
  }

  @isTest
  static void testTriggerSummarization_HttpError() {
    upsertTestSecrets();
    // Create test data
    Ticket__c testTicket = createTestTicket();
    insert testTicket;

    // Set up error mock response
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseError());

    Test.startTest();
    Set<Id> ticketIds = new Set<Id>{ testTicket.Id };
    TicketSummarizerCallout.triggerSummarization(ticketIds);
    Test.stopTest();

    // Test should complete without throwing unhandled exceptions
    // Errors are caught and logged within the method
  }

  @isTest
  static void testTriggerSummarization_MultipleTickets() {
    upsertTestSecrets();
    // Create multiple test tickets
    List<Ticket__c> testTickets = new List<Ticket__c>();
    for (Integer i = 0; i < 3; i++) {
      testTickets.add(createTestTicket());
    }
    insert testTickets;

    // Set up successful mock response
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());

    Test.startTest();
    Set<Id> ticketIds = new Set<Id>();
    for (Ticket__c ticket : testTickets) {
      ticketIds.add(ticket.Id);
    }
    TicketSummarizerCallout.triggerSummarization(ticketIds);
    Test.stopTest();

    // Verify processing of multiple tickets
  }

  @isTest
  static void testTriggerSummarization_Timeout() {
    upsertTestSecrets();
    // Create test data
    Ticket__c testTicket = createTestTicket();
    insert testTicket;

    // Set up timeout mock response
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseTimeout());

    Test.startTest();
    Set<Id> ticketIds = new Set<Id>{ testTicket.Id };
    TicketSummarizerCallout.triggerSummarization(ticketIds);
    Test.stopTest();

    // Test should handle timeout gracefully
  }

  @isTest
  static void testTriggerSummarizationWithDelay_UsesProductionBranch() {
    upsertTestSecrets();
    // Force the production branch in getEnvironment() for coverage.
    TicketSummarizerCallout.testEnvironmentOverride = 'production';
    try {
      Ticket__c testTicket = createTestTicket();
      insert testTicket;

      Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());

      Test.startTest();
      TicketSummarizerCallout.triggerSummarizationWithDelay(
        new Set<Id>{ testTicket.Id }
      );
      Test.stopTest();
    } finally {
      TicketSummarizerCallout.testEnvironmentOverride = null;
    }
  }

  // Helper method to create test ticket
  private static Ticket__c createTestTicket() {
    return new Ticket__c(
      Title__c = 'Test Ticket',
      Description__c = 'Test Description',
      Status__c = 'Open',
      Priority__c = 'Medium',
      Assignee__c = UserInfo.getUserId()
    );
  }

  // Mock class for successful HTTP response
  public class MockHttpResponseSuccess implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
      // Verify request details
      System.assertEquals('POST', request.getMethod());
      System.assertEquals(
        'application/json',
        request.getHeader('Content-Type')
      );
      System.assertEquals('test-apigw-key', request.getHeader('x-api-key'));

      // Create successful response
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setBody(
        '{"status": "success", "message": "Summarization triggered"}'
      );
      response.setStatusCode(200);
      return response;
    }
  }

  // Mock class for HTTP error response
  public class MockHttpResponseError implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setBody('{"error": "Internal server error"}');
      response.setStatusCode(500);
      return response;
    }
  }

  // Mock class for timeout scenario
  public class MockHttpResponseTimeout implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
      // Avoid throwing from the mock (can hang deploy test execution in some orgs).
      // Returning a non-200 response still exercises the error/exception path.
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setBody('{"error":"timeout"}');
      response.setStatusCode(504);
      return response;
    }
  }
}

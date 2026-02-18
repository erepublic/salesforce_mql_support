@isTest
public class TicketSummarizerCalloutTest {
  @isTest
  static void testTriggerSummarization_Success() {
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
      // Simulate timeout by throwing CalloutException
      throw new CalloutException('Read timed out');
    }
  }
}

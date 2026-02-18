@isTest
public class TicketSummarizerTestUtility {
  /**
   * Creates a single test ticket with default values
   */
  public static Ticket__c createTestTicket() {
    return createTestTicket('Test Ticket', 'Open', 'Medium');
  }

  /**
   * Creates a test ticket with custom values
   */
  public static Ticket__c createTestTicket(
    String subject,
    String status,
    String priority
  ) {
    return new Ticket__c(
      Title__c = subject,
      Description__c = 'Test Description for: ' + subject,
      Status__c = status,
      Priority__c = priority,
      Assignee__c = UserInfo.getUserId()
    );
  }

  /**
   * Creates multiple test tickets
   */
  public static List<Ticket__c> createTestTickets(Integer count) {
    List<Ticket__c> tickets = new List<Ticket__c>();
    for (Integer i = 0; i < count; i++) {
      tickets.add(createTestTicket('Test Ticket ' + i, 'Open', 'Medium'));
    }
    return tickets;
  }

  /**
   * Creates test tickets with various statuses and priorities
   */
  public static List<Ticket__c> createDiverseTestTickets() {
    List<String> statuses = new List<String>{
      'Open',
      'In Progress',
      'Pending',
      'Closed'
    };
    List<String> priorities = new List<String>{
      'Low',
      'Medium',
      'High',
      'Critical'
    };

    List<Ticket__c> tickets = new List<Ticket__c>();
    for (Integer i = 0; i < 4; i++) {
      tickets.add(
        createTestTicket('Diverse Ticket ' + i, statuses[i], priorities[i])
      );
    }
    return tickets;
  }

  /**
   * Creates a test ticket with all fields populated
   */
  public static Ticket__c createFullTestTicket() {
    return new Ticket__c(
      Title__c = 'Full Test Ticket',
      Description__c = 'Comprehensive test description with multiple lines.\nThis ticket has all fields populated for thorough testing.',
      Status__c = 'Open',
      Priority__c = 'High',
      Assignee__c = UserInfo.getUserId(),
      Type__c = 'Bug' // Correct field name from field discovery
    );
  }

  /**
   * Sets up test data and returns map of created records
   */
  public static Map<String, Object> setupTestData() {
    Map<String, Object> testData = new Map<String, Object>();

    // Create single ticket
    Ticket__c singleTicket = createTestTicket();
    insert singleTicket;
    testData.put('singleTicket', singleTicket);

    // Create multiple tickets
    List<Ticket__c> multipleTickets = createTestTickets(3);
    insert multipleTickets;
    testData.put('multipleTickets', multipleTickets);

    // Create diverse tickets
    List<Ticket__c> diverseTickets = createDiverseTestTickets();
    insert diverseTickets;
    testData.put('diverseTickets', diverseTickets);

    return testData;
  }

  /**
   * Mock HTTP response classes for testing
   */
  public class SuccessHttpMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setBody(
        '{"status": "success", "message": "Summarization triggered successfully"}'
      );
      response.setStatusCode(200);
      return response;
    }
  }

  public class ErrorHttpMock implements HttpCalloutMock {
    private Integer statusCode;
    private String errorMessage;

    public ErrorHttpMock(Integer statusCode, String errorMessage) {
      this.statusCode = statusCode;
      this.errorMessage = errorMessage;
    }

    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setBody('{"error": "' + errorMessage + '"}');
      response.setStatusCode(statusCode);
      return response;
    }
  }

  public class TimeoutHttpMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
      throw new CalloutException('Read timed out');
    }
  }

  /**
   * Helper method to verify HTTP request structure
   */
  public static void verifyHttpRequest(
    HTTPRequest request,
    String expectedMethod,
    String expectedContentType
  ) {
    System.assertEquals(
      expectedMethod,
      request.getMethod(),
      'HTTP method should match'
    );
    System.assertEquals(
      expectedContentType,
      request.getHeader('Content-Type'),
      'Content-Type header should match'
    );
    System.assert(request.getBody() != null, 'Request body should not be null');
  }

  /**
   * Helper method to assert ticket field values
   */
  public static void assertTicketFields(
    Ticket__c ticket,
    String expectedSubject,
    String expectedStatus,
    String expectedPriority
  ) {
    System.assertEquals(expectedSubject, ticket.Title__c, 'Title should match');
    System.assertEquals(
      expectedStatus,
      ticket.Status__c,
      'Status should match'
    );
    System.assertEquals(
      expectedPriority,
      ticket.Priority__c,
      'Priority should match'
    );
  }
}

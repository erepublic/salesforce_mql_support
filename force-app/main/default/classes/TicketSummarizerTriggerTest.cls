@isTest
public class TicketSummarizerTriggerTest {
  @isTest
  static void testTriggerOnInsert() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerCalloutTest.MockHttpResponseSuccess()
    );

    Test.startTest();

    // Create and insert new ticket
    Ticket__c newTicket = createTestTicket();
    insert newTicket;

    Test.stopTest();

    // Verify ticket was created successfully
    Ticket__c insertedTicket = [
      SELECT Id, Title__c, Status__c
      FROM Ticket__c
      WHERE Id = :newTicket.Id
    ];
    System.assertNotEquals(null, insertedTicket);
    System.assertEquals('Test Ticket', insertedTicket.Title__c);
  }

  @isTest
  static void testTriggerOnUpdate_RelevantChanges() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerCalloutTest.MockHttpResponseSuccess()
    );

    // Create and insert ticket
    Ticket__c testTicket = createTestTicket();
    insert testTicket;

    Test.startTest();

    // Update ticket with relevant changes
    testTicket.Status__c = 'In Progress';
    testTicket.Priority__c = 'High';
    update testTicket;

    Test.stopTest();

    // Verify update was successful
    Ticket__c updatedTicket = [
      SELECT Id, Status__c, Priority__c
      FROM Ticket__c
      WHERE Id = :testTicket.Id
    ];
    System.assertEquals('In Progress', updatedTicket.Status__c);
    System.assertEquals('High', updatedTicket.Priority__c);
  }

  @isTest
  static void testTriggerOnUpdate_NoRelevantChanges() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerCalloutTest.MockHttpResponseSuccess()
    );

    // Create and insert ticket
    Ticket__c testTicket = createTestTicket();
    insert testTicket;

    Test.startTest();

    // Update ticket with non-relevant changes (fields not monitored by trigger)
    testTicket.Title__c = 'Updated Subject';
    update testTicket;

    Test.stopTest();

    // Verify update was successful
    Ticket__c updatedTicket = [
      SELECT Id, Title__c
      FROM Ticket__c
      WHERE Id = :testTicket.Id
    ];
    System.assertEquals('Updated Subject', updatedTicket.Title__c);
  }

  @isTest
  static void testTriggerOnUpdate_StatusChange() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerCalloutTest.MockHttpResponseSuccess()
    );

    // Create and insert ticket
    Ticket__c testTicket = createTestTicket();
    insert testTicket;

    Test.startTest();

    // Test each relevant field change
    testTicket.Status__c = 'Closed';
    update testTicket;

    Test.stopTest();

    // Verify status change
    Ticket__c updatedTicket = [
      SELECT Id, Status__c
      FROM Ticket__c
      WHERE Id = :testTicket.Id
    ];
    System.assertEquals('Closed', updatedTicket.Status__c);
  }

  @isTest
  static void testTriggerOnUpdate_PriorityChange() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerCalloutTest.MockHttpResponseSuccess()
    );

    // Create and insert ticket
    Ticket__c testTicket = createTestTicket();
    insert testTicket;

    Test.startTest();

    testTicket.Priority__c = 'Critical';
    update testTicket;

    Test.stopTest();

    // Verify priority change
    Ticket__c updatedTicket = [
      SELECT Id, Priority__c
      FROM Ticket__c
      WHERE Id = :testTicket.Id
    ];
    System.assertEquals('Critical', updatedTicket.Priority__c);
  }

  @isTest
  static void testTriggerOnUpdate_DescriptionChange() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerCalloutTest.MockHttpResponseSuccess()
    );

    // Create and insert ticket
    Ticket__c testTicket = createTestTicket();
    insert testTicket;

    Test.startTest();

    testTicket.Description__c = 'Updated Description with more details';
    update testTicket;

    Test.stopTest();

    // Verify description change
    Ticket__c updatedTicket = [
      SELECT Id, Description__c
      FROM Ticket__c
      WHERE Id = :testTicket.Id
    ];
    System.assertEquals(
      'Updated Description with more details',
      updatedTicket.Description__c
    );
  }

  @isTest
  static void testTriggerOnUpdate_AssigneeChange() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerCalloutTest.MockHttpResponseSuccess()
    );

    // Create and insert ticket
    Ticket__c testTicket = createTestTicket();
    testTicket.Assignee__c = null; // Start with no assignee
    insert testTicket;

    Test.startTest();

    testTicket.Assignee__c = UserInfo.getUserId();
    update testTicket;

    Test.stopTest();

    // Verify assignee change
    Ticket__c updatedTicket = [
      SELECT Id, Assignee__c
      FROM Ticket__c
      WHERE Id = :testTicket.Id
    ];
    System.assertEquals(UserInfo.getUserId(), updatedTicket.Assignee__c);
  }

  @isTest
  static void testTriggerBulkOperations() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerCalloutTest.MockHttpResponseSuccess()
    );

    // Create multiple tickets
    List<Ticket__c> testTickets = new List<Ticket__c>();
    for (Integer i = 0; i < 10; i++) {
      Ticket__c ticket = createTestTicket();
      ticket.Title__c = 'Bulk Test Ticket ' + i;
      testTickets.add(ticket);
    }

    Test.startTest();

    // Bulk insert
    insert testTickets;

    // Bulk update
    for (Ticket__c ticket : testTickets) {
      ticket.Status__c = 'In Progress';
    }
    update testTickets;

    Test.stopTest();

    // Verify bulk operations
    List<Ticket__c> updatedTickets = [
      SELECT Id, Status__c
      FROM Ticket__c
      WHERE Id IN :testTickets
    ];
    System.assertEquals(10, updatedTickets.size());
    for (Ticket__c ticket : updatedTickets) {
      System.assertEquals('In Progress', ticket.Status__c);
    }
  }

  @isTest
  static void testTriggerWithHttpError() {
    // Set up mock for HTTP error
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerCalloutTest.MockHttpResponseError()
    );

    Test.startTest();

    // Create and insert ticket - should not fail even with HTTP error
    Ticket__c newTicket = createTestTicket();
    insert newTicket;

    Test.stopTest();

    // Verify ticket was still created successfully despite HTTP error
    Ticket__c insertedTicket = [
      SELECT Id, Title__c
      FROM Ticket__c
      WHERE Id = :newTicket.Id
    ];
    System.assertNotEquals(null, insertedTicket);
  }

  // Helper method to create test ticket
  private static Ticket__c createTestTicket() {
    return new Ticket__c(
      Title__c = 'Test Ticket',
      Description__c = 'Test Description for trigger testing',
      Status__c = 'Open',
      Priority__c = 'Medium',
      Assignee__c = UserInfo.getUserId()
    );
  }
}

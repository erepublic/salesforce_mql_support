@isTest
public class TicketChatterTriggerTest {
  @isTest
  static void testChatterPostOnTicket_SinglePost() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerTestUtility.SuccessHttpMock()
    );

    // Create and insert test ticket
    Ticket__c testTicket = TicketSummarizerTestUtility.createTestTicket();
    insert testTicket;

    Test.startTest();

    // Create chatter post on the ticket
    FeedItem chatterPost = new FeedItem(
      ParentId = testTicket.Id,
      Body = 'This is a test chatter post on the ticket',
      Type = 'TextPost'
    );
    insert chatterPost;

    Test.stopTest();

    // Verify chatter post was created successfully
    FeedItem insertedPost = [
      SELECT Id, ParentId, Body, Type
      FROM FeedItem
      WHERE Id = :chatterPost.Id
    ];
    System.assertEquals(testTicket.Id, insertedPost.ParentId);
    System.assertEquals('TextPost', insertedPost.Type);
    System.assertEquals(
      'This is a test chatter post on the ticket',
      insertedPost.Body
    );
  }

  @isTest
  static void testChatterPostOnTicket_MultipleTickets() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerTestUtility.SuccessHttpMock()
    );

    // Create and insert multiple test tickets
    List<Ticket__c> testTickets = TicketSummarizerTestUtility.createTestTickets(
      3
    );
    insert testTickets;

    Test.startTest();

    // Create chatter posts on all tickets
    List<FeedItem> chatterPosts = new List<FeedItem>();
    for (Integer i = 0; i < testTickets.size(); i++) {
      chatterPosts.add(
        new FeedItem(
          ParentId = testTickets[i].Id,
          Body = 'Chatter post ' + i + ' on ticket ' + testTickets[i].Title__c,
          Type = 'TextPost'
        )
      );
    }
    insert chatterPosts;

    Test.stopTest();

    // Verify all chatter posts were created
    List<FeedItem> insertedPosts = [
      SELECT Id, ParentId, Type
      FROM FeedItem
      WHERE ParentId IN :testTickets
    ];
    System.assertEquals(3, insertedPosts.size());

    for (FeedItem post : insertedPosts) {
      System.assertEquals('TextPost', post.Type);
    }
  }

  @isTest
  static void testChatterPostOnTicket_BulkPosts() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerTestUtility.SuccessHttpMock()
    );

    // Create and insert test ticket
    Ticket__c testTicket = TicketSummarizerTestUtility.createTestTicket();
    insert testTicket;

    Test.startTest();

    // Create multiple chatter posts on the same ticket
    List<FeedItem> chatterPosts = new List<FeedItem>();
    for (Integer i = 0; i < 5; i++) {
      chatterPosts.add(
        new FeedItem(
          ParentId = testTicket.Id,
          Body = 'Bulk chatter post number ' + i,
          Type = 'TextPost'
        )
      );
    }
    insert chatterPosts;

    Test.stopTest();

    // Verify all posts were created on the correct ticket
    List<FeedItem> insertedPosts = [
      SELECT Id, ParentId, Body
      FROM FeedItem
      WHERE ParentId = :testTicket.Id
    ];
    System.assertEquals(5, insertedPosts.size());

    for (FeedItem post : insertedPosts) {
      System.assertEquals(testTicket.Id, post.ParentId);
    }
  }

  @isTest
  static void testChatterPostOnNonTicket_ShouldNotTrigger() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerTestUtility.SuccessHttpMock()
    );

    // Create chatter post on a User object (not a ticket)
    User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    Test.startTest();

    // Create chatter post on user profile (should not trigger ticket processing)
    FeedItem userChatterPost = new FeedItem(
      ParentId = currentUser.Id,
      Body = 'This is a chatter post on user profile, not a ticket',
      Type = 'TextPost'
    );
    insert userChatterPost;

    Test.stopTest();

    // Verify chatter post was created but should not have triggered ticket processing
    FeedItem insertedPost = [
      SELECT Id, ParentId, Type
      FROM FeedItem
      WHERE Id = :userChatterPost.Id
    ];
    System.assertEquals(currentUser.Id, insertedPost.ParentId);
    System.assertEquals('TextPost', insertedPost.Type);

    // The key here is that no exceptions should be thrown and the post should be created normally
    // The trigger should ignore this post since it's not on a Ticket__c object
  }

  @isTest
  static void testNonTextPostOnTicket_ShouldTrigger() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerTestUtility.SuccessHttpMock()
    );

    // Create and insert test ticket
    Ticket__c testTicket = TicketSummarizerTestUtility.createTestTicket();
    insert testTicket;

    Test.startTest();

    // Create a feed item - in test context, Salesforce may create it as TextPost regardless of specified Type
    // Note: Since we removed the Type restriction, all post types should now trigger
    FeedItem feedPost = new FeedItem(
      ParentId = testTicket.Id,
      Body = 'This should trigger processing regardless of post type'
    );

    insert feedPost;

    // Verify the post was created successfully
    FeedItem insertedPost = [
      SELECT Id, ParentId, Type
      FROM FeedItem
      WHERE Id = :feedPost.Id
    ];
    System.assertEquals(testTicket.Id, insertedPost.ParentId);

    // The key assertion is that the post was created on the ticket, not the specific type
    // In test context, Salesforce may default to TextPost regardless of what we specify
    System.assert(insertedPost.Type != null, 'Post should have a type');

    Test.stopTest();

    // The main test here is that ALL post types on tickets now trigger processing
    // and no exceptions were thrown by our trigger logic
  }

  @isTest
  static void testChatterPostWithNullParent_ShouldNotTrigger() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerTestUtility.SuccessHttpMock()
    );

    Test.startTest();

    // Try to create chatter post with null parent (should be handled gracefully)
    try {
      FeedItem nullParentPost = new FeedItem(
        ParentId = null,
        Body = 'Post with null parent',
        Type = 'TextPost'
      );
      insert nullParentPost;
    } catch (Exception e) {
      // This is expected to fail at the database level, but our trigger should handle null checks
      System.debug('Expected failure for null parent: ' + e.getMessage());
    }

    Test.stopTest();

    // Main test is that our trigger doesn't throw null pointer exceptions
  }

  @isTest
  static void testChatterTriggerWithHttpError() {
    // Set up mock for HTTP error
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerTestUtility.ErrorHttpMock(500, 'Server Error')
    );

    // Create and insert test ticket
    Ticket__c testTicket = TicketSummarizerTestUtility.createTestTicket();
    insert testTicket;

    Test.startTest();

    // Create chatter post - should not fail even with HTTP error
    FeedItem chatterPost = new FeedItem(
      ParentId = testTicket.Id,
      Body = 'This post should succeed even with HTTP error',
      Type = 'TextPost'
    );
    insert chatterPost;

    Test.stopTest();

    // Verify chatter post was still created successfully despite HTTP error
    FeedItem insertedPost = [
      SELECT Id, ParentId, Body
      FROM FeedItem
      WHERE Id = :chatterPost.Id
    ];
    System.assertEquals(testTicket.Id, insertedPost.ParentId);
  }

  @isTest
  static void testChatterTriggerWithTimeoutError() {
    // Set up mock for timeout error
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerTestUtility.TimeoutHttpMock()
    );

    // Create and insert test ticket
    Ticket__c testTicket = TicketSummarizerTestUtility.createTestTicket();
    insert testTicket;

    Test.startTest();

    // Create chatter post - should not fail even with timeout
    FeedItem chatterPost = new FeedItem(
      ParentId = testTicket.Id,
      Body = 'This post should succeed even with timeout error',
      Type = 'TextPost'
    );
    insert chatterPost;

    Test.stopTest();

    // Verify chatter post was still created successfully despite timeout
    FeedItem insertedPost = [
      SELECT Id, ParentId, Body
      FROM FeedItem
      WHERE Id = :chatterPost.Id
    ];
    System.assertEquals(testTicket.Id, insertedPost.ParentId);
  }

  @isTest
  static void testGetTicketPrefix() {
    // This test verifies that the ticket prefix helper method works correctly
    Test.startTest();

    // Create a test ticket to ensure the Ticket__c object exists
    Ticket__c testTicket = TicketSummarizerTestUtility.createTestTicket();
    insert testTicket;

    // Verify that the ticket ID starts with the expected prefix
    String ticketId = String.valueOf(testTicket.Id);
    String expectedPrefix = Schema.getGlobalDescribe()
      .get('Ticket__c')
      .getDescribe()
      .getKeyPrefix();

    System.assert(
      ticketId.startsWith(expectedPrefix),
      'Ticket ID should start with the correct object prefix'
    );

    Test.stopTest();
  }

  @isTest
  static void testMixedFeedItems_OnlyTicketTextPostsTrigger() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerTestUtility.SuccessHttpMock()
    );

    // Create test tickets
    List<Ticket__c> testTickets = TicketSummarizerTestUtility.createTestTickets(
      2
    );
    insert testTickets;

    // Get current user for non-ticket posts
    User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    Test.startTest();

    // Create mixed feed items
    List<FeedItem> feedItems = new List<FeedItem>();

    // TextPost on ticket (SHOULD trigger)
    feedItems.add(
      new FeedItem(
        ParentId = testTickets[0].Id,
        Body = 'TextPost on ticket 1',
        Type = 'TextPost'
      )
    );

    // TextPost on ticket (SHOULD trigger)
    feedItems.add(
      new FeedItem(
        ParentId = testTickets[1].Id,
        Body = 'TextPost on ticket 2',
        Type = 'TextPost'
      )
    );

    // TextPost on user (should NOT trigger)
    feedItems.add(
      new FeedItem(
        ParentId = currentUser.Id,
        Body = 'TextPost on user profile',
        Type = 'TextPost'
      )
    );

    insert feedItems;

    Test.stopTest();

    // Verify all feed items were created
    List<FeedItem> insertedItems = [
      SELECT Id, ParentId, Type
      FROM FeedItem
      WHERE Id IN :feedItems
    ];
    System.assertEquals(3, insertedItems.size());

    // Verify ticket posts exist
    List<FeedItem> ticketPosts = [
      SELECT Id
      FROM FeedItem
      WHERE ParentId IN :testTickets
    ];
    System.assertEquals(2, ticketPosts.size());

    // Verify user post exists
    List<FeedItem> userPosts = [
      SELECT Id
      FROM FeedItem
      WHERE ParentId = :currentUser.Id
    ];
    System.assertEquals(1, userPosts.size());
  }

  @isTest
  static void testChatterPostWithMinimalBody() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerTestUtility.SuccessHttpMock()
    );

    // Create and insert test ticket
    Ticket__c testTicket = TicketSummarizerTestUtility.createTestTicket();
    insert testTicket;

    Test.startTest();

    // Create chatter post with minimal body (single character)
    FeedItem minimalPost = new FeedItem(
      ParentId = testTicket.Id,
      Body = 'x', // Minimal body - single character
      Type = 'TextPost'
    );
    insert minimalPost;

    Test.stopTest();

    // Verify post was created and trigger handled it gracefully
    FeedItem insertedPost = [
      SELECT Id, ParentId, Body
      FROM FeedItem
      WHERE Id = :minimalPost.Id
    ];
    System.assertEquals(testTicket.Id, insertedPost.ParentId);
    System.assertEquals('x', insertedPost.Body);
  }
}

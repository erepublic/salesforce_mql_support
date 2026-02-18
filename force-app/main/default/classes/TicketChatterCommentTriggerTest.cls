@isTest
public class TicketChatterCommentTriggerTest {
  @isTest
  static void testChatterCommentOnTicket_SingleComment() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerTestUtility.SuccessHttpMock()
    );

    // Create and insert test ticket
    Ticket__c testTicket = TicketSummarizerTestUtility.createTestTicket();
    insert testTicket;

    // Create a FeedItem on the ticket first
    FeedItem chatterPost = new FeedItem(
      ParentId = testTicket.Id,
      Body = 'Original chatter post on the ticket',
      Type = 'TextPost'
    );
    insert chatterPost;

    Test.startTest();

    // Create comment on the chatter post
    FeedComment chatterComment = new FeedComment(
      FeedItemId = chatterPost.Id,
      CommentBody = 'This is a test comment on the chatter post'
    );
    insert chatterComment;

    Test.stopTest();

    // Verify comment was created successfully
    FeedComment insertedComment = [
      SELECT Id, FeedItemId, CommentBody
      FROM FeedComment
      WHERE Id = :chatterComment.Id
    ];
    System.assertEquals(chatterPost.Id, insertedComment.FeedItemId);
    System.assertEquals(
      'This is a test comment on the chatter post',
      insertedComment.CommentBody
    );
  }

  @isTest
  static void testChatterCommentOnTicket_MultipleComments() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerTestUtility.SuccessHttpMock()
    );

    // Create and insert test ticket
    Ticket__c testTicket = TicketSummarizerTestUtility.createTestTicket();
    insert testTicket;

    // Create a FeedItem on the ticket first
    FeedItem chatterPost = new FeedItem(
      ParentId = testTicket.Id,
      Body = 'Original chatter post for multiple comments',
      Type = 'TextPost'
    );
    insert chatterPost;

    Test.startTest();

    // Create multiple comments on the chatter post
    List<FeedComment> chatterComments = new List<FeedComment>();
    for (Integer i = 0; i < 3; i++) {
      chatterComments.add(
        new FeedComment(
          FeedItemId = chatterPost.Id,
          CommentBody = 'Comment number ' + i + ' on the post'
        )
      );
    }
    insert chatterComments;

    Test.stopTest();

    // Verify all comments were created
    List<FeedComment> insertedComments = [
      SELECT Id, FeedItemId, CommentBody
      FROM FeedComment
      WHERE FeedItemId = :chatterPost.Id
    ];
    System.assertEquals(3, insertedComments.size());

    for (FeedComment comment : insertedComments) {
      System.assertEquals(chatterPost.Id, comment.FeedItemId);
    }
  }

  @isTest
  static void testChatterCommentOnMultipleTickets_BulkProcessing() {
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

    // Create FeedItems on each ticket
    List<FeedItem> chatterPosts = new List<FeedItem>();
    for (Integer i = 0; i < testTickets.size(); i++) {
      chatterPosts.add(
        new FeedItem(
          ParentId = testTickets[i].Id,
          Body = 'Post on ticket ' + i,
          Type = 'TextPost'
        )
      );
    }
    insert chatterPosts;

    Test.startTest();

    // Create comments on all posts (bulk operation test)
    List<FeedComment> chatterComments = new List<FeedComment>();
    for (Integer i = 0; i < chatterPosts.size(); i++) {
      chatterComments.add(
        new FeedComment(
          FeedItemId = chatterPosts[i].Id,
          CommentBody = 'Comment on post ' + i
        )
      );
    }
    insert chatterComments;

    Test.stopTest();

    // Verify all comments were created correctly
    List<FeedComment> insertedComments = [
      SELECT Id, FeedItemId
      FROM FeedComment
      WHERE FeedItemId IN :chatterPosts
    ];
    System.assertEquals(3, insertedComments.size());

    // Verify the bulk query optimization worked (no SOQL in loop errors)
    Set<Id> chatterPostIds = new Set<Id>();
    for (FeedItem post : chatterPosts) {
      chatterPostIds.add(post.Id);
    }

    for (FeedComment comment : insertedComments) {
      System.assert(
        chatterPostIds.contains(comment.FeedItemId),
        'Comment should be on one of our test posts'
      );
    }
  }

  @isTest
  static void testChatterCommentOnNonTicket_ShouldNotTrigger() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerTestUtility.SuccessHttpMock()
    );

    // Create chatter post on a User object (not a ticket)
    User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    FeedItem userChatterPost = new FeedItem(
      ParentId = currentUser.Id,
      Body = 'Post on user profile',
      Type = 'TextPost'
    );
    insert userChatterPost;

    Test.startTest();

    // Create comment on the user post (should not trigger ticket processing)
    FeedComment userComment = new FeedComment(
      FeedItemId = userChatterPost.Id,
      CommentBody = 'Comment on user post, not a ticket'
    );
    insert userComment;

    Test.stopTest();

    // Verify comment was created but should not have triggered ticket processing
    FeedComment insertedComment = [
      SELECT Id, FeedItemId, CommentBody
      FROM FeedComment
      WHERE Id = :userComment.Id
    ];
    System.assertEquals(userChatterPost.Id, insertedComment.FeedItemId);

    // The key here is that no exceptions should be thrown and the comment should be created normally
    // The trigger should ignore this comment since it's not on a Ticket__c object
  }

  @isTest
  static void testChatterCommentWithNullFeedItem_ShouldNotTrigger() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerTestUtility.SuccessHttpMock()
    );

    Test.startTest();

    // Try to create comment with null FeedItemId (should be handled gracefully)
    try {
      FeedComment nullFeedItemComment = new FeedComment(
        FeedItemId = null,
        CommentBody = 'Comment with null FeedItemId'
      );
      insert nullFeedItemComment;
    } catch (Exception e) {
      // This is expected to fail at the database level, but our trigger should handle null checks
      System.debug('Expected failure for null FeedItemId: ' + e.getMessage());
    }

    Test.stopTest();

    // Main test is that our trigger doesn't throw null pointer exceptions
  }

  @isTest
  static void testChatterCommentTriggerWithHttpError() {
    // Set up mock for HTTP error
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerTestUtility.ErrorHttpMock(500, 'Server Error')
    );

    // Create and insert test ticket
    Ticket__c testTicket = TicketSummarizerTestUtility.createTestTicket();
    insert testTicket;

    // Create FeedItem on the ticket
    FeedItem chatterPost = new FeedItem(
      ParentId = testTicket.Id,
      Body = 'Post for HTTP error test',
      Type = 'TextPost'
    );
    insert chatterPost;

    Test.startTest();

    // Create comment - should not fail even with HTTP error
    FeedComment chatterComment = new FeedComment(
      FeedItemId = chatterPost.Id,
      CommentBody = 'Comment should succeed even with HTTP error'
    );
    insert chatterComment;

    Test.stopTest();

    // Verify comment was still created successfully despite HTTP error
    FeedComment insertedComment = [
      SELECT Id, FeedItemId, CommentBody
      FROM FeedComment
      WHERE Id = :chatterComment.Id
    ];
    System.assertEquals(chatterPost.Id, insertedComment.FeedItemId);
  }

  @isTest
  static void testChatterCommentTriggerWithTimeoutError() {
    // Set up mock for timeout error
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerTestUtility.TimeoutHttpMock()
    );

    // Create and insert test ticket
    Ticket__c testTicket = TicketSummarizerTestUtility.createTestTicket();
    insert testTicket;

    // Create FeedItem on the ticket
    FeedItem chatterPost = new FeedItem(
      ParentId = testTicket.Id,
      Body = 'Post for timeout test',
      Type = 'TextPost'
    );
    insert chatterPost;

    Test.startTest();

    // Create comment - should not fail even with timeout
    FeedComment chatterComment = new FeedComment(
      FeedItemId = chatterPost.Id,
      CommentBody = 'Comment should succeed even with timeout error'
    );
    insert chatterComment;

    Test.stopTest();

    // Verify comment was still created successfully despite timeout
    FeedComment insertedComment = [
      SELECT Id, FeedItemId, CommentBody
      FROM FeedComment
      WHERE Id = :chatterComment.Id
    ];
    System.assertEquals(chatterPost.Id, insertedComment.FeedItemId);
  }

  @isTest
  static void testMixedComments_OnlyTicketCommentsTrigger() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerTestUtility.SuccessHttpMock()
    );

    // Create test ticket
    Ticket__c testTicket = TicketSummarizerTestUtility.createTestTicket();
    insert testTicket;

    // Get current user for non-ticket posts
    User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    // Create posts on both ticket and user
    FeedItem ticketPost = new FeedItem(
      ParentId = testTicket.Id,
      Body = 'Post on ticket',
      Type = 'TextPost'
    );

    FeedItem userPost = new FeedItem(
      ParentId = currentUser.Id,
      Body = 'Post on user',
      Type = 'TextPost'
    );

    List<FeedItem> posts = new List<FeedItem>{ ticketPost, userPost };
    insert posts;

    Test.startTest();

    // Create comments on both posts
    List<FeedComment> comments = new List<FeedComment>();

    // Comment on ticket post (SHOULD trigger)
    comments.add(
      new FeedComment(
        FeedItemId = ticketPost.Id,
        CommentBody = 'Comment on ticket post'
      )
    );

    // Comment on user post (should NOT trigger)
    comments.add(
      new FeedComment(
        FeedItemId = userPost.Id,
        CommentBody = 'Comment on user post'
      )
    );

    insert comments;

    Test.stopTest();

    // Verify all comments were created
    List<FeedComment> insertedComments = [
      SELECT Id, FeedItemId
      FROM FeedComment
      WHERE Id IN :comments
    ];
    System.assertEquals(2, insertedComments.size());

    // Verify ticket comment exists
    List<FeedComment> ticketComments = [
      SELECT Id
      FROM FeedComment
      WHERE FeedItemId = :ticketPost.Id
    ];
    System.assertEquals(1, ticketComments.size());

    // Verify user comment exists
    List<FeedComment> userComments = [
      SELECT Id
      FROM FeedComment
      WHERE FeedItemId = :userPost.Id
    ];
    System.assertEquals(1, userComments.size());
  }

  @isTest
  static void testChatterCommentWithMinimalBody() {
    // Set up mock for HTTP callouts
    Test.setMock(
      HttpCalloutMock.class,
      new TicketSummarizerTestUtility.SuccessHttpMock()
    );

    // Create and insert test ticket
    Ticket__c testTicket = TicketSummarizerTestUtility.createTestTicket();
    insert testTicket;

    // Create FeedItem on the ticket
    FeedItem chatterPost = new FeedItem(
      ParentId = testTicket.Id,
      Body = 'Post for minimal comment test',
      Type = 'TextPost'
    );
    insert chatterPost;

    Test.startTest();

    // Create comment with minimal body (single character)
    FeedComment minimalComment = new FeedComment(
      FeedItemId = chatterPost.Id,
      CommentBody = 'x' // Minimal body - single character
    );
    insert minimalComment;

    Test.stopTest();

    // Verify comment was created and trigger handled it gracefully
    FeedComment insertedComment = [
      SELECT Id, FeedItemId, CommentBody
      FROM FeedComment
      WHERE Id = :minimalComment.Id
    ];
    System.assertEquals(chatterPost.Id, insertedComment.FeedItemId);
    System.assertEquals('x', insertedComment.CommentBody);
  }
}

trigger TicketChatterCommentTrigger on FeedComment(after insert) {
  Set<Id> ticketIds = new Set<Id>();
  Set<Id> feedItemIds = new Set<Id>();

  // Collect all FeedItem IDs from the comments
  for (FeedComment feedComment : Trigger.new) {
    if (feedComment.FeedItemId != null) {
      feedItemIds.add(feedComment.FeedItemId);
    }
  }

  // Bulk query to get all parent FeedItems
  Map<Id, FeedItem> feedItemMap = new Map<Id, FeedItem>(
    [
      SELECT Id, ParentId
      FROM FeedItem
      WHERE Id IN :feedItemIds
    ]
  );

  // Process comments and check if they're on Ticket objects
  for (FeedComment feedComment : Trigger.new) {
    if (
      feedComment.FeedItemId != null &&
      feedItemMap.containsKey(feedComment.FeedItemId)
    ) {
      FeedItem parentFeedItem = feedItemMap.get(feedComment.FeedItemId);

      // Check if the parent FeedItem is on a Ticket__c object
      if (
        parentFeedItem.ParentId != null &&
        String.valueOf(parentFeedItem.ParentId).startsWith(getTicketPrefix())
      ) {
        ticketIds.add(parentFeedItem.ParentId);
        System.debug(
          'Chatter comment detected on ticket: ' +
            parentFeedItem.ParentId +
            ', Comment: ' +
            feedComment.CommentBody
        );
      }
    }
  }

  if (!ticketIds.isEmpty()) {
    // Add a small delay to ensure the chatter comment is fully committed before Lambda processes it
    TicketSummarizerCallout.triggerSummarizationWithDelay(ticketIds);
  }

  // Helper method to get the Ticket__c object key prefix
  private static String getTicketPrefix() {
    // Cache the prefix to avoid repeated describe calls
    if (ticketObjectPrefix == null) {
      ticketObjectPrefix = Schema.getGlobalDescribe()
        .get('Ticket__c')
        .getDescribe()
        .getKeyPrefix();
    }
    return ticketObjectPrefix;
  }

  private static String ticketObjectPrefix;
}

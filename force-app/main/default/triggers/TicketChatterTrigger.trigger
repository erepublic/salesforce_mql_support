trigger TicketChatterTrigger on FeedItem(after insert) {
  Set<Id> ticketIds = new Set<Id>();

  for (FeedItem feedItem : Trigger.new) {
    // Check if this is a chatter post on a Ticket__c object
    // Removed Type restriction to capture all types of posts (TextPost, LinkPost, etc.)
    if (
      feedItem.ParentId != null &&
      String.valueOf(feedItem.ParentId).startsWith(getTicketPrefix())
    ) {
      ticketIds.add(feedItem.ParentId);
      System.debug(
        'Chatter post detected on ticket: ' +
          feedItem.ParentId +
          ', Type: ' +
          feedItem.Type
      );
    }
  }

  if (!ticketIds.isEmpty()) {
    // Add a small delay to ensure the chatter post is fully committed before Lambda processes it
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

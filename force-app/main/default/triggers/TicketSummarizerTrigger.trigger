trigger TicketSummarizerTrigger on Ticket__c(after update, after insert) {
  Set<Id> ticketIds = new Set<Id>();

  for (Ticket__c ticket : Trigger.new) {
    // Check if relevant fields changed or it's a new ticket
    if (
      Trigger.isInsert ||
      hasRelevantChanges(ticket, Trigger.oldMap.get(ticket.Id))
    ) {
      ticketIds.add(ticket.Id);
    }
  }

  if (!ticketIds.isEmpty()) {
    // Call future method to make HTTP callout
    TicketSummarizerCallout.triggerSummarization(ticketIds);
  }

  private static Boolean hasRelevantChanges(
    Ticket__c newTicket,
    Ticket__c oldTicket
  ) {
    // Get all fields that might be relevant for summarization
    // This uses dynamic field detection to check all fields except AI summary fields
    Map<String, Object> newFields = newTicket.getPopulatedFieldsAsMap();
    Map<String, Object> oldFields = oldTicket.getPopulatedFieldsAsMap();

    // Fields to exclude from change detection (AI summary fields to prevent infinite loops)
    Set<String> excludedFields = new Set<String>{
      'AI_Summary__c',
      'Last_AI_Summary_Date__c',
      'Auto_Summary__c',
      'AI_Analysis__c',
      'AI_Summary_Date__c',
      'Last_Summary_Date__c',
      'Summary_Generated_Date__c',
      'LastModifiedDate',
      'LastModifiedById',
      'SystemModstamp'
    };

    // Check if any non-excluded field has changed
    for (String fieldName : newFields.keySet()) {
      if (!excludedFields.contains(fieldName)) {
        Object newValue = newFields.get(fieldName);
        Object oldValue = oldFields.get(fieldName);

        // Handle null comparisons properly
        if (newValue != oldValue) {
          if (
            newValue == null ||
            oldValue == null ||
            !newValue.equals(oldValue)
          ) {
            System.debug(
              'Relevant field changed: ' +
                fieldName +
                ' from ' +
                oldValue +
                ' to ' +
                newValue
            );
            return true;
          }
        }
      }
    }

    return false;
  }
}

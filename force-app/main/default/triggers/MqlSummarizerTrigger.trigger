trigger MqlSummarizerTrigger on MQL__c(after insert, after update) {
  Set<Id> mqlIdsToSummarize = new Set<Id>();

  if (Trigger.isAfter && Trigger.isInsert) {
    for (MQL__c mql : Trigger.new) {
      if (mql == null)
        continue;
      if (
        mql.Lead_Source__c == 'Fit and Behavior Threshold Reached' &&
        String.isBlank(mql.Engagement_AI_Summary__c)
      ) {
        mqlIdsToSummarize.add(mql.Id);
      }
    }
  }

  if (Trigger.isAfter && Trigger.isUpdate) {
    for (MQL__c mql : Trigger.new) {
      MQL__c oldMql = Trigger.oldMap.get(mql.Id);
      if (mql == null || oldMql == null)
        continue;

      Boolean becameThreshold =
        oldMql.Lead_Source__c != 'Fit and Behavior Threshold Reached' &&
        mql.Lead_Source__c == 'Fit and Behavior Threshold Reached';

      if (becameThreshold && String.isBlank(mql.Engagement_AI_Summary__c)) {
        mqlIdsToSummarize.add(mql.Id);
      }
    }
  }

  if (!mqlIdsToSummarize.isEmpty()) {
    MqlSummarizerCallout.triggerSummarization(mqlIdsToSummarize);
  }
}

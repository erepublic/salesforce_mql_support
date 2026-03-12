trigger MqlSummarizerTrigger on MQL__c(after insert, after update) {
  Set<Id> mqlIdsToSummarize = new Set<Id>();

  if (Trigger.isAfter && Trigger.isInsert) {
    for (MQL__c mql : Trigger.new) {
      if (mql == null)
        continue;
      if (String.isBlank(mql.Engagement_AI_Summary__c)) {
        mqlIdsToSummarize.add(mql.Id);
      }
    }
  }

  if (Trigger.isAfter && Trigger.isUpdate) {
    for (MQL__c mql : Trigger.new) {
      MQL__c oldMql = Trigger.oldMap.get(mql.Id);
      if (mql == null || oldMql == null)
        continue;

      Boolean leadSourceChanged = oldMql.Lead_Source__c != mql.Lead_Source__c;
      Boolean opportunityChanged = oldMql.Opportunity__c != mql.Opportunity__c;
      Boolean summaryStillBlank = String.isBlank(mql.Engagement_AI_Summary__c);

      if (summaryStillBlank && (leadSourceChanged || opportunityChanged)) {
        mqlIdsToSummarize.add(mql.Id);
      }
    }
  }

  if (!mqlIdsToSummarize.isEmpty()) {
    MqlSummarizerCallout.triggerSummarization(mqlIdsToSummarize);
  }
}

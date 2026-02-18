// Regenerate MQL engagement summaries for all MQL__c records in the sandbox.
// - Batches in groups of 50 to respect callout limits inside the future method.
// - Uses the FORCE path to overwrite existing summaries.

List<MQL__c> mqls = [
  SELECT Id
  FROM MQL__c
  ORDER BY CreatedDate DESC
];

System.debug('MQL_BACKFILL: found ' + mqls.size() + ' MQL__c records');

// Smaller batches reduce the chance of the async job timing out mid-loop.
Integer batchSize = 10;
for (Integer i = 0; i < mqls.size(); i += batchSize) {
  Set<Id> batchIds = new Set<Id>();
  for (Integer j = i; j < Math.min(i + batchSize, mqls.size()); j++) {
    batchIds.add(mqls[j].Id);
  }
  System.debug('MQL_BACKFILL: enqueuing batch size=' + batchIds.size());
  MqlSummarizerCallout.triggerSummarizationForce(batchIds);
}

public class MqlSummarizerAdmin {
  // Minimal wrapper so this can be used from Flow if desired.
  public class Request {
    @InvocableVariable(required=true)
    public Id mqlId;

    @InvocableVariable
    public Boolean forceOverwrite;
  }

  @InvocableMethod(
    label='Generate/Regenerate MQL Summary'
    description='Triggers the MQL summarizer callout for the given MQL__c records. Optionally overwrites existing summaries.'
  )
  public static void regenerateFromFlow(List<Request> requests) {
    if (requests == null || requests.isEmpty())
      return;

    Set<Id> normal = new Set<Id>();
    Set<Id> force = new Set<Id>();

    for (Request r : requests) {
      if (r == null || r.mqlId == null)
        continue;
      if (r.forceOverwrite == true)
        force.add(r.mqlId);
      else
        normal.add(r.mqlId);
    }

    if (!normal.isEmpty())
      MqlSummarizerCallout.triggerSummarization(normal);
    if (!force.isEmpty())
      MqlSummarizerCallout.triggerSummarizationForce(force);
  }

  // Convenience for anonymous apex / CLI-driven testing.
  public static void regenerateForce(Set<Id> mqlIds) {
    if (mqlIds == null || mqlIds.isEmpty())
      return;
    MqlSummarizerCallout.triggerSummarizationForce(mqlIds);
  }
}

public class OpportunityMergeController {
  @RemoteAction
  public static Opportunity getOpportunity(Id oppId) {
    Opportunity o = [SELECT Id, Name FROM Opportunity WHERE Id = :oppId];
    return o;
  }
  @RemoteAction
  public static List<Opportunity> searchOpportunities(String search) {
    String sQ = '%' + search + '%';
    List<Opportunity> results = [
      SELECT Id, Name
      FROM Opportunity
      WHERE Name LIKE :sQ AND CreatedDate > :Datetime.now().addYears(-1)
      ORDER BY CreatedDate DESC
    ];
    return results;
  }
  @RemoteAction
  public static String mergeOpportunities(String winner, String loserList) {
    List<String> losers = loserList.split('\\,');

    // Find out if the winner and/or looser opportunities contains products which have SIN in schedule comments: if yes cannot merge
    for (OpportunityLineItemSchedule schedule : [
      SELECT Id, Description, OpportunityLineItem.OpportunityId
      FROM OpportunityLineItemSchedule
      WHERE
        OpportunityLineItem.OpportunityId IN :losers
        OR OpportunityLineItem.OpportunityId = :winner
    ]) {
      if (
        (!String.isBlank(schedule.Description)) &&
        schedule.Description.length() >= 3 &&
        schedule.Description.substring(0, 3) == 'SIN'
      ) {
        // Cannot merge opportunities
        return ('FAILURE');
      }
    }
    return OpportunityMerge.mergeOpps(winner, losers);
  }
}

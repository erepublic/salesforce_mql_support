trigger trigger_oppWrittenUpdateSchedule on Opportunity(after update) {
  // Created for Ticket # 40529 https://erepublic.lightning.force.com/lightning/r/Ticket__c/a0w5Y00000rOs6gQAC/view
  // When an opportunity is set to 'Written' set all of the related OpportunityLineItemSchedule.Original_Close_Date__c to
  // Opportunity.CloseDate if the OLIS Original_Close_Date__c is empty
  //
  // test trigger_oppWrittenUpdateSchedule_test
  List<Id> OppList = new List<Id>();
  for (Opportunity Opp : Trigger.new) {
    if (Opp.Current_Stage__c == 'Written') {
      OppList.add(Opp.Id);
    }
  }
  if (!OppList.isEmpty()) {
    List<OpportunityLineItemSchedule> OLISList = [
      SELECT
        Id,
        Original_Close_Date__c,
        OpportunityLineItem.Opportunity.CloseDate
      FROM OpportunityLineItemSchedule
      WHERE
        OpportunityLineItem.Opportunity.Id IN :OppList
        AND Original_Close_Date__c = NULL
    ];
    if (!OLISList.isEmpty()) {
      for (OpportunityLineItemSchedule OLIS : OLISList) {
        OLIS.Original_Close_Date__c = OLIS.OpportunityLineItem.Opportunity.CloseDate;
      }
      update OLISList;
    }
  }

}

public with sharing class eventHotSheet {
  private Events__c event;
  public String currentEventName { get; set; }
  public Integer currentEventYear { get; set; }
  public String previousEventName { get; set; }
  public Integer previousEventYear { get; set; }
  public Date currentEventStartDate { get; set; }
  public Date currentEventEndDate { get; set; }
  public Decimal revenueTarget { get; set; }
  public Decimal revenueDifference { get; set; }

  public date advisoryBoard1Date { get; set; }
  public date advisoryBoard2Date { get; set; }
  public date programGuideSponsorDeadline { get; set; }

  public List<eventSponsorship> WonOpportunityItems = new List<eventSponsorship>();
  public Decimal WonTotal { get; set; }

  public List<eventSponsorship> HotOpportunityItems = new List<eventSponsorship>();
  public Decimal HotTotal { get; set; }

  public List<eventSponsorship> WarmOpportunityItems = new List<eventSponsorship>();
  public Decimal WarmTotal { get; set; }

  public List<eventSponsorship> ColdOpportunityItems = new List<eventSponsorship>();
  public Decimal ColdTotal { get; set; }

  public List<eventSponsorship> MissingOpportunityItems = new List<eventSponsorship>();
  public Decimal MissingTotal { get; set; }

  public eventHotSheet(Events__c event) {
    String previousEventId;
    List<ID> AccountIDs = new List<ID>();
    WonTotal = 0;
    HotTotal = 0;
    WarmTotal = 0;
    ColdTotal = 0;
    MissingTotal = 0;

    currentEventName = event.Nickname__c;
    currentEventStartDate = event.Event_Start_Date__c;
    currentEventEndDate = event.Event_End_Date__c;

    advisoryBoard1Date = event.Advisory_Board_1__c;
    advisoryBoard2Date = event.Advisory_Board_2__c;
    programGuideSponsorDeadline = event.Program_Guide_Sponsor_Deadline__c;

    if (event.Event_End_Date__c != null) {
      currentEventYear = event.Event_End_Date__c.year();
    } else if (event.Event_Year__c != null) {
      currentEventYear = Integer.valueOf(event.Event_Year__c);
    } else {
      currentEventYear = system.today().year();
    }

    if (event.Sponsorship_Revenue_Target__c != null) {
      revenueTarget = event.Sponsorship_Revenue_Target__c;
    }

    if (event.last_years_event__r != null) {
      // Previous Event ID
      previousEventId = event.last_years_event__r.Id;
      // Previous Event Name
      previousEventName = event.last_years_event__r.Nickname__c;
      // Previous Event Year
      if (event.last_years_event__r.Event_End_Date__c != null) {
        previousEventYear = event.last_years_event__r.Event_End_Date__c.year();
      }
    }

    List<OpportunityLineItem> List1 = [
      SELECT
        Id,
        TotalPrice,
        Sponsorship_Level__c,
        AccountName__c,
        Team__c,
        Returning_Status__c,
        Opportunity.StageName,
        Opportunity.AccountId,
        Opportunity.Owner.Name,
        Opportunity.Account.Owner.Name
      FROM OpportunityLineItem
      WHERE PricebookEntry.Product2.EE_Event__c = :event.Id
      ORDER BY AccountName__c ASC
    ];

    for (OpportunityLineItem Line : List1) {
      if (Line.Opportunity.StageName == 'Written') {
        AccountIDs.add(Line.Opportunity.AccountId);
        WonOpportunityItems.add(new eventSponsorship(Line));
        WonTotal += Line.TotalPrice;
      }
      if (
        Line.Opportunity.StageName == 'Verbal' ||
        Line.Opportunity.StageName == 'Negotiation' ||
        Line.Opportunity.StageName == 'Pending P.O.'
      ) {
        HotOpportunityItems.add(new eventSponsorship(Line));
        HotTotal += Line.TotalPrice;
      }
      if (
        Line.Opportunity.StageName == 'Meeting' ||
        Line.Opportunity.StageName == 'Proposal'
      ) {
        WarmOpportunityItems.add(new eventSponsorship(Line));
        WarmTotal += Line.TotalPrice;
      }
      if (Line.Opportunity.StageName == 'Qualification') {
        ColdOpportunityItems.add(new eventSponsorship(Line));
        ColdTotal += Line.TotalPrice;
      }
    }

    if (revenueTarget != null) {
      revenueDifference = revenueTarget - WonTotal;
    }

    if (previousEventId != null) {
      List<OpportunityLineItem> List2 = [
        SELECT
          Id,
          TotalPrice,
          Sponsorship_Level__c,
          AccountName__c,
          Team__c,
          Returning_Status__c,
          Opportunity.StageName,
          Opportunity.AccountId,
          Opportunity.Owner.Name,
          Opportunity.Account.Owner.Name
        FROM OpportunityLineItem
        WHERE
          Opportunity.StageName = 'Written'
          AND PricebookEntry.Product2.EE_Event__c = :previousEventId
          AND Opportunity.AccountId NOT IN :AccountIDs
        ORDER BY AccountName__c ASC
      ];

      for (OpportunityLineItem Line : List2) {
        MissingOpportunityItems.add(new eventSponsorship(Line));
        MissingTotal += Line.TotalPrice;
      }
    }
  }

  public List<eventSponsorship> getWonOpportunityItems() {
    return WonOpportunityItems;
  }

  public List<eventSponsorship> getMissingOpportunityItems() {
    return MissingOpportunityItems;
  }

  public List<eventSponsorship> getHotOpportunityItems() {
    return HotOpportunityItems;
  }

  public List<eventSponsorship> getWarmOpportunityItems() {
    return WarmOpportunityItems;
  }

  public List<eventSponsorship> getColdOpportunityItems() {
    return ColdOpportunityItems;
  }
}

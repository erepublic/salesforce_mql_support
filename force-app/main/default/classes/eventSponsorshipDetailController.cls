public with sharing class eventSponsorshipDetailController {
  public eventHotSheet HotSheet { get; set; }

  public eventSponsorshipDetailController() {
    Events__c event = [
      SELECT
        Id,
        Name,
        Nickname__c,
        Event_Start_Date__c,
        Event_End_Date__c,
        Event_Year__c,
        Sponsorship_Revenue_Target__c,
        last_years_event__r.Id,
        last_years_event__r.Name,
        last_years_event__r.Nickname__c,
        last_years_event__r.Event_Start_Date__c,
        last_years_event__r.Event_End_Date__c,
        Advisory_Board_1__c,
        Advisory_Board_2__c,
        Program_Guide_Sponsor_Deadline__c
      FROM Events__c
      WHERE Id = :ApexPages.currentPage().getParameters().get('id')
    ];
    HotSheet = new eventHotSheet(event);
  }
}

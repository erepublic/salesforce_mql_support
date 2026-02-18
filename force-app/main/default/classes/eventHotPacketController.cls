public with sharing class eventHotPacketController {
  public List<eventHotSheet> HotSheets = new List<eventHotSheet>();
  public Integer Quarter { get; set; }
  public Integer Year { get; set; }
  public Date StartDate { get; set; }
  public Date EndDate { get; set; }

  // Cover page properties
  public Decimal WonTotal { get; set; }
  public Decimal HotTotal { get; set; }
  public Decimal WarmTotal { get; set; }
  public Decimal MissingTotal { get; set; }
  public Decimal TargetTotal { get; set; }
  public Decimal RevenueDifference { get; set; }
  public String Brand { get; set; }

  public Date UpdateDate { get; set; }

  public eventHotPacketController() {
    Quarter = Integer.valueof(
      ApexPages.currentPage().getParameters().get('quarter')
    );
    Year = Integer.valueof(ApexPages.currentPage().getParameters().get('year'));
    UpdateDate = date.today();

    if (Quarter == 1) {
      StartDate = date.newInstance(Year, 1, 1);
      EndDate = date.newInstance(Year, 3, 31);
    } else if (Quarter == 2) {
      StartDate = date.newInstance(Year, 4, 1);
      EndDate = date.newInstance(Year, 6, 30);
    } else if (Quarter == 3) {
      StartDate = date.newInstance(Year, 7, 1);
      EndDate = date.newInstance(Year, 9, 30);
    } else if (Quarter == 4) {
      StartDate = date.newInstance(Year, 10, 1);
      EndDate = date.newInstance(Year, 12, 31);
    }

    WonTotal = 0;
    HotTotal = 0;
    WarmTotal = 0;
    MissingTotal = 0;
    TargetTotal = 0;
    RevenueDifference = 0;
    eventHotSheet hotSheet;

    String event_brand = ApexPages.currentPage().getParameters().get('brand');
    Brand = event_brand;
    String quart = 'Q' + Quarter;

    for (Events__c event : [
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
      WHERE
        ((Event_Start_Date__c >= :startDate
        AND Event_Start_Date__c <= :endDate)
        OR (Event_Year__c = :Year
        AND Event_Quarter__c = :quart))
        AND Brand__c = :event_brand
        AND RecordTypeId IN (
          SELECT Id
          FROM RecordType
          WHERE Name = 'Standard Event'
        )
      ORDER BY Event_Start_Date__c
    ]) {
      hotSheet = new eventHotSheet(event);
      WonTotal += hotSheet.WonTotal;
      HotTotal += hotSheet.HotTotal;
      WarmTotal += hotSheet.WarmTotal;
      MissingTotal += hotSheet.MissingTotal;
      if (hotSheet.revenueTarget != null) {
        TargetTotal += hotSheet.revenueTarget;
      }
      if (hotSheet.revenueDifference != null) {
        RevenueDifference += hotSheet.revenueDifference;
      }

      HotSheets.add(hotSheet);
    }
  }

  public List<eventHotSheet> getHotSheets() {
    return HotSheets;
  }
}

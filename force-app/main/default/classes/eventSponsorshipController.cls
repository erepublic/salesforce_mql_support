public class eventSponsorshipController { // test method for this class can be found in eventSponsorship_test
  public String Brand { get; set; }
  public List<QuarterListing> Quarters { get; set; }

  public eventSponsorshipController() {
    Quarters = new List<QuarterListing>();
    Date startDate;
    Date endDate;
    Integer startMonth;
    Integer endMonth;
    Integer year;
    Integer monthsInQuarter = 3;
    Integer quarter_num;

    Brand = ApexPages.currentPage().getParameters().get('brand');

    List<Events__c> tmp_list;

    // Start with beginning of this year, end with end of next year
    for (Integer i = 0; i < 8; i++) {
      //startMonth = (i * monthsInQuarter) + 1;
      //endMonth = startMonth + monthsInQuarter;
      if (i < 4) {
        year = date.today().year();
      } else {
        year = date.today().year() + 1;
      }

      if (i >= 4) {
        quarter_num = (i + 1) - 4;
      } else {
        quarter_num = (i + 1);
      }

      //startDate = date.newInstance(year, startMonth, 1);
      //endDate = date.newInstance(year, endMonth, 1);
      //System.debug(startDate + ' - ' + endDate);

      tmp_list = getEvents(quarter_num, year);

      if (tmp_list.size() > 0) {
        Quarters.add(new QuarterListing(quarter_num, year, tmp_list));
      }
    }
  }

  @TestVisible
  public class QuarterListing {
    public String title { get; set; }
    public List<Events__c> events { get; set; }
    public Integer Quarter { get; set; }
    public Integer Year { get; set; }

    // Quarter and year should be revisted.
    @TestVisible
    QuarterListing(Integer q, Integer y, List<Events__c> e) {
      title = 'Quarter ' + q + ', ' + y;
      events = e;
      Quarter = q;
      Year = y;
    }
  }

  public List<Events__c> getEvents(Integer quarter, Integer year) {
    String theQuarter = 'Q' + String.valueOf(quarter);
    return [
      SELECT Id, Name, Event_Start_Date__c
      FROM Events__c
      WHERE
        Event_Quarter__c = :theQuarter
        AND Event_Year__c = :year
        AND Brand__c = :Brand
        AND Event_Type__c = 'Virtual Summit'
        AND RecordTypeId IN (
          SELECT Id
          FROM RecordType
          WHERE Name = 'Standard Event'
        )
      ORDER BY Event_Start_Date__c
    ];
  }
}

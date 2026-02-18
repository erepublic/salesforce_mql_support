public class event_logistics_controller {
  // Used by event_logistics_by_year   Visual Source Page

  private Map<String, String> brand_names = new Map<String, String>{
    'EMERGENCYMGMT' => 'Emergency Management',
    'GOVTECH' => 'Government Technology',
    'GOVERNING' => 'Governing',
    'TECHWIRE' => 'TechWire',
    'CDG' => 'CDG',
    'CDE' => 'CDE'
  };

  public String brand_name { get; set; }
  public Integer year { get; set; }
  public List<LogisticsData> logistics { get; set; }

  public event_logistics_controller() {
    logistics = new List<LogisticsData>();
    year = Integer.valueOf(
      ApexPages.currentPage().getParameters().get('year').trim()
    );
    String brand = ApexPages.currentPage().getParameters().get('brand');
    brand_name = brand_names.get(brand);
    for (Events__c e : [
      SELECT
        Id,
        Name,
        Shipping_Notes__c,
        Ship_To_Address__c,
        Event_Start_Date__c,
        Event_End_Date__c,
        Event_Month__c
      FROM Events__c
      WHERE
        RecordTypeId = '01230000000ueuw'
        AND Brand__c = :brand
        AND Event_Year__c = :year
        AND (NOT Name LIKE '%REG ONLY%')
      ORDER BY Event_Month__c, Event_Start_Date__c
    ]) {
      logistics.add(new LogisticsData(e));
    }
  }

  // data container class
  class LogisticsData {
    public String name { get; set; }
    public String dates { get; set; }
    public String shipping_notes { get; set; }
    public String shipping_address { get; set; }

    public LogisticsData(Events__c e) {
      name = e.Name;
      if (e.Shipping_Notes__c != null)
        shipping_notes = '<p>' + e.Shipping_Notes__c + '</p>';
      else
        shipping_notes = '';

      if (e.Ship_To_Address__c != null)
        shipping_address =
          '<p> <b>All shipments should be properly labeled as shown below:</b> <br>' +
          e.Ship_To_Address__c +
          '</p>';
      else
        shipping_address = '';

      shipping_notes = replaceLineBreaks(shipping_notes);
      shipping_address = replaceLineBreaks(shipping_address);

      if (e.Event_Start_Date__c == null) {
        if (e.Event_Month__c == null)
          dates = '';
        else
          dates = e.Event_Month__c;
      } else {
        DateTime sd = e.Event_Start_Date__c;
        DateTime ed = e.Event_End_Date__c;

        // it looks like the dates are put in as GMT person entering must be on GMT
        dates = sd.format('MMM d', 'GMT');
        if (e.Event_End_Date__c != null && ed.dayOfYear() != sd.dayOfYear()) {
          if (ed.month() != sd.month())
            dates += ed.format(' - MMM d', 'GMT');
          else
            dates += ed.format(' - d', 'GMT');
        }
      } //e.Event_Start_Date__c != null
    }

    String replaceLineBreaks(String str) {
      str = str.replaceAll('\r\n', '<br/>');
      str = str.replaceAll('\n', '<br/>');
      str = str.replaceAll('\r', '<br/>');
      return str;
    }
  } // end off class LogisticsData
}

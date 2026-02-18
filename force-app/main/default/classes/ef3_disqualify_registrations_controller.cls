/*
Michael Tel 7/8/2015
used by the ef3_disqualify_registrations vf page
test cases in eventRegistration_test.cls
*/
public with sharing class ef3_disqualify_registrations_controller {
  //public  String[] pages = new String[]{};
  public String pagination { get; private set; }
  private List<Registration__c> registrations;
  private ID eventId;
  public Integer currentPage = 1;
  private Integer maxPage = 1;
  private Integer offset = 0;
  private Events__c event;

  private final Integer itemsPerPage = 100;
  public String sortOrder { get; set; } // = 'Name Desc'; // firstName, lastName, title, company, email, non_qual, no-show p

  //StandardSetController
  public ef3_disqualify_registrations_controller(
    ApexPages.StandardSetController controller
  ) {
    eventId = (ID) ApexPages.currentPage().getParameters().get('id');
    sortOrder = ApexPages.currentPage().getParameters().get('sortOrder');
    if (sortOrder == null)
      sortOrder = 'Name Desc';

    String cp = ApexPages.currentPage().getParameters().get('page');
    if (cp != null)
      currentPage = Integer.valueOf(cp);
    offset = (currentPage - 1) * itemsPerPage;
    event = [SELECT Id, Name FROM Events__c WHERE Id = :this.eventId];

    loadRegistrations();

    // pagination
    pagination = '';
    Integer numResults = Database.countQuery(
      'SELECT count() FROM Registration__c WHERE Event__c = :eventId'
    );
    if (numResults > itemsPerPage) {
      maxPage = numResults / itemsPerPage + 1;
      for (integer p = 1; p <= maxPage; p++) {
        if (p == currentPage)
          pagination = pagination + ' &nbsp; <b> page ' + currentPage + '</b>';
        else
          pagination =
            pagination +
            ' &nbsp; <a href="/apex/ef3_disqualify_registrations?id=' +
            eventId +
            '&sortorder=' +
            sortorder +
            '&page=' +
            p +
            '" target="top" >page ' +
            p +
            '</a>';
        //pages.add('/apex/ef3_disqualify_registrations?id='+ eventId  +'&sortorder='+sortorder+'&page='+ p );
      }
    }
  }

  private void loadRegistrations() {
    String socl =
      'SELECT Id, Name, Attendee_Name__c,Registrant_Name__r.RecordTypeId,  Registrant_Name__r.firstName, Registrant_Name__r.lastName,  Non_Qual__c, Event_No_Show__c, Reg_Company_Name__c,Reg_Type__c, Promo_Code__c, Registrant_Email__c ,Registrant_Title__c, CreatedBy.Name' +
      ' FROM Registration__c WHERE Event__c = :eventId  ORDER BY ' +
      sortOrder +
      '  LIMIT ' +
      itemsPerPage +
      ' OFFSET ' +
      offset;
    registrations = Database.query(socl);
  }

  public String getEventName() {
    return (String) event.Name;
  }

  public String getEventId() {
    return (ID) this.eventId;
  }

  public List<Registration__c> getRegistrations() {
    return this.registrations;
  }

  public PageReference save() {
    try {
      update (this.registrations);
    } catch (System.DMLException e) {
      ApexPages.addMessages(e);
      return null;
    }

    if (currentPage < maxpage)
      return new PageReference(
          '/apex/ef3_disqualify_registrations?id=' +
            eventId +
            '&sortorder=' +
            sortorder +
            '&page=' +
            (currentPage + 1)
        )
        .setRedirect(true);

    // After Save, navigate to the default view page:
    return (new ApexPages.StandardController(this.event)).view();
  }
}

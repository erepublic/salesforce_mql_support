public with sharing class advisory_board_controller {
  private ID eventId;
  private Events__c evt;
  private LIST<Id> memberIds = new List<Id>();

  public LIST<Contact> members;
  public LIST<String> coverSheets;
  public Integer coverSheetIndex = 1;
  public Boolean hasGovernmentPages { get; set; }
  public LIST<String> governmentPages { get; set; }
  public Boolean hasIndustryPages { get; set; }
  public LIST<String> industryPages { get; set; }
  public LIST<String> writeInPages { get; set; }

  public LIST<Contact> industryMembers; // these are public dummies to advertise the getter method
  public LIST<Contact> governmentMembers;
  public String eventName {
    get {
      return evt.Name.replace('EE - ', '');
    }
    set;
  }
  public String eventSFId {
    get {
      return evt.Id;
    }
    set;
  }

  public Decimal pageSize = 10.0; // must be a decimal because in apex Int / Int loses remainder.
  public Integer writeInPageQty = 3;

  public Boolean isRoster { get; set; }

  public Id id_to_be_deleted { get; set; }
  private MAP<Id, Id> idMap = new Map<Id, Id>(); // key= contact id, value=Advisory_Board_Member id . This is used by delete_ab function

  public advisory_board_controller() {
    init();
  }

  public void init() {
    eventId = (ID) ApexPages.currentPage().getParameters().get('id');
    evt = Database.query(
      'SELECT Name, Nickname__c, Banner_URL__c, OneForm_ID__c, Advisory_Board_1__c, Advisory_Board_2__c, Advisory_Board_3__c, Advisory_Board_4__c FROM Events__c WHERE Id =:eventId'
    );
    LIST<Advisory_Board_Member__c> ABmembers = Database.query(
      'SELECT Id, Contact__r.Id FROM Advisory_Board_Member__c WHERE Event__c = :eventId '
    );

    for (Advisory_Board_Member__c a : ABmembers) {
      System.debug('ab member ' + a.Id);
      memberIds.add(a.Contact__r.Id);
      idMap.put(a.Contact__r.Id, a.Id);
    }
    String socl =
      'SELECT  Id, AB_Salutation__c, AB_First_Name__c, AB_Middle_Name__c, AB_Last_Name__c, AB_Suffix__c, AB_Title__c, AB_Department__c, ' +
      'AB_Organization__c, AB_Email__c, AB_Phone__c, AB_Type__c' +
      ' FROM Contact' +
      ' WHERE Id IN :memberIds ORDER BY AB_Last_Name__c';
    members = Database.query(socl);

    if (ApexPages.currentPage().getParameters().get('roster') == '1') {
      this.isRoster = true;
    } else {
      this.isRoster = false;
    }
    if (ApexPages.currentPage().getParameters().get('coverSheet') != null) {
      coverSheetIndex = Integer.valueOf(
        ApexPages.currentPage().getParameters().get('coverSheet')
      );
    }

    makePages();
  }

  public System.PageReference save() {
    //return setCon.save();
    update members;
    oneFormConnector.makeTheCall(eventId, 'download_event_advisory_board');
    return new PageReference('/' + eventId); // return to the event detial page
  }

  public System.PageReference cancel() {
    return new PageReference('/' + eventId);
  }

  //public System.PageReference delete_ab(){
  public System.PageReference delete_ab() {
    Id abId = idMap.get(id_to_be_deleted);

    Advisory_Board_Member__c[] ab = [
      SELECT Id, Name
      FROM Advisory_Board_Member__c
      WHERE Id = :abId
    ];
    delete ab;

    System.debug('id_to_be_deleted: ' + id_to_be_deleted + ' abId: ' + abId);
    return null; //ApexPages.currentPage();
    //new PageReference('/'+ eventId);
  }

  public List<Contact> getMembers() {
    return (List<Contact>) members; //setCon.getRecords();
  }
  public List<Contact> getGovernmentMembers() {
    List<Contact> mm = new List<Contact>();
    for (Contact c : this.members) {
      if (c.AB_Last_Name__c == null || c.AB_Last_Name__c.length() < 1)
        continue;
      if (c.AB_Type__c != 'Government')
        continue;
      mm.add(c);
    }
    return mm;
  }
  public List<Contact> getIndustryMembers() {
    List<Contact> mm = new List<Contact>();
    for (Contact c : this.members) {
      if (c.AB_Last_Name__c == null || c.AB_Last_Name__c.length() < 1)
        continue;
      if (c.AB_Type__c != 'Industry')
        continue;
      mm.add(c);
    }
    return mm;
  }

  public Void makePages() {
    List<List<List<Contact>>> governmentPaginatedColumnatedContacts = chunkContactsIntoPages(
      getGovernmentMembers()
    );
    List<List<List<Contact>>> industryPaginatedColumnatedContacts = chunkContactsIntoPages(
      getIndustryMembers()
    );

    if (governmentPaginatedColumnatedContacts.size() > 0) {
      hasGovernmentPages = true;
      governmentPages = makePage(
        governmentPaginatedColumnatedContacts,
        'GOVERNMENT',
        1
      );
    }
    if (industryPaginatedColumnatedContacts.size() > 0) {
      hasIndustryPages = true;
      industryPages = makePage(
        industryPaginatedColumnatedContacts,
        'INDUSTRY',
        governmentPaginatedColumnatedContacts.size() + 1
      );
    }

    makeWriteInSheets();
  }

  /**
   * This bears explanation. The requirement is that the list of members be displayed
   * in alphabetical order (by last name) first by column, then by page. So this function
   * organizes them into:
   *   - list of sheets
   *   - list of columns
   *   - list of members
   *
   * +----------------------------+
   * |Outer List                  |
   * | +------------------------+ |
   * | |Page List               | |
   * | | Column List            | |
   * | | +---------+ +----------+ |
   * | | |A        | |E        || |
   * | | |         | |         || |
   * | | +---------+ +----------| |
   * | | +---------+ +----------| |
   * | | |B        | |F        || |
   * | | |         | |         || |
   * | | +---------+ +----------| |
   * | | +---------+ +----------| |
   * | | |C        | |G        || |
   * | | |         | |         || |
   * | | +---------+ +----------| |
   * | | +---------+ +----------| |
   * | | |D        | |H        || |
   * | | |         | |         || |
   * | | +---------+ +----------| |
   * | +------------------------+ |
   * |                            |
   * | +------------------------+ |
   * | |                        | |
   * | |                        | |
   * | | +---------+ +----------+ |
   * | | |I        | |M        || |
   * | | |         | |         || |
   * | | +---------+ +----------| |
   * | | +---------+ +----------| |
   * | | |J        | |N        || |
   * | | |         | |         || |
   * | | +---------+ +----------| |
   * | | +---------+            | |
   * | | |K        |            | |
   * | | |         |            | |
   * | | +---------+            | |
   * | | +---------+            | |
   * | | |L        |            | |
   * | | |         |            | |
   * | | +---------+            + |
   * | |                        | |
   * | +------------------------+ |
   * +----------------------------+
   **/
  public List<List<List<Contact>>> chunkContactsIntoPages(
    List<Contact> memberList
  ) {
    List<List<List<Contact>>> listPages = new List<List<List<Contact>>>();
    Decimal pagesNeeded = Math.ceil(memberList.size() / pageSize);
    Integer fullContactIndex = 0;
    for (Integer pageIndex = 0; pageIndex < pagesNeeded; pageIndex++) {
      List<List<Contact>> columns = new List<List<Contact>>();
      for (Integer columnIndex = 0; columnIndex < 2; columnIndex++) {
        Integer contactLimit = Math.ceil(pageSize / 2.0).intValue();
        List<Contact> contacts = new List<Contact>();
        for (
          Integer contactIndex = 0; contactIndex < contactLimit; contactIndex++
        ) {
          if (fullContactIndex < memberList.size()) {
            contacts.add(memberList.get(fullContactIndex));
            fullContactIndex++;
          } else {
            break;
          }
        }
        columns.add(contacts);
      }
      listPages.add(columns);
    }
    return listPages;
  }

  public List<String> makePage(
    List<List<List<Contact>>> columnatedPages,
    String pageType,
    Integer pageNumber
  ) {
    List<String> pagesOfType = new List<String>();
    for (List<List<Contact>> columnatedPage : columnatedPages) {
      String page = '';
      page += '<div style="page-break-after:always; width: 100%"/>';
      page += makePageHeader(pageType);
      for (
        Integer rowIndex = 0; rowIndex < Math.ceil(pageSize / 2); rowIndex++
      ) {
        page += '<div class="row">';
        for (Integer colIndex = 0; colIndex < 2; colIndex++) {
          if (
            columnatedPage.size() > colIndex &&
            columnatedPage.get(colIndex).size() > rowIndex
          ) {
            Contact ct = columnatedPage.get(colIndex).get(rowIndex);
            page += '<table class="contact">';
            page += '<tr>';
            if (!isRoster) {
              page += '<td rowspan="6"><div class="checkbox"></div></td>';
            } else {
              page += '<td rowspan="6"><div class="checkbox-spacer">&nbsp;</div></td>';
            }
            page += '<td>Name:</td>';
            page += '<td><strong>';
            if (String.isNotEmpty(ct.AB_Salutation__c)) {
              page += ct.AB_Salutation__c + ' ';
            }
            page += displayContactField(ct.AB_First_Name__c) + ' ';
            if (String.isNotEmpty(ct.AB_Middle_Name__c)) {
              page += ct.AB_Middle_Name__c + ' ';
            }
            page += displayContactField(ct.AB_Last_Name__c);
            if (String.isNotEmpty(ct.AB_Suffix__c)) {
              page += ' ' + ct.AB_Suffix__c;
            }
            page += '</strong></td>';

            page += '</tr>';
            page += '<tr>';
            page += '<td>Title:</td>';
            page += '<td>' + displayContactField(ct.AB_Title__c) + '</td>';
            page += '</tr>';
            page += '<tr>';
            page += '<td>Department:</td>';
            page += '<td>' + displayContactField(ct.AB_Department__c) + '</td>';
            page += '</tr>';
            page += '<tr>';
            page += '<td>Organization:</td>';
            page +=
              '<td>' +
              displayContactField(ct.AB_Organization__c) +
              '</td>';
            page += '</tr>';
            page += '<tr>';
            page += '<td>Phone:</td>';
            page += '<td>' + displayContactField(ct.AB_Phone__c) + '</td>';
            page += '</tr>';
            page += '<tr>';
            page += '<td>Email:</td>';
            page += '<td>' + displayContactField(ct.AB_Email__c) + '</td>';
            page += '</tr>';
            page += '</table>';
          }
        }
        page += '</div>';
      }
      page += makePageFooter(pageNumber);
      pageNumber++;
      pagesOfType.add(page);
    }
    return pagesOfType;
  }

  public String displayContactField(String field) {
    if (field == null) {
      return '';
    } else {
      return field;
    }
  }

  public String makePageHeader(String memberType) {
    String pageHeader =
      '<div class="page-header">' +
      '<h3>' +
      eventName +
      '</h3>';
    if (!isRoster) {
      pageHeader +=
        '<h4>ADVISORY BOARD MEETING SIGN-IN SHEET</h4>' +
        '<p>Please mark your attendance and make any corrections to your information.</p>';
    } else {
      pageHeader += '<h4>ADVISORY BOARD ROSTER</h4><p class="space"></p>';
    }
    pageHeader += '<h3 class="bar">' + memberType + ' MEMBERS</h3>' + '</div>';
    return pageHeader;
  }

  public String makePageFooter(Integer pageNumber) {
    String pageFooter =
      '<table class="page-footer">' +
      '<tr>' +
      '<td>PRINTED&nbsp;' +
      System.today().format() +
      '</td>' +
      '<td style="width:100%"></td>' +
      '<td>' +
      pageNumber +
      '</td>' +
      '</tr>' +
      '</table>';
    return pageFooter;
  }

  public List<String> getCoverSheets() {
    List<String> CoverSheets = new List<String>();
    if (evt.Advisory_Board_1__c != null && coverSheetIndex == 1) {
      CoverSheets.add(makeCoverSheet(evt.Advisory_Board_1__c));
    } else if (evt.Advisory_Board_2__c != null && coverSheetIndex == 2) {
      CoverSheets.add(makeCoverSheet(evt.Advisory_Board_2__c));
    } else if (evt.Advisory_Board_3__c != null && coverSheetIndex == 3) {
      CoverSheets.add(makeCoverSheet(evt.Advisory_Board_3__c));
    } else if (evt.Advisory_Board_4__c != null && coverSheetIndex == 4) {
      CoverSheets.add(makeCoverSheet(evt.Advisory_Board_4__c));
    }
    return CoverSheets;
  }

  public String makeCoverSheet(Date abmDate) {
    String abmDateFormatted = Datetime.newInstance(
        abmDate.year(),
        abmDate.month(),
        abmDate.day()
      )
      .format('MMMM d, YYYY');
    String CoverSheet =
      '<table class="page-flex cover-sheet">' +
      '<tr>' +
      '<td><img src="https://cms.erepublic.com/common/events/website_background/' +
      eventSFId +
      '" alt="' +
      eventName +
      '" style="width:100%;" /></td>' +
      '</tr>' +
      '<tr>' +
      '<td style="vertical-align: center; height: 7in">';
    if (!isRoster) {
      CoverSheet +=
        '<h1>ADVISORY BOARD MEETING SIGN-IN SHEET</h1>' +
        '<h2>' +
        abmDateFormatted +
        '</h2>' +
        '<p>Please mark your attendance and make any corrections to your information.</p>';
    } else {
      CoverSheet +=
        '<h1>ADVISORY BOARD ROSTER</h1>' +
        '<h2>AS OF ' +
        Datetime.now().format('MMMM d, YYYY') +
        '</h2>';
    }
    CoverSheet += '</td>' + '</tr>' + '</table>';
    return CoverSheet;
  }

  public Void makeWriteInSheets() {
    List<String> writeInPages = new List<String>();
    if (isRoster) {
      this.writeInPages = writeInPages;
    } else {
      String writeInForm =
        '<table class="write-in-form">' +
        '<tr>' +
        '<td style="width:15%">Name:</td><td style="width:85%"><div class="underline">&nbsp;</div></td>' +
        '</tr>' +
        '<tr>' +
        '<td>Title:</td><td><div class="underline">&nbsp;</div></td>' +
        '</tr>' +
        '<tr>' +
        '<td>Department:</td><td><div class="underline">&nbsp;</div></td>' +
        '</tr>' +
        '<tr>' +
        '<td>Organization:</td><td><div class="underline">&nbsp;</div></td>' +
        '</tr>' +
        '<tr>' +
        '<td>Phone:</td><td><div class="underline">&nbsp;</div></td>' +
        '</tr>' +
        '<tr>' +
        '<td>Email:</td><td><div class="underline">&nbsp;</div></td>' +
        '</tr>' +
        '</table>';

      for (
        Integer writeInPageIndex = 0;
        writeInPageIndex < writeInPageQty;
        writeInPageIndex++
      ) {
        String wiPage =
          '<div style="page-break-after:always;"/>' +
          '<div class="page-header">' +
          '<h3>' +
          eventName +
          '</h3>' +
          '<h4>ADVISORY BOARD MEETING SIGN-IN SHEET</h4>' +
          '<br /><p>If you are not already listed on the previous pages, please sign-in below.</p>' +
          '</div>' +
          writeInForm +
          '<div class="spacer"></div>' +
          writeInForm;

        writeInPages.add(wiPage);
      }
      this.writeInPages = writeInPages;
    }
  }
}

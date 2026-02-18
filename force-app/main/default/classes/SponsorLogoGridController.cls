public with sharing class SponsorLogoGridController {
  private Id eventId;

  public Events__c event { get; set; }
  public List<Contract> sponsors { get; set; }

  public String sortType { get; set; }
  public String searchTerm { get; set; }
  public String cmsEnv { get; set; }

  public void SponsorLogoGridController() {
    init();
  }

  public void init() {
    eventId = (ID) ApexPages.currentPage().getParameters().get('id');
    event = [
      SELECT Id, Name, Event_Start_Date__c
      FROM Events__c
      WHERE Id = :eventId
    ];
    setSponsors();
    setSearch();
    if ([SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox) {
      cmsEnv = 'https://proof.cms.erepublic.com';
    } else {
      cmsEnv = 'https://cms.erepublic.com';
    }
  }

  public void setSortType() {
    ApexPages.currentPage().getParameters().put('sortType', sortType);
    setSponsors();
  }

  public void setSponsors() {
    sortType = ApexPages.currentPage().getParameters().get('sortType');
    if (sortType == null || sortType == '') {
      sortType = 'branding_alpha';
    }
    List<String> excludeTypes = new List<String>{
      'Conference Bag Sponsor (Add-On)',
      'Lanyard Sponsor (Add-On)',
      'Notebook Sponsor (Add-On)',
      'Miscellaneous',
      'Additional Event Pass(es)'
    };
    List<Contract> sponsorsRef = [
      SELECT
        Account.Id,
        Account.Name,
        ActivatedDate,
        Branding_Guidelines__c,
        ContractNumber,
        Status,
        Logo_URL__c,
        Sponsorship_Level__c
      FROM Contract
      WHERE Event__c = :eventId AND Sponsorship_Level__c NOT IN :excludeTypes
      ORDER BY Branding_Guidelines__c
    ];

    if (sortType == 'branding_alpha') {
      sponsors = sponsorsRef;
    } else if (sortType == 'policy') {
      Events__c evtRef = [
        SELECT Id, Event_Type__c
        FROM Events__c
        WHERE Id = :eventId
      ];
      System.debug(evtRef.Event_Type__c);
      if (
        evtRef.Event_Type__c == 'Exec Event' ||
        evtRef.Event_Type__c == 'Standard_Public Sector only'
      ) {
        sponsors = sortSponsorsForExecEvent(sponsorsRef);
      } else if (evtRef.Event_Type__c == 'CDG Event') {
        sponsors = sortSponsorsForGTorCDGEvent(sponsorsRef);
      } else if (
        evtRef.Event_Type__c == 'Virtual Summit' ||
        evtRef.Event_Type__c == 'Standard_Invitation only w/ Hub' ||
        evtRef.Event_Type__c == 'Standard_Public Sector only w/ Hub'
      ) {
        sponsors = sortSponsorsForVirtualSummit(sponsorsRef);
      } else {
        sponsors = sortSponsorsForCDEEvent(sponsorsRef);
      }
    }
  }

  private List<Contract> sortSponsorsForVirtualSummit(
    List<Contract> sponsorsRef
  ) {
    List<List<String>> sortOrder = new List<List<String>>();
    sortOrder.add(new List<String>{ 'Underwriter' });
    sortOrder.add(new List<String>{ 'Roundtable w/ Session Sponsor' });
    sortOrder.add(new List<String>{ 'Roundtable Sponsor' });
    sortOrder.add(new List<String>{ 'Anchor Sponsor' });
    sortOrder.add(new List<String>{ 'Ambassador Sponsor' });
    sortOrder.add(new List<String>{ 'Keynote Sponsor' });
    sortOrder.add(new List<String>{ 'Patron Sponsor' });
    return sortByListOfLevels(sponsorsRef, sortOrder);
  }

  private List<Contract> sortSponsorsForExecEvent(List<Contract> sponsorsRef) {
    List<List<String>> sortOrder = new List<List<String>>();
    sortOrder.add(new List<String>{ 'Underwriter' });
    sortOrder.add(
      new List<String>{
        'Anchor Sponsor',
        'Roundtable Breakfast/Anchor Sponsor',
        'Roundtable Lunch/Anchor Sponsor'
      }
    );
    sortOrder.add(
      new List<String>{
        'Exhibitor Sponsor',
        'Exhibitor Sponsor (Cocktail Round)'
      }
    );
    sortOrder.add(new List<String>{ 'Tabletop Sponsor' });
    sortOrder.add(new List<String>{ 'Awards Reception Underwriter' });
    sortOrder.add(new List<String>{ 'Awards Reception Sponsor' });
    sortOrder.add(
      new List<String>{ 'Bob Bullock Reception/Dinner Underwriter' }
    );
    sortOrder.add(new List<String>{ 'Bob Bullock Reception/Dinner Sponsor' });
    sortOrder.add(new List<String>{ 'Hugh L. Carey Reception Underwriter' });
    sortOrder.add(new List<String>{ 'Hugh L. Carey Reception Sponsor' });
    sortOrder.add(new List<String>{ 'Conference Bag Sponsor' });
    sortOrder.add(new List<String>{ 'Lanyard Sponsor' });
    sortOrder.add(new List<String>{ 'Notebook Sponsor' });
    sortOrder.add(new List<String>{ 'Networking Breaks Sponsor' });
    sortOrder.add(new List<String>{ 'Keynote Sponsor' });
    sortOrder.add(new List<String>{ 'Patron Sponsor' });
    sortOrder.add(new List<String>{ 'Program Guide Display Ad (BC)' });
    sortOrder.add(new List<String>{ 'Program Guide Display Ad (IBC)' });
    return sortByListOfLevels(sponsorsRef, sortOrder);
  }

  private List<Contract> sortSponsorsForGTorCDGEvent(
    List<Contract> sponsorsRef
  ) {
    List<List<String>> sortOrder = new List<List<String>>();
    sortOrder.add(new List<String>{ 'DSPI Sponsor', 'DC Sponsor', 'Sponsor' });
    sortOrder.add(new List<String>{ 'Dinner Sponsor' });
    sortOrder.add(new List<String>{ 'Opening Reception & Golf Sponsor' });
    sortOrder.add(new List<String>{ 'Entertainment Sponsor' });
    sortOrder.add(new List<String>{ 'Book Sponsor' });
    sortOrder.add(new List<String>{ 'Main Event Sponsor' });
    sortOrder.add(
      new List<String>{ 'Underwriter', 'Underwriter w/ Speaking Role' }
    );
    sortOrder.add(new List<String>{ 'Gold Sponsor' });
    sortOrder.add(new List<String>{ 'Silver Sponsor' });
    sortOrder.add(new List<String>{ 'Bronze Sponsor' });
    return sortByListOfLevels(sponsorsRef, sortOrder);
  }

  private List<Contract> sortSponsorsForCDEEvent(List<Contract> sponsorsRef) {
    List<List<String>> sortOrder = new List<List<String>>();
    sortOrder.add(
      new List<String>{
        'Anchor Sponsor',
        'Roundtable Breakfast/Anchor Sponsor'
      }
    );
    sortOrder.add(new List<String>{ 'Anchor Exhibitor (Harvard)' });
    sortOrder.add(new List<String>{ 'Exhibitor Sponsor' });
    sortOrder.add(new List<String>{ 'Display Exhibitor (Harvard)' });
    sortOrder.add(new List<String>{ 'Photo Booth Sponsor' });
    sortOrder.add(new List<String>{ 'Conference Bag Sponsor' });
    sortOrder.add(new List<String>{ 'Lanyard Sponsor' });
    sortOrder.add(new List<String>{ 'Notebook Sponsor' });
    sortOrder.add(new List<String>{ 'Networking Breaks Sponsor' });
    sortOrder.add(new List<String>{ 'Networking Breaks Exhibitor (Harvard)' });
    sortOrder.add(new List<String>{ 'Keynote Sponsor' });
    sortOrder.add(new List<String>{ 'Patron Sponsor' });
    sortOrder.add(new List<String>{ 'Patron Exhibitor (Harvard)' });
    sortOrder.add(new List<String>{ 'Program Guide Display Ad (BC)' });
    sortOrder.add(new List<String>{ 'Program Guide Display Ad (IBC)' });
    return sortByListOfLevels(sponsorsRef, sortOrder);
  }

  private List<Contract> sortByListOfLevels(
    List<Contract> sponsorsRef,
    List<List<String>> levels
  ) {
    List<Contract> sortedSponsors = new List<Contract>();
    for (List<String> lev1 : levels) {
      for (String lev2 : lev1) {
        for (Contract sp : sponsorsRef) {
          if (sp.Sponsorship_Level__c == lev2) {
            sortedSponsors.add(sp);
          }
        }
      }
    }
    return sortedSponsors;
  }

  public List<SelectOption> getSortTypes() {
    List<SelectOption> sortTypes = new List<SelectOption>();
    sortTypes.add(
      new SelectOption(
        'branding_alpha',
        'Sort: Branding Guidelines Alphabetical'
      )
    );
    sortTypes.add(new SelectOption('policy', 'Sort: Sponsorship Level Policy'));
    return sortTypes;
  }

  public void setSearch() {
    ApexPages.currentPage().getParameters().put('searchTerm', searchTerm);
    filterSponsors();
  }

  private void filterSponsors() {
    searchTerm = ApexPages.currentPage().getParameters().get('searchTerm');
    if (searchTerm != null && searchTerm != '') {
      List<Contract> filteredSponsors = new List<Contract>();
      for (Contract sp : sponsors) {
        if (
          sp.Sponsorship_Level__c.contains(searchTerm) ||
          sp.Branding_Guidelines__c.contains(searchTerm)
        ) {
          filteredSponsors.add(sp);
        }
      }
      sponsors = filteredSponsors;
    }
  }
}

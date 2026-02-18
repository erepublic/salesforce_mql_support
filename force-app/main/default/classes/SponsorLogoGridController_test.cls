@isTest(seeAllData=true)
public class SponsorLogoGridController_test {
  static testMethod void test() {
    Events__c event = testData.createEventWithRegistrations();

    Account acc = testData.createAccount(true);
    Contract ct = testData.createContract('012a0000001RKA9', acc.Id);
    ct.Event_Passes__c = 4;
    ct.Sponsorship_Name__c = 'Test Sponsor';
    ct.Event__c = event.Id;
    update ct;

    Account acc2 = testData.createAccount(true);
    Contract ct2 = testData.createContract('012a0000001RKA9', acc2.Id);
    ct2.Event_Passes__c = 2;
    ct2.Sponsorship_Name__c = 'Test Sponsor 2';
    ct2.Event__c = event.Id;
    update ct2;

    ApexPages.currentPage().getParameters().put('id', event.Id);

    ApexPages.StandardController sc = new ApexPages.StandardController(event);
    SponsorLogoGridController slgc = new SponsorLogoGridController();

    slgc.SponsorLogoGridController();

    slgc.setSortType();
    System.assertEquals(3, slgc.sponsors.size());

    ApexPages.currentPage().getParameters().put('sortType', 'policy');
    slgc.setSponsors();

    event.Event_Type__c = 'Exec Event';
    update event;

    slgc.setSponsors();

    event.Event_Type__c = 'CDG Event';
    update event;

    slgc.setSponsors();

    event.Event_Type__c = 'CDE Event';
    update event;

    slgc.setSponsors();

    event.Event_Type__c = 'Virtual Summit';
    update event;

    slgc.setSponsors();

    event.Event_Type__c = 'Standard_Invitation only w/ Hub';
    update event;

    slgc.setSponsors();

    event.Event_Type__c = 'Standard_Public Sector only w/ Hub';
    update event;

    slgc.setSponsors();

    List<SelectOption> opts = slgc.getSortTypes();
    System.assertEquals(2, opts.size());

    slgc.searchTerm = 'Test';
    slgc.setSearch();
  }
}

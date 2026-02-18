@isTest(seeAllData=true)
public with sharing class eventSponsorship_test {
  static testMethod void eventSponsorship_test() {
    OpportunityLineItem opli = new OpportunityLineItem();
    opli.TotalPrice = 119.00;
    opli.Opportunity = new Opportunity();
    opli.Opportunity.StageName = 'Written';
    opli.Opportunity.Account = new Account();
    opli.Opportunity.Account.Name = 'Test Name';
    opli.PricebookEntry = new PricebookEntry();
    opli.PricebookEntry.Product2 = new Product2();
    opli.PricebookEntry.Product2.Sponsorship__c = 'Break';
    eventSponsorship es = new eventSponsorship(opli);
    /*
		User u = [Select Id From User Where Email = 'josterholt@erepublic.com.staging'];
		
		OpportunityLineItem opli = new OpportunityLineItem();
		opli.TotalPrice            = 119.00;
		opli.Opportunity           = new Opportunity(Stagename = 'Written', Account = new Account(Name = 'Long Long Long Test Name', GT_Owner__r = u));
		//opli.Opportunity.StageName = 'Written';
		//opli.Opportunity.Account = new Account();
		//opli.Opportunity.Account.Name = 'Long Long Long Test Name';
		
		
		//UserRole ur = [Select Id From UserRole Where Name = 'Team 3 - Sales Manager']; // new UserRole(Name = 'Team 1', User = new User(Name = 'Test User'));
		//Profile p = new Profile();
		
		
		//User u = new User( Username = 'testuser@test.com', LastName = 'Test', Email = 'tesuser@test.com', Alias = 'Test', CommunityNickname = 'Test', TimeZoneSidKey = 'America/Los_Angeles', EmailEncodingKey = 'UTF-8', ProfileId = p.Id, LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US');
		//u.UserRole = ur;
		//insert u;
		
        //opli.Opportunity.Account.GT_Owner__r = u;

        // opli.Opportunity.Account.GT_Sales_Team_Formula__c = 'Long Long Long Test Name';
		opli.PricebookEntry = new PricebookEntry();
		opli.PricebookEntry.Product2 = new Product2();
		opli.PricebookEntry.Product2.Sponsorship__c = 'Break';
		
		eventSponsorship es2 = new eventSponsorship(opli);
		*/
  }

  static testMethod void eventSponsorshipController_test() {
    ApexPages.currentPage().getParameters().put('brand', 'GOVTECH');
    eventSponsorshipController c = new eventSponsorshipController();
  }
}

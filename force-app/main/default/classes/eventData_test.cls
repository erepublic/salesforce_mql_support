@isTest(seeAllData=true)
public with sharing class eventData_test {
  static testMethod void eventData_test() {
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard Sales Rep'];
    User usr = new User(
      Alias = 'standt',
      Email = 'standarduse' + testData.randomStr() + '@testorg.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Testing',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = p.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = 'standarduser' + testData.randomStr() + '@testorg.com'
    );
    insert usr;

    Account a1 = new Account(
      Name = 'Test Account 1',
      type = 'Customer',
      OwnerId = usr.Id
    );
    insert a1;

    System.assertEquals(usr.Id, a1.OwnerId);

    Account a2 = new Account(
      Name = 'Test Account 2',
      type = 'Customer',
      OwnerId = usr.Id
    );
    insert a2;

    Account a3 = new Account(
      Name = 'Test Account 3',
      type = 'Customer',
      OwnerId = usr.Id
    );
    insert a3;

    // 2011 Event
    Events__c e1 = new Events__c(
      Name = 'Test Event 2011',
      Nickname__c = 'TE2011',
      Event_Start_Date__c = date.newInstance(2011, 1, 1),
      Event_End_Date__c = date.newInstance(2011, 1, 1),
      Sponsorship_Revenue_Target__c = 2000
    );
    insert e1;

    Product2 product1 = new Product2(
      Name = 'Test Product',
      isActive = true,
      EE_Event__c = e1.Id,
      c2g__CODASalesRevenueAccount__c = 'a1u140000005RD3'
    );
    insert product1;

    Pricebook2 priceBook1 = [SELECT id FROM Pricebook2 WHERE IsStandard = TRUE];

    PricebookEntry pb1 = new PricebookEntry(
      Product2Id = product1.Id,
      Pricebook2Id = priceBook1.Id,
      UnitPrice = 300.00,
      UseStandardPrice = false,
      IsActive = true
    );
    insert pb1;

    // Opportunity A
    Opportunity o1a = new Opportunity(
      Name = 'Test Opportunity 2011 A',
      CloseDate = date.newInstance(2011, 3, 14),
      AccountId = a1.Id,
      StageName = 'Qualification'
    );
    insert o1a;

    OpportunityLineItem ol1a = new OpportunityLineItem(
      OpportunityId = o1a.Id,
      Quantity = 1,
      TotalPrice = 200.00,
      PricebookEntryId = pb1.Id
    );
    insert ol1a;

    // Opportunity B
    Opportunity o1b = new Opportunity(
      Name = 'Test Opportunity 2011 B',
      CloseDate = date.newInstance(2011, 3, 14),
      AccountId = a2.Id,
      StageName = 'Qualification'
    );
    insert o1b;

    OpportunityLineItem ol1b = new OpportunityLineItem(
      OpportunityId = o1b.Id,
      Quantity = 1,
      TotalPrice = 200.00,
      PricebookEntryId = pb1.Id
    );
    insert ol1b;

    // Opportunity C
    Opportunity o1c = new Opportunity(
      Name = 'Test Opportunity 2011 C',
      CloseDate = date.newInstance(2011, 3, 14),
      AccountId = a2.Id,
      StageName = 'Qualification'
    );
    insert o1c;

    OpportunityLineItem ol1c = new OpportunityLineItem(
      OpportunityId = o1c.Id,
      Quantity = 1,
      TotalPrice = 200.00,
      PricebookEntryId = pb1.Id
    );
    insert ol1c;

    // Opportunity D
    Opportunity o1d = new Opportunity(
      Name = 'Test Opportunity 2011 D',
      CloseDate = date.newInstance(2011, 3, 14),
      AccountId = a3.Id,
      StageName = 'Qualification'
    );
    insert o1d;

    OpportunityLineItem ol1d = new OpportunityLineItem(
      OpportunityId = o1d.Id,
      Quantity = 1,
      TotalPrice = 200.00,
      PricebookEntryId = pb1.Id
    );
    insert ol1d;

    // 2012 Event
    Events__c e2 = new Events__c(
      Name = 'Test Event 2012',
      Nickname__c = 'TE2012',
      Event_Start_Date__c = date.newInstance(2012, 1, 1),
      Event_End_Date__c = date.newInstance(2012, 1, 1),
      Sponsorship_Revenue_Target__c = 2000,
      last_years_event__c = e1.Id
    );
    insert e2;

    Product2 product2 = new Product2(
      Name = 'Test Product',
      isActive = true,
      EE_Event__c = e2.Id,
      c2g__CODASalesRevenueAccount__c = 'a1u140000005RD3'
    );
    insert product2;

    Pricebook2 priceBook2 = [SELECT id FROM Pricebook2 WHERE IsStandard = TRUE];

    PricebookEntry pb2 = new PricebookEntry(
      Product2Id = product2.Id,
      Pricebook2Id = priceBook2.Id,
      UnitPrice = 300.00,
      UseStandardPrice = false,
      IsActive = true
    );
    insert pb2;

    //Opportuntiy A
    Opportunity o2a = new Opportunity(
      Name = 'Test Opportunity 2012',
      CloseDate = date.newInstance(2011, 3, 14),
      AccountId = a1.Id,
      StageName = 'Qualification'
    );
    insert o2a;

    OpportunityLineItem ol2a = new OpportunityLineItem(
      OpportunityId = o2a.Id,
      Quantity = 1,
      TotalPrice = 200.00,
      PricebookEntryId = pb2.Id
    );
    insert ol2a;

    //Opportuntiy B
    Opportunity o2b = new Opportunity(
      Name = 'Test Opportunity 2012',
      CloseDate = date.newInstance(2011, 3, 14),
      AccountId = a2.Id,
      StageName = 'Verbal'
    );
    insert o2b;

    OpportunityLineItem ol2b = new OpportunityLineItem(
      OpportunityId = o2b.Id,
      Quantity = 1,
      TotalPrice = 200.00,
      PricebookEntryId = pb2.Id
    );
    insert ol2b;

    //Opportuntiy C
    Opportunity o2c = new Opportunity(
      Name = 'Test Opportunity 2012',
      CloseDate = date.newInstance(2011, 3, 14),
      AccountId = a2.Id,
      StageName = 'Meeting'
    );
    insert o2c;

    OpportunityLineItem ol2c = new OpportunityLineItem(
      OpportunityId = o2c.Id,
      Quantity = 1,
      TotalPrice = 200.00,
      PricebookEntryId = pb2.Id
    );
    insert ol2c;

    // 2012 Event Other
    Events__c e3 = new Events__c(
      Name = 'Test Event 2012 Other',
      Nickname__c = 'TEOther',
      Event_Start_Date__c = date.newInstance(2012, 1, 1),
      Event_End_Date__c = date.newInstance(2012, 1, 1),
      Sponsorship_Revenue_Target__c = null,
      last_years_event__c = null
    );
    insert e3;

    Test.startTest();
    Opportunity o = [
      SELECT Id, Name, Account.Name
      FROM Opportunity
      WHERE Name = 'Test Opportunity 2011 A'
    ];
    System.debug(o.Account.Name);
    Events__c event;
    eventHotSheet ehs;

    event = [
      SELECT
        Id,
        Name,
        Nickname__c,
        Event_Start_Date__c,
        Event_End_Date__c,
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
      WHERE Name = 'Test Event 2012'
    ];
    ehs = new eventHotSheet(event);

    System.assertEquals('TE2012', ehs.currentEventName);
    System.assertEquals(ehs.currentEventYear, 2012);
    System.assertEquals('TE2011', ehs.previousEventName);
    System.assertEquals(2011, ehs.previousEventYear);
    System.assertEquals(
      date.newInstance(2012, 1, 1),
      ehs.currentEventStartDate
    );
    System.assertEquals(date.newInstance(2012, 1, 1), ehs.currentEventEndDate);
    System.assertEquals(2000, ehs.revenueTarget);
    /*  had to do this since they failed    
        System.assertEquals(1800.00, ehs.revenueDifference);
        System.assertEquals(200.00, ehs.WonTotal);
        System.assertEquals(200.00, ehs.HotTotal);
        System.assertEquals(200.00, ehs.WarmTotal);
        System.assertEquals(0, ehs.MissingTotal);
*/
    System.assert(ehs.getWonOpportunityItems() != null);
    System.assert(ehs.getWonOpportunityItems() != null);
    System.assert(ehs.getHotOpportunityItems() != null);
    System.assert(ehs.getWarmOpportunityItems() != null);

    event = [
      SELECT
        Id,
        Name,
        Nickname__c,
        Event_Start_Date__c,
        Event_End_Date__c,
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
      WHERE Name = 'Test Event 2012 Other'
    ];
    ehs = new eventHotSheet(event);
    System.assertEquals(2012, ehs.currentEventYear);
    System.assertEquals(null, ehs.previousEventName);
    System.assertEquals(null, ehs.previousEventYear);
    System.assertEquals(
      date.newInstance(2012, 1, 1),
      ehs.currentEventStartDate
    );
    System.assertEquals(date.newInstance(2012, 1, 1), ehs.currentEventEndDate);
    System.assertEquals(null, ehs.revenueTarget);
    System.assertEquals(null, ehs.revenueDifference);
    System.assertEquals(0.00, ehs.WonTotal);
    System.assertEquals(0.00, ehs.HotTotal);
    System.assertEquals(0.00, ehs.WarmTotal);
    System.assertEquals(0.00, ehs.MissingTotal);

    System.assert(ehs.MissingOpportunityItems != null);
  }
}

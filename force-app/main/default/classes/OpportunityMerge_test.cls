@isTest(SeeAllData=true)
public class OpportunityMerge_test {
  static testMethod void testMerge() {
    Opportunity winnerOpp = testData.createOpportunity();
    Opportunity loserOpp = testData.createOpportunity();

    List<OpportunityLineItem> lineItems = new List<OpportunityLineItem>();
    for (Integer i = 0; i < 2; i++) {
      Pricebook2 standardPB = [
        SELECT Id
        FROM Pricebook2
        WHERE IsStandard = TRUE
        LIMIT 1
      ];
      Product2 prod = new Product2(
        Name = 'Test Product',
        ProductCode = 'TestCode', // Product code is required when scheduling is enabled
        IsActive = true,
        CanUseRevenueSchedule = true, // Enable revenue scheduling
        CanUseQuantitySchedule = true, // Uncomment this line if you want to enable quantity scheduling
        c2g__CODASalesRevenueAccount__c = 'a1u140000005RD3'
      );
      insert prod;
      PricebookEntry pbe = new PricebookEntry(
        Pricebook2Id = standardPB.Id,
        Product2Id = prod.Id,
        UnitPrice = 100.00,
        IsActive = true
      );
      insert pbe;
      OpportunityLineItem oli = new OpportunityLineItem(
        OpportunityId = loserOpp.Id,
        UnitPrice = 10,
        Quantity = 5,
        PricebookEntryId = pbe.Id
      );
      lineItems.add(oli);
    }
    insert lineItems;

    // Create OpportunityLineItemSchedules for each OpportunityLineItem
    for (OpportunityLineItem oli : lineItems) {
      OpportunityLineItemSchedule olis = new OpportunityLineItemSchedule(
        OpportunityLineItemId = oli.Id,
        ScheduleDate = Date.today().addDays(30),
        Revenue = oli.UnitPrice,
        Type = 'Revenue',
        Description = 'CC '
      );
      insert olis;
    }

    // add activity history to the Opp.
    Task t = new Task(
      Status = 'Completed',
      Subject = 'Other',
      Priority = 'Normal',
      Type = 'Other',
      WhatId = loserOpp.Id
    );
    insert t;

    // Add agreements, contracts, files and contact roles
    Agreement__c ag = new Agreement__c(
      Opportunity__c = loserOpp.Id,
      Description__c = 'Losing Agreement',
      Status__c = 'Draft'
    );

    insert ag;

    Account ac = testData.createAccount();

    Contract ct = new Contract(
      Name = 'Test Losing Contract',
      Status = 'Draft',
      Primary_Opportunity__c = loserOpp.Id,
      AccountId = ac.Id
    );

    insert ct;

    testData.attachFile(loserOpp.Id);

    List<Id> losers = new List<Id>{ loserOpp.Id };
    OpportunityMerge.mergeOpps(winnerOpp.Id, losers);

    // check activity history
    System.assertEquals(
      1,
      database.countQuery(
        'SELECT COUNT() FROM Task WHERE WhatId =\'' + winnerOpp.Id + '\''
      )
    );
    // check files
    System.assertEquals(
      1,
      database.countQuery(
        'SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId =\'' +
          winnerOpp.Id +
          '\''
      )
    );
    // check contract
    System.assertEquals(
      false,
      [SELECT Id FROM Contract WHERE Primary_Opportunity__c = :winnerOpp.Id]
        .isEmpty()
    );
    // check that agreements were moved over
    System.assertEquals(
      false,
      [SELECT Id FROM Agreement__c WHERE Opportunity__c = :winnerOpp.Id]
        .isEmpty()
    );
    // check that the OpportunityLineItems have been added.
    System.assertEquals(
      12,
      database.countQuery(
        'SELECT COUNT() FROM OpportunityLineItem WHERE OpportunityId =\'' +
          winnerOpp.Id +
          '\''
      )
    );
    // check that the Opportunity has been deleted.
    System.assertEquals(
      true,
      [SELECT Id FROM Opportunity WHERE Id = :loserOpp.Id].isEmpty()
    );
    List<OpportunityLineItem> winnerLineItems = [
      SELECT Id
      FROM OpportunityLineItem
      WHERE OpportunityId = :winnerOpp.Id
    ];
    System.assertEquals(
      2,
      [
        SELECT COUNT()
        FROM OpportunityLineItemSchedule
        WHERE OpportunityLineItemId IN :winnerLineItems
      ]
    );
  }
}

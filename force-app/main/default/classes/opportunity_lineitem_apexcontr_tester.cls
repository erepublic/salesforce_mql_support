@isTest(SeeAllData=true)
public class opportunity_lineitem_apexcontr_tester {
  static testMethod void test_test_delete_event_lineitem() {
    Account theAccount = testdata.createAccount();
    // createOpportunityForAccount will create a product  which will create an event.
    // the second event that gets created automaticall gets its previous years event set
    testdata.Retvals lastYear = testData.createOpportunityForAccount(
      theAccount.Id,
      2
    );
    testdata.Retvals thisYear = testData.createOpportunityForAccount(
      theAccount.Id,
      2
    );
    System.debug(thisYear.lineItem);

    opportunity_lineitem_apexcontroller.delete_event_lineitem(
      thisYear.lineItem.Id,
      'test reason'
    );
    OpportunityLineItem li = [
      SELECT Id, Returning_status__c
      FROM OpportunityLineItem
      WHERE Id = :lastYear.lineItem.Id
      LIMIT 1
    ];
    System.assertEquals('test reason', li.Returning_status__c);
  }

  static testMethod void test_contract_from_product() {
    Opportunity o = testData.createOpportunity();
    OpportunityLineItem[] ls = [
      SELECT Id, Product2Id
      FROM OpportunityLineItem
      WHERE OpportunityId = :o.Id
    ];
    Product2 p = [
      SELECT Id, Product_Type__c
      FROM Product2
      WHERE Id = :ls.get(0).Product2Id
    ];
    //  part2(o); // events

    p.Product_Type__c = 'Navigator';
    update p;
    part2(o);
  }

  static testMethod void test_contract_from_product2() {
    Opportunity o = testData.createOpportunity();
    OpportunityLineItem[] ls = [
      SELECT Id, Product2Id
      FROM OpportunityLineItem
      WHERE OpportunityId = :o.Id
    ];
    Product2 p = [
      SELECT Id, Product_Type__c
      FROM Product2
      WHERE Id = :ls.get(0).Product2Id
    ];

    p.Product_Type__c = 'Techwire';
    update p;
    part2(o);

    p.Product_Type__c = 'Program';
    update p;
    part2(o);
  }

  static void part2(Opportunity o) {
    OpportunityLineItem[] ls = [
      SELECT Id
      FROM OpportunityLineItem
      WHERE OpportunityId = :o.Id
    ];

    for (OpportunityLineItem l : ls) {
      opportunity_lineitem_apexcontroller.create_contract(l.Id);
      try {
        opportunity_lineitem_apexcontroller.create_content_project_actn(l.Id);
      } catch (AuraHandledException e) {
        // this should not stop backend testing
      }
    }

    // check
    Contract[] cs = [
      SELECT Id, Primary_Opportunity__c
      FROM Contract
      WHERE Primary_Opportunity__c = :o.Id
    ];
    for (Contract c : cs) {
      System.debug('*** c ' + c.Primary_Opportunity__c);
    }
  }
}

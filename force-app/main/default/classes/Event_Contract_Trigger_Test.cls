@isTest
public class Event_Contract_Trigger_Test {
  static testMethod void testInsertContract() {
    Test.startTest();
    // create event.
    Events__c masterEvent = testData.createEvent(false);
    masterEvent.Name = 'Master Test Event';
    insert masterEvent;
    // create reception event, assoc with event.
    Events__c receptionEvent = testData.createEvent(false);
    receptionEvent.Name = 'Reception Test Event';
    receptionEvent.Parent_Event__c = masterEvent.id;
    insert receptionEvent;
    // create product for event with Sponsorship_Level__c and no_of_Reception_Passes
    Product2 p = new Product2(
      Name = 'Test Product With Reception Passes',
      Product_Type__c = 'Events',
      Event_Type__c = 'GOV',
      EE_Event__c = masterEvent.id,
      CanUseQuantitySchedule = true,
      CanUseRevenueSchedule = true,
      //Product_Platform__c = 'product platform',
      Sponsorship__c = 'Anchor',
      Event_Passes__c = 4,
      no_of_Reception_Passes__c = 2
    );
    insert p;
    // create a product without reception passes.
    Product2 p2 = new Product2(
      Name = 'Test Product Without Reception Passes',
      Product_Type__c = 'Events',
      Event_Type__c = 'GOV',
      EE_Event__c = masterEvent.id,
      CanUseQuantitySchedule = true,
      CanUseRevenueSchedule = true,
      //Product_Platform__c = 'product platform',
      Sponsorship__c = 'Exhibitor',
      Additional_Pass_Limit__c = 2,
      Event_Passes__c = 2
    );
    insert p2;

    // create account for sponsorship
    Account acc = testData.createAccount(true);

    // create a contract for sponsorship
    Contract ct = testData.createContract('012a0000001RKA9', acc.id);

    ct.Event_Passes__c = 4;
    ct.Sponsorship_Name__c = 'Test Sponsor';
    ct.Sponsorship_Level__c = 'Exhibitor';
    ct.Event__c = masterEvent.id;
    ct.Status = 'Draft';
    update ct;
    ct.Status = 'Active';
    update ct;
    // assert that no reception event contract exists yet.
    System.assertEquals(
      true,
      [SELECT Id FROM Contract WHERE Related_Contract__c = :ct.id].isEmpty()
    );

    // ct.Status = 'Draft';
    ct.Sponsorship_Level__c = 'Anchor';
    update ct;

    // assert that a contract on the reception event now exists with the number of passes
    // from the product no_of_Reception_Passes__c
    Contract existentContract = [
      SELECT
        Id,
        Event_Passes__c,
        Related_Contract__c,
        Change_Log__c,
        Contact_Role_Changes__c,
        SpecialTerms,
        Additional_Pass_Limit__c,
        Master_Contract__c
      FROM Contract
      WHERE Related_Contract__c = :ct.id
    ];
    System.assertNotEquals(null, existentContract);
    System.assertEquals(2, existentContract.Event_Passes__c);
    System.assertEquals(ct.id, existentContract.Related_Contract__c);
    System.assertEquals(null, existentContract.Change_Log__c);
    System.assertEquals(null, existentContract.Contact_Role_Changes__c);
    System.assertEquals(2, existentContract.Additional_Pass_Limit__c);
    System.assertEquals(false, existentContract.Master_Contract__c);
    System.assertEquals(
      'See main event for event contract.',
      existentContract.SpecialTerms
    );
    Test.stopTest();
  }
}

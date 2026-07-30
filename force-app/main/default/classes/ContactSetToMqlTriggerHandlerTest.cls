@isTest
private class ContactSetToMqlTriggerHandlerTest {
  private class FastSummaryMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"summaryHtml":"<p>mock summary</p>"}');
      return res;
    }
  }

  private static void setupCalloutMock() {
    upsert new MqlSecrets__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      ApiGatewayApiKey__c = 'test-apigw-key'
    );
    Test.setMock(HttpCalloutMock.class, new FastSummaryMock());
  }

  private static Contact createContact(Boolean setToMql) {
    Account a = new Account(Name = 'MQL Trigger Test Account ' + System.now());
    insert a;

    Contact c = new Contact(
      LastName = 'Trigger Test',
      Email = 'trigger.test.' +
        String.valueOf(Crypto.getRandomInteger()) +
        '@example.com',
      AccountId = a.Id,
      Set_to_MQL__c = setToMql
    );
    insert c;
    return c;
  }

  private static Product2 createThresholdProduct() {
    Product2 p = new Product2(
      Name = ContactSetToMqlTriggerHandler.THRESHOLD_PRODUCT_NAME,
      IsActive = false
    );
    insert p;
    return p;
  }

  private static Product2 createHandRaiserProduct() {
    Product2 p = new Product2(
      Name = 'Hand Raiser Product ' + System.now(),
      IsActive = false
    );
    insert p;
    return p;
  }

  private static Campaign createCampaignRecord() {
    Campaign c = new Campaign(
      Name = 'Hand Raiser Campaign ' + System.now(),
      IsActive = true
    );
    insert c;
    return c;
  }

  @isTest
  static void createsMqlWhenSetToMqlFlipsTrueOnUpdate() {
    setupCalloutMock();
    Product2 thresholdProduct = createThresholdProduct();
    Contact c = createContact(false);

    Test.startTest();
    c.Set_to_MQL__c = true;
    update c;
    Test.stopTest();

    List<MQL__c> mqls = [
      SELECT
        Id,
        Contact__c,
        Lead_Source__c,
        MQL_Status__c,
        MQL_Date__c,
        Product__c
      FROM MQL__c
      WHERE Contact__c = :c.Id
    ];
    System.assertEquals(1, mqls.size(), 'Expected one new MQL for contact');
    System.assertEquals(
      ContactSetToMqlTriggerHandler.THRESHOLD_LEAD_SOURCE,
      mqls[0].Lead_Source__c
    );
    System.assertEquals(
      ContactSetToMqlTriggerHandler.NEW_STATUS,
      mqls[0].MQL_Status__c
    );
    System.assertEquals(Date.today(), mqls[0].MQL_Date__c);
    System.assertEquals(
      thresholdProduct.Id,
      mqls[0].Product__c,
      'Expected threshold product to be assigned'
    );

    Contact refreshed = [SELECT Set_to_MQL__c FROM Contact WHERE Id = :c.Id];
    System.assertEquals(
      false,
      refreshed.Set_to_MQL__c,
      'Expected Set_to_MQL__c to be reset after processing'
    );
  }

  @isTest
  static void createsMqlWhenInsertedWithSetToMqlTrue() {
    setupCalloutMock();
    Product2 thresholdProduct = createThresholdProduct();
    Test.startTest();
    Contact c = createContact(true);
    Test.stopTest();

    List<MQL__c> mqls = [
      SELECT Id, Product__c
      FROM MQL__c
      WHERE
        Contact__c = :c.Id
        AND Lead_Source__c = :ContactSetToMqlTriggerHandler.THRESHOLD_LEAD_SOURCE
    ];
    System.assertEquals(
      1,
      mqls.size(),
      'Expected an MQL to be created on insert when Set_to_MQL is true'
    );
    System.assertEquals(
      thresholdProduct.Id,
      mqls[0].Product__c,
      'Expected threshold product to be assigned'
    );

    Contact refreshed = [SELECT Set_to_MQL__c FROM Contact WHERE Id = :c.Id];
    System.assertEquals(
      false,
      refreshed.Set_to_MQL__c,
      'Expected Set_to_MQL__c to be reset after processing'
    );
  }

  @isTest
  static void doesNotCreateDuplicateWhenNewThresholdMqlAlreadyExists() {
    setupCalloutMock();
    Contact c = createContact(false);
    insert new MQL__c(
      Contact__c = c.Id,
      Lead_Source__c = ContactSetToMqlTriggerHandler.THRESHOLD_LEAD_SOURCE,
      MQL_Status__c = ContactSetToMqlTriggerHandler.NEW_STATUS,
      MQL_Date__c = Date.today()
    );

    Test.startTest();
    c.Set_to_MQL__c = true;
    update c;
    Test.stopTest();

    Integer countMqls = [
      SELECT COUNT()
      FROM MQL__c
      WHERE
        Contact__c = :c.Id
        AND Lead_Source__c = :ContactSetToMqlTriggerHandler.THRESHOLD_LEAD_SOURCE
        AND MQL_Status__c = :ContactSetToMqlTriggerHandler.NEW_STATUS
    ];
    System.assertEquals(
      1,
      countMqls,
      'Expected no duplicate NEW threshold MQL for same contact'
    );

    Contact refreshed = [SELECT Set_to_MQL__c FROM Contact WHERE Id = :c.Id];
    System.assertEquals(
      false,
      refreshed.Set_to_MQL__c,
      'Expected Set_to_MQL__c to reset even when duplicate MQL exists'
    );
  }

  @isTest
  static void doesNotCreateThresholdMqlWhenRecentNonThresholdMqlExists() {
    setupCalloutMock();
    Contact c = createContact(false);
    insert new MQL__c(
      Contact__c = c.Id,
      Lead_Source__c = 'Email',
      MQL_Status__c = ContactSetToMqlTriggerHandler.NEW_STATUS,
      MQL_Date__c = Date.today()
    );

    Test.startTest();
    c.Set_to_MQL__c = true;
    update c;
    Test.stopTest();

    Integer thresholdCount = [
      SELECT COUNT()
      FROM MQL__c
      WHERE
        Contact__c = :c.Id
        AND Lead_Source__c = :ContactSetToMqlTriggerHandler.THRESHOLD_LEAD_SOURCE
    ];
    System.assertEquals(
      0,
      thresholdCount,
      'A recent non-threshold NEW MQL should block a second threshold-labeled MQL'
    );

    Contact refreshed = [SELECT Set_to_MQL__c FROM Contact WHERE Id = :c.Id];
    System.assertEquals(
      false,
      refreshed.Set_to_MQL__c,
      'Expected Set_to_MQL__c to reset even when threshold creation is skipped'
    );
  }

  @isTest
  static void createsMqlWithoutProductWhenThresholdProductMissing() {
    setupCalloutMock();
    Contact c = createContact(false);

    Test.startTest();
    c.Set_to_MQL__c = true;
    update c;
    Test.stopTest();

    List<MQL__c> mqls = [
      SELECT Id, Product__c
      FROM MQL__c
      WHERE
        Contact__c = :c.Id
        AND Lead_Source__c = :ContactSetToMqlTriggerHandler.THRESHOLD_LEAD_SOURCE
    ];
    System.assertEquals(1, mqls.size(), 'Expected threshold MQL to be created');
    System.assertEquals(
      null,
      mqls[0].Product__c,
      'Expected Product__c to remain null when threshold product is missing'
    );
  }

  @isTest
  static void createsHandRaiserMqlWithEventsPortalAndLinkedOpportunity() {
    setupCalloutMock();
    Account a = new Account(Name = 'Hand Raiser Test Account');
    insert a;
    Product2 product = createHandRaiserProduct();

    Opportunity opp = new Opportunity(
      Name = 'Hand Raiser Opp',
      AccountId = a.Id,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30)
    );
    insert opp;

    Contact c = new Contact(
      LastName = 'Hand Raiser Test',
      Email = 'hand.raiser.' +
        String.valueOf(Crypto.getRandomInteger()) +
        '@example.com',
      AccountId = a.Id,
      Set_to_MQL__c = false,
      Hand_Raiser_Opportunity_Id__c = opp.Id,
      Hand_Raiser_Product_Id__c = product.Id
    );
    insert c;

    Test.startTest();
    c.Set_to_MQL__c = true;
    update c;
    Test.stopTest();

    List<MQL__c> mqls = [
      SELECT
        Id,
        Lead_Source__c,
        Opportunity__c,
        MQL_Status__c,
        MQL_Date__c,
        Product__c
      FROM MQL__c
      WHERE Contact__c = :c.Id
    ];
    System.assertEquals(
      1,
      mqls.size(),
      'Expected one MQL for hand-raiser contact'
    );
    System.assertEquals(
      ContactSetToMqlTriggerHandler.EVENTS_PORTAL_LEAD_SOURCE,
      mqls[0].Lead_Source__c,
      'Expected Events Portal lead source for hand raiser'
    );
    System.assertEquals(
      opp.Id,
      mqls[0].Opportunity__c,
      'Expected linked Opportunity on hand-raiser MQL'
    );
    System.assertEquals(
      product.Id,
      mqls[0].Product__c,
      'Expected hand-raiser product to be copied onto the MQL'
    );
    System.assertEquals(
      ContactSetToMqlTriggerHandler.NEW_STATUS,
      mqls[0].MQL_Status__c
    );
    System.assertEquals(Date.today(), mqls[0].MQL_Date__c);

    Contact refreshed = [
      SELECT
        Set_to_MQL__c,
        Hand_Raiser_Opportunity_Id__c,
        Hand_Raiser_Product_Id__c
      FROM Contact
      WHERE Id = :c.Id
    ];
    System.assertEquals(
      false,
      refreshed.Set_to_MQL__c,
      'Expected Set_to_MQL__c to be reset after hand-raiser processing'
    );
    System.assertEquals(
      null,
      refreshed.Hand_Raiser_Opportunity_Id__c,
      'Expected Hand_Raiser_Opportunity_Id__c to be cleared after processing'
    );
    System.assertEquals(
      null,
      refreshed.Hand_Raiser_Product_Id__c,
      'Expected Hand_Raiser_Product_Id__c to be cleared after processing'
    );
  }

  // ---- Route A: Portal created a new Opp (Hand_Raiser_Opp_Is_New__c = true) ----

  @isTest
  static void routeA_createsConvertedMqlWithConversionFields() {
    setupCalloutMock();
    String transactionId = 'ep-route-a-000001';
    Account a = new Account(Name = 'Route A Test Account');
    insert a;
    Product2 product = createHandRaiserProduct();
    Campaign campaign = createCampaignRecord();

    Opportunity opp = new Opportunity(
      Name = 'Route A Opp',
      AccountId = a.Id,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30),
      Transaction_ID__c = transactionId
    );
    insert opp;

    Contact c = new Contact(
      LastName = 'Route A Test',
      Email = 'route.a.' +
        String.valueOf(Crypto.getRandomInteger()) +
        '@example.com',
      AccountId = a.Id,
      Set_to_MQL__c = false,
      Hand_Raiser_Opportunity_Id__c = opp.Id,
      Hand_Raiser_Product_Id__c = product.Id,
      Hand_Raiser_Transaction_Id__c = transactionId,
      Hand_Raiser_Opp_Is_New__c = true,
      Hand_Raiser_Lead_Source_Detail__c = '/events/sponsorship-opportunities/a0m123',
      Hand_Raiser_Lead_Detail_1__c = 'Route A comments',
      Hand_Raiser_Lead_Detail_2__c = 'Product: https://example.com/product',
      Hand_Raiser_Lead_Detail_3__c = 'Route A additional context',
      Hand_Raiser_Lead_Detail_4__c = 'Event datasheet + opp links',
      Hand_Raiser_Campaign_Id__c = campaign.Id,
      Hand_Raiser_Payload_Version__c = 'v1'
    );
    insert c;

    Test.startTest();
    c.Set_to_MQL__c = true;
    update c;
    Test.stopTest();

    List<MQL__c> mqls = [
      SELECT
        Id,
        Lead_Source__c,
        MQL_Status__c,
        Opportunity__c,
        Product__c,
        Transaction_Id__c,
        Lead_Source_Detail__c,
        Lead_Detail_1__c,
        Lead_Detail_2__c,
        Lead_Detail_3__c,
        Lead_Detail_4__c,
        Campaign__c,
        Conversion_Type__c,
        Conversion_Date__c,
        Converted_By__c
      FROM MQL__c
      WHERE Contact__c = :c.Id
    ];
    System.assertEquals(1, mqls.size(), 'Expected one MQL for Route A contact');
    System.assertEquals(
      ContactSetToMqlTriggerHandler.EVENTS_PORTAL_LEAD_SOURCE,
      mqls[0].Lead_Source__c,
      'Expected Events Portal lead source'
    );
    System.assertEquals(
      ContactSetToMqlTriggerHandler.CONVERTED_STATUS,
      mqls[0].MQL_Status__c,
      'Route A MQL should be Converted, not New'
    );
    System.assertEquals(
      opp.Id,
      mqls[0].Opportunity__c,
      'Expected linked Opportunity'
    );
    System.assertEquals(
      product.Id,
      mqls[0].Product__c,
      'Expected Route A to preserve the explicit product on the MQL'
    );
    System.assertEquals(
      opp.Transaction_ID__c,
      mqls[0].Transaction_Id__c,
      'Route A MQL and Opportunity transaction ids must match exactly'
    );
    System.assertEquals(
      '/events/sponsorship-opportunities/a0m123',
      mqls[0].Lead_Source_Detail__c
    );
    System.assertEquals('Route A comments', mqls[0].Lead_Detail_1__c);
    System.assertEquals(
      'Product: https://example.com/product',
      mqls[0].Lead_Detail_2__c
    );
    System.assertEquals('Route A additional context', mqls[0].Lead_Detail_3__c);
    System.assertEquals(
      'Event datasheet + opp links',
      mqls[0].Lead_Detail_4__c
    );
    System.assertEquals(campaign.Id, mqls[0].Campaign__c);
    System.assertEquals(
      ContactSetToMqlTriggerHandler.CONVERSION_TYPE_NEW_OPP,
      mqls[0].Conversion_Type__c,
      'Expected Conversion_Type__c = Created Opportunity'
    );
    System.assertEquals(
      Date.today(),
      mqls[0].Conversion_Date__c,
      'Expected Conversion_Date__c = today'
    );
    System.assertEquals(
      ContactSetToMqlTriggerHandler.CONVERTED_BY_AUTOMATION,
      mqls[0].Converted_By__c,
      'Expected Converted_By__c = Automation'
    );

    Contact refreshed = [
      SELECT
        Set_to_MQL__c,
        Hand_Raiser_Opportunity_Id__c,
        Hand_Raiser_Product_Id__c,
        Hand_Raiser_Transaction_Id__c,
        Hand_Raiser_Opp_Is_New__c,
        Hand_Raiser_Lead_Source_Detail__c,
        Hand_Raiser_Lead_Detail_1__c,
        Hand_Raiser_Lead_Detail_2__c,
        Hand_Raiser_Lead_Detail_3__c,
        Hand_Raiser_Lead_Detail_4__c,
        Hand_Raiser_Campaign_Id__c,
        Hand_Raiser_Payload_Version__c
      FROM Contact
      WHERE Id = :c.Id
    ];
    System.assertEquals(false, refreshed.Set_to_MQL__c);
    System.assertEquals(null, refreshed.Hand_Raiser_Opportunity_Id__c);
    System.assertEquals(null, refreshed.Hand_Raiser_Product_Id__c);
    System.assertEquals(null, refreshed.Hand_Raiser_Transaction_Id__c);
    System.assertEquals(
      false,
      refreshed.Hand_Raiser_Opp_Is_New__c,
      'Expected Hand_Raiser_Opp_Is_New__c to be cleared after Route A'
    );
    System.assertEquals(null, refreshed.Hand_Raiser_Lead_Source_Detail__c);
    System.assertEquals(null, refreshed.Hand_Raiser_Lead_Detail_1__c);
    System.assertEquals(null, refreshed.Hand_Raiser_Lead_Detail_2__c);
    System.assertEquals(null, refreshed.Hand_Raiser_Lead_Detail_3__c);
    System.assertEquals(null, refreshed.Hand_Raiser_Lead_Detail_4__c);
    System.assertEquals(null, refreshed.Hand_Raiser_Campaign_Id__c);
    System.assertEquals(null, refreshed.Hand_Raiser_Payload_Version__c);
  }

  // ---- Route B: Opp already existed (Hand_Raiser_Opp_Is_New__c = false/null) ----

  @isTest
  static void routeB_createsNewMqlWithoutConversionFields() {
    setupCalloutMock();
    String transactionId = 'ep-route-b-000001';
    Account a = new Account(Name = 'Route B Test Account');
    insert a;
    Campaign campaign = createCampaignRecord();

    Opportunity opp = new Opportunity(
      Name = 'Route B Opp',
      AccountId = a.Id,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30)
    );
    insert opp;

    // Hand_Raiser_Opp_Is_New__c is false (not set) — Route B
    Contact c = new Contact(
      LastName = 'Route B Test',
      Email = 'route.b.' +
        String.valueOf(Crypto.getRandomInteger()) +
        '@example.com',
      AccountId = a.Id,
      Set_to_MQL__c = false,
      Hand_Raiser_Opportunity_Id__c = opp.Id,
      Hand_Raiser_Transaction_Id__c = transactionId,
      Hand_Raiser_Lead_Source_Detail__c = '/events/sponsorship-opportunities/a0m456',
      Hand_Raiser_Lead_Detail_1__c = 'Route B comments',
      Hand_Raiser_Lead_Detail_2__c = 'Product: https://example.com/product-b',
      Hand_Raiser_Lead_Detail_3__c = 'Route B additional context',
      Hand_Raiser_Lead_Detail_4__c = 'Route B event links',
      Hand_Raiser_Campaign_Id__c = campaign.Id,
      Hand_Raiser_Payload_Version__c = 'v1'
    );
    insert c;

    Test.startTest();
    c.Set_to_MQL__c = true;
    update c;
    Test.stopTest();

    List<MQL__c> mqls = [
      SELECT
        Id,
        MQL_Status__c,
        Transaction_Id__c,
        Conversion_Type__c,
        Converted_By__c,
        Lead_Source_Detail__c,
        Lead_Detail_1__c,
        Lead_Detail_2__c,
        Lead_Detail_3__c,
        Lead_Detail_4__c,
        Campaign__c
      FROM MQL__c
      WHERE Contact__c = :c.Id
    ];
    System.assertEquals(1, mqls.size(), 'Expected one MQL for Route B contact');
    System.assertEquals(
      ContactSetToMqlTriggerHandler.NEW_STATUS,
      mqls[0].MQL_Status__c,
      'Route B MQL should be New for sales review'
    );
    System.assertEquals(
      transactionId,
      mqls[0].Transaction_Id__c,
      'Route B MQL must retain the current submission transaction id'
    );
    System.assertEquals(
      null,
      mqls[0].Conversion_Type__c,
      'Route B should not set Conversion_Type__c'
    );
    System.assertEquals(
      null,
      mqls[0].Converted_By__c,
      'Route B should not set Converted_By__c'
    );
    System.assertEquals(
      '/events/sponsorship-opportunities/a0m456',
      mqls[0].Lead_Source_Detail__c
    );
    System.assertEquals('Route B comments', mqls[0].Lead_Detail_1__c);
    System.assertEquals(
      'Product: https://example.com/product-b',
      mqls[0].Lead_Detail_2__c
    );
    System.assertEquals('Route B additional context', mqls[0].Lead_Detail_3__c);
    System.assertEquals('Route B event links', mqls[0].Lead_Detail_4__c);
    System.assertEquals(campaign.Id, mqls[0].Campaign__c);
  }

  @isTest
  static void ef3HandRaiserWithoutOppBypassesThresholdPath() {
    setupCalloutMock();
    createThresholdProduct();
    Product2 handRaiserProduct = createHandRaiserProduct();
    Contact c = createContact(false);

    Test.startTest();
    c.Set_to_MQL__c = true;
    c.Hand_Raiser_Source__c = ContactSetToMqlTriggerHandler.CMS_HAND_RAISER_SOURCE;
    c.Hand_Raiser_Product_Id__c = handRaiserProduct.Id;
    update c;
    Test.stopTest();

    List<MQL__c> mqls = [
      SELECT Id, Lead_Source__c, MQL_Status__c, Opportunity__c, Product__c
      FROM MQL__c
      WHERE Contact__c = :c.Id
    ];
    System.assertEquals(1, mqls.size(), 'Expected one EF3 hand-raiser MQL');
    System.assertEquals(
      ContactSetToMqlTriggerHandler.CMS_HAND_RAISER_LEAD_SOURCE,
      mqls[0].Lead_Source__c,
      'Expected EF3 hand-raisers to map to Submitted a Form'
    );
    System.assertEquals(
      ContactSetToMqlTriggerHandler.NEW_STATUS,
      mqls[0].MQL_Status__c,
      'Mql-only EF3 hand-raisers should enter as New'
    );
    System.assertEquals(
      null,
      mqls[0].Opportunity__c,
      'Mql-only EF3 hand-raisers should not require an Opportunity'
    );
    System.assertEquals(
      handRaiserProduct.Id,
      mqls[0].Product__c,
      'EF3 hand-raisers should use the explicit product instead of the threshold product'
    );

    Contact refreshed = [
      SELECT Set_to_MQL__c, Hand_Raiser_Source__c, Hand_Raiser_Product_Id__c
      FROM Contact
      WHERE Id = :c.Id
    ];
    System.assertEquals(false, refreshed.Set_to_MQL__c);
    System.assertEquals(
      null,
      refreshed.Hand_Raiser_Source__c,
      'Expected Hand_Raiser_Source__c to be cleared after processing'
    );
    System.assertEquals(null, refreshed.Hand_Raiser_Product_Id__c);
  }

  @isTest
  static void ef3NewOppSignalWithoutOppIdStaysNew() {
    setupCalloutMock();
    String transactionId = '123456789';
    Product2 handRaiserProduct = createHandRaiserProduct();
    Contact c = createContact(false);

    Test.startTest();
    c.Set_to_MQL__c = true;
    c.Hand_Raiser_Source__c = ContactSetToMqlTriggerHandler.CMS_HAND_RAISER_SOURCE;
    c.Hand_Raiser_Product_Id__c = handRaiserProduct.Id;
    c.Hand_Raiser_Transaction_Id__c = transactionId;
    c.Hand_Raiser_Opp_Is_New__c = true;
    update c;
    Test.stopTest();

    List<MQL__c> mqls = [
      SELECT
        Id,
        Lead_Source__c,
        MQL_Status__c,
        Opportunity__c,
        Product__c,
        Transaction_Id__c,
        Conversion_Type__c,
        Conversion_Date__c,
        Converted_By__c
      FROM MQL__c
      WHERE Contact__c = :c.Id
    ];
    System.assertEquals(1, mqls.size(), 'Expected one EF3 hand-raiser MQL');
    System.assertEquals(
      ContactSetToMqlTriggerHandler.CMS_HAND_RAISER_LEAD_SOURCE,
      mqls[0].Lead_Source__c,
      'Expected EF3 hand-raisers to map to Submitted a Form'
    );
    System.assertEquals(
      ContactSetToMqlTriggerHandler.NEW_STATUS,
      mqls[0].MQL_Status__c,
      'EF3 new-opportunity signals without an Opportunity Id must stay New'
    );
    System.assertEquals(
      null,
      mqls[0].Opportunity__c,
      'Expected no linked Opportunity when CMS did not provide one'
    );
    System.assertEquals(
      handRaiserProduct.Id,
      mqls[0].Product__c,
      'Expected the CMS product to be preserved'
    );
    System.assertEquals(
      transactionId,
      mqls[0].Transaction_Id__c,
      'Expected the EF3 form submission id to be preserved on the MQL'
    );
    System.assertEquals(
      null,
      mqls[0].Conversion_Type__c,
      'Missing-opportunity CMS hand-raisers must not be marked Created Opportunity'
    );
    System.assertEquals(null, mqls[0].Conversion_Date__c);
    System.assertEquals(null, mqls[0].Converted_By__c);
  }

  @isTest
  static void productOnlyHandRaiserBypassesThresholdPath() {
    setupCalloutMock();
    createThresholdProduct();
    Product2 handRaiserProduct = createHandRaiserProduct();
    Contact c = createContact(false);

    Test.startTest();
    c.Set_to_MQL__c = true;
    c.Hand_Raiser_Product_Id__c = handRaiserProduct.Id;
    update c;
    Test.stopTest();

    List<MQL__c> mqls = [
      SELECT Id, Lead_Source__c, MQL_Status__c, Opportunity__c, Product__c
      FROM MQL__c
      WHERE Contact__c = :c.Id
    ];
    System.assertEquals(
      1,
      mqls.size(),
      'Expected one product-only hand-raiser MQL'
    );
    System.assertEquals(
      ContactSetToMqlTriggerHandler.EVENTS_PORTAL_LEAD_SOURCE,
      mqls[0].Lead_Source__c,
      'A product-only hand raiser should still follow the Events Portal path'
    );
    System.assertEquals(
      ContactSetToMqlTriggerHandler.NEW_STATUS,
      mqls[0].MQL_Status__c
    );
    System.assertEquals(null, mqls[0].Opportunity__c);
    System.assertEquals(
      handRaiserProduct.Id,
      mqls[0].Product__c,
      'Expected product-only hand raisers to populate Product__c'
    );

    Contact refreshed = [
      SELECT Set_to_MQL__c, Hand_Raiser_Product_Id__c
      FROM Contact
      WHERE Id = :c.Id
    ];
    System.assertEquals(false, refreshed.Set_to_MQL__c);
    System.assertEquals(
      null,
      refreshed.Hand_Raiser_Product_Id__c,
      'Expected Hand_Raiser_Product_Id__c to be cleared after processing'
    );
  }

  @isTest
  static void eventsPortalHandRaiserDedupesSameContactAndProductWithinWindow() {
    setupCalloutMock();
    String transactionId = 'ep-dedupe-000001';
    Product2 handRaiserProduct = createHandRaiserProduct();
    Contact c = createContact(false);

    insert new MQL__c(
      Contact__c = c.Id,
      Product__c = handRaiserProduct.Id,
      Lead_Source__c = ContactSetToMqlTriggerHandler.EVENTS_PORTAL_LEAD_SOURCE,
      MQL_Status__c = ContactSetToMqlTriggerHandler.NEW_STATUS,
      MQL_Date__c = Date.today(),
      Transaction_Id__c = transactionId
    );

    Test.startTest();
    c.Set_to_MQL__c = true;
    c.Hand_Raiser_Product_Id__c = handRaiserProduct.Id;
    c.Hand_Raiser_Transaction_Id__c = transactionId;
    c.Hand_Raiser_Lead_Detail_3__c = 'Duplicate Events Portal signal';
    update c;
    Test.stopTest();

    Integer eventsPortalCount = [
      SELECT COUNT()
      FROM MQL__c
      WHERE
        Contact__c = :c.Id
        AND Product__c = :handRaiserProduct.Id
        AND Lead_Source__c = :ContactSetToMqlTriggerHandler.EVENTS_PORTAL_LEAD_SOURCE
    ];
    System.assertEquals(
      1,
      eventsPortalCount,
      'Expected recent same-contact same-product Events Portal hand raiser to be deduped'
    );

    Contact refreshed = [
      SELECT
        Set_to_MQL__c,
        Hand_Raiser_Product_Id__c,
        Hand_Raiser_Lead_Detail_3__c
      FROM Contact
      WHERE Id = :c.Id
    ];
    System.assertEquals(
      false,
      refreshed.Set_to_MQL__c,
      'Expected Set_to_MQL__c to reset even when hand-raiser creation is skipped'
    );
    System.assertEquals(null, refreshed.Hand_Raiser_Product_Id__c);
    System.assertEquals(null, refreshed.Hand_Raiser_Lead_Detail_3__c);
  }

  @isTest
  static void eventsPortalHandRaiserAllowsDifferentTransactionWithinWindow() {
    setupCalloutMock();
    Product2 handRaiserProduct = createHandRaiserProduct();
    Contact c = createContact(false);

    insert new MQL__c(
      Contact__c = c.Id,
      Product__c = handRaiserProduct.Id,
      Lead_Source__c = ContactSetToMqlTriggerHandler.EVENTS_PORTAL_LEAD_SOURCE,
      MQL_Status__c = ContactSetToMqlTriggerHandler.NEW_STATUS,
      MQL_Date__c = Date.today(),
      Transaction_Id__c = 'ep-distinct-000001'
    );

    Test.startTest();
    c.Set_to_MQL__c = true;
    c.Hand_Raiser_Product_Id__c = handRaiserProduct.Id;
    c.Hand_Raiser_Transaction_Id__c = 'ep-distinct-000002';
    update c;
    Test.stopTest();

    List<MQL__c> mqls = [
      SELECT Transaction_Id__c
      FROM MQL__c
      WHERE
        Contact__c = :c.Id
        AND Product__c = :handRaiserProduct.Id
        AND Lead_Source__c = :ContactSetToMqlTriggerHandler.EVENTS_PORTAL_LEAD_SOURCE
      ORDER BY Transaction_Id__c
    ];
    System.assertEquals(
      2,
      mqls.size(),
      'Distinct submissions must not be suppressed by contact/product dedupe'
    );
    System.assertEquals('ep-distinct-000001', mqls[0].Transaction_Id__c);
    System.assertEquals('ep-distinct-000002', mqls[1].Transaction_Id__c);
  }

  @isTest
  static void eventsPortalHandRaiserAllowsSameContactDifferentProduct() {
    setupCalloutMock();
    Product2 existingProduct = createHandRaiserProduct();
    Product2 newProduct = createHandRaiserProduct();
    Contact c = createContact(false);

    insert new MQL__c(
      Contact__c = c.Id,
      Product__c = existingProduct.Id,
      Lead_Source__c = ContactSetToMqlTriggerHandler.EVENTS_PORTAL_LEAD_SOURCE,
      MQL_Status__c = ContactSetToMqlTriggerHandler.NEW_STATUS,
      MQL_Date__c = Date.today()
    );

    Test.startTest();
    c.Set_to_MQL__c = true;
    c.Hand_Raiser_Product_Id__c = newProduct.Id;
    c.Hand_Raiser_Lead_Detail_3__c = 'Different Events Portal product';
    update c;
    Test.stopTest();

    Integer eventsPortalCount = [
      SELECT COUNT()
      FROM MQL__c
      WHERE
        Contact__c = :c.Id
        AND Lead_Source__c = :ContactSetToMqlTriggerHandler.EVENTS_PORTAL_LEAD_SOURCE
    ];
    System.assertEquals(
      2,
      eventsPortalCount,
      'Expected same-contact Events Portal hand raisers for different products to be allowed'
    );
  }

  @isTest
  static void eventsPortalHandRaiserAllowsSameContactAndProductAfterWindow() {
    setupCalloutMock();
    String transactionId = 'ep-window-000001';
    Product2 handRaiserProduct = createHandRaiserProduct();
    Contact c = createContact(false);

    MQL__c existingMql = new MQL__c(
      Contact__c = c.Id,
      Product__c = handRaiserProduct.Id,
      Lead_Source__c = ContactSetToMqlTriggerHandler.EVENTS_PORTAL_LEAD_SOURCE,
      MQL_Status__c = ContactSetToMqlTriggerHandler.NEW_STATUS,
      MQL_Date__c = Date.today(),
      Transaction_Id__c = transactionId
    );
    insert existingMql;
    Test.setCreatedDate(
      existingMql.Id,
      System.now()
        .addMinutes(
          -ContactSetToMqlTriggerHandler.HAND_RAISER_DEDUPE_MINUTES - 1
        )
    );

    Test.startTest();
    c.Set_to_MQL__c = true;
    c.Hand_Raiser_Product_Id__c = handRaiserProduct.Id;
    c.Hand_Raiser_Transaction_Id__c = transactionId;
    c.Hand_Raiser_Lead_Detail_3__c = 'New Events Portal signal after window';
    update c;
    Test.stopTest();

    Integer eventsPortalCount = [
      SELECT COUNT()
      FROM MQL__c
      WHERE
        Contact__c = :c.Id
        AND Product__c = :handRaiserProduct.Id
        AND Lead_Source__c = :ContactSetToMqlTriggerHandler.EVENTS_PORTAL_LEAD_SOURCE
    ];
    System.assertEquals(
      2,
      eventsPortalCount,
      'Expected same-contact same-product Events Portal hand raiser after the window to be allowed'
    );
  }

  @isTest
  static void ef3HandRaiserWithOppUsesSubmittedAFormLeadSource() {
    setupCalloutMock();
    Account a = new Account(Name = 'EF3 Dual Write Test Account');
    insert a;

    Opportunity opp = new Opportunity(
      Name = 'EF3 Dual Write Opp',
      AccountId = a.Id,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30)
    );
    insert opp;

    Contact c = new Contact(
      LastName = 'EF3 Dual Write',
      Email = 'ef3.dual.write.' +
        String.valueOf(Crypto.getRandomInteger()) +
        '@example.com',
      AccountId = a.Id,
      Set_to_MQL__c = false,
      Hand_Raiser_Source__c = ContactSetToMqlTriggerHandler.CMS_HAND_RAISER_SOURCE,
      Hand_Raiser_Opportunity_Id__c = opp.Id
    );
    insert c;

    Test.startTest();
    c.Set_to_MQL__c = true;
    update c;
    Test.stopTest();

    List<MQL__c> mqls = [
      SELECT Id, Lead_Source__c, MQL_Status__c, Opportunity__c
      FROM MQL__c
      WHERE Contact__c = :c.Id
    ];
    System.assertEquals(1, mqls.size(), 'Expected one EF3 dual-write MQL');
    System.assertEquals(
      ContactSetToMqlTriggerHandler.CMS_HAND_RAISER_LEAD_SOURCE,
      mqls[0].Lead_Source__c,
      'Expected EF3 dual-write MQL to use Submitted a Form'
    );
    System.assertEquals(
      ContactSetToMqlTriggerHandler.NEW_STATUS,
      mqls[0].MQL_Status__c,
      'Existing/reused opp hand-raisers should remain New'
    );
    System.assertEquals(
      opp.Id,
      mqls[0].Opportunity__c,
      'Expected EF3 dual-write path to preserve the linked Opportunity'
    );

    Contact refreshed = [
      SELECT Set_to_MQL__c, Hand_Raiser_Source__c, Hand_Raiser_Opportunity_Id__c
      FROM Contact
      WHERE Id = :c.Id
    ];
    System.assertEquals(false, refreshed.Set_to_MQL__c);
    System.assertEquals(null, refreshed.Hand_Raiser_Source__c);
    System.assertEquals(null, refreshed.Hand_Raiser_Opportunity_Id__c);
  }

  // ---- Existing hand-raiser tests kept below ----

  @isTest
  static void handRaiserBypassesThresholdDedup() {
    setupCalloutMock();
    Account a = new Account(Name = 'Hand Raiser Dedup Test Account');
    insert a;

    Opportunity opp = new Opportunity(
      Name = 'Events Opp',
      AccountId = a.Id,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30)
    );
    insert opp;

    Contact c = new Contact(
      LastName = 'Hand Raiser Dedup',
      Email = 'hr.dedup.' +
        String.valueOf(Crypto.getRandomInteger()) +
        '@example.com',
      AccountId = a.Id,
      Set_to_MQL__c = false
    );
    insert c;

    // Pre-existing non-threshold MQL that would normally block threshold creation.
    insert new MQL__c(
      Contact__c = c.Id,
      Lead_Source__c = 'Email',
      MQL_Status__c = ContactSetToMqlTriggerHandler.NEW_STATUS,
      MQL_Date__c = Date.today()
    );

    Test.startTest();
    c.Set_to_MQL__c = true;
    c.Hand_Raiser_Opportunity_Id__c = opp.Id;
    update c;
    Test.stopTest();

    List<MQL__c> handRaiserMqls = [
      SELECT Id, Lead_Source__c
      FROM MQL__c
      WHERE
        Contact__c = :c.Id
        AND Lead_Source__c = :ContactSetToMqlTriggerHandler.EVENTS_PORTAL_LEAD_SOURCE
    ];
    System.assertEquals(
      1,
      handRaiserMqls.size(),
      'Hand-raiser MQL should be created even when a recent non-threshold MQL exists'
    );
  }
}

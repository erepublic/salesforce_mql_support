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

  @isTest
  static void createsMqlWhenSetToMqlFlipsTrueOnUpdate() {
    setupCalloutMock();
    Contact c = createContact(false);

    Test.startTest();
    c.Set_to_MQL__c = true;
    update c;
    Test.stopTest();

    List<MQL__c> mqls = [
      SELECT Id, Contact__c, Lead_Source__c, MQL_Status__c, MQL_Date__c
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
  }

  @isTest
  static void createsMqlWhenInsertedWithSetToMqlTrue() {
    setupCalloutMock();
    Test.startTest();
    Contact c = createContact(true);
    Test.stopTest();

    Integer countMqls = [
      SELECT COUNT()
      FROM MQL__c
      WHERE
        Contact__c = :c.Id
        AND Lead_Source__c = :ContactSetToMqlTriggerHandler.THRESHOLD_LEAD_SOURCE
    ];
    System.assertEquals(
      1,
      countMqls,
      'Expected an MQL to be created on insert when Set_to_MQL is true'
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
  }
}

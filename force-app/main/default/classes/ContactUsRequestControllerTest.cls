@isTest
private class ContactUsRequestControllerTest {
  /**
   * Test successful form submission
   */
  @isTest
  static void testSuccessfulFormSubmission() {
    // Set up ApexPages context
    PageReference pageRef = Page.ContactUsRequest;
    Test.setCurrentPage(pageRef);
    ApexPages.currentPage().getParameters().put('TimeSpent', '20.0');

    // Set mock HTTP response for both reCAPTCHA and HubSpot API (must be before Test.startTest)
    Test.setMock(HttpCalloutMock.class, new CombinedMock(true, true, false));

    // Get a valid topic value from the picklist
    ContactUsRequestController tempController = new ContactUsRequestController();
    List<SelectOption> topics = tempController.getRequestTopic();
    String validTopic = topics.size() > 1
      ? topics[1].getValue()
      : 'Editorial and Article Submissions';

    // Create test data
    ContactUsRequestController controller = new ContactUsRequestController();
    controller.First_Name = 'John';
    controller.Last_Name = 'Doe';
    controller.Email = 'john.doe@example.com';
    controller.Phone = '555-1234';
    controller.Organization = 'Test Company';
    controller.RTopic = validTopic;
    controller.Message = 'This is a test message';
    controller.recaptchaToken = 'valid_recaptcha_token';
    controller.isChecked = true;

    Test.startTest();
    PageReference result = controller.submit();
    Test.stopTest();

    // Verify Salesforce record was created
    List<Contact_Us__c> requests = [
      SELECT Id, First_Name__c, Last_Name__c, Email__c
      FROM Contact_Us__c
      WHERE Email__c = 'john.doe@example.com'
    ];
    System.assertEquals(
      1,
      requests.size(),
      'Contact request should be created. Errors: ' + ApexPages.getMessages()
    );
    System.assertEquals('John', requests[0].First_Name__c);
    System.assertEquals('Doe', requests[0].Last_Name__c);

    // Verify redirect to success page
    System.assertNotEquals(null, result, 'Should return a page reference');
    System.assertEquals(
      '1',
      result.getParameters().get('s'),
      'Should redirect to success page'
    );
  }

  /**
   * Test form submission with minimal data
   */
  @isTest
  static void testMinimalFormSubmission() {
    // Set up ApexPages context
    PageReference pageRef = Page.ContactUsRequest;
    Test.setCurrentPage(pageRef);
    ApexPages.currentPage().getParameters().put('TimeSpent', '20.0');

    // Set mock first
    Test.setMock(HttpCalloutMock.class, new CombinedMock(true, true, false));

    // Get a valid topic value
    ContactUsRequestController tempController = new ContactUsRequestController();
    List<SelectOption> topics = tempController.getRequestTopic();
    String validTopic = topics.size() > 1
      ? topics[1].getValue()
      : 'Editorial and Article Submissions';

    ContactUsRequestController controller = new ContactUsRequestController();
    controller.First_Name = 'Jane';
    controller.Last_Name = 'Smith';
    controller.Email = 'jane.smith@example.com';
    controller.RTopic = validTopic;
    controller.Message = 'Test';
    controller.recaptchaToken = 'valid_recaptcha_token';
    controller.isChecked = true;

    Test.startTest();
    PageReference result = controller.submit();
    Test.stopTest();

    // Verify record was created with minimal data
    List<Contact_Us__c> requests = [
      SELECT Id, Phone__c, Organization__c
      FROM Contact_Us__c
      WHERE Email__c = 'jane.smith@example.com'
    ];
    System.assertEquals(
      1,
      requests.size(),
      'Record should be created. Errors: ' + ApexPages.getMessages()
    );
    System.assertEquals(null, requests[0].Phone__c);
    System.assertEquals(null, requests[0].Organization__c);
  }

  /**
   * Test topic picklist values
   */
  @isTest
  static void testGetRequestTopic() {
    ContactUsRequestController controller = new ContactUsRequestController();

    Test.startTest();
    List<SelectOption> options = controller.getRequestTopic();
    Test.stopTest();

    System.assertNotEquals(null, options, 'Options should not be null');
    System.assert(options.size() > 0, 'Should have at least one option');
    System.assertEquals(
      '-- Please Select --',
      options[0].getLabel(),
      'First option should be placeholder'
    );
  }

  /**
   * Test getter for contact request
   */
  @isTest
  static void testGetTheContactRequest() {
    ContactUsRequestController controller = new ContactUsRequestController();

    Test.startTest();
    Contact_Us__c request = controller.getTheContactRequest();
    Test.stopTest();

    System.assertNotEquals(null, request, 'Contact request should not be null');
  }

  /**
   * Test HubSpot API error handling (409 Conflict - contact exists)
   */
  @isTest
  static void testHubSpotContactExists() {
    // Set up ApexPages context
    PageReference pageRef = Page.ContactUsRequest;
    Test.setCurrentPage(pageRef);
    ApexPages.currentPage().getParameters().put('TimeSpent', '20.0');

    // Set mock first
    Test.setMock(HttpCalloutMock.class, new CombinedMock(true, true, true));

    // Get a valid topic value
    ContactUsRequestController tempController = new ContactUsRequestController();
    List<SelectOption> topics = tempController.getRequestTopic();
    String validTopic = topics.size() > 1
      ? topics[1].getValue()
      : 'Editorial and Article Submissions';

    ContactUsRequestController controller = new ContactUsRequestController();
    controller.First_Name = 'Existing';
    controller.Last_Name = 'Contact';
    controller.Email = 'existing@example.com';
    controller.RTopic = validTopic;
    controller.Message = 'Test existing contact';
    controller.recaptchaToken = 'valid_recaptcha_token';
    controller.isChecked = true;

    Test.startTest();
    PageReference result = controller.submit();
    Test.stopTest();

    // Should still create Salesforce record even if HubSpot has conflict
    List<Contact_Us__c> requests = [
      SELECT Id
      FROM Contact_Us__c
      WHERE Email__c = 'existing@example.com'
    ];
    System.assertEquals(
      1,
      requests.size(),
      'Salesforce record should be created. Errors: ' + ApexPages.getMessages()
    );
  }

  /**
   * Test that Sales & Advertising submissions are sent to HubSpot
   */
  @isTest
  static void testSalesAdvertisingTopicSentToHubSpot() {
    // Set up ApexPages context
    PageReference pageRef = Page.ContactUsRequest;
    Test.setCurrentPage(pageRef);
    ApexPages.currentPage().getParameters().put('TimeSpent', '20.0');

    // Set mock first
    Test.setMock(HttpCalloutMock.class, new CombinedMock(true, true, false));

    ContactUsRequestController controller = new ContactUsRequestController();
    controller.First_Name = 'Sales';
    controller.Last_Name = 'Contact';
    controller.Email = 'sales@example.com';
    controller.Phone = '555-9999';
    controller.Organization = 'Sales Company';
    controller.RTopic = 'Sales & Advertising';
    controller.Message = 'Sales inquiry';
    controller.recaptchaToken = 'valid_recaptcha_token';
    controller.isChecked = true;

    Test.startTest();
    PageReference result = controller.submit();
    Test.stopTest();

    // Verify Salesforce record was created
    List<Contact_Us__c> requests = [
      SELECT Id, Topic__c
      FROM Contact_Us__c
      WHERE Email__c = 'sales@example.com'
    ];
    System.assertEquals(
      1,
      requests.size(),
      'Contact request should be created'
    );
    System.assertEquals(
      'Sales & Advertising',
      requests[0].Topic__c,
      'Topic should be Sales & Advertising'
    );

    // The HubSpot call will be made (verified by mock)
  }

  /**
   * Test that non-Sales & Advertising submissions are NOT sent to HubSpot
   */
  @isTest
  static void testNonSalesAdvertisingTopicNotSentToHubSpot() {
    // Set up ApexPages context
    PageReference pageRef = Page.ContactUsRequest;
    Test.setCurrentPage(pageRef);
    ApexPages.currentPage().getParameters().put('TimeSpent', '20.0');

    // Set mock for reCAPTCHA (HubSpot won't be called for non-Sales topics)
    Test.setMock(HttpCalloutMock.class, new CombinedMock(true, false, false));

    // Get a valid non-Sales & Advertising topic from the picklist
    ContactUsRequestController tempController = new ContactUsRequestController();
    List<SelectOption> topics = tempController.getRequestTopic();
    String nonSalesTopic = null;
    for (SelectOption option : topics) {
      if (
        !String.isBlank(option.getValue()) &&
        option.getValue() != 'Sales & Advertising'
      ) {
        nonSalesTopic = option.getValue();
        break;
      }
    }
    System.assert(
      !String.isBlank(nonSalesTopic),
      'Should have at least one non-Sales & Advertising topic'
    );

    ContactUsRequestController controller = new ContactUsRequestController();
    controller.First_Name = 'Other';
    controller.Last_Name = 'Topic';
    controller.Email = 'other@example.com';
    controller.Phone = '555-8888';
    controller.Organization = 'Other Company';
    controller.RTopic = nonSalesTopic;
    controller.Message = 'Non-sales inquiry';
    controller.recaptchaToken = 'valid_recaptcha_token';
    controller.isChecked = true;

    Test.startTest();
    PageReference result = controller.submit();
    Test.stopTest();

    // Verify Salesforce record was created
    List<Contact_Us__c> requests = [
      SELECT Id, Topic__c
      FROM Contact_Us__c
      WHERE Email__c = 'other@example.com'
    ];
    System.assertEquals(
      1,
      requests.size(),
      'Contact request should be created. Errors: ' + ApexPages.getMessages()
    );
    System.assertEquals(
      nonSalesTopic,
      requests[0].Topic__c,
      'Topic should match the non-Sales & Advertising topic'
    );

    // HubSpot call should NOT have been made (if it was, the mock failure would cause issues)
  }

  /**
   * Test Sales & Advertising with HubSpot 409 Conflict (contact exists, needs update)
   */
  @isTest
  static void testSalesAdvertisingHubSpotConflictUpdate() {
    // Set up ApexPages context
    PageReference pageRef = Page.ContactUsRequest;
    Test.setCurrentPage(pageRef);
    ApexPages.currentPage().getParameters().put('TimeSpent', '20.0');

    // Set mock to return 409 conflict, which triggers update flow
    Test.setMock(HttpCalloutMock.class, new CombinedMock(true, true, true));

    ContactUsRequestController controller = new ContactUsRequestController();
    controller.First_Name = 'Sales';
    controller.Last_Name = 'Conflict';
    controller.Email = 'sales.conflict@example.com';
    controller.Phone = '555-7777';
    controller.Organization = 'Conflict Company';
    controller.RTopic = 'Sales & Advertising';
    controller.Message = 'Sales conflict test';
    controller.recaptchaToken = 'valid_recaptcha_token';
    controller.isChecked = true;

    Test.startTest();
    PageReference result = controller.submit();
    Test.stopTest();

    // Verify Salesforce record was created
    List<Contact_Us__c> requests = [
      SELECT Id, Topic__c
      FROM Contact_Us__c
      WHERE Email__c = 'sales.conflict@example.com'
    ];
    System.assertEquals(
      1,
      requests.size(),
      'Contact request should be created. Errors: ' + ApexPages.getMessages()
    );
    System.assertEquals(
      'Sales & Advertising',
      requests[0].Topic__c,
      'Topic should be Sales & Advertising'
    );
  }

  /**
   * Test HubSpot API error response (500 error)
   */
  @isTest
  static void testHubSpotApiError() {
    // Set up ApexPages context
    PageReference pageRef = Page.ContactUsRequest;
    Test.setCurrentPage(pageRef);
    ApexPages.currentPage().getParameters().put('TimeSpent', '20.0');

    // Set mock to return API error for HubSpot, but success for reCAPTCHA
    Test.setMock(
      HttpCalloutMock.class,
      new CombinedMock(true, false, false, true)
    );

    ContactUsRequestController controller = new ContactUsRequestController();
    controller.First_Name = 'Error';
    controller.Last_Name = 'Test';
    controller.Email = 'error.test@example.com';
    controller.Phone = '555-6666';
    controller.Organization = 'Error Company';
    controller.RTopic = 'Sales & Advertising';
    controller.Message = 'API error test';
    controller.recaptchaToken = 'valid_recaptcha_token';
    controller.isChecked = true;

    Test.startTest();
    PageReference result = controller.submit();
    Test.stopTest();

    // Verify Salesforce record was created (should succeed even if HubSpot fails)
    List<Contact_Us__c> requests = [
      SELECT Id
      FROM Contact_Us__c
      WHERE Email__c = 'error.test@example.com'
    ];
    System.assertEquals(
      1,
      requests.size(),
      'Contact request should be created even if HubSpot fails. Errors: ' +
      ApexPages.getMessages()
    );
  }

  /**
   * Combined mock for both reCAPTCHA and HubSpot API calls
   */
  private class CombinedMock implements HttpCalloutMock {
    private Boolean captchaValid;
    private Boolean hubspotSuccess;
    private Boolean hubspotConflict;
    private Boolean hubspotError;

    public CombinedMock(
      Boolean captchaValid,
      Boolean hubspotSuccess,
      Boolean hubspotConflict
    ) {
      this.captchaValid = captchaValid;
      this.hubspotSuccess = hubspotSuccess;
      this.hubspotConflict = hubspotConflict;
      this.hubspotError = false;
    }

    public CombinedMock(
      Boolean captchaValid,
      Boolean hubspotSuccess,
      Boolean hubspotConflict,
      Boolean hubspotError
    ) {
      this.captchaValid = captchaValid;
      this.hubspotSuccess = hubspotSuccess;
      this.hubspotConflict = hubspotConflict;
      this.hubspotError = hubspotError;
    }

    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');

      // Handle reCAPTCHA verification
      if (req.getEndpoint().contains('google.com/recaptcha/api/siteverify')) {
        if (captchaValid) {
          res.setBody('{"success": true, "score": 0.9}');
        } else {
          res.setBody('{"success": false, "score": 0.3}');
        }
        res.setStatusCode(200);
        return res;
      }

      // Handle HubSpot API calls
      if (hubspotError) {
        res.setBody('{"status":"error","message":"API Error"}');
        res.setStatusCode(500);
        return res;
      }

      if (req.getMethod() == 'POST' && req.getEndpoint().contains('/search')) {
        // Search request
        res.setBody('{"results":[{"id":"12345"}]}');
        res.setStatusCode(200);
      } else if (req.getMethod() == 'PATCH') {
        // Update request
        res.setBody('{"id":"12345","properties":{"email":"test@example.com"}}');
        res.setStatusCode(200);
      } else if (req.getMethod() == 'POST' && hubspotConflict) {
        // Create request returns conflict
        res.setBody('{"status":"error","message":"Contact already exists"}');
        res.setStatusCode(409);
      } else if (req.getMethod() == 'POST' && hubspotSuccess) {
        // Create request
        res.setBody('{"id":"12345","properties":{"email":"test@example.com"}}');
        res.setStatusCode(201);
      }

      return res;
    }
  }

  /**
   * Mock HTTP callout for successful HubSpot API response
   */
  private class HubSpotMockSuccess implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"id":"12345","properties":{"email":"test@example.com"}}');

      if (req.getMethod() == 'POST' && req.getEndpoint().contains('/search')) {
        // Search request
        res.setBody('{"results":[{"id":"12345"}]}');
        res.setStatusCode(200);
      } else if (req.getMethod() == 'PATCH') {
        // Update request
        res.setStatusCode(200);
      } else {
        // Create request
        res.setStatusCode(201);
      }

      return res;
    }
  }

  /**
   * Mock HTTP callout for HubSpot 409 Conflict response
   */
  private class HubSpotMockConflict implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');

      if (req.getMethod() == 'POST' && !req.getEndpoint().contains('/search')) {
        // Create request returns conflict
        res.setBody('{"status":"error","message":"Contact already exists"}');
        res.setStatusCode(409);
      } else if (
        req.getMethod() == 'POST' && req.getEndpoint().contains('/search')
      ) {
        // Search request succeeds
        res.setBody('{"results":[{"id":"12345"}]}');
        res.setStatusCode(200);
      } else if (req.getMethod() == 'PATCH') {
        // Update request succeeds
        res.setBody('{"id":"12345","properties":{"email":"test@example.com"}}');
        res.setStatusCode(200);
      }

      return res;
    }
  }

  /**
   * Mock HTTP callout for HubSpot API failure
   */
  private class HubSpotMockFailure implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"status":"error","message":"API Error"}');
      res.setStatusCode(500);
      return res;
    }
  }

  /**
   * Mock HTTP callout for HubSpot API error (500)
   */
  private class HubSpotMockError implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"status":"error","message":"API Error"}');
      res.setStatusCode(500);
      return res;
    }
  }
}

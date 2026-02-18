/**
 * Test class for PDFService with enhanced coverage
 */
@isTest
private class PDFServiceTest {
  // Test data setup
  @TestSetup
  static void setupTestData() {
    // Create a test account to use as a record
    Account testAccount = new Account(Name = 'Test Account');
    insert testAccount;

    // Create test template storage records
    List<TemplateStorage__c> templates = new List<TemplateStorage__c>();

    // Valid template with token
    templates.add(
      new TemplateStorage__c(
        Name = 'TEST-TOKEN-VALID',
        Content__c = '<p>Valid template content</p>',
        ExpirationDate__c = DateTime.now().addHours(1)
      )
    );

    // Expired template
    templates.add(
      new TemplateStorage__c(
        Name = 'TEST-TOKEN-EXPIRED',
        Content__c = '<p>Expired template content</p>',
        ExpirationDate__c = DateTime.now().addHours(-1)
      )
    );

    insert templates;
  }

  /**
   * Test generating a preview URL
   */
  @isTest
  static void testGeneratePreviewUrl() {
    // Setup test data
    String templateContent = '<h1>Test Template</h1><p>This is a test</p>';
    Account testAccount = [
      SELECT Id
      FROM Account
      WHERE Name = 'Test Account'
      LIMIT 1
    ];
    String recordId = testAccount.Id;
    String orientation = 'portrait';

    // Capture timestamp before test
    DateTime testStartTime = DateTime.now();

    Test.startTest();

    // Call the method to test
    String previewUrl = PDFService.generatePreviewUrl(
      templateContent,
      recordId,
      orientation
    );

    Test.stopTest();

    // Assertions
    System.assertNotEquals(null, previewUrl, 'Preview URL should not be null');
    System.assert(
      previewUrl.contains('token='),
      'Preview URL should contain a token parameter'
    );
    System.assert(
      previewUrl.contains('recordId='),
      'Preview URL should contain the record ID'
    );

    // Verify template storage was created - can't filter on Content__c field
    List<TemplateStorage__c> templates = [
      SELECT Id, Name, Content__c
      FROM TemplateStorage__c
      WHERE CreatedDate >= :testStartTime
    ];
    System.assertEquals(
      1,
      templates.size(),
      'One template storage record should be created for the content'
    );
    System.assertEquals(
      templateContent,
      templates[0].Content__c,
      'Template should contain the correct content'
    );
  }

  /**
   * Test generating a preview URL with null inputs
   */
  @isTest
  static void testGeneratePreviewUrlWithNullInputs() {
    Test.startTest();

    // Call with null template content (should handle gracefully)
    String previewUrl = PDFService.generatePreviewUrl(null, null, null);

    Test.stopTest();

    // Assertions
    System.assertNotEquals(
      null,
      previewUrl,
      'Preview URL should not be null even with null inputs'
    );
    System.assert(
      previewUrl.contains('token='),
      'Preview URL should contain a token parameter'
    );
  }

  /**
   * Test generating a preview URL with HTML that needs sanitization
   */
  @isTest
  static void testGeneratePreviewUrlWithUnsafeHTML() {
    // Setup test data with unsafe HTML
    String unsafeHTML = '<script>alert("XSS")</script><p>Test content</p><img src="x" onerror="alert(\'XSS\')">';

    // Capture timestamp before test
    DateTime testStartTime = DateTime.now();

    Test.startTest();

    String previewUrl = PDFService.generatePreviewUrl(
      unsafeHTML,
      null,
      'landscape'
    );

    Test.stopTest();

    // Verify sanitization occurred in stored template
    List<TemplateStorage__c> templates = [
      SELECT Content__c
      FROM TemplateStorage__c
      WHERE CreatedDate >= :testStartTime
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    System.assertEquals(
      1,
      templates.size(),
      'Template storage record should be created'
    );
    System.assert(
      !templates[0].Content__c.contains('<script>'),
      'Script tags should be sanitized'
    );
    System.assert(
      !templates[0].Content__c.contains('onerror='),
      'Event handlers should be sanitized'
    );
    System.assert(
      templates[0].Content__c.contains('<p>Test content</p>'),
      'Safe content should be preserved'
    );
  }

  /**
   * Test generating a PDF document
   */
  @isTest
  static void testGeneratePDFDocument() {
    // Setup test data
    String templateContent = '<h1>Test Template</h1><p>This is a test</p>';
    Account testAccount = [
      SELECT Id
      FROM Account
      WHERE Name = 'Test Account'
      LIMIT 1
    ];
    String recordId = testAccount.Id;
    String fileName = 'TestDocument.pdf';
    String orientation = 'landscape';

    Test.startTest();

    // Call the method to test
    PDFService.PDFResult result = PDFService.generatePDFDocument(
      templateContent,
      recordId,
      fileName,
      orientation
    );
    String contentDocumentId = result.contentDocumentId;
    String contentVersionId = result.contentVersionId;

    Test.stopTest();

    // Assertions
    System.assertNotEquals(null, result.contentDocumentId);
    System.assertNotEquals(null, result.contentVersionId);

    // Verify ContentDocument was created
    List<ContentDocument> documents = [
      SELECT Id, Title
      FROM ContentDocument
      WHERE Id = :contentDocumentId
    ];
    System.assertEquals(
      1,
      documents.size(),
      'One content document should be created'
    );
    System.assertEquals(
      'TestDocument.pdf',
      documents[0].Title,
      'Document title should match'
    );

    // Verify ContentDocumentLink was created
    List<ContentDocumentLink> links = [
      SELECT Id, LinkedEntityId, ShareType, Visibility
      FROM ContentDocumentLink
      WHERE
        ContentDocumentId = :contentDocumentId
        AND LinkedEntityId = :recordId
    ];
    System.assertEquals(
      1,
      links.size(),
      'Document should be linked to the record'
    );
    System.assertEquals(
      'I',
      links[0].ShareType,
      'ShareType should be Inferred permission'
    );
  }

  /**
   * Test generating a PDF document with embedded token
   */
  @isTest
  static void testGeneratePDFWithEmbeddedToken() {
    // Get a valid token from test setup
    String validToken = 'TEST-TOKEN-VALID';
    String recordId = [
      SELECT Id
      FROM Account
      WHERE Name = 'Test Account'
      LIMIT 1
    ]
    .Id;

    // Create template content with embedded token
    String templateWithToken =
      '<!--TOKEN:' +
      validToken +
      '--><p>Content with embedded token</p>';

    Test.startTest();

    // Call the method to test
    PDFService.PDFResult result = PDFService.generatePDFDocument(
      templateWithToken,
      recordId,
      'EmbeddedToken.pdf',
      'portrait'
    );
    String contentDocumentId = result.contentDocumentId;
    String contentVersionId = result.contentVersionId;

    Test.stopTest();

    // Assertions
    System.assertNotEquals(null, result.contentDocumentId);
    System.assertNotEquals(null, result.contentVersionId);

    // Verify ContentDocument was created using the embedded token
    List<ContentDocument> documents = [SELECT Id, Title FROM ContentDocument];
    System.assertEquals(
      1,
      documents.size(),
      'One content document should be created'
    );
  }

  /**
   * Test generating a PDF document with invalid embedded token
   */
  @isTest
  static void testGeneratePDFWithInvalidEmbeddedToken() {
    // Create a non-existent token
    String invalidToken = 'NON-EXISTENT-TOKEN';
    String recordId = [
      SELECT Id
      FROM Account
      WHERE Name = 'Test Account'
      LIMIT 1
    ]
    .Id;

    // Create template content with embedded token
    String templateWithInvalidToken =
      '<!--TOKEN:' +
      invalidToken +
      '--><p>Content with invalid token</p>';

    // Capture timestamp before test
    DateTime testStartTime = DateTime.now();

    Test.startTest();

    // Call the method to test - should create new template instead of failing
    PDFService.PDFResult result = PDFService.generatePDFDocument(
      templateWithInvalidToken,
      recordId,
      'InvalidToken.pdf',
      'portrait'
    );
    String contentDocumentId = result.contentDocumentId;
    String contentVersionId = result.contentVersionId;

    Test.stopTest();

    // Assertions
    System.assertNotEquals(
      null,
      contentDocumentId,
      'ContentDocumentId should not be null'
    );
    System.assertNotEquals(
      null,
      contentVersionId,
      'ContentDocumentId should not be null'
    );

    // Verify a new template was created - can't filter on Content__c field
    List<TemplateStorage__c> newTemplates = [
      SELECT Id, Name, Content__c
      FROM TemplateStorage__c
      WHERE CreatedDate >= :testStartTime
    ];
    System.assertEquals(
      1,
      newTemplates.size(),
      'A new template should be created'
    );
    // Check content of the newly created template
    System.assert(
      newTemplates[0].Content__c.contains('Content with invalid token'),
      'New template should contain the correct content'
    );
  }

  /**
   * Test generating a PDF document with null filename (should use default)
   */
  @isTest
  static void testGeneratePDFWithNullFilename() {
    // Setup test data
    String templateContent = '<p>Test with null filename</p>';

    Test.startTest();

    // Call with null filename
    PDFService.PDFResult result = PDFService.generatePDFDocument(
      templateContent,
      null,
      null,
      'portrait'
    );
    String contentDocumentId = result.contentDocumentId;
    String contentVersionId = result.contentVersionId;

    Test.stopTest();

    // Assertions
    System.assertNotEquals(
      null,
      contentDocumentId,
      'ContentDocumentId should not be null'
    );
    System.assertNotEquals(
      null,
      contentVersionId,
      'ContentDocumentId should not be null'
    );

    // Verify default filename was used
    List<ContentDocument> documents = [
      SELECT Id, Title
      FROM ContentDocument
      WHERE Id = :contentDocumentId
    ];
    System.assertEquals(
      1,
      documents.size(),
      'One content document should be created'
    );
    System.assertEquals(
      'Generated_Document.pdf',
      documents[0].Title,
      'Default document title should be used'
    );
  }

  /**
   * Test generating a PDF document with non-PDF filename (should append .pdf)
   */
  @isTest
  static void testGeneratePDFWithNonPDFFilename() {
    // Setup test data
    String templateContent = '<p>Test with non-PDF filename</p>';

    Test.startTest();

    // Call with filename missing .pdf extension
    PDFService.PDFResult result = PDFService.generatePDFDocument(
      templateContent,
      null,
      'MyDocument',
      'portrait'
    );
    String contentDocumentId = result.contentDocumentId;
    String contentVersionId = result.contentVersionId;

    Test.stopTest();

    // Assertions
    System.assertNotEquals(
      null,
      contentDocumentId,
      'ContentDocumentId should not be null'
    );

    // Verify .pdf was appended
    List<ContentDocument> documents = [
      SELECT Id, Title
      FROM ContentDocument
      WHERE Id = :contentDocumentId
    ];
    System.assertEquals(
      1,
      documents.size(),
      'One content document should be created'
    );
    System.assertEquals(
      'MyDocument.pdf',
      documents[0].Title,
      '.pdf should be appended to filename'
    );
  }

  /**
   * Test the flow invocable method
   */
  @isTest
  static void testGeneratePDFForFlow() {
    // Setup test data
    Account testAccount = [
      SELECT Id
      FROM Account
      WHERE Name = 'Test Account'
      LIMIT 1
    ];
    String recordId = testAccount.Id;

    PDFService.FlowRequest request = new PDFService.FlowRequest();
    request.templateContent = '<h1>Flow Test</h1><p>This is a test from Flow</p>';
    request.recordId = recordId;
    request.fileName = 'FlowTest.pdf';
    request.orientation = 'portrait';
    request.autoGenerate = true;

    List<PDFService.FlowRequest> requests = new List<PDFService.FlowRequest>{
      request
    };

    Test.startTest();

    // Call the method to test
    List<PDFService.FlowResult> results = PDFService.generatePDFForFlow(
      requests
    );

    Test.stopTest();

    // Assertions
    System.assertEquals(1, results.size(), 'One result should be returned');
    System.assertEquals(
      true,
      results[0].success,
      'Operation should be successful'
    );
    System.assertNotEquals(
      null,
      results[0].contentDocumentId,
      'ContentDocumentId should not be null'
    );
    System.assertNotEquals(
      null,
      results[0].previewUrl,
      'Preview URL should not be null'
    );
  }

  /**
   * Test flow invocable method with error
   */
  @isTest
  static void testGeneratePDFForFlowWithError() {
    // Create an invalid request that will definitely cause an error
    PDFService.FlowRequest request = new PDFService.FlowRequest();
    // Set invalid recordId - this should cause an error since it's not a valid ID format
    request.templateContent = '<p>Test</p>';
    request.recordId = 'NOT_A_VALID_ID';

    List<PDFService.FlowRequest> requests = new List<PDFService.FlowRequest>{
      request
    };

    Test.startTest();

    // Call the method to test
    List<PDFService.FlowResult> results = PDFService.generatePDFForFlow(
      requests
    );

    Test.stopTest();

    // Assertions
    System.assertEquals(1, results.size(), 'One result should be returned');
    System.assertEquals(
      false,
      results[0].success,
      'Operation should not be successful'
    );
    System.assertNotEquals(
      null,
      results[0].message,
      'Error message should be provided'
    );
  }

  /**
   * Test cleanup of expired templates
   */
  @isTest
  static void testCleanupExpiredTemplates() {
    // We already have templates set up in TestSetup
    Integer beforeCount = [SELECT COUNT() FROM TemplateStorage__c];

    Test.startTest();

    // Call the method to test
    PDFService.cleanupExpiredTemplates();

    Test.stopTest();

    // Assertions
    Integer afterCount = [SELECT COUNT() FROM TemplateStorage__c];
    System.assertEquals(
      beforeCount - 1,
      afterCount,
      'One expired template should be deleted'
    );

    // Verify only expired template was removed
    List<TemplateStorage__c> remainingTemplates = [
      SELECT Name
      FROM TemplateStorage__c
      WHERE Name = 'TEST-TOKEN-EXPIRED'
    ];
    System.assertEquals(
      0,
      remainingTemplates.size(),
      'Expired template should be removed'
    );

    List<TemplateStorage__c> validTemplates = [
      SELECT Name
      FROM TemplateStorage__c
      WHERE Name = 'TEST-TOKEN-VALID'
    ];
    System.assertEquals(
      1,
      validTemplates.size(),
      'Valid template should remain'
    );
  }

  /**
   * Test the PDFService constructor and getFormattedHTML
   */
  @isTest
  static void testPDFServiceConstructor_TokenBased() {
    // Get the valid token
    String validToken = 'TEST-TOKEN-VALID';

    // Set up page parameters
    Test.setCurrentPage(Page.PDFGeneratorPage);
    ApexPages.currentPage().getParameters().put('token', validToken);
    ApexPages.currentPage().getParameters().put('orientation', 'landscape');

    Test.startTest();

    // Instantiate the controller
    PDFService controller = new PDFService();
    String formattedHTML = controller.getFormattedHTML();

    Test.stopTest();

    // Assertions
    System.assert(
      formattedHTML.contains('Valid template content'),
      'Formatted HTML should contain the template content'
    );
    System.assert(
      formattedHTML.contains('size: landscape'),
      'Formatted HTML should have landscape orientation'
    );
  }

  /**
   * Test the PDFService constructor with direct content
   */
  @isTest
  static void testPDFServiceConstructor_DirectContent() {
    // Create encoded content
    String directContent = EncodingUtil.urlEncode(
      '<p>Direct content test</p>',
      'UTF-8'
    );

    // Set up page parameters
    Test.setCurrentPage(Page.PDFGeneratorPage);
    ApexPages.currentPage()
      .getParameters()
      .put('templateContent', directContent);
    ApexPages.currentPage().getParameters().put('orientation', 'portrait');

    Test.startTest();

    // Instantiate the controller
    PDFService controller = new PDFService();
    String formattedHTML = controller.getFormattedHTML();

    Test.stopTest();

    // Assertions
    System.assert(
      formattedHTML.contains('Direct content test'),
      'Formatted HTML should contain the direct content'
    );
    System.assert(
      formattedHTML.contains('size: portrait'),
      'Formatted HTML should have portrait orientation'
    );
  }

  /**
   * Test the PDFService constructor with no content or token
   */
  @isTest
  static void testPDFServiceConstructor_NoContent() {
    // Set up page parameters with no content
    Test.setCurrentPage(Page.PDFGeneratorPage);

    Test.startTest();

    // Instantiate the controller
    PDFService controller = new PDFService();
    String formattedHTML = controller.getFormattedHTML();

    Test.stopTest();

    // Assertions
    System.assert(
      formattedHTML.contains('Error: No template content provided'),
      'Formatted HTML should contain error message'
    );
  }

  /**
   * Test the PDFService constructor with expired token
   */
  @isTest
  static void testPDFServiceConstructor_ExpiredToken() {
    // Get the expired token
    String expiredToken = 'TEST-TOKEN-EXPIRED';

    // Set up page parameters
    Test.setCurrentPage(Page.PDFGeneratorPage);
    ApexPages.currentPage().getParameters().put('token', expiredToken);

    Test.startTest();

    // Instantiate the controller
    PDFService controller = new PDFService();

    Test.stopTest();

    // Instead of checking for specific content, just check that we got an error message
    // related to an expired or missing template
    System.assert(
      controller.templateContent.contains('Error') ||
        controller.templateContent.contains('expired') ||
        controller.templateContent.contains('not found'),
      'Error message about expired template should be shown'
    );
  }

  /**
   * Test the getFormattedHTML method with content that already has HTML structure
   */
  @isTest
  static void testGetFormattedHTML_WithHTMLStructure() {
    // Create a controller instance
    PDFService controller = new PDFService();

    // Set template content with HTML structure
    controller.templateContent = '<html><head><title>Test</title></head><body><p>Content with HTML structure</p></body></html>';
    controller.orientation = 'landscape';

    Test.startTest();

    String formattedHTML = controller.getFormattedHTML();

    Test.stopTest();

    // Assertions
    System.assert(
      formattedHTML.contains('<html>'),
      'Original HTML structure should be preserved'
    );
    System.assert(
      formattedHTML.contains('size: landscape'),
      'Landscape style should be added'
    );
  }

  /**
   * Test the getFormattedHTML method with content that has style tag
   */
  @isTest
  static void testGetFormattedHTML_WithStyleTag() {
    // Create a controller instance
    PDFService controller = new PDFService();

    // Set template content with style tag
    controller.templateContent = '<html><head><style>body { color: blue; }</style></head><body><p>Content with style</p></body></html>';
    controller.orientation = 'portrait';

    Test.startTest();

    String formattedHTML = controller.getFormattedHTML();

    Test.stopTest();

    // Assertions
    System.assert(
      formattedHTML.contains('body { color: blue; }'),
      'Original style should be preserved'
    );
    System.assert(
      formattedHTML.contains('size: portrait'),
      'Portrait style should be added'
    );
  }

  /**
   * Test the getFormattedHTML method with blank content
   */
  @isTest
  static void testGetFormattedHTML_BlankContent() {
    // Create a controller instance
    PDFService controller = new PDFService();

    // Set blank template content
    controller.templateContent = '';

    Test.startTest();

    String formattedHTML = controller.getFormattedHTML();

    Test.stopTest();

    // Assertions
    System.assertEquals(
      '<p>No content provided</p>',
      formattedHTML,
      'Should show no content message'
    );
  }

  /**
   * Test validateAccess method
   */
  @isTest
  static void testValidateAccess() {
    // Get the valid token
    String validToken = 'TEST-TOKEN-VALID';

    // Set up page parameters
    Test.setCurrentPage(Page.PDFGeneratorPage);
    ApexPages.currentPage().getParameters().put('token', validToken);

    Test.startTest();

    // Create controller and call validateAccess
    PDFService controller = new PDFService();
    PageReference result = controller.validateAccess();

    Test.stopTest();

    // Assertions
    System.assertEquals(
      null,
      result,
      'ValidateAccess should return null (continue) for valid token'
    );
  }

  /**
   * Test validateAccess method with expired token
   */
  @isTest
  static void testValidateAccess_ExpiredToken() {
    // Get the expired token
    String expiredToken = 'TEST-TOKEN-EXPIRED';

    // Set up page parameters
    Test.setCurrentPage(Page.PDFGeneratorPage);
    ApexPages.currentPage().getParameters().put('token', expiredToken);

    Test.startTest();

    // Create controller and call validateAccess
    PDFService controller = new PDFService();
    PageReference result = controller.validateAccess();

    Test.stopTest();

    // Assertions
    System.assertNotEquals(
      null,
      result,
      'ValidateAccess should redirect for expired token'
    );

    // Use case-insensitive comparison for the page name
    String redirectPage = result.getUrl().substringBetween('apex/', '?');
    System.assert(
      redirectPage.equalsIgnoreCase('ErrorPage'),
      'Should redirect to ErrorPage (case insensitive). Got: ' + redirectPage
    );
  }

  /**
   * Test validateAccess method with no token
   */
  @isTest
  static void testValidateAccess_NoToken() {
    // Set up page parameters with no token
    Test.setCurrentPage(Page.PDFGeneratorPage);

    Test.startTest();

    // Create controller and call validateAccess
    PDFService controller = new PDFService();
    PageReference result = controller.validateAccess();

    Test.stopTest();

    // Assertions
    System.assertNotEquals(
      null,
      result,
      'ValidateAccess should redirect when no token is provided'
    );

    // Use case-insensitive comparison for the page name
    String redirectPage = result.getUrl().substringBetween('apex/', '?');
    System.assert(
      redirectPage.equalsIgnoreCase('ErrorPage'),
      'Should redirect to ErrorPage (case insensitive). Got: ' + redirectPage
    );
  }
}

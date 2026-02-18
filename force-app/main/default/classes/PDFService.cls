public class PDFService {
  // Public property to store template content
  public String templateContent { get; set; }

  // Public property to store record ID if needed
  public String recordId { get; set; }

  // Public property to store orientation setting
  public String orientation { get; set; }

  // Public property to store Auto Generate PDF setting
  public Boolean autoGenerate { get; set; }

  // Static map to cache templates by token
  private static Map<String, TemplateStorage__c> templateCache = new Map<String, TemplateStorage__c>();

  // Method to get template from cache or database
  private static TemplateStorage__c getTemplateByToken(String token) {
    // First check if it's in the cache
    if (templateCache.containsKey(token)) {
      TemplateStorage__c cachedTemplate = templateCache.get(token);

      // Check if template has expired
      if (cachedTemplate.ExpirationDate__c >= DateTime.now()) {
        System.debug('Retrieved template from cache: ' + token);
        return cachedTemplate;
      } else {
        // Remove expired template from cache
        templateCache.remove(token);
        System.debug('Removed expired template from cache: ' + token);
      }
    }

    // Not in cache or expired, query from database
    List<TemplateStorage__c> templates = [
      SELECT Id, Name, Content__c, ExpirationDate__c
      FROM TemplateStorage__c
      WHERE Name = :token
      LIMIT 1
    ];

    if (!templates.isEmpty()) {
      TemplateStorage__c template = templates[0];

      // Only cache if not expired
      if (template.ExpirationDate__c >= DateTime.now()) {
        templateCache.put(token, template);
        System.debug('Added template to cache: ' + token);
      }

      return template;
    }

    return null;
  }

  /**
   * Method to validate access before rendering PDF
   */
  public PageReference validateAccess() {
    try {
      String token = ApexPages.currentPage().getParameters().get('token');

      if (String.isBlank(token)) {
        return redirectToError('No token provided');
      }

      // Check if token exists and is not expired using the cache
      TemplateStorage__c template = getTemplateByToken(token);

      if (template == null) {
        return redirectToError('Invalid token');
      }

      if (template.ExpirationDate__c < DateTime.now()) {
        return redirectToError('Token expired');
      }

      // Continue with rendering if all checks pass
      return null;
    } catch (Exception e) {
      return redirectToError('Error validating access');
    }
  }

  // Constructor with improved validation
  public PDFService() {
    try {
      // Get parameters from page URL with validation
      Map<String, String> params = ApexPages.currentPage().getParameters();
      String token = validateAndSanitize(params.get('token'));
      String directContent = params.get('templateContent'); // Will be sanitized later
      recordId = validateId(params.get('recordId'));
      orientation = validateOrientation(params.get('orientation'));

      System.debug('PDFService Constructor - token: ' + token);
      System.debug('PDFService Constructor - orientation: ' + orientation);

      // First try to get content using token
      if (String.isNotBlank(token)) {
        try {
          // Use the cache method to get template
          TemplateStorage__c template = getTemplateByToken(token);

          if (template != null) {
            // Check if template has expired
            if (template.ExpirationDate__c < DateTime.now()) {
              templateContent = '<p>Error: Template has expired</p>';
              System.debug('Template has expired: ' + token);
            } else {
              templateContent = template.Content__c;
              System.debug(
                'Successfully retrieved template with token: ' + token
              );
            }
          } else {
            templateContent = '<p>Error: Template not found</p>';
            System.debug('Template not found with token: ' + token);
          }
        } catch (Exception e) {
          // Handle query exceptions
          templateContent = '<p>Error retrieving template</p>';
          System.debug('Error retrieving template: ' + e.getStackTraceString());
        }
      }
      // If no token, try direct content
      else if (String.isNotBlank(directContent)) {
        try {
          templateContent = HTMLSanitizer.sanitize(
            EncodingUtil.urlDecode(directContent, 'UTF-8')
          );
          System.debug('Using direct content from URL parameter');
        } catch (Exception e) {
          templateContent = '<p>Error decoding template content</p>';
          System.debug('Error decoding content: ' + e.getStackTraceString());
        }
      } else {
        templateContent = '<p>Error: No template content provided</p>';
        System.debug('No template content provided');
      }
    } catch (Exception e) {
      // Capture any exceptions in constructor
      templateContent = '<p>Error initializing PDF</p>';
      System.debug(
        'Error in PDFService constructor: ' + e.getStackTraceString()
      );
    }
  }

  // Helper methods for parameter validation

  private String validateAndSanitize(String input) {
    if (String.isBlank(input)) {
      return null;
    }
    // Remove any potentially dangerous characters
    return input.replaceAll('[^a-zA-Z0-9\\-_]', '');
  }

  private String validateId(String input) {
    if (String.isBlank(input)) {
      return null;
    }

    // Validate if it's a proper Salesforce ID format
    Pattern idPattern = Pattern.compile('^[a-zA-Z0-9]{15}$|^[a-zA-Z0-9]{18}$');
    Matcher matcher = idPattern.matcher(input);

    if (matcher.matches()) {
      return input;
    }

    System.debug('Invalid record ID format: ' + input);
    return null;
  }

  private String validateOrientation(String input) {
    if (String.isBlank(input)) {
      return 'portrait'; // Default
    }

    String lowercaseInput = input.toLowerCase();
    if (lowercaseInput == 'portrait' || lowercaseInput == 'landscape') {
      return lowercaseInput;
    }

    System.debug('Invalid orientation: ' + input + ', defaulting to portrait');
    return 'portrait';
  }

  // Method to generate HTML with proper orientation styling
  public String getFormattedHTML() {
    if (String.isBlank(templateContent)) {
      return '<p>No content provided</p>';
    }

    // Force stronger CSS for orientation and ensure case-insensitive comparison
    String orientationStyle = 'landscape'.equalsIgnoreCase(orientation)
      ? '@page { size: landscape !important; margin: 0.5in; }\n'
      : '@page { size: portrait !important; margin: 0.5in; }\n';

    // Add debugging
    System.debug(
      'PDFService.getFormattedHTML - Applying orientation: ' + orientation
    );

    // Check if the content already has HTML structure
    Boolean hasHtmlTag = templateContent.toLowerCase().contains('<html');

    if (hasHtmlTag) {
      // If content already has HTML structure, add orientation style
      if (templateContent.toLowerCase().contains('<style')) {
        // Insert into existing style tag - at the beginning to take precedence
        return templateContent.replaceFirst(
          '(?i)<style>',
          '<style>\n' + orientationStyle
        );
      } else if (templateContent.toLowerCase().contains('<head>')) {
        // Add style tag to head
        return templateContent.replaceFirst(
          '(?i)<head>',
          '<head>\n<style>' + orientationStyle + '</style>'
        );
      } else {
        // Add both head and style
        return templateContent.replaceFirst(
          '(?i)<html>',
          '<html>\n<head>\n<style>' + orientationStyle + '</style>\n</head>'
        );
      }
    } else {
      // If it doesn't have HTML structure, wrap it with appropriate tags
      return '<!DOCTYPE html>\n' +
        '<html>\n<head>\n' +
        '<meta charset="UTF-8">\n' +
        '<style>\n' +
        orientationStyle +
        'body { font-family: Arial, Helvetica, sans-serif; }\n' +
        'table { border-collapse: collapse; width: 100%; }\n' +
        'th, td { padding: 8px; text-align: left; }\n' +
        '</style>\n' +
        '</head>\n<body>\n' +
        templateContent +
        '\n</body>\n</html>';
    }
  }

  // Generate a unique token for template identification
  private static String generateUniqueToken() {
    Blob b = Crypto.generateAesKey(128);
    String h = EncodingUtil.convertToHex(b);
    return 'PDF_' + h.substring(0, 15); // Return a token prefixed with PDF_
  }

  /**
   * Extract token from content if present
   * Looks for an HTML comment in the format <!--TOKEN:PDF_xyz123-->
   */
  private static String extractTokenFromContent(String content) {
    if (String.isBlank(content)) {
      return null;
    }

    String tokenMarkerPattern = '<!--TOKEN:([^>]*)-->';
    Pattern p = Pattern.compile(tokenMarkerPattern);
    Matcher m = p.matcher(content);

    if (m.find()) {
      return m.group(1);
    }

    return null;
  }

  /**
   * Remove token marker from content
   * Removes the HTML comment containing the token
   */
  private static String removeTokenMarker(String content) {
    if (String.isBlank(content)) {
      return content;
    }

    return content.replaceFirst('<!--TOKEN:[^>]*-->', '');
  }

  @AuraEnabled
  public static String generatePreviewUrl(
    String templateContent,
    String recordId,
    String orientation
  ) {
    try {
      // Clean up expired templates before creating new ones
      // This ensures cleanup happens regularly with normal usage
      cleanupExpiredTemplates();

      System.debug(
        'Generating preview with template length: ' +
        (templateContent != null ? templateContent.length() : 0)
      );
      System.debug('Orientation requested: ' + orientation);

      // Sanitize the template content to prevent XSS
      String sanitizedContent = HTMLSanitizer.sanitize(templateContent);

      // Generate a secure UUID-style token
      String uniqueToken = generateUniqueToken();

      // Store template with the token
      TemplateStorage__c storage = new TemplateStorage__c(
        Content__c = sanitizedContent,
        ExpirationDate__c = DateTime.now().addMinutes(30), // 30 minutes
        Name = uniqueToken
      );

      insert storage;
      // Add to cache
      templateCache.put(uniqueToken, storage);
      System.debug(
        'Created template storage with token: ' +
          uniqueToken +
          ' (ID: ' +
          storage.Id +
          ')'
      );

      // Create PageReference to the Visualforce page
      PageReference pdfPage = Page.PDFGeneratorPage;

      // Use token instead of ID
      pdfPage.getParameters().put('token', uniqueToken);

      if (String.isNotBlank(recordId)) {
        pdfPage.getParameters().put('recordId', recordId);
      }

      if (String.isNotBlank(orientation)) {
        pdfPage.getParameters().put('orientation', orientation.toLowerCase());
        System.debug(
          'Setting orientation parameter: ' + orientation.toLowerCase()
        );
      }

      // Get the URL for preview
      return pdfPage.getUrl();
    } catch (Exception e) {
      System.debug('Error generating preview URL: ' + e.getStackTraceString());
      throw new AuraHandledException(
        'Something went wrong while generating the preview URL.'
      );
    }
  }

  @AuraEnabled
  public static PDFResult generatePDFDocument(
    String templateContent,
    String recordId,
    String fileName,
    String orientation
  ) {
    String uniqueToken = null;
    // Create the result object at the beginning
    PDFResult pdfResult = new PDFResult();

    try {
      cleanupExpiredTemplates();
      // Check if the template contains an embedded token marker
      String embeddedToken = extractTokenFromContent(templateContent);

      if (String.isNotBlank(embeddedToken)) {
        System.debug('Found embedded token in content: ' + embeddedToken);

        // Use cache to verify token exists
        TemplateStorage__c existingTemplate = getTemplateByToken(embeddedToken);

        if (existingTemplate != null) {
          // Reuse existing template and its content
          uniqueToken = embeddedToken;
          templateContent = existingTemplate.Content__c;
          System.debug('Found existing template with token: ' + uniqueToken);
          System.debug('Existing Template with orientation: ' + orientation);
        } else {
          // Token not found, use content as-is but remove the marker
          System.debug(
            'Embedded token not found in database: ' + embeddedToken
          );
          templateContent = removeTokenMarker(templateContent);

          // Generate new token for this content
          uniqueToken = generateUniqueToken();

          // Store with new token
          TemplateStorage__c storage = new TemplateStorage__c(
            Content__c = templateContent,
            ExpirationDate__c = DateTime.now().addHours(1),
            Name = uniqueToken
          );

          insert storage;
          // Add to cache
          templateCache.put(uniqueToken, storage);
          System.debug(
            'Created new template storage with token: ' + uniqueToken
          );
          System.debug('PDF generation with orientation: ' + orientation);
        }
      } else {
        // No embedded token, generate new token and create new template storage
        System.debug('No embedded token found, creating new template');
        System.debug(
          'Template length: ' +
          (templateContent != null ? templateContent.length() : 0)
        );
        System.debug('New Template Orientation: ' + orientation);

        // Generate a unique token for this template
        uniqueToken = generateUniqueToken();

        // Store template with the token - use the Name field
        TemplateStorage__c storage = new TemplateStorage__c(
          Content__c = templateContent,
          ExpirationDate__c = DateTime.now().addHours(1),
          Name = uniqueToken
        );

        insert storage;
        System.debug(
          'Created template storage with token: ' +
            uniqueToken +
            ' (ID: ' +
            storage.Id +
            ')'
        );
      }

      // Create PageReference to the Visualforce page
      PageReference pdfPage = Page.PDFGeneratorPage;

      // Use token instead of ID
      pdfPage.getParameters().put('token', uniqueToken);

      if (String.isNotBlank(recordId)) {
        pdfPage.getParameters().put('recordId', recordId);
      }

      if (String.isNotBlank(orientation)) {
        pdfPage.getParameters().put('orientation', orientation);
      }

      // Generate PDF blob
      Blob pdfBlob;
      if (Test.isRunningTest()) {
        pdfBlob = Blob.valueOf('Test PDF Content');
      } else {
        pdfBlob = pdfPage.getContentAsPDF();
      }

      // Use default filename if none provided
      if (String.isBlank(fileName)) {
        fileName = 'Generated_Document.pdf';
      } else if (!fileName.toLowerCase().endsWith('.pdf')) {
        fileName += '.pdf';
      }

      // Create ContentVersion
      ContentVersion cv = new ContentVersion();
      cv.Title = fileName;
      cv.PathOnClient = fileName;
      cv.VersionData = pdfBlob;
      cv.IsMajorVersion = true;

      insert cv;

      // Get ContentDocumentId
      cv = [
        SELECT Id, ContentDocumentId
        FROM ContentVersion
        WHERE Id = :cv.Id
        LIMIT 1
      ];

      // If recordId is provided, link the document to it
      if (String.isNotBlank(recordId)) {
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = cv.ContentDocumentId;
        cdl.LinkedEntityId = recordId;
        cdl.ShareType = 'I';
        cdl.Visibility = 'AllUsers';

        insert cdl;
      }

      // Log the template ID for reference
      System.debug(
        'Successfully generated PDF with template token: ' + uniqueToken
      );

      pdfResult.contentVersionId = cv.Id;
      pdfResult.contentDocumentId = cv.ContentDocumentId;

      // Log the result
      System.debug(
        'PDF generation successful - ContentDocumentId: ' +
        pdfResult.contentDocumentId
      );
      System.debug(
        'PDF generation successful - ContentVersionId: ' +
        pdfResult.contentVersionId
      );

      return pdfResult;
    } catch (Exception e) {
      System.debug('Error generating PDF Document: ' + e.getStackTraceString());
      throw new AuraHandledException(
        'Error generating PDF document: ' + e.getMessage()
      );
    }
  }

  // Helper method to clean up old template storage records
  public static void cleanupExpiredTemplates() {
    try {
      // Current time for comparison
      DateTime now = DateTime.now();

      // Clean cache first
      List<String> expiredTokensInCache = new List<String>();
      for (String token : templateCache.keySet()) {
        TemplateStorage__c template = templateCache.get(token);
        if (template.ExpirationDate__c < now) {
          expiredTokensInCache.add(token);
        }
      }

      // Remove expired templates from cache
      for (String token : expiredTokensInCache) {
        templateCache.remove(token);
      }

      if (!expiredTokensInCache.isEmpty()) {
        System.debug(
          'Removed ' +
            expiredTokensInCache.size() +
            ' expired templates from cache'
        );
      }

      // Get expired templates from database
      List<TemplateStorage__c> expiredTemplates = [
        SELECT Id
        FROM TemplateStorage__c
        WHERE ExpirationDate__c < :now
        LIMIT 100
      ];

      if (!expiredTemplates.isEmpty()) {
        delete expiredTemplates;
        System.debug(
          'Deleted ' +
            expiredTemplates.size() +
            ' expired template records from database'
        );
      }
    } catch (Exception e) {
      System.debug('Error cleaning up expired templates: ' + e.getMessage());
    }
  }

  @InvocableMethod(
    label='Generate PDF Document'
    description='Generates a PDF from template content and returns ContentDocumentId'
  )
  public static List<FlowResult> generatePDFForFlow(
    List<FlowRequest> requests
  ) {
    List<FlowResult> results = new List<FlowResult>();

    for (FlowRequest req : requests) {
      FlowResult result = new FlowResult();

      try {
        // Always generate the preview URL - using the method without fileName parameter
        String previewUrl = generatePreviewUrl(
          req.templateContent,
          req.recordId,
          req.orientation
        );
        result.previewUrl = previewUrl;

        // Check the flag: if true, generate the PDF document and attach it to the record
        if (req.autoGenerate) {
          PDFResult pdfResult = generatePDFDocument(
            req.templateContent,
            req.recordId,
            req.fileName,
            req.orientation
          );

          result.contentDocumentId = pdfResult.contentDocumentId;
          result.contentVersionId = pdfResult.contentVersionId;
          result.message = 'PDF generated and attached successfully';
        } else {
          // If autoGenerate is false, only provide the preview URL.
          result.message = 'Preview URL generated. PDF will not be auto-generated.';
        }
        result.success = true;
      } catch (Exception e) {
        result.success = false;
        result.message = 'Error generating PDF: ' + e.getMessage();
        System.debug('Error in generatePDFForFlow: ' + e.getStackTraceString());
      }

      results.add(result);
    }

    // Log the results for debugging
    System.debug('Returning Flow results: ' + JSON.serialize(results));

    return results;
  }

  public class PDFResult {
    @AuraEnabled
    public String contentVersionId;
    @AuraEnabled
    public String contentDocumentId;

    // Default constructor
    public PDFResult() {
      this.contentVersionId = '';
      this.contentDocumentId = '';
    }
  }

  // Helper method to redirect to error page
  private PageReference redirectToError(String errorMessage) {
    System.debug('PDFService error redirect: ' + errorMessage);

    PageReference errorPage = Page.ErrorPage; // Create this VF page
    errorPage.getParameters().put('error', 'An unexpected error occurred.');
    errorPage.setRedirect(true);
    return errorPage;
  }

  // Flow request class
  public class FlowRequest {
    @InvocableVariable(
      required=true
      label='Template Content'
      description='The HTML content to render as PDF'
    )
    public String templateContent;

    @InvocableVariable(
      required=false
      label='Record ID'
      description='ID of the record to link the document to'
    )
    public String recordId;

    @InvocableVariable(
      required=false
      label='File Name'
      description='Name for the generated PDF file'
    )
    public String fileName;

    @InvocableVariable(
      required=false
      label='Orientation'
      description='PDF orientation (portrait or landscape)'
    )
    public String orientation;

    @InvocableVariable(
      required=false
      label='Auto Generate PDF'
      description='If true, automatically generate and attach the PDF; if false, only display preview option'
    )
    public Boolean autoGenerate;
  }

  // Flow result class
  public class FlowResult {
    @InvocableVariable(
      label='Content Document ID'
      description='Content Document ID of the generated PDF document - Used to attach the document to a record'
    )
    public String contentDocumentId;

    @InvocableVariable(
      label='Content Version ID'
      description='Content Version ID of the generated PDF document - used to send the document via an email'
    )
    public String contentVersionId;

    @InvocableVariable(label='Preview URL' description='URL to preview the PDF')
    public String previewUrl;

    @InvocableVariable(
      label='Success'
      description='Whether the operation was successful'
    )
    public Boolean success;

    @InvocableVariable(
      label='Message'
      description='Status message or error details'
    )
    public String message;

    @InvocableVariable(
      label='Auto Generate PDF'
      description='If true, automatically generate and attach the PDF; if false, only display preview option'
    )
    public Boolean autoGenerate;
  }
}

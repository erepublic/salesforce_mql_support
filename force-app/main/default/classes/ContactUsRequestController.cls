public with sharing class ContactUsRequestController {
  // test https://erepublic--staging--c.visualforce.com/apex/ContactUsRequest

  // HubSpot Configuration
  private static final String HUBSPOT_API_URL = 'https://api.hubapi.com/crm/v3/objects/contacts';

  // Google reCAPTCHA keys must be configured in the org (do not commit them).

  public String First_Name { get; set; }
  public String Last_Name { get; set; }
  public String Email { get; set; }
  public String Phone { get; set; }
  public String Organization { get; set; }
  public String RTopic { get; set; }
  public String Message { get; set; }
  public String HomeAddressHP { get; set; }
  public String recaptchaToken { get; set; }
  public Boolean isChecked { get; set; }

  public Contact_Us__c contactRequest { get; set; }

  public Contact_Us__c getTheContactRequest() {
    return contactRequest;
  }

  public ContactUsRequestController() {
    this.contactRequest = new Contact_Us__c();
    isChecked = false;
  }

  List<selectOption> requestTopic = new List<selectOption>();
  public List<selectOption> getRequestTopic() {
    list<selectoption> options = new List<selectoption>();
    options.add(new selectOption('', '-- Please Select --'));
    schema.DescribeFieldResult fd = Contact_Us__c.Topic__c.getDescribe();
    list<Schema.PicklistEntry> pc = fd.getPicklistValues();
    for (Schema.PicklistEntry f : pc) {
      options.add(new selectOption(f.getlabel(), f.getvalue()));
    }
    return options;
  }

  private Boolean validateCaptcha(String response) {
    // String secretKey = '6LcgTxInAAAAAMV-upoVlSD8ONFTXLCw5qBrDIAN';
    String secretKey = MqlSecrets.getRecaptchaSecretKey();
    // Fail closed if the org isn't configured.
    if (String.isBlank(secretKey))
      return false;
    String captchaVerifyURL = 'https://www.google.com/recaptcha/api/siteverify';

    HttpRequest req = new HttpRequest();
    req.setEndpoint(captchaVerifyURL);
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
    req.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    req.setHeader('Pragma', 'no-cache');
    req.setHeader('Expires', '0');
    Integer unixTimestamp = (Integer) (System.now().getTime() / 1000);
    req.setBody(
      'secret=' +
        secretKey +
        '&response=' +
        EncodingUtil.urlEncode(response, 'UTF-8') +
        '&remoteip=' +
        unixTimestamp
    );

    HttpResponse res = new Http().send(req);
    if (res.getStatusCode() == 200) {
      Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
        res.getBody()
      );
      if (!(Boolean) result.get('success')) {
        return false;
      } else if ((Double) result.get('score') < 0.6) {
        return false;
      }
      return true;
    }

    return false;
  }

  public PageReference submit() {
    // Validate honeypot field
    if (!String.isEmpty(HomeAddressHP)) {
      ApexPages.addMessage(
        new ApexPages.Message(ApexPages.Severity.ERROR, 'Submission failed.')
      );
      return null;
    }

    // Validate form time
    if (
      Decimal.valueOf(
        ApexPages.currentPage().getParameters().get('TimeSpent')
      ) < 1
    ) {
      ApexPages.addMessage(
        new ApexPages.Message(
          ApexPages.Severity.ERROR,
          'Please fill out the form.'
        )
      );
      return null;
    }

    // Validate CAPTCHA
    String captchaResponse = recaptchaToken;
    if (String.isEmpty(captchaResponse) || !validateCaptcha(captchaResponse)) {
      ApexPages.addMessage(
        new ApexPages.Message(
          ApexPages.Severity.ERROR,
          'Invalid CAPTCHA. Please try again.'
        )
      );
      return null;
    }

    PageReference pageRef = null;
    try {
      contactRequest.First_Name__c = First_Name;
      contactRequest.Last_Name__c = Last_Name;
      contactRequest.Email__c = Email;
      contactRequest.Phone__c = Phone;
      contactRequest.Organization__c = Organization;
      contactRequest.Topic__c = RTopic;
      contactRequest.Message__c = Message;
      contactRequest.Source__c = !String.isBlank(
          ApexPages.currentPage().getParameters().get('src')
        )
        ? ApexPages.currentPage().getParameters().get('src')
        : ApexPages.currentPage().getHeaders().get('Referer');
      insert contactRequest;

      // Send to HubSpot - all submissions per ticket 99842
      sendToHubSpot(
        First_Name,
        Last_Name,
        Email,
        Phone,
        Organization,
        RTopic,
        Message
      );
    } catch (Exception e) {
      ApexPages.addMessages(e);
      return null;
    }

    if (pageRef == null) {
      String r = '/apex/ContactUsRequest';
      pageRef = new PageReference(r);
      pageRef.getParameters().put('s', '1');
      pageRef.setRedirect(true);
    }

    return pageRef;
  }

  /**
   * Send contact data to HubSpot via API
   */
  @future(callout=true)
  public static void sendToHubSpot(
    String firstName,
    String lastName,
    String email,
    String phone,
    String organization,
    String topic,
    String message
  ) {
    String hubspotToken = MqlSecrets.getHubspotPrivateAppToken();
    if (String.isBlank(hubspotToken)) {
      System.debug('HubSpot token not configured; skipping callout.');
      return;
    }
    try {
      // Build the request body
      Map<String, Object> properties = new Map<String, Object>();
      properties.put('email', email);
      properties.put('firstname', firstName);
      properties.put('lastname', lastName);

      if (!String.isBlank(phone)) {
        properties.put('phone', phone);
      }

      if (!String.isBlank(organization)) {
        properties.put('company', organization);
      }

      if (!String.isBlank(topic)) {
        properties.put('contact_request_topic', topic);
      }

      if (!String.isBlank(message)) {
        properties.put('salesforce_contact_message', message);
      }

      // Add source tracking
      properties.put('hs_lead_status', 'NEW');
      properties.put('lifecyclestage', 'lead');

      Map<String, Object> requestBody = new Map<String, Object>();
      requestBody.put('properties', properties);

      // Make the HTTP request
      Http http = new Http();
      HttpRequest request = new HttpRequest();
      request.setEndpoint(HUBSPOT_API_URL);
      request.setMethod('POST');
      request.setHeader('Content-Type', 'application/json');
      request.setHeader('Authorization', 'Bearer ' + hubspotToken);
      request.setBody(JSON.serialize(requestBody));
      request.setTimeout(120000);

      HttpResponse response = http.send(request);

      if (response.getStatusCode() == 201 || response.getStatusCode() == 200) {
        System.debug(
          'Successfully sent contact to HubSpot: ' + response.getBody()
        );
      } else if (response.getStatusCode() == 409) {
        // Contact already exists, update instead
        System.debug('Contact already exists in HubSpot, attempting update');
        updateHubSpotContact(email, properties);
      } else {
        System.debug(
          'Error sending to HubSpot. Status: ' +
            response.getStatusCode() +
            ', Body: ' +
            response.getBody()
        );
      }
    } catch (Exception e) {
      System.debug('Exception while sending to HubSpot: ' + e.getMessage());
    }
  }

  /**
   * Update existing HubSpot contact
   */
  private static void updateHubSpotContact(
    String email,
    Map<String, Object> properties
  ) {
    String hubspotToken = MqlSecrets.getHubspotPrivateAppToken();
    if (String.isBlank(hubspotToken)) {
      System.debug('HubSpot token not configured; skipping callout.');
      return;
    }
    try {
      // First, search for the contact by email
      String searchUrl = 'https://api.hubapi.com/crm/v3/objects/contacts/search';

      Map<String, Object> searchBody = new Map<String, Object>();
      List<Map<String, Object>> filterGroups = new List<Map<String, Object>>();
      Map<String, Object> filterGroup = new Map<String, Object>();
      List<Map<String, Object>> filters = new List<Map<String, Object>>();

      Map<String, Object> emailFilter = new Map<String, Object>();
      emailFilter.put('propertyName', 'email');
      emailFilter.put('operator', 'EQ');
      emailFilter.put('value', email);
      filters.add(emailFilter);

      filterGroup.put('filters', filters);
      filterGroups.add(filterGroup);
      searchBody.put('filterGroups', filterGroups);

      Http http = new Http();
      HttpRequest searchRequest = new HttpRequest();
      searchRequest.setEndpoint(searchUrl);
      searchRequest.setMethod('POST');
      searchRequest.setHeader('Content-Type', 'application/json');
      searchRequest.setHeader('Authorization', 'Bearer ' + hubspotToken);
      searchRequest.setBody(JSON.serialize(searchBody));
      searchRequest.setTimeout(120000);

      HttpResponse searchResponse = http.send(searchRequest);

      if (searchResponse.getStatusCode() == 200) {
        Map<String, Object> searchResult = (Map<String, Object>) JSON.deserializeUntyped(
          searchResponse.getBody()
        );
        List<Object> results = (List<Object>) searchResult.get('results');

        if (results != null && results.size() > 0) {
          Map<String, Object> contact = (Map<String, Object>) results[0];
          String contactId = (String) contact.get('id');

          // Update the contact
          String updateUrl = HUBSPOT_API_URL + '/' + contactId;
          Map<String, Object> updateBody = new Map<String, Object>();
          updateBody.put('properties', properties);

          HttpRequest updateRequest = new HttpRequest();
          updateRequest.setEndpoint(updateUrl);
          updateRequest.setMethod('PATCH');
          updateRequest.setHeader('Content-Type', 'application/json');
          updateRequest.setHeader('Authorization', 'Bearer ' + hubspotToken);
          updateRequest.setBody(JSON.serialize(updateBody));
          updateRequest.setTimeout(120000);

          HttpResponse updateResponse = http.send(updateRequest);

          if (updateResponse.getStatusCode() == 200) {
            System.debug('Successfully updated contact in HubSpot');
          } else {
            System.debug(
              'Error updating HubSpot contact: ' + updateResponse.getBody()
            );
          }
        }
      }
    } catch (Exception e) {
      System.debug(
        'Exception while updating HubSpot contact: ' + e.getMessage()
      );
    }
  }
}

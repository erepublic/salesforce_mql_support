public with sharing class PrivacyRequestController {
  // test https://erepublic--staging--c.sandbox.vf.force.com/apex/PrivacyRequest

  // Google reCAPTCHA keys must be configured in the org (do not commit them).

  public String RType { get; set; }
  public String First_Name { get; set; }
  public String Last_Name { get; set; }
  public String Organization { get; set; }
  public String Phone { get; set; }
  public String Email { get; set; }
  public String Address_Line_1 { get; set; }
  public String Address_Line_2 { get; set; }
  public String City { get; set; }
  public String State { get; set; }
  public String Zip { get; set; }
  public String Comments { get; set; }
  public String HomeAddressHP { get; set; }
  public String recaptchaToken { get; set; }
  public Boolean isChecked { get; set; }

  public Privacy_Request__c privacyRequest { get; set; }

  public Privacy_Request__c getThePrivacyRequest() {
    return privacyRequest;
  }

  public PrivacyRequestController() {
    this.privacyRequest = new Privacy_Request__c();
    isChecked = false;
  }

  List<selectOption> stateOptions = new List<selectOption>();
  public List<selectOption> getStateOptions() {
    List<selectOption> options = new List<selectOption>();
    options.add(new selectOption('', '-- Please Select --'));
    options.add(new selectOption('AK', 'Alaska'));
    options.add(new selectOption('AL', 'Alabama'));
    options.add(new selectOption('AR', 'Arkansas'));
    options.add(new selectOption('AS', 'American Samoa'));
    options.add(new selectOption('AZ', 'Arizona'));
    options.add(new selectOption('CA', 'California'));
    options.add(new selectOption('CO', 'Colorado'));
    options.add(new selectOption('CT', 'Connecticut'));
    options.add(new selectOption('DC', 'D.C.'));
    options.add(new selectOption('DE', 'Delaware'));
    options.add(new selectOption('FL', 'Florida'));
    options.add(new selectOption('FM', 'Micronesia'));
    options.add(new selectOption('GA', 'Georgia'));
    options.add(new selectOption('GU', 'Guam'));
    options.add(new selectOption('HI', 'Hawaii'));
    options.add(new selectOption('IA', 'Iowa'));
    options.add(new selectOption('ID', 'Idaho'));
    options.add(new selectOption('IL', 'Illinois'));
    options.add(new selectOption('IN', 'Indiana'));
    options.add(new selectOption('KS', 'Kansas'));
    options.add(new selectOption('KY', 'Kentucky'));
    options.add(new selectOption('LA', 'Louisiana'));
    options.add(new selectOption('MA', 'Massachusetts'));
    options.add(new selectOption('MD', 'Maryland'));
    options.add(new selectOption('ME', 'Maine'));
    options.add(new selectOption('MH', 'Marshall Islands'));
    options.add(new selectOption('MI', 'Michigan'));
    options.add(new selectOption('MN', 'Minnesota'));
    options.add(new selectOption('MO', 'Missouri'));
    options.add(new selectOption('MP', 'Marianas'));
    options.add(new selectOption('MS', 'Mississippi'));
    options.add(new selectOption('MT', 'Montana'));
    options.add(new selectOption('NC', 'North Carolina'));
    options.add(new selectOption('ND', 'North Dakota'));
    options.add(new selectOption('NE', 'Nebraska'));
    options.add(new selectOption('NH', 'New Hampshire'));
    options.add(new selectOption('NJ', 'New Jersey'));
    options.add(new selectOption('NM', 'New Mexico'));
    options.add(new selectOption('NV', 'Nevada'));
    options.add(new selectOption('NY', 'New York'));
    options.add(new selectOption('OH', 'Ohio'));
    options.add(new selectOption('OK', 'Oklahoma'));
    options.add(new selectOption('OR', 'Oregon'));
    options.add(new selectOption('PA', 'Pennsylvania'));
    options.add(new selectOption('PR', 'Puerto Rico'));
    options.add(new selectOption('PW', 'Palau'));
    options.add(new selectOption('RI', 'Rhode Island'));
    options.add(new selectOption('SC', 'South Carolina'));
    options.add(new selectOption('SD', 'South Dakota'));
    options.add(new selectOption('TN', 'Tennessee'));
    options.add(new selectOption('TX', 'Texas'));
    options.add(new selectOption('UT', 'Utah'));
    options.add(new selectOption('VA', 'Virginia'));
    options.add(new selectOption('VI', 'Virgin Islands'));
    options.add(new selectOption('VT', 'Vermont'));
    options.add(new selectOption('WA', 'Washington'));
    options.add(new selectOption('WI', 'Wisconsin'));
    options.add(new selectOption('WV', 'West Virginia'));
    options.add(new selectOption('WY', 'Wyoming'));
    options.add(new selectOption('AA', 'Military Americas'));
    options.add(new selectOption('AE', 'Military Europe/ME/Canada'));
    options.add(new selectOption('AP', 'Military Pacific'));
    options.add(new selectOption('AB', 'Alberta'));
    options.add(new selectOption('MB', 'Manitoba'));
    options.add(new selectOption('BC', 'British Columbia'));
    options.add(new selectOption('NB', 'New Brunswick'));
    options.add(new selectOption('NL', 'Newfoundland and Labrador'));
    options.add(new selectOption('NS', 'Nova Scotia'));
    options.add(new selectOption('NT', 'Northwest Territories'));
    options.add(new selectOption('NU', 'Nunavut'));
    options.add(new selectOption('ON', 'Ontario'));
    options.add(new selectOption('PE', 'Prince Edward Island'));
    options.add(new selectOption('QC', 'Quebec'));
    options.add(new selectOption('SK', 'Saskatchewan'));
    options.add(new selectOption('YT', 'Yukon Territory'));
    options.add(new selectOption('OTHER', 'Outside USA/CAN'));
    return options;
  }

  List<selectOption> requestType = new List<selectOption>();
  public List<selectOption> getRequestType() {
    list<selectoption> options = new List<selectoption>();
    options.add(new selectOption('', '-- Please Select --'));
    schema.DescribeFieldResult fd = Privacy_Request__c.Type__c.getDescribe();
    list<Schema.PicklistEntry> pc = fd.getPicklistValues();
    for (Schema.PicklistEntry f : pc) {
      options.add(new selectOption(f.getlabel(), f.getvalue()));
    }
    return options;
  }

  public PageReference checkState() {
    /*
        if( privacyRequest.State__c != 'CA' && privacyRequest.State__c != '' ) {
            ApexPages.Message errormsg = new ApexPages.Message(ApexPages.severity.ERROR,'Value not allowed');
        }
         */
    String r = URL.getSalesforceBaseUrl().toExternalForm();
    PageReference pageRef = new PageReference(r);
    return pageRef;
  }

  private Boolean validateCaptcha(String response) {
    // String secretKey = '6LcgTxInAAAAAMV-upoVlSD8ONFTXLCw5qBrDIAN';
    String secretKey = '';
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
    if (!String.isEmpty(HomeAddressHP)) {
      ApexPages.addMessage(
        new ApexPages.Message(ApexPages.Severity.ERROR, 'Submission failed.')
      );
      return null;
    }
    if (!isChecked) {
      ApexPages.addMessage(
        new ApexPages.Message(
          ApexPages.Severity.ERROR,
          'You need to check the box'
        )
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

    try {
      privacyRequest.Type__c = RType;
      privacyRequest.First_Name__c = First_Name;
      privacyRequest.Last_Name__c = Last_Name;
      privacyRequest.Phone__c = Phone;
      privacyRequest.Email__c = Email;
      privacyRequest.Organization__c = Organization;
      privacyRequest.Address_Line_1__c = Address_Line_1;
      privacyRequest.Address_Line_2__c = Address_Line_2;
      privacyRequest.City__c = City;
      privacyRequest.State__c = State;
      privacyRequest.Zip__c = Zip;
      privacyRequest.Comments__c = Comments;

      insert privacyRequest;
      System.debug('privacyRequest: ' + JSON.serialize(privacyRequest));
      // Return the success PageReference if insert succeeds
      PageReference pageRef = new PageReference('/apex/PrivacyRequest');
      pageRef.getParameters().put('s', '1');
      pageRef.setRedirect(true);
      return pageRef;
    } catch (Exception e) {
      ApexPages.addMessages(e);
      return null;
    }
  }
}

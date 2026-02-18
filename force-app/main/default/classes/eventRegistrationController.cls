public virtual with sharing class eventRegistrationController {
  // App settings
  /*  
  public String InfoMsg { get; set; }
  public String ErrorMsg { get; set; }
  public String SuccessMsg { get; set; }
  public Events__c Event { get; set; }
  public Event_Custom_Price__c EventCustomPrice { get; set; }
  public User EventContact { get; set; }
  public User RegCoordinator { get; set; }
  public Decimal PublicFee {get; set; }
  public Decimal IndustryFee {get; set; }
  public Decimal CustomFee { get; set; }
  public String ClassesCSV {get; set; } // For use in form
  public List<Event_Session__c> Sessions {get; set; }
  public Integer SessionCount { get; set; }
  public Map<String, String> Fields {get; set; }
  public Decimal Total { get; set; } // For price assertion
  public Boolean AllowIndustryRegistration {get; set;}
  public Boolean IsEarlyBird {get; set;}
  public Boolean IsSponsorshipForm { get; set; }
  public Boolean Debug { get; set; }
  public String OpenToPrivateCompGOV { get; set; }
  public String OpenToPrivateCompEE { get; set; }
  public List<Event_Session__c> CafeSession { get; set; }
  public Integer CafeSessionCount { get; set; }
  public List<Event_Session__c> CafeSessionSelected { get; set; }
  public String testL { get; set; }
  public String EventContactPhone { get; set; }
  public String FormType { get; set; }
  public String zip { get; set; }
  
  // Site Settings
  
  public String MerchantName { get; set; }
  public String Copyright {get; set; }
  public Map<String, List<String>> Demographics { get; set; }
  public Map<String, List<String>> Dietary { get; set; }
  public String ElqFormName {get; set; }
  public String SuccessURL { get; set; }
  public String EventBaseURL {get; set;}
  public String EventURL {get; set;}
  public String ShowQuestions {get; set;}
  public String DisplayQuestions {get; set;}
  public Boolean ShowDietaryQuestion {get; set;}
  public String DisplayDietaryQuestion {get; set;}
  public Boolean ShowCommentQuestion {get; set;}
  public String DisplayCommentQuestion {get; set;}
  public Boolean ShowBio {get; set;}
  public String DisplayBio {get; set;}
  public String HideElements { get; set; }
  public String CustomDisclaimer { get; set; }

  public Boolean CardCharged { get; set; }

*/

  public eventRegistrationController() {
    //init();
  }

  /*
  public PageReference save() {
    try {
      return SaveRegistration();
    } catch(Exception e) {
      return HandleFatalError('An internal error occurred while submitting your request.', e);
    }
  }

  public PageReference init() {
    CardCharged = false;
    Fields = ApexPages.currentPage().getParameters();
    
    zip = Fields.get('zip');
    if( zip != null && zip.length() > 5 ){
     zip = zip.substring(0, 5);
    }
    
    Sessions = new List<Event_Session__c>();
    SessionCount = 0;
    CustomFee = 0;
    ClassesCSV = Fields.get('classes');
    List<String> dirty_classes;

    if(Fields.get('classes') != null) {
      dirty_classes = Fields.get('classes').split(',');
    }
    Total = 0;

    IsSponsorshipForm = false;
    String PageURL = ApexPages.currentPage().getURL();
    if(PageURL.indexOf('event_sponsor_reg') != -1){
      IsSponsorshipForm = true;
    }

    if(Fields.get('debug') == '1') {
      Debug = true;
    } else {
      Debug = false;
    }
    if(Fields.get('event_id') == null) {
      return handleError('Invalid event ID');
    }
    try{
      Event = [Select Id, Name, Display_Name__c, Registration_Coordinator__c, Closed_Message__c, Sponsor_Message__c, Registration_Open__c, Sponsor_Registration_Open__c, Sponsor_Closed_Message__c, Brand__c, Event_Website__c, Event_Start_Date__c, Event_End_Date__c, Cancel_by_Date__c , Public_Reg_Fee__c, Public_Early_Bird_Fee__c, Industry_Reg_Fee__c, Industry_Early_Bird_Fee__c, Early_Bird_End_Date__c, Credit_Card_Only__c, Owner.Id, Venue_Name__c, Venue_Street__c, Venue_City__c, Venue_State__c, Venue_Zip__c, Twitter_Hashtag__c, Banner_URL__c, Email_Confirmation_Template__c, Show_Demographic_Questions__c, Show_Dietary_Question__c, Show_Comment_Question__c, Show_Bio__c, Open_to_private_companies__c, Info_Message__c, Hide_Page_Elements__c, Custom_Disclaimer__c,  (SELECT Id, Name From attachments), (SELECT Id, Name, Fee__c, Description__c FROM Event_Custom_Prices__r) From Events__c Where (Web_Status__c = 'live' OR Web_Status__c = 'In Progress') AND Id = :Fields.get('event_id')];
      if( Event.Registration_Coordinator__c != null ){
        RegCoordinator = [Select Id, Name, Email, Phone, Extension FROM User WHERE Id = :Event.Registration_Coordinator__c LIMIT 1];  
      }        
      CafeSession = [Select Id, Name, Display_Name__c, Session_Code__c, Reg_Fee__c, Early_Bird_Fee__c, Event__c, Description__c From Event_Session__c WHERE Reg_Open__c = True AND Session_Type__c = 'Cafe' AND Event__c = :Fields.get('event_id')];
      CafeSessionCount = CafeSession.size();
      
      testL = Fields.get('event_id');

      for(Event_Custom_Price__c price: Event.Event_Custom_Prices__r) {
        CustomFee += price.Fee__c;
      }

      //patch mtel   close registration but keep it open for classes
      if(Event.Id == 'a0ma0000002KYGcAAO' && dirty_classes == null ){
        return HandleError('Pre-registration for this event is now closed.');
      }

      if(Event.Owner != null) {
        try{
          EventContact = [Select Name, Email, Phone, Extension From User Where Id = :Event.Owner.Id LIMIT 1];          
        }
        catch(System.QueryException e) {
          // if query is not returning a row, then assign new user (hack)
          EventContact = new User(lastname = '', firstname = '', email = '');
        }
      }

      if(IsSponsorshipForm == false){
        if(Event.Registration_Open__c == false) {
          if(Event.Closed_Message__c == null) {
            return HandleFatalError('Pre-registration for this event is now closed.');
          }
          else{
            return HandleError(Event.Closed_Message__c);
          }
        }
      }
      else{
        if(Event.Sponsor_Registration_Open__c == false) {
          if(Event.Sponsor_Closed_Message__c == null) {
            return HandleError('We apologize but we are no longer accepting sponsorship registrations for this event.');
          }
          else{
            return HandleError(Event.Sponsor_Closed_Message__c);
          }
        }
      }
      
      ShowQuestions = Event.Show_Demographic_Questions__c;
      ShowDietaryQuestion = Event.Show_Dietary_Question__c;
      ShowCommentQuestion = Event.Show_Comment_Question__c;
      ShowBio = Event.Show_Bio__c;
      HideElements = Event.Hide_Page_Elements__c;
      CustomDisclaimer = Event.Custom_Disclaimer__c;

      // show demographics questions
      if( ShowQuestions == 'Show Demographic Questions' || ShowQuestions == null ){
        DisplayQuestions = '';
      }
      else{
        DisplayQuestions = 'none';
      }
      // show dietary question
      if( ShowDietaryQuestion ){
        DisplayDietaryQuestion = '';
      }
      else{
        DisplayDietaryQuestion = 'none';
      }
      // show comment question
      if( ShowCommentQuestion ){
        DisplayCommentQuestion = '';
      }
      else{
        DisplayCommentQuestion = 'none';
      }
      // show attendee/sponsor bio field
      if( ShowBio ){
        DisplayBio = '';
      }
      else{
        DisplayBio = 'none';
      }

      // open to private companies?
      if(Event.Open_to_private_companies__c == false){
        if(
          Event.Brand__c == 'Governing' ||
          Event.Brand__c == 'GOVERNING' ||
          Event.Brand__c == 'CDE/Converge'
        ){
          OpenToPrivateCompGOV = '';
          OpenToPrivateCompEE = 'display:none;';
        }
        else if( Event.Brand__c == 'Exec Events' ){
          OpenToPrivateCompGOV = 'display:none;';
          OpenToPrivateCompEE = '';
        }
        else{
          OpenToPrivateCompGOV = 'display:none;';
          OpenToPrivateCompEE = 'display:none;';
        }
      }
      else{
        OpenToPrivateCompGOV = 'display:none;';
        OpenToPrivateCompEE = 'display:none';
      }

      if(Event.Brand__c == 'Governing' || Event.Brand__c == 'GOVERNING') {
        
        // Governing initialization
        

        EventBaseURL = 'http://www.governing.com/events/';
        ElqFormName = 'gOVEventsForm-1349998405421';
        if(!IsSponsorshipForm){
          SuccessURL  = 'http://forms.erepublic.com/gov-thank-you-events';
        }
        else{
          SuccessURL  = '/event_sponsor_reg_thank_you?event_id=' + Fields.get('event_id');
        }

        MerchantName = 'GOVERNING';
        Copyright = 'Governing.com is a part of e.Republic ? '+date.today().year()+'. All rights reserved.';

        //Contact Information
        if( EventContact.Email.length() > 0 ){
          List<String> email_pieces = EventContact.Email.split('@', 2);
          EventContact.Email = email_pieces.get(0) + '@governing.com';         
        }

        InfoMsg = Event.Info_Message__c;
      }
      else{
        List<String> email_pieces = new List<String>();
        if( EventContact.Email.length() > 0 ){
          email_pieces = EventContact.Email.split('@', 2);
        }
        
        // Load site configuration
        if(Event.Brand__c == 'CDE/Converge'){
          EventBaseURL = 'http://www.centerdigitaled.com/events/';
          MerchantName = 'Center For Digital Education';
          ElqFormName = 'CDE-Events-SalesforceIntegrationForm';
          Copyright = 'Centerdigitaled.com is a part of e.Republic ? 2014. All rights reserved.';
          if(!IsSponsorshipForm){
            SuccessURL  = 'http://forms.erepublic.com/cvg-thank-you-events';
          }
          else{
            SuccessURL  = '/event_sponsor_reg_thank_you?event_id=' + Fields.get('event_id');
          }

          if( EventContact.Email.length() > 0 ){
            EventContact.Email = email_pieces.get(0) + '@centerdigitaled.com';
          }          
          EventContact.Phone = '800.940.6039';
          InfoMsg = Event.Info_Message__c;
        }
        else if( Event.Brand__c == 'EM' ) {
          EventBaseURL = 'http://www.emergencymgmt.com/events/';
          MerchantName = 'Emergency Management';
          ElqFormName = '01-MASTER-EEPaidEventRegistration';
          Copyright = 'EmergencyMgmt.com is a part of e.Republic ? 2014. All rights reserved.';
          if(!IsSponsorshipForm)
          {
          SuccessURL  = 'http://forms.erepublic.com/gt-thank-you-events';
          } else {
          SuccessURL  = '/event_sponsor_reg_thank_you?event_id=' + Fields.get('event_id');
          }
          
          if( EventContact.Email.length() > 0 ){
            EventContact.Email = email_pieces.get(0) + '@emergencymgmt.com';
          }
          EventContact.Phone = '800.917.7732';
          InfoMsg = Event.Info_Message__c;
        }
        else{
          EventBaseURL = 'http://www.govtech.com/events/';
          MerchantName = 'Government Technology';
          ElqFormName = '01-MASTER-EEPaidEventRegistration';
          Copyright = 'Govtech.com is a part of e.Republic ? 2014. All rights reserved.';
          if(!IsSponsorshipForm)
          {
              SuccessURL  = 'http://forms.erepublic.com/gt-thank-you-events';
          } else {
              SuccessURL  = '/event_sponsor_reg_thank_you?event_id=' + Fields.get('event_id');
          }
          
          if( EventContact.Email.length() > 0 ){
            EventContact.Email = email_pieces.get(0) + '@govtech.com';
          }
          
          EventContact.Phone = '800.917.7732';
          InfoMsg = Event.Info_Message__c;
        }
      }

      //***************   Demographic data   **************
      // Demographics init
      Demographics = new Map<String, List<String>>();

      Demographics.put('branches', new List<String> {
        '01 - Federal',
        '02 - State',
        '03 - County',
        '04 - Municipal',
        '05 - Special District',
        '06 - Government Association',
        '07 - Higher Education',
        '08 - K-12 Education',
        '09 - Private Sector',
        '99 - Other'
      });

      Demographics.put('agency_functions', new List<String> {
        '01 - Elected Official/Legislative',
        '02 - Finance/Taxation/Budgeting',
        '03 - Information Technology/Telecommunications',
        '04 - Public Works/Transportation/Infrastructure/Utility/Planning',
        '05 - Health/Human Services',
        '06 - Human Resources/Benefits/Personnel',
        '07 - Environment/Energy',
        '08 - Administration/Operations/General Services/Purchasing',
        '09 - Economic Development/Workforce Development',
        '10 - Agriculture/Parks & Rec/Land Management',
        '11 - Courts/Corrections/Justice',
        '12 - Law Enforcement',
        '13 - Fire/Emergency Services',
        '14 - Emergency Operations Center',
        '15 - Homeland Security/Defense',
        '16 - Education/Library Services',
        '99 - Other'
      });

      Demographics.put('job_roles', new List<String> {
        '01 - Executive/C-Level',
        '02 - Senior Management',
        '03 - Supervision',
        '04 - Subject Matter Expert/Practitioner'
      });

      if( Event.Brand__c == 'CDE/Converge' ){
        Demographics.put('job_functions', new List<String> {
          '01 - Elected Official/Legislative',
          '02 - Finance/Procurement/Budget/Auditor',
          '03 - Information Technology',
          '04 - Engineering/Technical',
          '05 - Operations/Administration',
          '06 - Human Resource/Workforce/Training/Benefits',
          '07 - First Responder (Police/Fire/EMS)',
          '08 - Emergency Management',
          '09 - Marketing/Sales',
          '10 - Commissioner/School Board President/Member/Staff',
          '11 - President/Vice President/Chancellor/Staff',
          '12 - Director/Provost/Dean/Staff',
          '13 - Superintendent/Assistant Superintendent/Staff',
          '14 - District Administrator/Staff',
          '15 - Principal/Assistant Principal/Staff',
          '16 - CIO/CTO/IT Director/Staff',
          '17 - Tech Manager/Coordinator/Specialist/Administrator',
          '18 - Curriculum/Instructional Learning Manager/Librarian',
          '19 - Professor/Teacher',
          '20 - Business/Purchasing Manager',
          '99 - Other'
        });
      }
      else{
        Demographics.put('job_functions', new List<String> {
          '01 - Elected Official/Legislative',
          '02 - Finance/Procurement/Budget/Auditor',
          '03 - Information Technology',
          '04 - Engineering/Technical',
          '05 - Operations/Administration',
          '06 - Human Resource/Workforce/Training/Benefits',
          '07 - First Responder (Police/Fire/EMS)',
          '08 - Emergency Management',
          '09 - Marketing/Sales',
          '99 - Other'
        });
      }

      //***************   Dietary Question/Answers   **************
      Dietary = new Map<String, List<String>>();

      if( Event.Venue_State__c == 'NY' ){
        Dietary.put('needs', new List<String> {
          '01 - Vegetarian',
          '02 - Vegan',
          '03 - Gluten-free',
          '04 - Kosher'
        });
      }
      else{
        Dietary.put('needs', new List<String> {
          '01 - Vegetarian',
          '02 - Vegan',
          '03 - Gluten-free'
        });
      }

      // Only use early bird if today is before end of early bird,
      // and early bird has a date.
      IsEarlyBird = false;
      if(Event.Early_Bird_End_Date__c > date.today()) {
        IsEarlyBird = true;
        PublicFee = Event.Public_Early_Bird_Fee__c;
        IndustryFee = Event.Industry_Early_Bird_Fee__c;
      }
      else{
        PublicFee = Event.Public_Reg_Fee__c;
        IndustryFee = Event.Industry_Reg_Fee__c;
      }
      AllowIndustryRegistration = True;
      if(IndustryFee == Null) {
        AllowIndustryRegistration = False;
        IndustryFee = 0;
      }
    }
    catch(System.QueryException e) {
      return HandleError('Unable to load event');
    }
    catch(System.DmlException e) {
      return HandleFatalError('An error occurred while initializing the event', e);
    }

    if(dirty_classes != null) {
      try {
        Sessions = [Select Id, Name, Display_Name__c, Session_Code__c, Reg_Fee__c, Early_Bird_Fee__c, Event__c From Event_Session__c WHERE Reg_Open__c = True AND Session_Type__c = 'Class' AND Event__c = :Fields.get('event_id') AND Id IN :dirty_classes];
        SessionCount = sessions.size();
      }
      catch(System.DmlException e){
        return HandleFatalError('An error occurred while initializing the session', e);
      }
    }

    return null;
  }

  
  //  Future method for abstracted classes
   
  public virtual void initSite() {

  }

  public PageReference SaveRegistration() {
    Long TransactionID;
    Decimal event_total;
    Pagereference pageRef;

    pageRef = init();
    if(pageRef != Null) {
      return pageRef;
    }

    Total = 0;
    event_total = 0;

    if(Fields.get('attending_event') == 'PUBLIC') {
      event_total = PublicFee;
      Total += PublicFee;
    }
    else if(Fields.get('attending_event') == 'INDUSTRY'){
      event_total = IndustryFee;
      Total += IndustryFee;
    }
    else if(Fields.get('attending_event') != 'NOT_ATTENDING') {
      for(Event_Custom_Price__c price: Event.Event_Custom_Prices__r) {
        if(String.valueOf(price.Id) == Fields.get('attending_event')) {
          event_total = price.Fee__c;
          Total += price.Fee__c;
        }
      }
    }

    if(Fields.get('classes') != null) {
      List<String> dirty_classes = Fields.get('classes').split(',');

      try {
        for(Event_Session__c session: Sessions) {
          if(IsEarlyBird && Session.Early_Bird_Fee__c != Null) {
            Total += Session.Early_Bird_Fee__c;
          }
          else{
            Total += Session.Reg_Fee__c;
          }
        }
      }
      catch(System.DmlException e){
        return HandleFatalError('An error occurred while initializing the session', e);
      }
    }

    // Only process payments for paid events
    if(Total != 0.00 && Fields.get('payment_type') == 'cc') {
      List<String> receipt_descriptions = new List<String>();

      authorizeNetProcessor auth = new authorizeNetProcessor();
      if(Debug == true) {
        auth.Debug = 1;
      }
      else{
        auth.Debug = 0;
      }

      String receipt_header = '<strong>*Important*</strong> If you have questions about your order please contact <a href=\"mailto:' + EventContact.Email + '\">' + EventContact.Name + '</a> . DO NOT REPLY TO THIS EMAIL - THIS IS ONLY A NOTIFICATION!<br /><br />';

      auth.ReceiptHeader = receipt_header;

      Integer i = 1;
      List<Map<String, String>> other_data = new List<Map<String, String>>();
      if(Fields.get('attending_event') != 'NOT_ATTENDING') {
        String event_name = '';
        if(Event.Display_Name__c.length() > 25) {
          event_name = Event.Display_Name__c.substring(0, 25);
        }
        else {
          event_name = Event.Display_Name__c;
        }

        //auth.ReceiptDescription = event_name;
        receipt_descriptions.add(Event.Display_Name__c);

        other_data.add(new Map<String, String> { 'key' => 'Item ' + i + ': ', 'value' => event_name});
        auth.AddItem(String.ValueOf(i), event_name, '', 1, event_total, False);
        i++;
      }

      auth.CCNumber = Fields.get('cc_number');
      auth.CCExpDate = Fields.get('cc_exp_month') + '/' + Fields.get('cc_exp_year');
      auth.CCSecCode = Fields.get('cc_sec_code');
      auth.FirstName = Fields.get('cc_first_name');
      auth.LastName = Fields.get('cc_last_name');
      if(Fields.get('cc_email') != null && Fields.get('cc_email') != '') {
        auth.Email = Fields.get('cc_email');
      }
      else {
        auth.Email = Fields.get('email');
      }

      auth.ShippingFirstName = Fields.get('first_name');
      auth.ShippingLastName  = Fields.get('last_name');

      other_data.add(new Map<String, String> { 'key' => 'Product', 'value' => Fields.get('product') });
      other_data.add(new Map<String, String> { 'key' => 'First Name', 'value' => Fields.get('first_name') });
      other_data.add(new Map<String, String> { 'key' => 'Last Name', 'value' => Fields.get('last_name') });
      other_data.add(new Map<String, String> { 'key' => 'Title', 'value' => Fields.get('title') });
      other_data.add(new Map<String, String> { 'key' => 'Agency', 'value' => Fields.get('agency') });
      other_data.add(new Map<String, String> { 'key' => 'Address 1', 'value' => Fields.get('address') });
      other_data.add(new Map<String, String> { 'key' => 'Address 2', 'value' => Fields.get('address2') });
      other_data.add(new Map<String, String> { 'key' => 'City', 'value' => Fields.get('city') });
      other_data.add(new Map<String, String> { 'key' => 'State', 'value' => Fields.get('state') });
      other_data.add(new Map<String, String> { 'key' => 'Zip', 'value' => zip });
      other_data.add(new Map<String, String> { 'key' => 'Phone', 'value' => Fields.get('phone') });
      other_data.add(new Map<String, String> { 'key' => 'Email', 'value' => Fields.get('email') });
      other_data.add(new Map<String, String> { 'key' => 'CC Number', 'value' => Fields.get('cc_number').substring(0, 4) });
      other_data.add(new Map<String, String> { 'key' => 'CC First Name', 'value' => Fields.get('cc_first_name') });
      other_data.add(new Map<String, String> { 'key' => 'CC Last Name', 'value' => Fields.get('cc_last_name') });
      other_data.add(new Map<String, String> { 'key' => 'CC Email', 'value' => Fields.get('cc_email') });
      other_data.add(new Map<String, String> { 'key' => 'CC Exp Month', 'value' => Fields.get('credit_card_exp_month') });
      other_data.add(new Map<String, String> { 'key' => 'CC Exp Year', 'value' => Fields.get('credit_card_exp_year') });
      other_data.add(new Map<String, String> { 'key' => 'CC Sec Code', 'value' => Fields.get('cc_sec_code') });
      other_data.add(new Map<String, String> { 'key' => 'Total', 'value' => Fields.get('hiddenTotal') });
      other_data.add(new Map<String, String> { 'key' => 'Cust ID', 'value' => Fields.get('cust_id') });
      other_data.add(new Map<String, String> { 'key' => 'Event Name', 'value' => Fields.get('event_name') });
      auth.OtherData = other_data;

      for(Event_Session__c session: Sessions) {
        String session_name = '';
        if(session.Display_Name__c != null && session.Display_Name__c.length() > 31) {
          session_name = session.Display_Name__c.substring(0, 31);
        }
        else {
          session_name = session.Display_Name__c;
        }

        receipt_descriptions.add(session_name);
        if(IsEarlyBird && session.Early_Bird_Fee__c != Null) {
          auth.AddItem(String.ValueOf(i), session_name, '', 1, session.Early_Bird_Fee__c, False);
        }
        else {
          auth.AddItem(String.ValueOf(i), session_name, '', 1, session.Reg_Fee__c, False);
        }

        other_data.add(new Map<String, String> { 'key' => 'Item ' + i + ': ', 'value' => session_name});
        i++;
      }

      Integer tmp_num = 0;
      auth.receiptDescription = Fields.get('event_name');
      
      auth.TotalAmount = Total;

      if(auth.Process() == false) {
        return handleError('Unable to process payment: ' + auth.ErrorMsg);
      }
      CardCharged = true;
      TransactionID = auth.TransactionID;
    }

    // Internal confirmaiton
    try {
      EmailTemplate template;
      if(IsSponsorshipForm == false){
        try{
          template = [SELECT Id FROM EmailTemplate Where DeveloperName = 'Event_Registration_Owner_Notification'];
        }
        catch(Exception e) {
          return HandleFatalError('Unable to retreive Registration email confirmation template. '+e.getMessage(), e);
        }
      }
      else {
        try{
          template = [SELECT Id FROM EmailTemplate Where DeveloperName = 'Event_Sponsor_Reg_Owner_Notification'];
        }
        catch(Exception e) {
          return HandleFatalError('Unable to retreive Sponsor Registration email confirmation template. '+e.getMessage(), e);
        }
      }

      Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
      
      String[] to_addresses = new String[] { RegCoordinator.Email };
      mail.setToAddresses( to_addresses );
      
      // String[] bccAddresses = new String[] {'nbockoven@erepublic.com'};
      // mail.setBccAddresses( bccAddresses );
      
      mail.setTemplateId(template.Id);

      mail.setTargetObjectId(RegCoordinator.Id);
      mail.setSaveAsActivity(false);
      Messaging.Email[] emails = new Messaging.Email[] {mail};
      Messaging.sendEmail(emails);
    }
    catch(System.Exception e) {
      System.debug('Error sending internal confirmation e-mail');
    }

    // insert contact
    Contact contact;
    try {
      Contact[] contacts = [Select Id From Contact Where Email = :Fields.get('email')];
      if(contacts.size() > 0) {
        contact = contacts.get(0);
      }
      else {
        contact = new Contact();
        try {
          Account[] accounts =[Select Id From Account Where Name = 'e.Republic - Subscriptions'];
          if(accounts.size() > 0) {
            contact.AccountId = accounts.get(0).Id;
          }
          else {
            return handleFatalError('Unable to retrieve subscription account');
          }
        }
        catch(Exception e2) {
          return handleFatalError('Unable to retrieve subscription account');
        }
      }
    }
    catch(System.QueryException e) {
      contact = new Contact();
      try {
        Account[] accounts =[Select Id From Account Where Name = 'e.Republic - Subscriptions'];
        if(accounts.size() > 0) {
          contact.AccountId = accounts.get(0).Id;
        }
        else {
          return handleFatalError('Unable to retrieve subscription account');
        }
      }
      catch(Exception e2) {
        return handleFatalError('Unable to retrieve subscription account');
      }
    }

    if(Fields.get('sector') == 'Public') {
      List<RecordType> types = [Select Id From RecordType Where Name = 'Public Sector' AND SObjectType = 'Contact'];
      contact.RecordTypeId = types.get(0).id;
    }
    else {
      List<RecordType> types = [Select Id From RecordType Where Name = 'Private Sector' AND SObjectType = 'Contact'];
      contact.RecordTypeId = types.get(0).Id;
    }

    contact.FirstName = Fields.get('first_name');
    contact.LastName = Fields.get('last_name');
    contact.Title = Fields.get('title');
    contact.Company_Name_Holder__c = Fields.get('company');
    contact.Department = Fields.get('division');
    contact.Phone = Fields.get('phone');
    contact.Phone_Extension__c = Fields.get('phone_ext');
    contact.Fax = Fields.get('fax');
    contact.Email = Fields.get('email');
    contact.MailingStreet = Fields.get('address') + '\n' + fields.get('address2');
    contact.MailingCity = Fields.get('city');
    contact.MailingState = Fields.get('state');
    contact.MailingCountry = Fields.get('country');
    contact.MailingPostalCode = zip;
    contact.Master_Agency_Dept_Function__c = Fields.get('agency_dept_function');
    contact.Master_Branch_Bus_Activity__c = Fields.get('branch_of_government');
    contact.Master_Job_Function__c = Fields.get('job_function');
    contact.Agency_Institution_Size__c = Fields.get('agency_size');
    contact.Contact_Bio__c = Fields.get('bio');

    try {
      if(contact.Id == null) {
        insert contact;
      }
      else {
        update contact;
      }
    }
    catch(System.DmlException e) {
      return HandleFatalError('Unable to create contact', e);
    }

    // insert survey
    Registration__c registration = new Registration__c();
    registration.Transaction_ID__c = TransactionID;

    if( Fields.get('attending_event') == 'PUBLIC' ) {
      registration.Reg_Type__c = 'Govt Attendee';
    }
    else if(Fields.get('attending_event') == 'SPONSOR') {
      registration.Reg_Type__c = 'Sponsor';
    }
    else {
      registration.Reg_Type__c = 'Industry Attendee';
      if( Event.Event_Custom_Prices__r.size() > 0 && Fields.get('attending_event').length() > 0 ){
        EventCustomPrice = [SELECT Reg_Type__c FROM Event_Custom_Price__c where Id = :Fields.get('attending_event')];
        if( EventCustomPrice != null ){
          if( EventCustomPrice.Reg_Type__c != null ){
            if( EventCustomPrice.Reg_Type__c.length() > 0 ){
              registration.Reg_Type__c = EventCustomPrice.Reg_Type__c;
            }
          }
        }
      }
    }

    registration.Reg_Source__c = 'O Online';

    if(Fields.get('optin') == 'true') {
      registration.Exclude_From_Mailing_List__c = true;
    }
    else {
      registration.Exclude_From_Mailing_List__c = false;
    }
    
    if( Fields.get('dietary_needs').trim().length() > 0 ){
      registration.Dietary_Needs__c = Fields.get('dietary_needs').substring(5);
    }
    
    if( Fields.get('questions_comments').trim().length() > 0 ){
      registration.Questions_or_Comments__c = Fields.get('questions_comments').trim();
    }
    
    if( Fields.containsKey('promo_code') ){
      registration.Promo_Code__c = Fields.get('promo_code').trim();
    }

    //title
    //company name
    registration.Reg_Date__c = date.Today();
    registration.Event__c = event.Id;
    registration.Registrant_Name__c = contact.Id;
    registration.Sponsor_Company__c = Fields.get('sponsor_company');

    // Collect payment info
    if( fields.get('payment_type') == 'cc' ){
      registration.Payment_Type__c = 'Credit Card';
      registration.Reg_Billing_First_Name__c = Fields.get('cc_first_name');
      registration.Reg_Billing_First_Name__c = Fields.get('cc_last_name');

      String cc_number = Fields.get('cc_number');
      if( cc_number.length() > 0 ){
        registration.CC_Number__c = cc_number.substring(cc_number.length() - 4, cc_number.length());
      }
      registration.CC_First_Name__c = fields.get('cc_first_name');
      registration.CC_Last_Name__c = fields.get('cc_last_name');
      registration.CC_Expiration_Date__c = fields.get('cc_exp_month') + '/' + fields.get('cc_exp_year');
      registration.CC_Email_Recipient__c = fields.get('cc_email');
    }
    else if( fields.get('payment_type') == 'po' ){
      registration.Payment_Type__c = 'Purchase Order';
      registration.PO_Number__c = fields.get('po_number');
    }
    else if( fields.get('payment_type') == 'billme' ){
      registration.Payment_Type__c = 'Bill Me';
      registration.Reg_Billing_First_Name__c = fields.get('billme_first_name');
      registration.Reg_Billing_Last_Name__c = fields.get('billme_last_name');
      registration.Reg_Billing_Address_1__c = fields.get('billme_address');
      registration.Reg_Billing_Address_2__c = fields.get('billme_address2');
      registration.Reg_Billing_Company_Name__c = fields.get('billme_company');
      registration.Reg_Billing_City__c = fields.get('billme_city');
      registration.Reg_Billing_State__c = fields.get('billme_state');
      registration.Reg_Billing_Country__c = fields.get('billme_country');
      registration.Reg_Billing_Zip_Code__c = fields.get('billme_zip').substring(0, 5);
      registration.Reg_Billing_Phone__c = fields.get('billme_phone');
      registration.Reg_Billing_Phone_Ext__c = fields.get('billme_phone_ext');
    }
    else if(fields.get('payment_type') != 'none' && Total > 0) {
      return HandleError('Invalid payment type');
    }

    try {
      insert registration;
    }
    catch(System.DmlException e) {
      return HandleFatalError('Unable to create registration: ' + e.getMessage());
    }

    if( Event.Event_Custom_Prices__r.size() > 0 ){
      if( fields.get('attending_event') != 'SPONSOR' ){
        Event_Custom_Price__c CustomPrice = [Select Name, Event__c, Fee__c From Event_Custom_Price__c WHERE Id = :Fields.get('attending_event') AND Event__c = :Fields.get('event_id')];
        Registration_Line_Item__c registration_item = new Registration_Line_Item__c(Name = CustomPrice.Name, Type__c = 'Event', Cost__c = CustomPrice.Fee__c, Registration__c = registration.Id, Event__c = event.Id);
        insert registration_item;
      }
    }
    else if( fields.get('attending_event') != 'NOT_ATTENDING' ){
      Registration_Line_Item__c registration_item = new Registration_Line_Item__c(Name = event.Display_Name__c, Type__c = 'Event', Cost__c = event_total, Registration__c = registration.Id, Event__c = event.Id);
      insert registration_item;
    }

    for(Event_Session__c session: Sessions) {
      if(IsEarlyBird && session.Early_Bird_Fee__c != Null) {
        Registration_Line_Item__c registration_item = new Registration_Line_Item__c(Name = session.Display_Name__c, Type__c = 'Session', Cost__c = session.Early_Bird_Fee__c, Registration__c = registration.Id, Session__c = session.Id);
        insert registration_item;
      }
      else {
        Registration_Line_Item__c registration_item = new Registration_Line_Item__c(Name = session.Display_Name__c, Type__c = 'Session', Cost__c = session.Reg_Fee__c, Registration__c = registration.Id, Session__c = session.Id);
        insert registration_item;
      }
    }

    if(CafeSessionCount > 0 && Fields.get('cafeSelect') != 'none'){
      CafeSessionSelected = [Select Id, Name, Display_Name__c, Session_Code__c, Reg_Fee__c, Early_Bird_Fee__c, Event__c, Description__c From Event_Session__c WHERE Reg_Open__c = True AND Session_Type__c = 'Cafe' AND Id = :Fields.get('cafeSelect')];
      for(Event_Session__c session: CafeSessionSelected) {
        if(IsEarlyBird && session.Early_Bird_Fee__c != Null) {
          //Registration_Line_Item__c registration_item2 = new Registration_Line_Item__c(Name = session.Display_Name__c, Type__c = 'Session', Cost__c = session.Early_Bird_Fee__c, Registration__c = registration.Id, Session__c = session.Id);
          Registration_Line_Item__c registration_item2 = new Registration_Line_Item__c(Name = session.Display_Name__c, Type__c = 'Cafe', Cost__c = session.Early_Bird_Fee__c, Registration__c = registration.Id, Session__c = Fields.get('cafeSelect'));
          insert registration_item2;
        }
        else {
          //Registration_Line_Item__c registration_item2 = new Registration_Line_Item__c(Name = session.Display_Name__c, Type__c = 'Session', Cost__c = session.Reg_Fee__c, Registration__c = registration.Id, Session__c = session.Id);
          Registration_Line_Item__c registration_item2 = new Registration_Line_Item__c(Name = session.Display_Name__c, Type__c = 'Cafe', Cost__c = event_total, Registration__c = registration.Id, Session__c = Fields.get('cafeSelect'));
          insert registration_item2;
        }
      }
    }

    if(IsSponsorshipForm == false){
      // Eloqua Sync
      Map<String, String> elqFields = new Map<String, String>();
      elqFields.put('elqFormName', ElqFormName);
      elqFields.put('elqSiteID', '1222');
      elqFields.put('event_root_title', Event.Display_Name__c);
      elqFields.put('first_name', Fields.get('first_name'));
      elqFields.put('last_name', Fields.get('last_name'));
      elqFields.put('title', Fields.get('title'));
      elqFields.put('organization', Fields.get('company'));
      elqFields.put('division', Fields.get('division'));
      elqFields.put('phone', Fields.get('phone'));
      elqFields.put('phone_extension', Fields.get('phone_extension'));
      elqFields.put('fax', Fields.get('fax'));
      elqFields.put('email1', Fields.get('email'));
      elqFields.put('address1', Fields.get('address'));
      elqFields.put('address2', Fields.get('address2'));
      elqFields.put('city', Fields.get('city'));
      elqFields.put('state', Fields.get('state'));
      elqFields.put('country', Fields.get('country'));
      elqFields.put('zip', zip);
      elqFields.put('gov_branch', Fields.get('branch_of_government'));
      elqFields.put('job_function', Fields.get('job_function'));      
      elqFields.put('demoJobRole', Fields.get('roles_of_job'));
      elqFields.put('agency_function', Fields.get('agency_dept_function'));
      elqFields.put('agency_size', Fields.get('agency_size'));
      elqFields.put('how_hear', Fields.get('how_hear'));
      if( Fields.get('promo_code').trim().length() > 0 ){
        elqFields.put('promo_code', Fields.get('promo_code').trim());
      }
      if( Fields.get('event_subscribe') == 'No' || Fields.get('event_subscribe') == '' ){
        elqFields.put('ext-comp-1038', '');
      }
      else{
        elqFields.put('ext-comp-1038', 'on');
      }
      elqFields.put('salesforce_id', Event.Id);
      elqFields.put('Sector', Fields.get('sector'));
      elqConnector.Process(elqFields);
    }

    if(IsSponsorshipForm == false){
      if(Event.Email_Confirmation_Template__c != null) {
        EmailTemplate tmpl = [SELECT IsActive FROM EmailTemplate WHERE id = :Event.Email_Confirmation_Template__c];

        if(tmpl.IsActive == true){
          Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
          mail.replyTo = RegCoordinator.Email;
          mail.senderDisplayName = RegCoordinator.Name;

          String[] to_addresses = new String[] { contact.Email };
          mail.setToAddresses(to_addresses);
          mail.setTargetObjectId(contact.Id);
          mail.setWhatId(registration.Id);
          mail.setTemplateId(Event.Email_Confirmation_Template__c);
          Messaging.sendEmail(new Messaging.Email[] { mail});
          registration.Confirmation_Sent__c = true;
        }
      }
    }
    update registration;

    SuccessMsg = 'Registration Complete';
    pageRef = new PageReference(SuccessURL);
    pageRef.setRedirect(true);

    return pageRef;
  }

  public PageReference HandleError(String error) {
    PageReference pageRef = Page.Event_Registration_Error;

    if(CardCharged == true) {
      try {
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        
        if( RegCoordinator != null ){
          String[] toAddresses = new String[] { RegCoordinator.Email };
          message.setToAddresses( toAddresses );
          // String[] bccAddresses = new String[] { 'nbockoven@erepublic.com' };          
          // message.setBccAddresses( bccAddresses );
        }
        else{
          String[] toAddresses = new String[] { 'web_dev@erepublic.com' };
          message.setToAddresses( toAddresses );
        }
        
        message.setSubject('Registration Error');
        message.setHTMLBody('The registration system has made a charge for a registration, but an error occurred while saving the registration.<br />Name: ' + Fields.get('first_name') + ' ' + Fields.get('last_name') + '<br />Event: ' + Event.Display_Name__c + '.<br /><br />The original registration data should have been sent in a separate e-mail.');
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { message });
      }
      catch(System.EmailException e) {
        // Do nothing.
      }

      if(error == ''){
        // Overwrite error with generic to keep error display clean
        error = 'Registration not complete. Do not resubmit registration.';
      }
    }

    pageRef.getParameters().put('error', error);
    if(Event != Null) {
      pageRef.getParameters().put('event_id', Event.Id);
    }
    pageRef.setRedirect(true);
    return pageRef;
  }

  public PageReference HandleFatalError(String error) {
    return HandleFatalerror(error, null);
  }

  public PageReference HandleFatalError(String error, Exception e) {
    String internal_error_message;
    if(e != null) {
      internal_error_message = 'Event: ' + Fields.get('event_id') + '<br />Error: ' + error + '<br />Details: ' + e.getMessage() + '<br/>Line: ' + e.getLineNumber() + '<br/>Type: ' + e.getTypeName() + '<br/>Cause: ' + e.getCause() + '<br/>Stack Trace: ' + e.getStackTraceString() + '<br/>Form Submission:<br/>';
      for( String fieldName : Fields.keySet() ){
        internal_error_message += '<br/> ' + fieldName + ' = ' + Fields.get( fieldName );
      }
    }
    else {
      internal_error_message = error;
    }

    Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
    String[] addresses = new String[] { 'web_dev@erepublic.com' };
    message.setToAddresses(addresses);
    message.setSubject('Registration Submission Error');
    message.setHTMLBody(internal_error_message);
    Messaging.sendEmail(new Messaging.SingleEmailMessage[] { message });

    return HandleError(error);
  }
  */
}

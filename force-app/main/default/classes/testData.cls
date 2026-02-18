/*
sample use:

REMEMBER: YOU HAVE TO BE ONEFORM_ADMIN TO RUN TESTS THAT TOUCH FINANCIAL_FORCE.

Contact c1 =  testData.createContact();
Contact c2 =  testData.createContact(false);  // will return the un-inserted object, if you want to set particular fields

go here to unlock all periods for the current year:
https://erepublic--michaels2.lightning.force.com/one/one.app#/sObject/a2v1O000005RMCVQA4/rlName/c2g__Periods__r/view
or run : testdata.openAllPeriods();
*/

@isTest(SeeAllData=true)
global class testData {
  // these are the type_ids for Events__c
  public static final Id RECORD_TYPE_EVENT = '01230000000ueuw';
  public static final Id RECORD_TYPE_CUSTOM_EVENT = '01230000000ueur';
  public static final Id RECORD_TYPE_WEBINAR = '01214000000AUym';
  public static final Id RECORD_TYPE_MARKETING_WEBINAR = '01214000000AVlo';

  // these are the type_ids for CONTRACTS
  public static final Id DELIVERY_CONTRACT = '01214000000AV7y';
  public static final Id LOCKED_DELIVERY_CONTRACT = '01214000001RYWe';
  public static final Id TECHWIRE_CONTRACT = '01214000000AUmM';
  public static final Id LOCKED_TECHWIRE_CONTRACT = '01214000001RYWt';
  public static final Id EVENT_CONTRACT = '012a0000001RKA9';
  public static final Id LOCKED_EVENT_CONTRACT = '01214000001RYWj';

  public static Id LastYearsdEventId = null; // this is used to set the Events__r.last_years_event__c   field
  public static Pricebook2 standardPricebook = null;

  static testMethod void testTestData() {
    FlowControl.setBypassFlows(true);
    Contact c = createContact();
    User u = createUser();
    Account a = createAccount();
    // Contract co = createContract(testData.EVENT_CONTRACT, a.Id);
    Paper__c p = createPaper('GT');
    Events__c e = createEventWithRegistrations();
    Opportunity o = createOpportunity();
    Product2 pr = createProduct();
    Agreement__c ag = createAgreement();
    Class__c cl = createClass();
    Class__c cl2 = createClassWithBrand('GOVERNING');
    Class_Reg__c st = createStudent(cl.Id);
    Events__c wb = createWebinar(true);
    Events__c ce = createCustomEvent(true);
    Publication__c pub = createPublication();
    Subscription__c sub = createSubscription(pub.Id);
    FlowControl.shouldBypassFlows();
    FlowControl.setBypassFlows(false);
    List<String> inputParams = new List<String>{ 'param1', 'param2' };
    List<BypassFlowController.BypassResult> results = BypassFlowController.checkBypassCondition(
      inputParams
    );
    System.assertEquals(1, results.size());
    System.assertEquals(false, results[0].shouldBypass);
  }

  public static void openAllPeriods() {
    List<c2g__codaPeriod__c> periods = new List<c2g__codaPeriod__c>();
    for (c2g__codaPeriod__c p : [
      SELECT Id, Name, c2g__Closed__c
      FROM c2g__codaPeriod__c
      WHERE Name LIKE '2018%'
    ]) {
      p.c2g__Closed__c = false;
      periods.add(p);
    }
    update periods;
  }

  public static Ticket__c createTicket() {
    String title = 'ticket ' + randomStr();
    Ticket__c t = new Ticket__c(Title__c = title);
    insert t;
    return t;
  }

  public static Contact createContact() {
    return createContact(true);
  }

  /* map with values for the contact
   */
  public static Contact createContact(boolean insertIt) {
    Account a = createAccount(true);
    String randomEmail = randomStr() + '_tester@test.com';
    Contact contact = new Contact(
      FirstName = 'Gerard T.',
      LastName = 'Tester',
      Email = randomEmail,
      AccountId = a.Id,
      MailingPostalCode = '95816',
      MailingState = 'CA',
      MailingCity = 'Folsom',
      EE_Tracking_Interested__c = 'CA',
      EE_Tracking_Past_Participant__c = 'CA',
      Last_Engaged_Class_Date__c = Date.today()
    );
    if (insertIt) {
      insert contact;
    }
    return contact;
  }

  public static Job_Role__c createRole(Contact c) {
    String randomEmail = randomStr() + '_tester_role@test.com';
    Job_Role__c role = new Job_Role__c(
      Job_Role_Title__c = 'job role title',
      Account__c = c.AccountId,
      Job_Role_Mailing_Zip_Code__c = '12345',
      Job_Role_Email__c = randomEmail,
      Contact__c = c.Id
    );
    insert role;
    return role;
  }

  public static Account createAccount() {
    return createAccount(true);
  }
  public static Account createAccount(boolean insertIt) {
    String randomName = randomStr() + '_account';
    Account a = new Account(
      Name = randomName,
      type = 'Customer',
      BillingPostalCode = '92345',
      BillingState = 'CA',
      BillingCity = 'Sacramento'
    );
    if (insertIt)
      insert a;
    return a;
  }

  public static User createUser() {
    String rnd = randomStr();
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard Sales Rep'];
    Account a = createAccount(true);
    String randomEmail = 'e' + rnd + '@test.com';
    String firstName = 'John';
    String lastName = 'Smith';
    Contact contact = new Contact(
      FirstName = firstName,
      LastName = lastName,
      Email = randomEmail,
      AccountId = a.Id,
      MailingPostalCode = '95816',
      MailingState = 'CA',
      MailingCity = 'Folsom'
    );
    User u = new User(
      Phone = '9169321300',
      alias = 'u1',
      Email = randomEmail,
      lastname = lastName,
      firstname = firstName,
      username = randomEmail,
      emailencodingkey = 'UTF-8',
      languagelocalekey = 'en_US',
      localesidkey = 'en_US',
      TimeZoneSidKey = 'America/Los_Angeles',
      ProfileId = p.Id,
      User_Contact_Id__c = contact.Id
    );
    insert u;
    return u;
  }

  public static Contract createContract(Id typeId, Id accountId) {
    String rnd = randomStr();
    User salesRep = createUser();
    Contact primaryContact = createContact();

    Contract c = new Contract(
      Name = 'Paid Event' + rnd,
      RecordTypeId = typeId,
      AccountId = accountId,
      Status = 'Draft',
      Sales_Rep_Contracts__c = salesRep.Id
    );
    insert c;

    insert new ContractContactRole(
      ContractId = c.Id,
      ContactId = primaryContact.Id,
      Role = 'Logistics',
      IsPrimary = true
    );

    return c;
  }

  public static Paper__c createPaper(String brand) {
    String rnd = randomStr();

    Paper__c p = new Paper__c(
      Name = brand + ' Paper' + rnd,
      Brand__c = brand,
      RecordTypeId = '01214000000AVly',
      Asset_Type__c = 'eRepublic Content'
    );
    insert p;
    return p;
  }

  public static Events__c createEvent(boolean insertIt) {
    String rnd = randomStr();

    User u = createUser();

    Events__c event = new Events__c(
      Name = 'Paid Event' + rnd,
      RecordTypeId = testData.RECORD_TYPE_EVENT,
      Brand__c = 'GOVERNING',
      Registration_Coordinator__c = u.Id,
      Display_Name__c = 'Paid Event_' + rnd,
      OwnerId = u.Id,
      Public_Reg_Fee__c = 200,
      Event_Start_Date__c = date.Today(),
      Event_End_Date__c = date.Today(),
      Banner_URL__c = 'http://www.test.com',
      Web_Status__c = 'live',
      Venue_State__c = 'CA'
    );

    // if we are creating more than 1 event, the last_years_event__c will be set
    if (LastYearsdEventId != null)
      event.last_years_event__c = LastYearsdEventId;

    if (insertIt) {
      insert event;
      LastYearsdEventId = event.Id;
    }
    return event;
  }

  public static Events__c createWebinar(boolean insertIt) {
    String rnd = randomStr();

    User u = createUser();

    Events__c event = new Events__c(
      Name = 'Webinar' + rnd,
      RecordTypeId = testData.RECORD_TYPE_WEBINAR,
      Brand__c = 'GOVERNING',
      Registration_Coordinator__c = u.Id,
      Display_Name__c = 'Webinar_' + rnd,
      OwnerId = u.Id,
      Public_Reg_Fee__c = 200,
      Event_Start_Date__c = date.Today(),
      Event_End_Date__c = date.Today(),
      Banner_URL__c = 'http://www.test.com',
      Web_Status__c = 'live',
      Venue_State__c = 'CA'
    );

    // if we are creating more than 1 event, the last_years_event__c will be set
    if (LastYearsdEventId != null)
      event.last_years_event__c = LastYearsdEventId;

    if (insertIt) {
      insert event;
      LastYearsdEventId = event.Id;
    }
    return event;
  }

  public static Events__c createCustomEvent(boolean insertIt) {
    String rnd = randomStr();

    User u = createUser();

    Events__c event = new Events__c(
      Name = 'Custom Event' + rnd,
      RecordTypeId = testData.RECORD_TYPE_CUSTOM_EVENT,
      Brand__c = 'GOVERNING',
      Registration_Coordinator__c = u.Id,
      Display_Name__c = 'Custom Event_' + rnd,
      OwnerId = u.Id,
      Public_Reg_Fee__c = 200,
      Event_Start_Date__c = date.Today(),
      Event_End_Date__c = date.Today(),
      Banner_URL__c = 'http://www.test.com',
      Web_Status__c = 'live',
      Venue_State__c = 'CA'
    );

    // if we are creating more than 1 event, the last_years_event__c will be set
    if (LastYearsdEventId != null)
      event.last_years_event__c = LastYearsdEventId;

    if (insertIt) {
      insert event;
      LastYearsdEventId = event.Id;
    }
    return event;
  }

  public static Events__c createEventWithRegistrations() {
    Events__c event = createEvent(true);

    // INDUSTRY / AD BOARD PROCESS
    // 'Govt Attendee' type
    Contact contact = createContact();

    // 'Industry' -- 'Advisory Board' type
    Contact contact2 = createContact(false);
    contact2.AB_First_Name__c = 'joe';
    contact2.AB_Last_Name__c = 'Tester2';
    contact2.AB_Type__c = 'Government';
    contact2.AB_Title__c = 'Mayor';
    contact2.AB_Organization__c = 'Sacramento city';
    contact2.AB_Email__c = 't232334@widgetsinc.com';
    contact2.AB_Department__c = 'office of the CEO';
    contact2.AB_Organization__c = 'Fancy Widgets Inc.';
    insert contact2;

    // 'Advisory Board' type
    Contact contact3 = createContact(false);
    contact3.AB_First_Name__c = 'joe';
    contact3.AB_Last_Name__c = 'Tester3';
    contact3.AB_Type__c = 'Industry';
    contact3.AB_Title__c = 'CEO';
    contact3.AB_Organization__c = 'Fancy Widgets Inc.';
    contact3.AB_Email__c = 'e34343@widgetsinc.com';
    contact3.AB_Department__c = 'office of the CEO';
    contact3.AB_Organization__c = 'Fancy Widgets Inc.';
    insert contact3;

    Registration__c reg = new Registration__c(
      Registrant_Name__c = contact.Id,
      Event__c = event.Id,
      Reg_Type__c = 'Govt Attendee',
      Reg_Date__c = date.Today(),
      Reg_Source__c = 'O Online',
      Temporary_Id__c = '_T1234567890AB'
    );
    insert reg;

    Registration__c reg2 = new Registration__c(
      Registrant_Name__c = contact2.Id,
      Event__c = event.Id,
      Reg_Type__c = 'Industry Attendee',
      Reg_Date__c = date.Today(),
      Reg_Source__c = 'O Online',
      Temporary_Id__c = '_T1234567888CC'
    );
    insert reg2;

    Advisory_Board_Member__c a1 = new Advisory_Board_Member__c(
      Event__c = event.Id,
      Contact__c = contact2.Id
    );
    insert a1;

    Advisory_Board_Member__c a2 = new Advisory_Board_Member__c(
      Event__c = event.Id,
      Contact__c = contact3.Id
    );
    insert a2;

    // add a product
    Id glId = [
      SELECT Id
      FROM c2g__codaGeneralLedgerAccount__c
      ORDER BY CreatedDate DESC
      LIMIT 1
    ]
    .Id;
    Product2 p = new Product2(
      Sponsorship__c = 'Attendee',
      EE_Event__c = event.Id,
      Name = 'Attendee product'
    );
    p.c2g__CODASalesRevenueAccount__c = glId;
    p.IsActive = true;
    insert p;

    // SPONSOR PROCESS
    // 'Sponsor' type
    Contact contact4 = createContact();

    // create account for sponsorship
    Account acc = testData.createAccount(true);

    // create a contract for sponsorship
    Contract ct = createContract('012a0000001RKA9', acc.Id);
    ct.Event_Passes__c = 4;
    ct.Sponsorship_Name__c = 'Test Sponsor';
    ct.Event__c = event.Id;
    update ct;

    // create a registration for the sponsor attendee tied to the contract
    Registration__c reg3 = new Registration__c(
      Registrant_Name__c = contact4.Id,
      Event__c = event.Id,
      Reg_Type__c = 'Sponsor',
      Reg_Date__c = date.Today(),
      Reg_Source__c = 'O Online',
      Sponsor_Company__c = 'Test Sponsor'
    );
    insert reg3;

    return event;
  }

  public class Retvals {
    public Retvals(Opportunity o, OpportunityLineItem li) {
      opportunity = o;
      lineItem = li;
    }
    public Opportunity opportunity;
    public OpportunityLineItem lineItem;
  }

  /// creates opportunity with a lineItem containing an event
  public static Opportunity createOpportunity() {
    Account account = createAccount(true);
    Retvals ret = createOpportunityForAccount(account.Id, 5);
    return ret.opportunity;
  }
  // for any test that needs to create invoices, use a real account like Pretend Computer Company: 001a000001JVDnXAAX that has fferpcore__IsBillingAddressValidated__c set
  public static Retvals createOpportunityForAccount(
    ID accountId,
    Integer numLineItems
  ) {
    Contact c = createContact(true);
    User owner = createUser();

    // Account a2 = createAccount(true);  //Ssince there is a new validation rule for billing the Bill_To__c has to have fferpcore__IsBillingAddressValidated__c set so use a real account

    Opportunity o = new Opportunity(
      OwnerId = owner.Id,
      Primary_Contact__c = c.Id,
      AccountId = accountId,
      Bill_To__c = accountId, //bill_to_id,
      CloseDate = Date.today(),
      Name = 'michael test opportunity',
      StageName = 'Verbal'
    );
    insert o;
    System.assert(o != null);

    Events__c event = createEvent(true);

    Product2 p;
    PricebookEntry pbe;
    OpportunityLineItem li;
    List<String> sponsorships = new List<String>{
      'Patron Sponsor',
      'Main Sponsor',
      'small sponsor',
      'table sponsor',
      'banner sponsor'
    };

    for (Integer i = 0; i < numLineItems; i++) {
      p = createProduct4Event(event.Id, sponsorships[i]);
      pbe = createPriceBookEntry(p.Id);
      li = new OpportunityLineItem(
        OpportunityId = o.Id,
        PricebookEntryId = pbe.Id,
        Quantity = 1,
        TotalPrice = 500.00
      );
      insert li;
      System.assert(li != null);
    }

    return new Retvals(o, li);
  }

  public static PricebookEntry createPriceBookEntry(ID productId) {
    if (standardPricebook == null)
      standardPricebook = [
        SELECT Id
        FROM Pricebook2
        WHERE Name = 'Standard Price Book'
        LIMIT 1
      ];

    PricebookEntry pbe = new PricebookEntry(
      Pricebook2Id = standardPricebook.Id,
      Product2Id = productId,
      UnitPrice = 500.00,
      IsActive = true
    );
    insert pbe;
    System.assert(pbe != null);
    return pbe;
  }

  public static Product2 createProduct() {
    Events__c e = createEvent(true);
    return createProduct4Event(e.Id, 'Patron Sponsor');
  }

  public static Product2 createProduct4Event(ID eventID, String sponsorship) {
    Id glId = [
      SELECT Id
      FROM c2g__codaGeneralLedgerAccount__c
      ORDER BY CreatedDate DESC
      LIMIT 1
    ]
    .Id;
    Product2 p = new Product2(
      Name = 'test product ' + randomStr(),
      Product_Type__c = 'Events',
      Event_Type__c = 'GOV',
      EE_Event__c = eventID,
      CanUseQuantitySchedule = true,
      CanUseRevenueSchedule = true,
      //Product_Platform__c = 'product platform',
      Sponsorship__c = sponsorship,
      Event_Passes__c = 5,
      c2g__CODASalesRevenueAccount__c = glId,
      IsActive = true
    );
    insert p;
    System.assert(p != null);
    return p;
  }

  public static Agreement__c createAgreement() {
    Contact c = createContact();
    User rep = createUser();
    User admin = createUser();
    Agreement__c a = new Agreement__c(
      Main_Contact__c = c.Id,
      Account__c = c.Account.Id,
      Sales_Rep__c = rep.Id,
      Sales_Admin__c = admin.id,
      Description__c = 'test agreement description',
      Status__c = 'Draft',
      Amount__c = 3000
    );

    insert a;
    System.assert(a != null);
    attachFile(a.Id);
    return a;
  }

  //'Test Campaign 1', ' Campaign_GT_GovTech_Navigator__c'
  public static Campaign createCampaign(String cname, String x) {
    Campaign c = new Campaign(
      Name = cname,
      Contact_Campaign_API_Reference__c = x
    );
    insert c;
    return c;
  }

  /*
    public static void addAttachment(Id parentId){
        Blob b =  Blob.valueOf( 'Hi, how are you today?  I am the body of the test attachment'); 
        Attachment a = new Attachment(
        	Name='test attachment.pdf',
            ParentId = parentId,
            Body = b
        );
        insert a;       
        return;
    }
    */
  public static void attachFile(Id parentId) {
    Blob b = Blob.valueOf(
      'Hi, how are you today?  I am the body of the test attachment'
    );
    ContentVersion cv = new ContentVersion(
      //ContentLocation = 'S',
      //ContentDocumentId = NULL,
      FirstPublishLocationId = parentId,
      VersionData = Blob.valueof('this is a test'),
      Title = 'Test Attached File',
      PathOnClient = 'test_attached_file.pdf'
    );
    insert cv;
    /* 
        ContentVersion cv2 = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = : cv.Id LIMIT 1];
        insert new ContentDocumentLink(ContentDocumentId = cv2.ContentDocumentId, 
                                       LinkedEntityId    = parentId ,
                                       ShareType 		 = 'I' );   
*/
  }

  //=================================================================================================

  public static String randomStr() {
    final String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz';
    String randStr = '';
    while (randStr.length() < 4) {
      Integer idx = Math.mod(
        Math.abs(Crypto.getRandomInteger()),
        chars.length()
      );
      randStr += chars.substring(idx, idx + 1);
    }
    return randStr;
  }

  // returns after a delay
  public static void delay(Integer ms) {
    Integer start = System.Now().millisecond();
    while (System.Now().millisecond() < start + ms) {
    }
  }

  public static Class__c createClass() {
    Class__c cl1 = new Class__c(
      Name__c = 'Test Insert Class',
      Lead_Guarantee__c = 100
    );
    insert cl1;
    Class_Session__c cs1 = new Class_Session__c(
      Name__c = 'Test Session 1',
      Video_URL__c = 'https://vimeo.com/148751763',
      Order__c = 1,
      Class__c = cl1.Id
    );
    insert cs1;
    Class_Session__c cs2 = new Class_Session__c(
      Name__c = 'Test Session 2',
      Video_URL__c = 'https://vimeo.com/377312118',
      Order__c = 2,
      Class__c = cl1.Id
    );
    insert cs2;
    return cl1;
  }

  public static Class__c createClassWithBrand(String brand) {
    Class__c cl = createClass();
    cl.Brand__c = brand;
    update cl;
    return cl;
  }

  public static Class_Reg__c createStudent(Id classId) {
    Contact ct = createContact(true);
    Class_Reg__c st = new Class_Reg__c(
      Class__c = classId,
      Email__c = ct.Email,
      Name__c = ct.FirstName + ' ' + ct.LastName,
      Contact__c = ct.Id
    );
    insert st;
    return st;
  }

  public static Publication__c createPublication() {
    Publication__c pub = new Publication__c(
      Name = 'Governing Technology',
      Audit_Cycle_Date__c = Date.today()
    );
    insert pub;
    return pub;
  }

  public static Subscription__c createSubscription(Id publication_id) {
    Contact ct = createContact(true);
    Subscription__c sub = new Subscription__c(
      Batch__c = '',
      Cancellation_Reason__c = '',
      PIQ__c = '',
      Promo_Code__c = '1401WEB',
      Publication__c = publication_id, // GT
      Qual__c = 'Requestor',
      Qual_Date__c = Date.today(),
      Source__c = '1C',
      Status__c = 'Active',
      Subscriber__c = ct.Id,
      Version__c = 'Print'
    );
    insert sub;
    return sub;
  }
}

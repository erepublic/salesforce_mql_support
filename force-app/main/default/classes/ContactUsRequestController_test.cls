@isTest
public class ContactUsRequestController_test {
  public static testMethod void testContactUsReqController() {
    ContactUsRequestController testCtrl = new ContactUsRequestController();
    List<selectOption> requestTopics = testCtrl.getRequestTopic();
    System.assert(requestTopics.size() > 1);

    List<selectOption> requestTopic = testCtrl.getRequestTopic();
    System.assert(requestTopic.size() > 1);

    Contact_Us__c pr = testCtrl.getTheContactRequest();

    // Instantiate a new controller with all parameters in the page
    ContactUsRequestController ctrl = makeContactRequest(
      new ContactUsRequestController()
    );
    PageReference res = ctrl.submit();

    // Verify that the success page displays
    System.assertEquals('/apex/ContactUsRequest?s=1', res.getUrl());

    Contact_Us__c pr_res = [
      SELECT
        First_Name__c,
        Last_Name__c,
        Phone__c,
        Email__c,
        Organization__c,
        Topic__c,
        Message__c
      FROM Contact_Us__c
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];

    System.assertEquals('Joe', pr_res.First_Name__c);
    System.assertEquals('McTesterson', pr_res.Last_Name__c);
    System.assertEquals('(999) 999-9999', pr_res.Phone__c);
    System.assertEquals('j.mctest@gmail.net', pr_res.Email__c);
    System.assertEquals('Testsers Inc.', pr_res.Organization__c);
    System.assertEquals('Events', pr_res.Topic__c);
    System.assertEquals('Hey, I\'d like to buy stuff!', pr_res.Message__c);
  }

  private static ContactUsRequestController makeContactRequest(
    ContactUsRequestController ctrl
  ) {
    ctrl.First_Name = 'Joe';
    ctrl.Last_Name = 'McTesterson';
    ctrl.Phone = '(999) 999-9999';
    ctrl.Email = 'j.mctest@gmail.net';
    ctrl.Organization = 'Testsers Inc.';
    ctrl.RTopic = 'Events';
    ctrl.Message = 'Hey, I\'d like to buy stuff!';
    return ctrl;
  }
}

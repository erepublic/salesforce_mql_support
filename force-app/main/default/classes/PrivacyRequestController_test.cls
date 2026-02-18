@isTest
public class PrivacyRequestController_test {
  public static testMethod void testPrivacyReqController() {
    PrivacyRequestController testCtrl = new PrivacyRequestController();
    List<selectOption> stateOpts = testCtrl.getStateOptions();
    System.assertEquals(stateOpts.size(), 77);

    List<selectOption> requestType = testCtrl.getRequestType();
    System.assert(requestType.size() > 1);

    Privacy_Request__c pr = testCtrl.getThePrivacyRequest();
    Test.startTest();
    Test.setMock(HttpCalloutMock.class, new MockCaptchaValidation(true)); // Pass the expected validation result
    // Instantiate a new controller with all parameters in the page
    PrivacyRequestController ctrl = makePrivacyRequest(
      new PrivacyRequestController()
    );
    ApexPages.currentPage().getParameters().put('TimeSpent', '20.0');
    PageReference res = ctrl.submit();
    Test.stopTest();

    // Verify that the success page displays
    //System.assertEquals('/apex/PrivacyRequest?s=1', res.getUrl());

    Privacy_Request__c pr_res = [
      SELECT
        First_Name__c,
        Last_Name__c,
        Phone__c,
        Email__c,
        Organization__c,
        Address_Line_1__c,
        Address_Line_2__c,
        City__c,
        State__c,
        Zip__c,
        Comments__c
      FROM Privacy_Request__c
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];

    System.assertEquals('Joe', pr_res.First_Name__c);
    System.assertEquals('McTesterson', pr_res.Last_Name__c);
    System.assertEquals('(999) 999-9999', pr_res.Phone__c);
    System.assertEquals('j.mctest@gmail.net', pr_res.Email__c);
    System.assertEquals('Testsers Inc.', pr_res.Organization__c);
    System.assertEquals('100 Blue Ravine Rd.', pr_res.Address_Line_1__c);
    System.assertEquals(null, pr_res.Address_Line_2__c);
    System.assertEquals('Folsom', pr_res.City__c);
    System.assertEquals('CA', pr_res.State__c);
    System.assertEquals('95630', pr_res.Zip__c);
    System.assertEquals('Please Dont Sell!', pr_res.Comments__c);
  }

  private static PrivacyRequestController makePrivacyRequest(
    PrivacyRequestController ctrl
  ) {
    ctrl.First_Name = 'Joe';
    ctrl.Last_Name = 'McTesterson';
    ctrl.Phone = '(999) 999-9999';
    ctrl.Email = 'j.mctest@gmail.net';
    ctrl.Organization = 'Testsers Inc.';
    ctrl.Address_Line_1 = '100 Blue Ravine Rd.';
    ctrl.Address_Line_2 = '';
    ctrl.City = 'Folsom';
    ctrl.State = 'CA';
    ctrl.Zip = '95630';
    ctrl.Comments = 'Please Dont Sell!';
    ctrl.recaptchaToken = 'valid_recaptcha_token';
    ctrl.isChecked = true;
    return ctrl;
  }
}

public with sharing class contact_buttons_apexcontroller {
  @AuraEnabled
  public static integer remove_optouts() {
    List<Contact> contacts = new List<Contact>();
    for (Contact c : [
      SELECT Id, Email, HasOptedOutOfEmail, Email_Opt_Out_Removal_Needed__c
      FROM Contact
      WHERE Email_Opt_Out_Removal_Needed__c = TRUE
      LIMIT 50
    ]) {
      c.HasOptedOutOfEmail = false;
      c.Email_Opt_Out_Removal_Needed__c = false;
      contacts.add(c);
      makeTheCall(c.Id, c.Email);
    }
    update contacts;
    return contacts.size();
  }

  @future(callout=true) // runs asynchronously
  private static void makeTheCall(String id, String email) {
    String url =
      'http://marketing.erepublic.com/acton/eform/16245/0040/d-ext-0001?Email=' +
      email +
      '&Salesforce%20Contact%20Id=' +
      id;
    //System.Debug(url);
    Http http = new Http();
    HttpRequest req = new HttpRequest();
    req.setMethod('GET');

    req.setEndpoint(url);

    if (!test.isrunningTest()) {
      try {
        HTTPResponse res = http.send(req);
        System.Debug(res.getBody());
      } catch (Exception e) {
        System.Debug('something went wrong during outcall');
      }
    } else
      System.Debug('this is a test so no outcall');
  }
}

global class navConnector {
  @future(callout=true) // runs asynchronously
  public static void makeTheCall(String rectype, String id, String method) {
    String url = 'https://www.governmentnavigator.com/api/salesforce/';
    Http http = new Http();
    HttpRequest req = new HttpRequest();
    req.setMethod('GET');

    url = url + '?rectype=' + rectype + '&ids=' + id + '&method=' + method;
    req.setEndpoint(url);

    if (!Test.isRunningTest()) {
      // can't do a callout during a test
      HTTPResponse res = http.send(req);
    }
  }
} // navConnector

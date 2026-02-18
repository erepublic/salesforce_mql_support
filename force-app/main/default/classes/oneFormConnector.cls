global class oneFormConnector {
  //@future (callout=true)   // runs asynchronously
  public static void makeTheCall(String ids, String method) {
    makeTheCall(ids, method, '');
  }

  @future(callout=true) // runs asynchronously
  public static void makeTheCall(String ids, String method, String extra) {
    String url =
      'https://cms.erepublic.com/common/queue/add?interface=salesforce&method=' +
      method +
      '&salesforce_id=' +
      ids +
      extra;
    System.debug(url);
    Http http = new Http();
    HttpRequest req = new HttpRequest();
    req.setMethod('GET');

    req.setEndpoint(url);

    if (!test.isrunningTest())
      HTTPResponse res = http.send(req);
  }
}

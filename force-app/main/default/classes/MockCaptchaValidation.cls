public class MockCaptchaValidation implements HttpCalloutMock {
  private Boolean isValid;

  public MockCaptchaValidation(Boolean isValid) {
    this.isValid = isValid;
  }

  public HttpResponse respond(HttpRequest req) {
    HttpResponse res = new HttpResponse();
    res.setStatusCode(200);
    res.setBody('{"success": ' + String.valueOf(isValid) + '}');
    return res;
  }
}

public class MqlSecrets {
  // Centralize org-level secrets so they never live in Git.
  private static MqlSecrets__c cached;

  private static MqlSecrets__c orgDefaults() {
    if (cached == null) {
      try {
        cached = MqlSecrets__c.getOrgDefaults();
      } catch (Exception e) {
        // Custom setting not deployed yet.
        cached = null;
      }
    }
    return cached;
  }

  public static String getApiGatewayApiKey() {
    MqlSecrets__c s = orgDefaults();
    return s == null ? null : s.ApiGatewayApiKey__c;
  }

  public static String getHubspotPrivateAppToken() {
    MqlSecrets__c s = orgDefaults();
    return s == null ? null : s.HubspotPrivateAppToken__c;
  }

  public static String getRecaptchaSecretKey() {
    MqlSecrets__c s = orgDefaults();
    return s == null ? null : s.RecaptchaSecretKey__c;
  }
}

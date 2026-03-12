public class MqlSummarizerCallout {
  // API Gateway base URLs (fallback if CMDT not present).
  private static final String SANDBOX_BASE_URL = 'https://ur090e3441.execute-api.us-west-1.amazonaws.com';
  private static final String PRODUCTION_BASE_URL = 'https://3fncen6rdd.execute-api.us-west-1.amazonaws.com';

  // Reuse the existing endpoint CMDT to avoid ticket-specific behavior while
  // still sourcing the base URL + API key from metadata.
  // (We can rename/generalize the CMDT later without changing callout logic.)
  private class EndpointConfig {
    public String baseUrl;
  }

  private static String getEnvironment() {
    try {
      Organization org = [SELECT IsSandbox FROM Organization LIMIT 1];
      return org.IsSandbox ? 'sandbox' : 'production';
    } catch (Exception e) {
      return 'production';
    }
  }

  private static EndpointConfig loadEndpointConfig(String environment) {
    EndpointConfig cfg = new EndpointConfig();
    try {
      List<TicketSummarizerEndpoint__mdt> rows = [
        SELECT BaseUrl__c
        FROM TicketSummarizerEndpoint__mdt
        WHERE Environment__c = :environment
        LIMIT 1
      ];
      if (!rows.isEmpty()) {
        cfg.baseUrl = rows[0].BaseUrl__c;
      }
    } catch (Exception e) {
      // If the CMDT isn't available in this org, fall back to hardcoded defaults.
    }
    return cfg;
  }

  private static String getEndpointUrl(String environment) {
    EndpointConfig cfg = loadEndpointConfig(environment);
    String baseUrl = String.isNotBlank(cfg.baseUrl)
      ? cfg.baseUrl
      : ((environment == 'production')
          ? PRODUCTION_BASE_URL
          : SANDBOX_BASE_URL);
    return baseUrl + '/' + environment + '/summarize';
  }

  @future(callout=true)
  public static void triggerSummarization(Set<Id> mqlIds) {
    if (mqlIds == null || mqlIds.isEmpty())
      return;

    for (Id mqlId : mqlIds) {
      try {
        makeCalloutAndEnqueueSummary(mqlId, false);
      } catch (Exception e) {
        System.debug(
          'MQL_SUMMARIZER_ERROR: MQL=' + mqlId + ', Error=' + e.getMessage()
        );
      }
    }
  }

  // On-demand / manual regeneration. This is intentionally separate from the
  // trigger path so we never overwrite summaries automatically.
  @future(callout=true)
  public static void triggerSummarizationForce(Set<Id> mqlIds) {
    if (mqlIds == null || mqlIds.isEmpty())
      return;

    for (Id mqlId : mqlIds) {
      try {
        makeCalloutAndEnqueueSummary(mqlId, true);
      } catch (Exception e) {
        System.debug(
          'MQL_SUMMARIZER_FORCE_ERROR: MQL=' +
            mqlId +
            ', Error=' +
            e.getMessage()
        );
      }
    }
  }

  // Enqueue-only callout. Lambda does the heavy work asynchronously and writes
  // back to Salesforce once complete.
  private static void makeCalloutAndEnqueueSummary(
    Id mqlId,
    Boolean forceOverwrite
  ) {
    // Query inside the async context to ensure we see final flow-updated values.
    MQL__c mql = [
      SELECT Id, Contact__c, Lead_Source__c, Engagement_AI_Summary__c
      FROM MQL__c
      WHERE Id = :mqlId
      LIMIT 1
    ];

    // Automatic path: summarize any newly created MQL that still has a blank
    // summary so non-threshold records do not inherit stale Contact text.
    // Manual/force path: allow any MQL so we can test prompt tweaks on demand.

    // Don't overwrite existing summaries automatically.
    if (!forceOverwrite && String.isNotBlank(mql.Engagement_AI_Summary__c))
      return;

    String environment = getEnvironment();

    HttpRequest request = new HttpRequest();
    request.setEndpoint(getEndpointUrl(environment));
    request.setMethod('POST');
    request.setHeader('Content-Type', 'application/json');

    // API Gateway requires x-api-key when api_key_required = true.
    String apiKey = MqlSecrets.getApiGatewayApiKey();
    if (String.isNotBlank(apiKey)) {
      request.setHeader('x-api-key', apiKey);
    }

    Map<String, Object> requestBody = new Map<String, Object>{
      'mqlId' => mql.Id,
      'contactId' => mql.Contact__c,
      'environment' => environment
    };
    request.setBody(JSON.serialize(requestBody));
    // Keep this call short. Long-running summary work now happens async in Lambda.
    request.setTimeout(15000);

    Http http = new Http();
    HttpResponse response = http.send(request);

    Integer statusCode = response.getStatusCode();
    if (statusCode != 200 && statusCode != 202) {
      throw new CalloutException(
        'Failed to enqueue MQL summarization. Status=' +
          statusCode +
          ', Body=' +
          response.getBody()
      );
    }
  }
}

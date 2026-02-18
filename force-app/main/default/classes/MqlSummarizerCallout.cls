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
        makeCalloutAndWriteSummary(mqlId, false);
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
        makeCalloutAndWriteSummary(mqlId, true);
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

  private static void makeCalloutAndWriteSummary(
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

    // Automatic path: per spec, only run for threshold-triggered MQLs.
    // Manual/force path: allow any MQL so we can test prompt tweaks on demand.
    if (
      !forceOverwrite &&
      mql.Lead_Source__c != 'Fit and Behavior Threshold Reached'
    )
      return;

    // Don't overwrite existing summaries (flows may map Contact summary on creation).
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
    request.setTimeout(60000);

    Http http = new Http();
    HttpResponse response = http.send(request);

    if (response.getStatusCode() != 200) {
      throw new CalloutException(
        'Failed to summarize MQL. Status=' +
          response.getStatusCode() +
          ', Body=' +
          response.getBody()
      );
    }

    String summaryHtml = null;
    try {
      Object parsed = JSON.deserializeUntyped(response.getBody());
      if (parsed instanceof Map<String, Object>) {
        Map<String, Object> mapParsed = (Map<String, Object>) parsed;
        if (
          mapParsed.containsKey('summaryHtml') &&
          mapParsed.get('summaryHtml') instanceof String
        ) {
          summaryHtml = (String) mapParsed.get('summaryHtml');
        } else if (
          mapParsed.containsKey('summary') &&
          mapParsed.get('summary') instanceof String
        ) {
          summaryHtml = (String) mapParsed.get('summary');
        }
      }
    } catch (Exception e) {
      // If response isn't JSON (or doesn't have summary fields), fall back to the raw body.
    }
    if (String.isBlank(summaryHtml)) {
      summaryHtml = response.getBody();
    }

    update new MQL__c(Id = mql.Id, Engagement_AI_Summary__c = summaryHtml);
  }
}

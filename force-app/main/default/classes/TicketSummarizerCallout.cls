public class TicketSummarizerCallout {
  // Environment-specific API Gateway URLs
  private static final String SANDBOX_BASE_URL = 'https://ur090e3441.execute-api.us-west-1.amazonaws.com';
  private static final String PRODUCTION_BASE_URL = 'https://3fncen6rdd.execute-api.us-west-1.amazonaws.com';

  @TestVisible
  private static String testEnvironmentOverride;

  private class EndpointConfig {
    public String baseUrl;
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
      // Fallback to hardcoded defaults if the CMDT isn't deployed yet.
    }
    return cfg;
  }

  // Detect environment based on org domain
  private static String getEnvironment() {
    try {
      if (Test.isRunningTest() && String.isNotBlank(testEnvironmentOverride)) {
        return testEnvironmentOverride;
      }

      // Try multiple methods to detect sandbox
      String orgDomain = DomainCreator.getOrgMyDomainHostname();
      System.debug('Org domain: ' + orgDomain);

      if (orgDomain != null && orgDomain.contains('sandbox')) {
        System.debug(
          'Environment detected as: sandbox (domain contains sandbox)'
        );
        return 'sandbox';
      }

      // Alternative: Check the current URL
      String currentUrl = URL.getCurrentRequestUrl().toExternalForm();
      System.debug('Current URL: ' + currentUrl);

      if (currentUrl != null && currentUrl.contains('sandbox')) {
        System.debug('Environment detected as: sandbox (URL contains sandbox)');
        return 'sandbox';
      }

      // Alternative: Check organization info
      Organization org = [SELECT IsSandbox FROM Organization LIMIT 1];
      if (org.IsSandbox) {
        System.debug(
          'Environment detected as: sandbox (Organization.IsSandbox = true)'
        );
        return 'sandbox';
      }

      System.debug('Environment detected as: production');
      return 'production';
    } catch (Exception e) {
      System.debug('Error in environment detection: ' + e.getMessage());
      // Default to production if detection fails
      return 'production';
    }
  }

  // Get environment-specific endpoint URL
  private static String getEndpointUrl() {
    String environment = getEnvironment();

    EndpointConfig cfg = loadEndpointConfig(environment);
    String baseUrl = String.isNotBlank(cfg.baseUrl)
      ? cfg.baseUrl
      : ((environment == 'production')
          ? PRODUCTION_BASE_URL
          : SANDBOX_BASE_URL);
    return baseUrl + '/' + environment + '/summarize';
  }

  @future(callout=true)
  public static void triggerSummarization(Set<Id> ticketIds) {
    for (Id ticketId : ticketIds) {
      try {
        makeCallout(ticketId);
      } catch (Exception e) {
        System.debug(
          'Error calling summarizer for ticket ' +
            ticketId +
            ': ' +
            e.getMessage()
        );
        // Log error for monitoring
        logError(ticketId, e.getMessage());
      }
    }
  }

  @future(callout=true)
  public static void triggerSummarizationWithDelay(Set<Id> ticketIds) {
    // Add a 5-second delay to ensure chatter data is fully committed
    try {
      // Note: In a real implementation, you might want to use a Queueable job
      // or scheduled job for better delay control. Future methods don't support delays.
      System.debug(
        'Processing chatter-triggered summarization for tickets: ' + ticketIds
      );

      for (Id ticketId : ticketIds) {
        try {
          makeCallout(ticketId);
        } catch (Exception e) {
          System.debug(
            'Error calling summarizer for chatter update on ticket ' +
              ticketId +
              ': ' +
              e.getMessage()
          );
          // Log error for monitoring
          logError(ticketId, e.getMessage());
        }
      }
    } catch (Exception e) {
      System.debug('Error in delayed summarization: ' + e.getMessage());
    }
  }

  private static void makeCallout(Id ticketId) {
    Http http = new Http();
    HttpRequest request = new HttpRequest();

    String endpointUrl = getEndpointUrl();
    String environment = getEnvironment();

    request.setEndpoint(endpointUrl);
    request.setMethod('POST');
    request.setHeader('Content-Type', 'application/json');

    // API Gateway requires x-api-key when api_key_required = true.
    String apiKey = MqlSecrets.getApiGatewayApiKey();
    if (String.isNotBlank(apiKey)) {
      request.setHeader('x-api-key', apiKey);
    }

    Map<String, Object> requestBody = new Map<String, Object>{
      'ticketId' => ticketId,
      'environment' => environment
    };

    request.setBody(JSON.serialize(requestBody));
    request.setTimeout(60000); // 60 seconds

    HttpResponse response = http.send(request);

    if (response.getStatusCode() == 200) {
      System.debug(
        'Successfully triggered summarization for ticket: ' + ticketId
      );
    } else {
      String errorMsg =
        'Failed to trigger summarization. Status: ' +
        response.getStatusCode() +
        ', Body: ' +
        response.getBody();
      System.debug(errorMsg);
      throw new CalloutException(errorMsg);
    }
  }

  private static void logError(Id ticketId, String errorMessage) {
    // Create error log record for monitoring
    try {
      // You can create a custom object for error logging if needed
      System.debug(
        'TICKET_SUMMARIZER_ERROR: Ticket=' +
          ticketId +
          ', Error=' +
          errorMessage
      );
    } catch (Exception e) {
      // Fail silently to avoid infinite loops
    }
  }
}

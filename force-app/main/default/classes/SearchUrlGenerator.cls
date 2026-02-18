public with sharing class SearchUrlGenerator {
  // Cache for user access results to prevent repeated queries
  private static Map<Id, Boolean> userAccessCache = new Map<Id, Boolean>();

  @TestVisible
  private static Boolean hasAccess(Id userId) {
    // Check cache first
    if (userAccessCache.containsKey(userId)) {
      return userAccessCache.get(userId);
    }

    Boolean hasAccess = false;

    try {
      // Combine queries into one
      User currentUser = [
        SELECT
          Profile.Name,
          (
            SELECT PermissionSet.Name
            FROM PermissionSetAssignments
            WHERE PermissionSet.Name = 'Apex_Class_Access_SearchURLGenerator'
          )
        FROM User
        WHERE Id = :userId
        LIMIT 1
      ];

      // Check permission set first
      if (!currentUser.PermissionSetAssignments.isEmpty()) {
        hasAccess = true;
      } else {
        // Check profile
        Set<String> allowedProfiles = new Set<String>{
          'CommDev User',
          'System Administrator',
          'System Admin User - Sales Layouts',
          'System Admin User - Standard Layouts'
        };
        hasAccess = allowedProfiles.contains(currentUser.Profile.Name);
      }
    } catch (Exception e) {
      hasAccess = false;
    }

    // Cache the result
    userAccessCache.put(userId, hasAccess);
    return hasAccess;
  }

  @AuraEnabled(cacheable=true)
  public static String generateSearchUrl(String searchQuery) {
    if (String.isBlank(searchQuery)) {
      return '';
    }

    if (!hasAccess(UserInfo.getUserId())) {
      throw new SecurityException('Access Denied'); // Ensure exception is thrown
    }

    try {
      String safeSearchQuery = String.escapeSingleQuotes(
        searchQuery.trim().substring(0, Math.min(255, searchQuery.length()))
      );

      String jsonString = JSON.serialize(
        new Map<String, Object>{
          'componentDef' => 'forceSearch:search',
          'attributes' => new Map<String, Object>{
            'term' => safeSearchQuery,
            'scopeMap' => new Map<String, Object>{
              'type' => 'TOP_RESULTS',
              'contactSearch' => new Map<String, String>{ 'type' => 'Contact' }
            },
            'context' => new Map<String, Object>{
              'disableSpellCorrection' => true,
              'SEARCH_ACTIVITY' => new Map<String, String>{
                'term' => safeSearchQuery
              }
            }
          }
        }
      );

      String encodedString = EncodingUtil.base64Encode(
        Blob.valueOf(jsonString)
      );
      return '/one/one.app?source=alohaHeader#' + encodedString;
    } catch (Exception e) {
      System.debug('ERROR: Search URL Generation Error - ' + e.getMessage());
      return '';
    }
  }

  @TestVisible
  private static void logSecurityEvent(String eventType, String details) {
    // Handle null inputs
    eventType = String.isBlank(eventType) ? 'INFO' : eventType;
    details = details == null ? '' : details;

    // Only log critical security events to save space
    if (
      eventType.containsIgnoreCase('ALERT') ||
      eventType.containsIgnoreCase('ERROR')
    ) {
      String sourceIp = 'unknown';
      if (!Test.isRunningTest()) {
        try {
          Map<String, String> session = Auth.SessionManagement.getCurrentSession();
          sourceIp = session != null ? session.get('SourceIp') : 'no_session';
        } catch (Exception e) {
          sourceIp = 'session_unavailable';
        }
      }

      Map<String, String> logData = new Map<String, String>{
        'timestamp' => String.valueOf(System.now()),
        'eventType' => eventType,
        'userId' => UserInfo.getUserId(),
        'details' => details.abbreviate(255), // Limit detail length
        'sourceIp' => sourceIp
      };

      System.debug(
        LoggingLevel.ERROR,
        'SECURITY_EVENT: ' + JSON.serialize(logData)
      );
    }
    // For normal operations, just log minimal info
    else if (eventType.containsIgnoreCase('INFO')) {
      System.debug(
        LoggingLevel.INFO,
        'Search performed by: ' + UserInfo.getUserId()
      );
    }
  }

  // Add session validation
  @TestVisible
  private static Boolean validateSession() {
    // Check for test context first, before attempting to access session
    if (Test.isRunningTest()) {
      return true;
    }

    try {
      Map<String, String> session = Auth.SessionManagement.getCurrentSession();
      if (session == null) {
        return false;
      }
      String createdDateStr = session.get('createdDate');
      Long sessionAge = Long.valueOf(createdDateStr);
      Long currentTime = System.now().getTime();
      return (currentTime - sessionAge) < (8 * 60 * 60 * 1000); // 8 hours
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Session validation error: ' + e.getMessage()
      );
      return false; // Fail secure - return false if we can't validate the session
    }
  }

  @TestVisible
  private static Boolean isRateLimited() {
    String userId = UserInfo.getUserId();

    if (String.isBlank(userId)) {
      return false;
    }

    // Only store a hash of the user ID and timestamp (hour-based)
    String timeWindow = String.valueOf(
      Datetime.now().getTime() / (1000 * 60 * 60)
    ); // Current hour
    String rateKey =
      'SRCH_' +
      Crypto.generateDigest('SHA-256', Blob.valueOf(userId + timeWindow));

    try {
      Integer currentCount = 0;
      // Use Platform Cache only if available
      if (Cache.Org.getPartition('local') != null) {
        Cache.OrgPartition partition = Cache.Org.getPartition('local');
        currentCount = (Integer) partition.get(rateKey) ?? 0;
        partition.put(rateKey, currentCount + 1, 3600); // 1 hour TTL
      }
      return currentCount >= 50;
    } catch (Exception e) {
      // If cache fails, log it and fail open
      System.debug(
        LoggingLevel.ERROR,
        'Rate limiting error: ' + e.getMessage()
      );
      return false;
    }
  }

  // Helper method to check login attempts in the last minute
  @TestVisible
  private static Integer getUserLoginAttempts(Id userId) {
    Datetime oneMinuteAgo = System.now().addMinutes(-1);

    // Query LoginHistory for this user in the last minute
    Integer userAttempts = [
      SELECT COUNT()
      FROM LoginHistory
      WHERE UserId = :userId AND LoginTime >= :oneMinuteAgo
    ];

    return userAttempts;
  }
}

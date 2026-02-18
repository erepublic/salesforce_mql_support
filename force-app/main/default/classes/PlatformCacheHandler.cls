public with sharing class PlatformCacheHandler {
  private static final String CACHE_PARTITION = 'PrivacyCache';

  @AuraEnabled(cacheable=true)
  public static String getCacheData(String key) {
    try {
      Cache.SessionPartition partition = Cache.Session.getPartition(
        CACHE_PARTITION
      );
      if (partition != null) {
        Object cachedValue = partition.get(key);
        return cachedValue != null ? String.valueOf(cachedValue) : '';
      } else {
        return ''; // Cache is not available
      }
    } catch (Exception e) {
      System.debug('Error retrieving cache: ' + e.getMessage());
      return ''; // Return an empty string instead of failing
    }
  }

  @AuraEnabled
  public static void setCacheData(String key, String value) {
    try {
      Cache.SessionPartition partition = Cache.Session.getPartition(
        CACHE_PARTITION
      );
      if (partition != null) {
        partition.put(key, value);
      }
    } catch (Exception e) {
      System.debug('Error setting cache: ' + e.getMessage());
    }
  }
}

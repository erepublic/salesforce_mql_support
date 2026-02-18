@IsTest
private class SearchUrlGeneratorTest {
  @TestSetup
  static void setupTestData() {
    // Query the profile for creating non-admin test users.
    Profile standardProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];

    // Create non-admin test users.
    List<User> usersToCreate = new List<User>();
    usersToCreate.add(
      createUser(standardProfile.Id, 'Test', 'User', 'testuser')
    );
    usersToCreate.add(
      createUser(standardProfile.Id, 'Unpriv', 'User', 'unprivuser')
    );
    insert usersToCreate;

    // Create and assign the PermissionSet for SearchUrlGenerator.
    PermissionSet ps = new PermissionSet(
      Name = 'Apex_Class_Access_SearchURLGenerator',
      Label = 'Apex Class Access - Search URL Generator'
    );
    insert ps;

    insert new PermissionSetAssignment(
      AssigneeId = usersToCreate[0].Id,
      PermissionSetId = ps.Id
    );
  }

  // Helper method to create a user record.
  private static User createUser(
    Id profileId,
    String firstName,
    String lastName,
    String alias
  ) {
    String uniqueEmail = alias + DateTime.now().getTime() + '@test.com';
    return new User(
      FirstName = firstName,
      LastName = lastName,
      Email = uniqueEmail,
      Username = uniqueEmail,
      Alias = alias.left(8),
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      TimeZoneSidKey = 'America/Los_Angeles',
      ProfileId = profileId,
      IsActive = true
    );
  }

  @IsTest
  static void testSearchUrlGeneratorComprehensive() {
    // Query the test users created in setupTestData.
    User testUser = [
      SELECT Id
      FROM User
      WHERE LastName = 'User' AND FirstName = 'Test'
      LIMIT 1
    ];
    User unprivUser = [
      SELECT Id
      FROM User
      WHERE LastName = 'User' AND FirstName = 'Unpriv'
      LIMIT 1
    ];
    // Retrieve the running user record.
    User adminUser = [
      SELECT Id, Profile.Name
      FROM User
      WHERE Id = :UserInfo.getUserId()
    ];

    Test.startTest();

    // Test scenarios for a privileged (non-admin) test user.
    System.runAs(testUser) {
      String searchUrl = SearchUrlGenerator.generateSearchUrl('test query');
      System.assertNotEquals(null, searchUrl, 'Search URL should not be null');

      System.assertEquals(
        '',
        SearchUrlGenerator.generateSearchUrl(''),
        'Empty search should return empty string'
      );
      System.assertEquals(
        '',
        SearchUrlGenerator.generateSearchUrl(null),
        'Null search should return empty string'
      );

      // Test long search query.
      searchUrl = SearchUrlGenerator.generateSearchUrl('a'.repeat(300));
      System.assert(searchUrl.length() > 0, 'Should handle long query');

      // Test special characters.
      searchUrl = SearchUrlGenerator.generateSearchUrl(
        'test\'query"with\'quotes"'
      );
      System.assertNotEquals(
        null,
        searchUrl,
        'Search URL should handle special characters'
      );

      // Test session validation and rate limiting.
      System.assert(
        SearchUrlGenerator.validateSession(),
        'Session should be valid'
      );
      System.assert(
        !SearchUrlGenerator.isRateLimited(),
        'Should not be rate limited'
      );

      for (Integer i = 0; i < 3; i++) {
        Boolean isLimited = SearchUrlGenerator.isRateLimited();
        System.assert(!isLimited, 'Should not be rate limited on attempt ' + i);
      }

      Integer attempts = SearchUrlGenerator.getUserLoginAttempts(testUser.Id);
      System.assertNotEquals(null, attempts);

      // Test security event logging.
      SearchUrlGenerator.logSecurityEvent('ALERT', 'Test alert');
      SearchUrlGenerator.logSecurityEvent('ERROR', 'Test error');
      SearchUrlGenerator.logSecurityEvent('INFO', 'Test info');
      SearchUrlGenerator.logSecurityEvent(null, null);
      SearchUrlGenerator.logSecurityEvent('', '');
      SearchUrlGenerator.logSecurityEvent('ERROR', 'a'.repeat(300));
    }

    // Test admin user access only if the running user is a System Administrator.
    if (adminUser.Profile.Name.startsWith('System Administrator')) {
      System.runAs(adminUser) {
        String searchUrl = SearchUrlGenerator.generateSearchUrl('admin test');
        System.assertNotEquals(
          null,
          searchUrl,
          'Admin should have access via profile'
        );
        System.assert(
          SearchUrlGenerator.hasAccess(adminUser.Id),
          'Admin should have access'
        );
      }
    } else {
      System.debug(
        'Current running user is not a System Administrator. Skipping admin tests.'
      );
    }

    // Test unprivileged user scenario.
    System.runAs(unprivUser) {
      try {
        SearchUrlGenerator.generateSearchUrl('test');
        System.assert(false, 'Should have thrown SecurityException');
      } catch (SecurityException e) {
        System.assertEquals('Access Denied', e.getMessage());
      }

      System.assert(
        !SearchUrlGenerator.hasAccess(unprivUser.Id),
        'Unprivileged user should not have access'
      );
    }

    Test.stopTest();
  }

  @IsTest
  static void testCacheScenarios() {
    User testUser = [
      SELECT Id
      FROM User
      WHERE LastName = 'User' AND FirstName = 'Test'
      LIMIT 1
    ];

    Test.startTest();
    System.runAs(testUser) {
      try {
        Cache.Org.getPartition('nonexistent');
      } catch (Exception e) {
        Boolean isLimited = SearchUrlGenerator.isRateLimited();
        System.assert(
          !isLimited,
          'Should not be rate limited when cache fails'
        );
      }

      Boolean firstCheck = SearchUrlGenerator.hasAccess(testUser.Id);
      Boolean secondCheck = SearchUrlGenerator.hasAccess(testUser.Id);
      System.assertEquals(
        firstCheck,
        secondCheck,
        'Cached access check should match'
      );
    }
    Test.stopTest();
  }

  //--------------------------------------------------------------------------
  // Additional tests to improve code coverage
  //--------------------------------------------------------------------------

  // Test the exception catch block in hasAccess by passing an invalid user Id.
  @IsTest
  static void testHasAccessInvalidUser() {
    // Pass a valid format Id that doesn't correspond to any user.
    Id invalidUserId = '005000000000000AAA';
    Boolean result = SearchUrlGenerator.hasAccess(invalidUserId);
    System.assertEquals(false, result, 'Invalid user id should return false');
  }

  // Test logSecurityEvent with an event type that doesn't match ALERT, ERROR, or INFO.
  @IsTest
  static void testLogSecurityEventOther() {
    // This should exercise the branch where no logging occurs.
    SearchUrlGenerator.logSecurityEvent('DEBUG', 'Some debug details');
  }
}

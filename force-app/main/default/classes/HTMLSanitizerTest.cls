/**
 * Test class for HTMLSanitizer utility
 */
@isTest
private class HTMLSanitizerTest {
  /**
   * Test basic sanitization functionality
   */
  @isTest
  static void testBasicSanitization() {
    // Test HTML with script tags
    String unsafeHTML = '<script>alert("XSS")</script><p>Test content</p>';

    Test.startTest();

    String safeHTML = HTMLSanitizer.sanitize(unsafeHTML);

    Test.stopTest();

    // Assertions
    System.assert(
      !safeHTML.contains('<script>'),
      'Script tags should be removed'
    );
    System.assert(
      safeHTML.contains('<p>Test content</p>'),
      'Safe content should be preserved'
    );
  }

  /**
   * Test sanitization of event handlers
   */
  @isTest
  static void testEventHandlerSanitization() {
    // Test HTML with event handlers
    String unsafeHTML =
      '<div onclick="alert(\'XSS\')">Click me</div>' +
      '<img src="x" onerror="alert(\'XSS\')" onload="alert(\'XSS\')">';

    Test.startTest();

    String safeHTML = HTMLSanitizer.sanitize(unsafeHTML);

    Test.stopTest();

    // Assertions
    System.assert(
      !safeHTML.contains('onclick='),
      'onclick handler should be removed'
    );
    System.assert(
      !safeHTML.contains('onerror='),
      'onerror handler should be removed'
    );
    System.assert(
      !safeHTML.contains('onload='),
      'onload handler should be removed'
    );
    System.assert(
      safeHTML.contains('data-blocked='),
      'Event handlers should be replaced with data-blocked'
    );
  }

  /**
   * Test sanitization of JavaScript URLs
   */
  @isTest
  static void testJavaScriptURLSanitization() {
    // Test HTML with JavaScript URLs
    String unsafeHTML =
      '<a href="javascript:alert(\'XSS\')">Click me</a>' +
      '<a href="JAVASCRIPT:alert(\'XSS\')">Also click me</a>';

    Test.startTest();

    String safeHTML = HTMLSanitizer.sanitize(unsafeHTML);

    Test.stopTest();

    // Assertions
    System.assert(
      !safeHTML.contains('javascript:'),
      'javascript: protocol should be removed'
    );
    System.assert(
      !safeHTML.contains('JAVASCRIPT:'),
      'JAVASCRIPT: protocol should be removed (case insensitive)'
    );
    System.assert(
      safeHTML.contains('blocked:'),
      'javascript: should be replaced with blocked:'
    );
  }

  /**
   * Test sanitization of iframe tags
   */
  @isTest
  static void testIframeSanitization() {
    // Test HTML with iframe
    String unsafeHTML = '<iframe src="https://malicious.com"></iframe><p>Test content</p>';

    Test.startTest();

    String safeHTML = HTMLSanitizer.sanitize(unsafeHTML);

    Test.stopTest();

    // Assertions
    System.assert(
      !safeHTML.contains('<iframe'),
      'iframe tags should be removed'
    );
    System.assert(
      safeHTML.contains('<p>Test content</p>'),
      'Safe content should be preserved'
    );
  }

  /**
   * Test sanitization of object/embed tags
   */
  @isTest
  static void testObjectEmbedSanitization() {
    // Test HTML with object and embed tags
    String unsafeHTML =
      '<object data="data:text/html,<script>alert(\'XSS\')</script>"></object>' +
      '<embed src="data:text/html,<script>alert(\'XSS\')</script>">' +
      '<p>Test content</p>';

    Test.startTest();

    String safeHTML = HTMLSanitizer.sanitize(unsafeHTML);

    Test.stopTest();

    // Assertions
    System.assert(
      !safeHTML.contains('<object'),
      'object tags should be removed'
    );
    System.assert(!safeHTML.contains('<embed'), 'embed tags should be removed');
    System.assert(
      safeHTML.contains('<p>Test content</p>'),
      'Safe content should be preserved'
    );
  }

  /**
   * Test sanitization with mixed content
   */
  @isTest
  static void testMixedContentSanitization() {
    // Test HTML with mixed safe and unsafe content
    String mixedHTML =
      '<div class="content">' +
      '<h1>Welcome</h1>' +
      '<p>This is safe content</p>' +
      '<script>document.cookie = "stolen="+document.cookie</script>' +
      '<img src="valid.jpg" onmouseover="alert(\'XSS\')">' +
      '<a href="javascript:evil()">Click me</a>' +
      '<iframe src="https://evil.com"></iframe>' +
      '</div>';

    Test.startTest();

    String safeHTML = HTMLSanitizer.sanitize(mixedHTML);

    Test.stopTest();

    // Assertions
    System.assert(
      safeHTML.contains('<div class="content">'),
      'Safe div should be preserved'
    );
    System.assert(
      safeHTML.contains('<h1>Welcome</h1>'),
      'Safe h1 should be preserved'
    );
    System.assert(
      safeHTML.contains('<p>This is safe content</p>'),
      'Safe paragraph should be preserved'
    );
    System.assert(
      !safeHTML.contains('<script>'),
      'Script tag should be removed'
    );
    System.assert(
      !safeHTML.contains('onmouseover='),
      'Event handler should be removed'
    );
    System.assert(
      !safeHTML.contains('javascript:'),
      'JavaScript URL should be replaced'
    );
    System.assert(!safeHTML.contains('<iframe'), 'iframe should be removed');
  }

  /**
   * Test handling of null or blank input
   */
  @isTest
  static void testNullOrBlankInput() {
    Test.startTest();

    String nullResult = HTMLSanitizer.sanitize(null);
    String emptyResult = HTMLSanitizer.sanitize('');
    String blankResult = HTMLSanitizer.sanitize('   ');

    Test.stopTest();

    // Assertions
    System.assertEquals(null, nullResult, 'Null input should return null');
    System.assertEquals(
      '',
      emptyResult,
      'Empty input should return empty string'
    );
    System.assertEquals(
      '   ',
      blankResult,
      'Blank input should return unchanged'
    );
  }
}

/**
 * Basic HTML Sanitizer to help prevent XSS attacks
 */
public class HTMLSanitizer {
  // List of allowed HTML tags
  private static final Set<String> ALLOWED_TAGS = new Set<String>{
    'a',
    'b',
    'blockquote',
    'br',
    'caption',
    'code',
    'div',
    'dl',
    'dt',
    'em',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'hr',
    'i',
    'img',
    'li',
    'nl',
    'ol',
    'p',
    'pre',
    'span',
    'strike',
    'strong',
    'sub',
    'sup',
    'table',
    'tbody',
    'td',
    'tfoot',
    'th',
    'thead',
    'tr',
    'u',
    'ul'
  };

  // List of allowed attributes
  private static final Set<String> ALLOWED_ATTRIBUTES = new Set<String>{
    'align',
    'alt',
    'bgcolor',
    'border',
    'cellpadding',
    'cellspacing',
    'class',
    'colspan',
    'height',
    'href',
    'id',
    'rowspan',
    'src',
    'style',
    'title',
    'type',
    'valign',
    'width'
  };

  // List of allowed protocols in URLs
  private static final Set<String> ALLOWED_PROTOCOLS = new Set<String>{
    'http',
    'https',
    'mailto',
    'ftp',
    'tel'
  };

  /**
   * Sanitize HTML content to prevent XSS
   */
  public static String sanitize(String input) {
    if (String.isBlank(input)) {
      return input;
    }

    // Block JavaScript URLs and event handlers
    String sanitized = input;

    // Remove JavaScript URLs
    sanitized = sanitized.replaceAll('(?i)javascript:', 'blocked:');

    // Remove on* event handlers
    sanitized = sanitized.replaceAll('(?i)\\son\\w+\\s*=', ' data-blocked=');

    // Remove <script> tags and their content
    sanitized = sanitized.replaceAll(
      '(?i)<script\\b[^<]*(?:(?!<\\/script>)<[^<]*)*<\\/script>',
      ''
    );

    // Remove iframe tags - use a more robust pattern
    sanitized = sanitized.replaceAll(
      '(?i)<iframe[^>]*>[\\s\\S]*?<\\/iframe>',
      ''
    );

    // Remove object tags - use a more robust pattern
    sanitized = sanitized.replaceAll(
      '(?i)<object[^>]*>[\\s\\S]*?<\\/object>',
      ''
    );

    // Remove embed tags - using a more robust pattern
    sanitized = sanitized.replaceAll(
      '(?i)<embed[^>]*>(?:[\\s\\S]*?<\\/embed>)?',
      ''
    );

    // Handle self-closing embed tags
    sanitized = sanitized.replaceAll('(?i)<embed[^>]*\\/>', '');

    return sanitized;
  }
}

import 'dart:convert';

class Api {
  static String? token;

  /// Server address for optional PayPal checkout (set at start-up from the build-time value).
  static String base = '';

  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
}
// Preview builds now receive the Firebase environment variables.

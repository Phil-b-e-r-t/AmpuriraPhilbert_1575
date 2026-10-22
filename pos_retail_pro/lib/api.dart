import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

/// One place that talks to the Node server (which talks to MySQL).
class Api {
  static String base = '';
  static String? token;

  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token'
      };

  static const _timeout = Duration(seconds: 15);

  static dynamic _handle(http.Response r) {
    dynamic body;
    try {
      body = r.body.isEmpty ? null : jsonDecode(r.body);
    } catch (_) {}
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    final msg = body is Map && body['error'] != null
        ? body['error'].toString()
        : 'Server error (${r.statusCode})';
    throw ApiException(r.statusCode, msg);
  }

  static Future<dynamic> get(String path) async => _handle(await http
      .get(Uri.parse('$base$path'), headers: headers)
      .timeout(_timeout));

  static Future<dynamic> post(String path, Object body) async =>
      _handle(await http
          .post(Uri.parse('$base$path'),
              headers: headers, body: jsonEncode(body))
          .timeout(_timeout));

  static Future<dynamic> put(String path, Object body) async =>
      _handle(await http
          .put(Uri.parse('$base$path'),
              headers: headers, body: jsonEncode(body))
          .timeout(_timeout));
}

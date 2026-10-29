import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'api.dart';

class PaypalOrder {
  final String id, approveUrl;
  final double usd;
  PaypalOrder(this.id, this.approveUrl, this.usd);
}

/// Talks to YOUR backend (server/server.js). The PayPal secret NEVER lives in the app.
class PaypalService {
  // The WebView watches for these URLs to know the customer approved/cancelled.
  static const returnUrl = 'https://pos.local/paypal/success';
  static const cancelUrl = 'https://pos.local/paypal/cancel';

  /// Sends the signed-in Firebase user's ID token. getIdToken() refreshes it
  /// automatically when it has expired (tokens last 1 hour).
  static Future<Map<String, String>> _headers() async {
    final h = Map<String, String>.from(Api.headers);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    } catch (_) {
      // Firebase not set up: fall back to the old server login token (if any).
    }
    return h;
  }

  static Future<PaypalOrder> createOrder({
    required String apiBase,
    required int amountUgx,
    required String reference,
  }) async {
    final r = await http
        .post(Uri.parse('$apiBase/paypal/orders'),
            headers: await _headers(),
            body: jsonEncode({
              'amountUgx': amountUgx,
              'reference': reference,
              'returnUrl': returnUrl,
              'cancelUrl': cancelUrl,
            }))
        .timeout(const Duration(seconds: 20));
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw Exception('Could not create PayPal order (${r.statusCode})');
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return PaypalOrder(j['id'], j['approveUrl'], (j['usd'] as num).toDouble());
  }

  /// Returns the PayPal capture id when the payment is COMPLETED.
  static Future<String> capture({required String apiBase, required String orderId}) async {
    final r = await http
        .post(Uri.parse('$apiBase/paypal/orders/$orderId/capture'),
            headers: await _headers())
        .timeout(const Duration(seconds: 20));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200 || j['status'] != 'COMPLETED') {
      throw Exception('PayPal capture failed: ${j['status'] ?? r.statusCode}');
    }
    return (j['captureId'] ?? orderId) as String;
  }
}

import 'dart:convert';
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
  static Map<String, String> get _h => Api.headers; // includes the login token

  static Future<PaypalOrder> createOrder({
    required String apiBase,
    required int amountUgx,
    required String reference,
  }) async {
    final r = await http
        .post(Uri.parse('$apiBase/paypal/orders'),
            headers: _h,
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
        .post(Uri.parse('$apiBase/paypal/orders/$orderId/capture'), headers: _h)
        .timeout(const Duration(seconds: 20));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200 || j['status'] != 'COMPLETED') {
      throw Exception('PayPal capture failed: ${j['status'] ?? r.statusCode}');
    }
    return (j['captureId'] ?? orderId) as String;
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'api.dart';

class PaypalOrder {
  final String id, approveUrl;
  final double usd;
  final int amountUgx;
  PaypalOrder(this.id, this.approveUrl, this.usd, this.amountUgx);
}

/// A payment problem that is safe to show to the person using the app
/// (never contains server addresses or technical details).
class PaymentException implements Exception {
  final String message;
  PaymentException(this.message);
  @override
  String toString() => message;
}

const _unreachable =
    'Could not reach the payment service. Check your internet connection and try again.';
const _unconfirmed =
    'We could not confirm this payment. Check PayPal activity before retrying.';

/// Talks to YOUR backend (server/server.js). The PayPal secret NEVER lives in the app,
/// and the server address is configured at build time, never typed in by the user.
class PaypalService {
  static String get returnUrl => kIsWeb
      ? '${Uri.base.origin}/?paypal=success'
      : 'https://pos.local/paypal/success';
  static String get cancelUrl => kIsWeb
      ? '${Uri.base.origin}/?paypal=cancel'
      : 'https://pos.local/paypal/cancel';

  static Future<Map<String, String>> _headers() async {
    final h = Map<String, String>.from(Api.headers);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    } catch (_) {
      // Firebase not set up: fall back to old server login token (if any).
    }
    return h;
  }

  static Future<PaypalOrder> createOrder({
    required String apiBase,
    required int amountUgx,
    required String reference,
  }) async {
    try {
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
        throw PaymentException(
            'The payment could not be started. Please try again or use another payment method.');
      }
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return PaypalOrder(
          j['id'], j['approveUrl'], (j['usd'] as num).toDouble(), amountUgx);
    } on PaymentException {
      rethrow;
    } catch (_) {
      throw PaymentException(_unreachable);
    }
  }

  static Future<String> capture({
    required String apiBase,
    required String orderId,
    required double expectedUsd,
  }) async {
    try {
      final r = await http
          .post(Uri.parse('$apiBase/paypal/orders/$orderId/capture'),
              headers: await _headers())
          .timeout(const Duration(seconds: 20));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final amount = j['amount'];
      final amountValue =
          amount is num ? amount.toStringAsFixed(2) : amount?.toString();
      if (r.statusCode != 200 ||
          j['status'] != 'COMPLETED' ||
          j['currency'] != 'USD' ||
          amountValue != expectedUsd.toStringAsFixed(2)) {
        throw PaymentException(_unconfirmed);
      }
      final captureId = j['captureId'];
      if (captureId is! String || captureId.isEmpty) {
        throw PaymentException(_unconfirmed);
      }
      return captureId;
    } on PaymentException {
      rethrow;
    } catch (_) {
      throw PaymentException(_unreachable);
    }
  }
}

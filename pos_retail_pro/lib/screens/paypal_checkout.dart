import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../paypal_service.dart';
import '../widgets.dart';

/// Opens PayPal's own secure page. Card numbers / PayPal passwords are typed on PayPal's page,
/// never inside our code (this keeps you out of heavy PCI scope).
/// Pops `true` when the customer approved, `false` when cancelled.
class PaypalCheckoutPage extends StatefulWidget {
  final String url;
  const PaypalCheckoutPage({super.key, required this.url});
  @override
  State<PaypalCheckoutPage> createState() => _PaypalCheckoutPageState();
}

class _PaypalCheckoutPageState extends State<PaypalCheckoutPage> {
  late final WebViewController _c;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (r) {
          if (r.url.startsWith(PaypalService.returnUrl)) {
            Navigator.pop(context, true);
            return NavigationDecision.prevent;
          }
          if (r.url.startsWith(PaypalService.cancelUrl)) {
            Navigator.pop(context, false);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('PayPal Checkout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, false)),
        ),
        body: Stack(children: [
          WebViewWidget(controller: _c),
          if (_loading) Center(child: CircularProgressIndicator(color: context.primary)),
        ]),
      );
}

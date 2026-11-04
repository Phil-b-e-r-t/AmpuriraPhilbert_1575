import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// What the scanner screen shows after a code was read in continuous mode.
class ScanResult {
  final String message;
  final bool ok;
  const ScanResult(this.message, this.ok);
}

/// Full-screen barcode / QR scanner.
///  • [onCode] == null  → single scan: the screen closes and returns the code (used when adding products).
///  • [onCode] given    → keeps scanning and shows the result of each scan (used for selling / price check).
/// A text box lets the user type a code when the camera is unavailable (or use a USB/Bluetooth scanner).
class ScannerPage extends StatefulWidget {
  final String title, hint;
  final ScanResult Function(String code)? onCode;
  const ScannerPage({
    super.key,
    required this.title,
    this.hint = 'Point the camera at a barcode or QR code',
    this.onCode,
  });
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final _controller = MobileScannerController();
  final _manual = TextEditingController();
  String? _last;
  DateTime _lastAt = DateTime(2000);
  bool _done = false, _ok = true;
  late String _msg = widget.hint;

  @override
  void dispose() {
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _handle(String raw) {
    final code = raw.trim();
    if (code.isEmpty || _done) return;
    final now = DateTime.now();
    // The camera reports the same code many times a second: ignore repeats for 2 seconds.
    if (code == _last && now.difference(_lastAt) < const Duration(seconds: 2)) return;
    _last = code;
    _lastAt = now;
    HapticFeedback.selectionClick();
    final cb = widget.onCode;
    if (cb == null) {
      _done = true;
      Navigator.pop(context, code);
      return;
    }
    final r = cb(code);
    setState(() {
      _msg = r.message;
      _ok = r.ok;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) {
        _handle(v);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBar(context, widget.title, actions: [
          IconButton(
              icon: const Icon(Icons.flash_on),
              tooltip: 'Torch',
              onPressed: () => _controller.toggleTorch()),
          IconButton(
              icon: const Icon(Icons.cameraswitch_outlined),
              tooltip: 'Switch camera',
              onPressed: () => _controller.switchCamera()),
          if (widget.onCode != null)
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ]),
        body: Column(children: [
          Expanded(
            child: Stack(children: [
              MobileScanner(controller: _controller, onDetect: _onDetect),
              Center(
                  child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(16)))),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                      color: (_ok ? Colors.black : C.red).withValues(alpha: .75),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(_msg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              ),
            ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(child: AppField('Or type the code', controller: _manual, icon: Icons.keyboard_outlined)),
                const SizedBox(width: 10),
                SizedBox(
                    width: 84,
                    child: PrimaryButton('Go', onTap: () {
                      _handle(_manual.text);
                      _manual.clear();
                    })),
              ]),
            ),
          ),
        ]),
      );
}

/// Scan items straight into the cart (each scan adds one unit at the current promotional price).
Future<void> openSaleScanner(BuildContext context) {
  final s = context.read<AppState>();
  return Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ScannerPage(
              title: 'Scan items to sell',
              onCode: (c) {
                final m = s.addByBarcode(c);
                return ScanResult(m, m.startsWith('Added'));
              })));
}

/// Scan to see a product's current price and stock without selling it.
Future<void> openPriceCheck(BuildContext context) {
  final s = context.read<AppState>();
  return Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ScannerPage(
              title: 'Price check',
              onCode: (c) {
                final p = s.productByBarcode(c);
                if (p == null) return ScanResult('No product found for "${c.trim()}"', false);
                final promo = s.unitDiscount(p) > 0 ? ' (was ${ugx(p.price)})' : '';
                return ScanResult('${p.name}\n${ugx(s.unitPrice(p))}$promo · Stock ${p.stock}', true);
              })));
}

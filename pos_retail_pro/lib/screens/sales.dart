import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../models.dart';
import '../paypal_service.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'paypal_checkout.dart';
import 'receipt.dart';
import 'scanner.dart';

// ─────────────────────── 4. Product / Item Selection ───────────────────────
class ProductSelectionPage extends StatefulWidget {
  final bool tab;
  const ProductSelectionPage({super.key, this.tab = false});
  @override
  State<ProductSelectionPage> createState() => _ProductSelectionPageState();
}

class _ProductSelectionPageState extends State<ProductSelectionPage> {
  String q = '', cat = 'All';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cats = ['All', ...{...s.products.map((p) => p.category)}];
    final query = q.trim().toLowerCase();
    final list = s.products
        .where((p) =>
            (cat == 'All' || p.category == cat) &&
            (p.name.toLowerCase().contains(query) || p.barcode.toLowerCase().contains(query)))
        .toList();

    return Scaffold(
      appBar: appBar(context, 'New Sale', back: !widget.tab, actions: [
        IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan barcode / QR code',
            onPressed: () => openSaleScanner(context)),
      ]),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: AppField('Search name or barcode...', icon: Icons.search, onChanged: (v) => setState(() => q = v))),
        SizedBox(
          height: 36,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: cats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text(cats[i], style: TextStyle(fontSize: 12, color: cat == cats[i] ? Colors.white : C.grey)),
              selected: cat == cats[i],
              selectedColor: context.primary,
              showCheckmark: false,
              onSelected: (_) => setState(() => cat = cats[i]),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: C.border),
            itemBuilder: (_, i) {
              final p = list[i];
              final inCart = s.cart[p.id] ?? 0;
              final off = s.unitDiscount(p);
              final canAdd = p.stock > 0 && inCart < p.stock;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  ProductImage(p.image),
                  const SizedBox(width: 20),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
                      if (off > 0)
                        Text(ugx(p.price),
                            style: const TextStyle(fontSize: 11, color: C.grey, decoration: TextDecoration.lineThrough)),
                      Text(ugx(s.unitPrice(p)),
                          style: TextStyle(fontSize: 12, color: context.primary, fontWeight: FontWeight.w600)),
                      if (off > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: C.green.withValues(alpha: .12), borderRadius: BorderRadius.circular(4)),
                          child: Text(s.promoFor(p)!.label,
                              style: const TextStyle(fontSize: 10, color: C.green, fontWeight: FontWeight.w600)),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Text('Stock: ${p.stock}', style: TextStyle(fontSize: 11, color: p.low ? C.red : C.grey)),
                  ])),
                  if (inCart > 0)
                    Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text('×$inCart', style: const TextStyle(fontSize: 12, color: C.grey))),
                  GestureDetector(
                    onTap: canAdd ? () => s.addToCart(p) : null,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                          color: canAdd ? context.primary : C.border, borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.add, color: Colors.white, size: 18),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
        if (s.cart.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: PrimaryButton('View Cart (${s.cartCount}) • ${ugx(s.total)}',
                  icon: Icons.shopping_bag_outlined,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutPage()))),
            ),
          ),
      ]),
    );
  }
}

// ─────────────────────── 5. Create Sale / Checkout ───────────────────────
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final code = TextEditingController();
  String? codeError;

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  void _apply(AppState s) {
    final err = s.applyCode(code.text);
    setState(() => codeError = err);
    if (err == null) code.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    Widget row(String l, String v, {bool big = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Text(l, style: TextStyle(fontSize: big ? 15 : 12, fontWeight: big ? FontWeight.w700 : FontWeight.w400, color: big ? C.text : C.grey)),
            const Spacer(),
            Text(v, style: TextStyle(fontSize: big ? 15 : 12, fontWeight: big ? FontWeight.w700 : FontWeight.w500, color: color ?? (big ? context.primary : C.text))),
          ]),
        );

    return Scaffold(
      appBar: appBar(context, 'Checkout', actions: [
        IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan more items',
            onPressed: () => openSaleScanner(context)),
      ]),
      body: s.cart.isEmpty
          ? const Center(child: Text('Cart is empty', style: TextStyle(color: C.grey)))
          : Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  GestureDetector(
                    onTap: () => showSheet(
                        context,
                        'Select Customer',
                        Column(children: [
                          ListTile(
                              leading: const Icon(Icons.person_outline),
                              title: const Text('Walk-in Customer'),
                              onTap: () {
                                s.setCustomer(null);
                                Navigator.pop(context);
                              }),
                          for (final c in s.customers)
                            ListTile(
                                leading: const Icon(Icons.person),
                                title: Text(c.name),
                                subtitle: Text(c.phone),
                                onTap: () {
                                  s.setCustomer(c);
                                  Navigator.pop(context);
                                }),
                        ])),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(border: Border.all(color: C.border), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.person_outline, size: 18, color: C.grey),
                        const SizedBox(width: 10),
                        Expanded(child: Text(s.customer?.name ?? 'Walk-in Customer', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                        Text('Change', style: TextStyle(fontSize: 12, color: context.primary, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final e in s.lines) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(children: [
                        ProductImage(e.key.image, w: 28, h: 52),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.key.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Wrap(spacing: 6, children: [
                            if (s.unitDiscount(e.key) > 0)
                              Text(ugx(e.key.price),
                                  style: const TextStyle(fontSize: 11, color: C.grey, decoration: TextDecoration.lineThrough)),
                            Text(ugx(s.unitPrice(e.key)),
                                style: TextStyle(fontSize: 11, color: s.unitDiscount(e.key) > 0 ? C.green : C.grey)),
                          ]),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(border: Border.all(color: C.border), borderRadius: BorderRadius.circular(6)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              InkWell(onTap: () => s.changeQty(e.key, -1), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Icon(Icons.remove, size: 14))),
                              SizedBox(width: 28, child: Text('${e.value}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                              InkWell(onTap: () => s.changeQty(e.key, 1), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Icon(Icons.add, size: 14))),
                            ]),
                          ),
                        ])),
                        Text(ugx(s.unitPrice(e.key) * e.value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    const Divider(height: 1, color: C.border),
                  ],
                  const SizedBox(height: 16),
                  // ── promo code ──
                  if (s.appliedCode != null && s.appliedCode!.live)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: C.green.withValues(alpha: .1), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.local_offer_outlined, size: 16, color: C.green),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text('${s.appliedCode!.code} · ${s.appliedCode!.label}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.green))),
                        InkWell(onTap: s.clearCode, child: const Icon(Icons.close, size: 16, color: C.green)),
                      ]),
                    )
                  else
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: AppField('Promo code', icon: Icons.local_offer_outlined, controller: code)),
                      const SizedBox(width: 10),
                      SizedBox(width: 90, child: PrimaryButton('Apply', outlined: true, onTap: () => _apply(s))),
                    ]),
                  if (codeError != null)
                    Padding(padding: const EdgeInsets.only(top: 6), child: Text(codeError!, style: const TextStyle(color: C.red, fontSize: 11))),
                  const SizedBox(height: 12),
                  row('Subtotal', ugx(s.subtotal)),
                  if (s.discount > 0) row('Discount', '-${ugx(s.discount)}', color: C.green),
                  row('Tax (${(taxRate * 100).round()}%)', ugx(s.tax)),
                  const Divider(color: C.border),
                  row('Total', ugx(s.total), big: true),
                  const SizedBox(height: 16),
                  const Text('Payment Method', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final m in s.methods)
                      ChoiceChip(
                        avatar: Icon(methodIcon(m), size: 16, color: s.payMethod == m ? Colors.white : C.grey),
                        label: Text(m, style: TextStyle(fontSize: 12, color: s.payMethod == m ? Colors.white : C.text)),
                        selected: s.payMethod == m,
                        selectedColor: context.primary,
                        showCheckmark: false,
                        onSelected: (_) => s.setMethod(m),
                      ),
                  ]),
                ]),
              ),
              SafeArea(
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: PrimaryButton('Complete Sale',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentPage()))))),
            ]),
    );
  }
}

// ─────────────────────── 6. Payment Methods  (+ PayPal integration) ───────────────────────
class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});
  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool busy = false;

  // key stored in DB → [label shown, subtitle]
  static const labels = {
    'Cash': ['Cash', ''],
    'Card': ['Credit / Debit Card', ' (via PayPal)'],
    'Mobile Money': ['Mobile Money', ' (MTN/Airtel)'],
    'Bank Transfer': ['Bank Transfer', ''],
    'PayPal': ['PayPal', ''],
  };

  Future<bool> _confirm(String title, String msg) async =>
      await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
                title: Text(title),
                content: Text(msg),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Payment received')),
                ],
              )) ??
      false;

  Future<void> _pay() async {
    final s = context.read<AppState>();
    if (s.cart.isEmpty) return;
    setState(() => busy = true);
    try {
      String? ref;
      final m = s.payMethod;

      if (m == 'PayPal' || m == 'Card') {
        // ── PAYPAL FLOW (the server address is built into the app, never entered by the user) ──
        if (!s.online) {
          context.snack('PayPal needs internet. Use Cash or Mobile Money while offline.');
          return;
        }
        // 1) ask OUR server to create the order (server holds the secret + converts UGX→USD)
        final order = await PaypalService.createOrder(
            apiBase: s.apiBase, amountUgx: s.total, reference: const Uuid().v4());
        if (!mounted) return;
        // 2) customer approves on PayPal's page
        bool? approved;
        if (kIsWeb) {
          // Browsers can't embed PayPal in a WebView: open a new tab instead.
          await launchUrl(Uri.parse(order.approveUrl), webOnlyWindowName: '_blank');
          approved = await _confirm('PayPal',
              'Finish the payment in the new PayPal tab. When PayPal says it is approved, come back here and press "Payment received".');
        } else {
          approved = await Navigator.push<bool>(
              context, MaterialPageRoute(builder: (_) => PaypalCheckoutPage(url: order.approveUrl)));
        }
        if (approved != true) {
          if (mounted) context.snack('Payment cancelled');
          return;
        }
        // 3) server captures the money, we only record the result
        ref = await PaypalService.capture(apiBase: s.apiBase, orderId: order.id);
      } else if (m == 'Mobile Money') {
        if (!await _confirm('Mobile Money',
            'Ask the customer to pay ${ugx(s.total)} to your MTN/Airtel merchant number, then confirm when the SMS arrives.')) {
          return;
        }
      } else if (m == 'Bank Transfer') {
        if (!await _confirm('Bank Transfer', 'Confirm the ${ugx(s.total)} transfer has reached your account.')) return;
      } else {
        if (!await _confirm('Cash', 'Collect ${ugx(s.total)} in cash from the customer.')) return;
      }

      final sale = await s.completeSale(m, paypalRef: ref);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PaymentSuccessPage(sale: sale)));
    } on PaymentException catch (e) {
      if (mounted) context.snack(e.message);
    } catch (_) {
      // Never show raw errors: they can contain server addresses.
      if (mounted) context.snack('Payment failed. Please try again or use another payment method.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: appBar(context, 'Payment'),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const SizedBox(height: 10),
        const Center(child: Text('Total Amount', style: TextStyle(fontSize: 12, color: C.grey))),
        const SizedBox(height: 10),
        Center(child: Text(ugx(s.total), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: C.navy))),
        if (s.discount > 0)
          Center(
              child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('You saved ${ugx(s.discount)}', style: const TextStyle(fontSize: 12, color: C.green, fontWeight: FontWeight.w600)))),
        const SizedBox(height: 28),
        for (final m in s.methods)
          GestureDetector(
            onTap: busy ? null : () => s.setMethod(m),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: s.payMethod == m ? context.primary : C.border, width: 1.2)),
              child: Row(children: [
                MethodIcon(m),
                const SizedBox(width: 16),
                Expanded(
                    child: Text.rich(TextSpan(text: labels[m]![0], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), children: [
                  TextSpan(text: labels[m]![1], style: const TextStyle(color: C.grey)),
                ]))),
                Icon(s.payMethod == m ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: s.payMethod == m ? context.primary : C.grey),
              ]),
            ),
          ),
        const SizedBox(height: 10),
        PrimaryButton('Pay Now', loading: busy, onTap: busy ? null : _pay),
      ]),
    );
  }
}

// ─────────────────────── 13. Payment Success ───────────────────────
class PaymentSuccessPage extends StatelessWidget {
  final Sale sale;
  const PaymentSuccessPage({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    Widget row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Text(l, style: const TextStyle(fontSize: 12, color: C.grey)),
          const Spacer(),
          Flexible(child: Text(v, textAlign: TextAlign.end, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ]));

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              const Spacer(),
              Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: C.green.withValues(alpha: .12)),
                  child: const Center(child: CircleAvatar(radius: 38, backgroundColor: C.green, child: Icon(Icons.check, color: Colors.white, size: 44)))),
              const SizedBox(height: 28),
              const Text('Payment Successful', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('${ugx(sale.total)} received', style: const TextStyle(fontSize: 14, color: C.grey)),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
                child: Column(children: [
                  row('Receipt No', sale.receipt),
                  row('Date', DateFormat('MMM d, yyyy · hh:mm a').format(sale.created)),
                  row('Payment Method', sale.method),
                  if (sale.discount > 0) row('Discount', '-${ugx(sale.discount)}'),
                  row('Cashier', sale.cashier.isEmpty ? s.userName : sale.cashier),
                  if (sale.paypalRef != null) row('PayPal Ref', sale.paypalRef!),
                ]),
              ),
              const Spacer(),
              PrimaryButton('View Receipt',
                  icon: Icons.description_outlined,
                  outlined: true,
                  onTap: () => showReceipt(context, sale, s.businessName)),
              const SizedBox(height: 12),
              PrimaryButton('Back to Home', onTap: () => Navigator.popUntil(context, (r) => r.isFirst)),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ),
    );
  }
}

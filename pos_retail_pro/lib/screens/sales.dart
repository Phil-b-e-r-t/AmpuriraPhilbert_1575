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

void _toPayment(BuildContext context) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => const PaymentPage()));

// ─────────────────────── POS: product list (+ live cart panel on tablets / desktop) ───────────────────────
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
    final wide = context.wide;
    final cats = [
      'All',
      ...{...s.products.map((p) => p.category)}
    ];
    final query = q.trim().toLowerCase();
    final list = s.products
        .where((p) =>
            (cat == 'All' || p.category == cat) &&
            (p.name.toLowerCase().contains(query) ||
                p.barcode.toLowerCase().contains(query)))
        .toList();

    final catalog = Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: AppField('Search name or barcode',
              icon: Icons.search,
              soft: true,
              onChanged: (v) => setState(() => q = v))),
      SizedBox(
        height: 38,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: cats.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final sel = cat == cats[i];
            return ChoiceChip(
              label: Text(cats[i],
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: sel ? Colors.white : C.text)),
              selected: sel,
              selectedColor: context.primary,
              backgroundColor: C.bg,
              side: BorderSide(color: sel ? context.primary : C.border),
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              onSelected: (_) => setState(() => cat = cats[i]),
            );
          },
        ),
      ),
      Expanded(
        child: list.isEmpty
            ? const EmptyState(Icons.search_off, 'No products found',
                'Try a different name, barcode or category.')
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                itemCount: list.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: C.divider),
                itemBuilder: (_, i) => _ProductRow(list[i]),
              ),
      ),
      if (!wide && s.cart.isNotEmpty)
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
            child: Material(
              color: context.primary,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CheckoutPage())),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .22),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('${s.cartCount}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    const Text('View cart',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    const Spacer(),
                    Text(ugx(s.total),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ]),
                ),
              ),
            ),
          ),
        ),
    ]);

    return Scaffold(
      appBar: appBar(context, 'New Sale', back: !widget.tab, actions: [
        IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan barcode / QR code',
            onPressed: () => openSaleScanner(context)),
      ]),
      body: wide
          ? Row(children: [
              Expanded(child: catalog),
              const VerticalDivider(width: 1, color: C.divider),
              Container(
                  width: 400,
                  color: Colors.white,
                  child: CartPanel(onCharge: () => _toPayment(context))),
            ])
          : catalog,
    );
  }
}

/// One product: picture, name, price, stock and a round "+" button that adds it to the cart.
class _ProductRow extends StatelessWidget {
  final Product p;
  const _ProductRow(this.p);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final inCart = s.cart[p.id] ?? 0;
    final off = s.unitDiscount(p);
    final soldOut = p.stock <= 0;
    final canAdd = !soldOut && inCart < p.stock;
    return Opacity(
      opacity: soldOut ? .55 : 1,
      child: InkWell(
        onTap: canAdd ? () => s.addToCart(p) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(children: [
            ProductImage(p.image, name: p.name, w: 36, h: 56),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                      child: Text(p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600))),
                  if (off > 0) ...[
                    const SizedBox(width: 8),
                    Pill(s.promoFor(p)!.label, C.green),
                  ],
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Text(ugx(s.unitPrice(p)),
                      style: const TextStyle(fontSize: 12.5, color: C.grey)),
                  if (off > 0) ...[
                    const SizedBox(width: 6),
                    Text(ugx(p.price).replaceFirst('UGX ', ''),
                        style: const TextStyle(
                            fontSize: 11,
                            color: C.hint,
                            decoration: TextDecoration.lineThrough)),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(soldOut ? 'Sold out' : 'Stock: ${p.stock}',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: soldOut || p.low ? C.red : C.grey)),
              ]),
            ),
            if (inCart > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                    color: context.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('$inCart',
                    style: TextStyle(
                        color: context.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
            ],
            Material(
              color: canAdd ? context.primary : C.divider,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: canAdd ? () => s.addToCart(p) : null,
                child: const SizedBox(
                    width: 30,
                    height: 30,
                    child: Icon(Icons.add, size: 18, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────── Cart panel (used by Checkout on phones and beside the list on tablets) ───────────────────────
class CartPanel extends StatefulWidget {
  final VoidCallback onCharge;
  const CartPanel({super.key, required this.onCharge});
  @override
  State<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<CartPanel> {
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

  void _clear(AppState s) {
    for (final e in s.lines.toList()) {
      s.changeQty(e.key, -e.value);
    }
  }

  Widget _stepper(AppState s, Product p, int qty) => Container(
        decoration: BoxDecoration(
            border: Border.all(color: C.border, width: 1.2),
            borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          InkWell(
              onTap: () => s.changeQty(p, -1),
              child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(Icons.remove, size: 15))),
          SizedBox(
              width: 28,
              child: Text('$qty',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600))),
          InkWell(
              onTap: () => s.changeQty(p, 1),
              child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(Icons.add, size: 15))),
        ]),
      );

  Widget _line(AppState s, Product p, int qty) {
    final off = s.unitDiscount(p) > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ProductImage(p.image, name: p.name, w: 34, h: 60),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Wrap(spacing: 6, children: [
            if (off)
              Text(ugx(p.price),
                  style: const TextStyle(
                      fontSize: 11.5,
                      color: C.hint,
                      decoration: TextDecoration.lineThrough)),
            Text(ugx(s.unitPrice(p)),
                style: TextStyle(
                    fontSize: 11.5,
                    color: off ? C.green : C.grey,
                    fontWeight: off ? FontWeight.w600 : FontWeight.w400)),
          ]),
          const SizedBox(height: 10),
          _stepper(s, p, qty),
        ])),
        const SizedBox(width: 8),
        SizedBox(
          height: 80,
          child: Align(
            alignment: Alignment.bottomRight,
            child: Text(ugx(s.unitPrice(p) * qty),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Widget _totalRow(String l, String v, {bool big = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Text(l,
              style: TextStyle(
                  fontSize: big ? 15 : 13,
                  fontWeight: big ? FontWeight.w700 : FontWeight.w400,
                  color: big ? C.text : C.grey)),
          const Spacer(),
          Text(v,
              style: TextStyle(
                  fontSize: big ? 17 : 13,
                  fontWeight: big ? FontWeight.w700 : FontWeight.w500,
                  color: color ?? (big ? C.navy : C.grey))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
        child: Row(children: [
          const Expanded(
              child: Text('Current order',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          if (s.cart.isNotEmpty)
            TextButton(onPressed: () => _clear(s), child: const Text('Clear')),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
          child: Row(children: [
            const Icon(Icons.person_outline, size: 18, color: C.grey),
            const SizedBox(width: 12),
            Expanded(
                child: Text(s.customer?.name ?? 'Walk-in Customer',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500))),
            Text('Change',
                style: TextStyle(fontSize: 12, color: context.primary)),
          ]),
        ),
      ),
      Expanded(
        child: s.cart.isEmpty
            ? const EmptyState(Icons.shopping_basket_outlined, 'Cart is empty',
                'Tap a product or scan a barcode to start a sale.')
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                    for (final e in s.lines) ...[
                      _line(s, e.key, e.value),
                      const Divider(height: 1, color: C.divider)
                    ],
                    const SizedBox(height: 14),
                    if (s.appliedCode != null && s.appliedCode!.live)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                            color: C.green.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          const Icon(Icons.local_offer_outlined,
                              size: 16, color: C.green),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  '${s.appliedCode!.code} \u00b7 ${s.appliedCode!.label}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: C.green))),
                          InkWell(
                              onTap: s.clearCode,
                              child: const Icon(Icons.close,
                                  size: 16, color: C.green)),
                        ]),
                      )
                    else
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: AppField('Promo code',
                                    icon: Icons.local_offer_outlined,
                                    controller: code,
                                    onSubmitted: (_) => _apply(s))),
                            const SizedBox(width: 10),
                            SizedBox(
                                width: 88,
                                child: PrimaryButton('Apply',
                                    outlined: true,
                                    height: 48,
                                    onTap: () => _apply(s))),
                          ]),
                    if (codeError != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(codeError!,
                              style: const TextStyle(
                                  color: C.red, fontSize: 11.5))),
                    const SizedBox(height: 16),
                  ]),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: C.divider))),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _totalRow('Subtotal', ugx(s.subtotal)),
            if (s.discount > 0)
              _totalRow('Discount', '-${ugx(s.discount)}', color: C.green),
            _totalRow('Tax (${(taxRate * 100).round()}%)', ugx(s.tax)),
            const Divider(color: C.divider, height: 18),
            _totalRow('Total', ugx(s.total), big: true),
            const SizedBox(height: 10),
            PrimaryButton(s.cart.isEmpty ? 'Charge' : 'Charge ${ugx(s.total)}',
                height: 50, onTap: s.cart.isEmpty ? null : widget.onCharge),
          ]),
        ),
      ),
    ]);
  }
}

// Phone checkout screen = the cart panel full-screen.
class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: appBar(context, 'Checkout', actions: [
          IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scan more items',
              onPressed: () => openSaleScanner(context)),
        ]),
        body: CartPanel(onCharge: () => _toPayment(context)),
      );
}

// ─────────────────────── Payment  (+ PayPal integration) ───────────────────────
class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});
  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool busy = false;
  PaypalOrder? pendingOrder;
  Map<String, int>? pendingCart;
  int? pendingTax, pendingDiscount;
  String? pendingCustomerId;

  // key stored in DB → [label shown, subtitle]
  static const labels = {
    'Cash': ['Cash', 'Collect cash from the customer'],
    'Card': ['Credit / Debit Card', 'Processed securely via PayPal'],
    'Mobile Money': ['Mobile Money', 'MTN / Airtel'],
    'Bank Transfer': ['Bank Transfer', 'Confirm when the transfer arrives'],
    'PayPal': ['PayPal', 'Customer approves online'],
  };

  Future<bool> _confirm(String title, String msg) async =>
      await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
                title: Text(title),
                content: Text(msg),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Payment received')),
                ],
              )) ??
      false;

  Future<void> _pay() async {
    final s = context.read<AppState>();
    if (s.cart.isEmpty) return;
    setState(() => busy = true);
    var paymentCaptured = false;
    try {
      String? ref;
      final m = s.payMethod;

      if (m == 'PayPal' || m == 'Card') {
        // PayPal flow. The server address is built into the app, never entered by the user.
        if (!s.online) {
          context.snack(
              'PayPal needs internet. Use Cash or Mobile Money while offline.');
          return;
        }
        // 1) ask OUR server to create the order (server holds the secret + converts UGX→USD)
        final canReuseOrder = pendingOrder?.amountUgx == s.total &&
            mapEquals(pendingCart, s.cart) &&
            pendingTax == s.tax &&
            pendingDiscount == s.discount &&
            pendingCustomerId == s.customer?.id;
        final order = canReuseOrder
            ? pendingOrder!
            : await PaypalService.createOrder(
                apiBase: s.apiBase,
                amountUgx: s.total,
                reference: const Uuid().v4());
        pendingOrder = order;
        pendingCart = Map<String, int>.of(s.cart);
        pendingTax = s.tax;
        pendingDiscount = s.discount;
        pendingCustomerId = s.customer?.id;
        if (!mounted) return;
        // 2) customer approves on PayPal's page
        bool? approved;
        if (kIsWeb) {
          // Browsers can't embed PayPal in a WebView: open a new tab instead.
          final launched = await launchUrl(Uri.parse(order.approveUrl),
              webOnlyWindowName: '_blank');
          if (!launched) {
            throw PaymentException(
                'Could not open PayPal checkout. Allow pop-ups and try again.');
          }
          approved = await _confirm('PayPal',
              'Finish the payment in the new PayPal tab. When PayPal says it is approved, come back here and press "Payment received".');
        } else {
          approved = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                  builder: (_) => PaypalCheckoutPage(url: order.approveUrl)));
        }
        if (approved != true) {
          if (mounted) context.snack('Payment cancelled');
          return;
        }
        // 3) server captures the money, we only record the result
        ref = await PaypalService.capture(
            apiBase: s.apiBase, orderId: order.id, expectedUsd: order.usd);
        paymentCaptured = true;
      } else if (m == 'Mobile Money') {
        if (!await _confirm('Mobile Money',
            'Ask the customer to pay ${ugx(s.total)} to your MTN/Airtel merchant number, then confirm when the SMS arrives.')) {
          return;
        }
      } else if (m == 'Bank Transfer') {
        if (!await _confirm('Bank Transfer',
            'Confirm the ${ugx(s.total)} transfer has reached your account.'))
          return;
      } else {
        if (!await _confirm(
            'Cash', 'Collect ${ugx(s.total)} in cash from the customer.'))
          return;
      }

      final sale = await s.completeSale(m, paypalRef: ref);
      pendingOrder = null;
      pendingCart = null;
      pendingTax = null;
      pendingDiscount = null;
      pendingCustomerId = null;
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => PaymentSuccessPage(sale: sale)));
    } on PaymentException catch (e) {
      if (mounted) context.snack(e.message);
    } catch (_) {
      // Never show raw errors: they can contain server addresses.
      if (mounted) {
        context.snack(paymentCaptured
            ? 'Payment was received, but this sale could not be saved. Retry here to finish recording it.'
            : 'Payment could not be confirmed. Check PayPal activity before retrying.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: appBar(context, 'Payment', divider: true),
      body: Centered(
        maxWidth: 520,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 28, 20, 20), children: [
          const Center(
              child: Text('Total Amount',
                  style: TextStyle(fontSize: 13, color: C.grey))),
          const SizedBox(height: 10),
          Center(
              child: Text(ugx(s.total),
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: C.navy,
                      letterSpacing: -.5))),
          if (s.discount > 0) ...[
            const SizedBox(height: 10),
            Center(child: Pill('You saved ${ugx(s.discount)}', C.green)),
          ],
          const SizedBox(height: 30),
          for (final m in s.methods)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                onTap: busy ? null : () => s.setMethod(m),
                borderColor: s.payMethod == m ? context.primary : null,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  MethodIcon(m, size: 30),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(labels[m]![0],
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(labels[m]![1],
                            style:
                                const TextStyle(fontSize: 11.5, color: C.grey)),
                      ])),
                  Icon(
                      s.payMethod == m
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: s.payMethod == m ? context.primary : C.hint),
                ]),
              ),
            ),
          const SizedBox(height: 14),
          PrimaryButton('Pay Now',
              height: 50, loading: busy, onTap: busy ? null : _pay),
        ]),
      ),
    );
  }
}

// ─────────────────────── Payment success ───────────────────────
class PaymentSuccessPage extends StatelessWidget {
  final Sale sale;
  const PaymentSuccessPage({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    Widget row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Text(l, style: const TextStyle(fontSize: 12.5, color: C.grey)),
          const Spacer(),
          Flexible(
              child: Text(v,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600))),
        ]));

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Centered(
            maxWidth: 480,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                const Spacer(),
                Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: C.green.withValues(alpha: .12)),
                    child: const Center(
                        child: CircleAvatar(
                            radius: 36,
                            backgroundColor: C.green,
                            child: Icon(Icons.check_rounded,
                                color: Colors.white, size: 44)))),
                const SizedBox(height: 24),
                const Text('Payment Successful',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: C.navy)),
                const SizedBox(height: 6),
                Text('${ugx(sale.total)} received',
                    style: const TextStyle(fontSize: 14, color: C.grey)),
                const SizedBox(height: 26),
                AppCard(
                  child: Column(children: [
                    row('Receipt No', sale.receipt),
                    row(
                        'Date',
                        DateFormat('MMM d, yyyy · hh:mm a')
                            .format(sale.created)),
                    row('Payment Method', sale.method),
                    if (sale.discount > 0)
                      row('Discount', '-${ugx(sale.discount)}'),
                    row('Cashier',
                        sale.cashier.isEmpty ? s.userName : sale.cashier),
                    if (sale.paypalRef != null)
                      row('PayPal ref', sale.paypalRef!),
                  ]),
                ),
                const Spacer(),
                PrimaryButton('View Receipt',
                    icon: Icons.description_outlined,
                    outlined: true,
                    onTap: () => showReceipt(context, sale, s.businessName)),
                const SizedBox(height: 10),
                PrimaryButton('Back to Home',
                    onTap: () => Navigator.popUntil(context, (r) => r.isFirst)),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

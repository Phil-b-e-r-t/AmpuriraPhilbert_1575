import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// Plain-text version of a receipt (used for Copy / sharing).
String receiptText(Sale s, String business) {
  final df = DateFormat('MMM d, yyyy · hh:mm a');
  final b = StringBuffer()
    ..writeln(business)
    ..writeln('Receipt ${s.receipt}')
    ..writeln(df.format(s.created))
    ..writeln('Customer: ${s.customer}');
  if (s.cashier.isNotEmpty) b.writeln('Cashier: ${s.cashier}');
  b.writeln('------------------------');
  for (final l in s.lines) {
    b.writeln('${l.qty} x ${l.name}  ${ugx(l.price * l.qty)}');
  }
  b.writeln('------------------------');
  b.writeln('Subtotal: ${ugx(s.subtotal)}');
  if (s.discount > 0) b.writeln('Discount: -${ugx(s.discount)}');
  b.writeln('Tax: ${ugx(s.tax)}');
  b.writeln('TOTAL: ${ugx(s.total)}');
  b.writeln('Paid by ${s.method}');
  if (s.paypalRef != null) b.writeln('PayPal ref: ${s.paypalRef}');
  b.writeln('Thank you!');
  return b.toString();
}

/// Opens the receipt for any sale (after payment, from Home, from Reports > History).
Future<void> showReceipt(BuildContext context, Sale sale, String business) =>
    showSheet(context, 'Receipt ${sale.receipt}', _ReceiptBody(sale, business));

class _ReceiptBody extends StatefulWidget {
  final Sale sale;
  final String business;
  const _ReceiptBody(this.sale, this.business);
  @override
  State<_ReceiptBody> createState() => _ReceiptBodyState();
}

class _ReceiptBodyState extends State<_ReceiptBody> {
  bool copied = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.sale;
    Widget row(String l, String v, {Color? color, bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Text(l, style: TextStyle(fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: color)),
            const Spacer(),
            Text(v, style: TextStyle(fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.business, style: const TextStyle(fontWeight: FontWeight.w700)),
      Text(DateFormat('MMM d, yyyy · hh:mm a').format(s.created), style: const TextStyle(fontSize: 11, color: C.grey)),
      Text('Customer: ${s.customer}', style: const TextStyle(fontSize: 11, color: C.grey)),
      if (s.cashier.isNotEmpty) Text('Cashier: ${s.cashier}', style: const TextStyle(fontSize: 11, color: C.grey)),
      const Divider(height: 24),
      if (s.lines.isEmpty)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Item details were not recorded for this sale.', style: TextStyle(fontSize: 12, color: C.grey))),
      for (final l in s.lines)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${l.qty} × ${l.name}', style: const TextStyle(fontSize: 12)),
              if (l.listPrice > l.price)
                Text('was ${ugx(l.listPrice)} each', style: const TextStyle(fontSize: 10, color: C.green)),
            ])),
            Text(ugx(l.price * l.qty), style: const TextStyle(fontSize: 12)),
          ]),
        ),
      const Divider(height: 24),
      row('Subtotal', ugx(s.subtotal)),
      if (s.discount > 0) row('Discount', '-${ugx(s.discount)}', color: C.green),
      row('Tax', ugx(s.tax)),
      const SizedBox(height: 4),
      row('TOTAL', ugx(s.total), bold: true),
      const SizedBox(height: 6),
      Text('Paid by ${s.method}', style: const TextStyle(fontSize: 11, color: C.grey)),
      const SizedBox(height: 16),
      PrimaryButton(copied ? 'Copied ✓' : 'Copy receipt',
          icon: Icons.copy_outlined,
          outlined: true,
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: receiptText(s, widget.business)));
            if (mounted) setState(() => copied = true);
          }),
    ]);
  }
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'receipt.dart';

// ─────────────────────── Reports & Analytics (owner only, reads live data) ───────────────────────
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int type = 0, range = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!s.isOwner) {
      return Scaffold(
          appBar: appBar(context, 'Reports'),
          body: const EmptyState(Icons.lock_outline, 'Owners only', 'Reports are available to owners.'));
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final len = const [1, 7, 30][range];
    final start = today.subtract(Duration(days: len - 1));
    final prevStart = start.subtract(Duration(days: len));
    final list = s.sales.where((x) => !x.created.isBefore(start)).toList();
    final total = list.fold<int>(0, (a, b) => a + b.total);
    final discounts = list.fold<int>(0, (a, b) => a + b.discount);
    final taxes = list.fold<int>(0, (a, b) => a + b.tax);
    final avg = list.isEmpty ? 0 : (total / list.length).round();
    final prev = s.totalSince(prevStart, start);
    final pct = prev == 0 ? 0 : ((total - prev) / prev * 100).round();

    Widget bar(double h) => Container(
        width: 6,
        height: h,
        decoration: BoxDecoration(color: context.primary, borderRadius: BorderRadius.circular(2)));

    return Scaffold(
      appBar: appBar(context, 'Reports'),
      body: Centered(
        maxWidth: 900,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
          SegTabs(const ['Sales', 'Products', 'Payments', 'History'], type, (i) => setState(() => type = i)),
          const SizedBox(height: 10),
          SegTabs(const ['Today', 'Week', 'Month'], range, (i) => setState(() => range = i)),
          const SizedBox(height: 22),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Total Sales', style: TextStyle(fontSize: 12.5, color: C.grey)),
              const SizedBox(height: 6),
              Text(ugx(total), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: C.navy)),
              const SizedBox(height: 8),
              Text('${pct >= 0 ? '↑' : '↓'} ${pct.abs()}%', style: TextStyle(fontSize: 12, color: pct >= 0 ? C.green : C.red)),
            ])),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [bar(16), const SizedBox(width: 4), bar(26), const SizedBox(width: 4), bar(36)]),
          ]),
          const Divider(height: 28, color: C.divider),
          Row(children: [
            _Stat('Transactions', '${list.length}'),
            _Stat('Avg. sale', ugx(avg)),
            _Stat('Discounts', ugx(discounts)),
            _Stat('Tax', ugx(taxes)),
          ]),
          const SizedBox(height: 24),
          if (type == 0) ...[
            const SectionTitle('Sales Trend'),
            Padding(padding: const EdgeInsets.only(top: 6, right: 4), child: SizedBox(height: 200, child: _Trend(days: range == 2 ? 30 : 7))),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _MiniCard(Icons.trending_up, 'Top Products', () => setState(() => type = 1))),
              const SizedBox(width: 12),
              Expanded(child: _MiniCard(Icons.account_balance_wallet_outlined, 'Payment Methods', () => setState(() => type = 2))),
            ]),
          ],
          if (type == 1) ..._topProducts(list, s),
          if (type == 2) AppCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Column(children: _byMethod(list, total))),
          if (type == 3) ..._history(context, list, s),
        ]),
      ),
    );
  }

  List<Widget> _topProducts(List<Sale> list, AppState s) {
    final qty = <String, int>{}, rev = <String, int>{};
    for (final sale in list) {
      for (final l in sale.lines) {
        qty[l.name] = (qty[l.name] ?? 0) + l.qty;
        rev[l.name] = (rev[l.name] ?? 0) + l.qty * l.price;
      }
    }
    final names = qty.keys.toList()..sort((a, b) => rev[b]!.compareTo(rev[a]!));
    final reorder = s.products.where((p) => p.low).toList()..sort((a, b) => a.stock.compareTo(b.stock));
    return [
      const SectionTitle('Top Products'),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: names.isEmpty
            ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No product sales in this period yet.', style: TextStyle(color: C.grey, fontSize: 12.5))))
            : Column(children: [
                for (var i = 0; i < names.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: C.divider),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(radius: 15, backgroundColor: context.primary.withValues(alpha: .10), child: Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.primary))),
                    title: Text(names[i], style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                    subtitle: Text('${qty[names[i]]} sold', style: const TextStyle(fontSize: 11.5)),
                    trailing: Text(ugx(rev[names[i]]!), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ],
              ]),
      ),
      if (reorder.isNotEmpty) ...[
        const SizedBox(height: 20),
        const SectionTitle('Stock to reorder'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            for (var i = 0; i < reorder.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: C.divider),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(reorder[i].name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                subtitle: Text('Reorder level ${reorder[i].reorder}', style: const TextStyle(fontSize: 11.5)),
                trailing: reorder[i].stock == 0 ? const Pill('Out of stock', C.red) : Pill('${reorder[i].stock} left', C.amber),
              ),
            ],
          ]),
        ),
      ],
    ];
  }

  List<Widget> _byMethod(List<Sale> list, int total) {
    final m = <String, int>{};
    for (final x in list) {
      m[x.method] = (m[x.method] ?? 0) + x.total;
    }
    final keys = m.keys.toList()..sort((a, b) => m[b]!.compareTo(m[a]!));
    if (keys.isEmpty) return [const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No payments in this period yet.', style: TextStyle(color: C.grey, fontSize: 12.5))))];
    return [
      for (final k in keys)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(children: [
            Row(children: [
              MethodIcon(k, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(k, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500))),
              Text(ugx(m[k]!), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: total == 0 ? 0 : m[k]! / total, minHeight: 6, backgroundColor: C.divider)),
          ]),
        )
    ];
  }

  /// Every sale in the period; tap one to open its receipt.
  List<Widget> _history(BuildContext context, List<Sale> list, AppState s) {
    return [
      SectionTitle('Transactions',
          trailing: list.isEmpty
              ? null
              : TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _csv(list)));
                    if (context.mounted) context.snack('Copied ${list.length} sales — paste into Excel or Sheets');
                  },
                  icon: const Icon(Icons.table_chart_outlined, size: 16),
                  label: const Text('Copy CSV'))),
      list.isEmpty
          ? const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No sales in this period yet.', style: TextStyle(color: C.grey, fontSize: 12.5))))
          : Column(children: [
              for (var i = 0; i < list.take(100).length; i++) ...[
                if (i > 0) const Divider(height: 1, color: C.divider),
                InkWell(
                  onTap: () => showReceipt(context, list[i], s.businessName),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      MethodIcon(list[i].method, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(list[i].receipt, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('${list[i].customer} · ${DateFormat('MMM d, hh:mm a').format(list[i].created)}', style: const TextStyle(fontSize: 11, color: C.grey)),
                      ])),
                      Text(ugx(list[i].total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ],
            ]),
    ];
  }

  String _csv(List<Sale> list) {
    final b = StringBuffer('Receipt,Date,Customer,Cashier,Method,Subtotal,Discount,Tax,Total\n');
    for (final x in list) {
      b.writeln([
        x.receipt,
        DateFormat('yyyy-MM-dd HH:mm').format(x.created),
        x.customer,
        x.cashier,
        x.method,
        x.subtotal,
        x.discount,
        x.tax,
        x.total,
      ].map(_cell).join(','));
    }
    return b.toString();
  }

  /// Quotes CSV cells and neutralises spreadsheet formulas (=, +, -, @) in free-text fields.
  String _cell(Object? v) {
    var t = '$v';
    if (t.isNotEmpty && '=+-@'.contains(t[0]) && v is String) t = "'$t";
    return t.contains(',') || t.contains('"') || t.contains('\n') ? '"${t.replaceAll('"', '""')}"' : t;
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: C.grey)),
          const SizedBox(height: 3),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _MiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MiniCard(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        child: Row(children: [
          Icon(icon, color: context.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500))),
          const Icon(Icons.chevron_right, size: 18, color: C.hint),
        ]),
      );
}

class _Trend extends StatelessWidget {
  final int days;
  const _Trend({required this.days});
  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppState>().dailyTotals(days);
    final maxV = data.reduce((a, b) => a > b ? a : b);
    final maxY = maxV <= 0 ? 1.0 : maxV * 1.2;
    final today = DateTime.now();
    const ts = TextStyle(fontSize: 10, color: C.grey);
    return LineChart(LineChartData(
      minY: 0,
      maxY: maxY,
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: maxY / 2,
          getDrawingHorizontalLine: (_) => const FlLine(color: C.divider, strokeWidth: 1)),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: maxY / 2,
                getTitlesWidget: (v, _) => Text(NumberFormat.compact().format(v), style: ts))),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                interval: days > 7 ? 5 : 1,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= days) return const SizedBox();
                  final d = today.subtract(Duration(days: days - 1 - i));
                  return Padding(padding: const EdgeInsets.only(top: 6), child: Text(DateFormat('d').format(d), style: ts));
                })),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i])],
          isCurved: true,
          color: context.primary,
          barWidth: 2.5,
          dotData: FlDotData(show: days <= 7),
          belowBarData: BarAreaData(show: true, color: context.primary.withValues(alpha: .12)),
        )
      ],
    ));
  }
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

// ───────────────────────── 9. Reports & Analytics (real-time: reads live data) ─────────────────────────
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final len = const [1, 7, 30][range];
    final start = today.subtract(Duration(days: len - 1));
    final prevStart = start.subtract(Duration(days: len));
    final list = s.sales.where((x) => !x.created.isBefore(start)).toList();
    final total = list.fold<int>(0, (a, b) => a + b.total);
    final prev = s.totalSince(prevStart, start);
    final pct = prev == 0 ? 0 : ((total - prev) / prev * 100).round();

    return Scaffold(
      appBar: appBar(context, 'Reports'),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        SegTabs(const ['Sales', 'Products', 'Payments'], type, (i) => setState(() => type = i)),
        const SizedBox(height: 12),
        SegTabs(const ['Today', 'Week', 'Month'], range, (i) => setState(() => range = i)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
          child: Row(children: [
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Total Sales', style: TextStyle(fontSize: 12, color: C.grey)),
              const SizedBox(height: 6),
              Text(ugx(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.navy)),
              const SizedBox(height: 6),
              Text('${pct >= 0 ? '↑' : '↓'} ${pct.abs()}%  •  ${list.length} transactions',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: pct >= 0 ? C.green : C.red)),
            ])),
            for (final h in [16.0, 26.0, 36.0])
              Container(width: 6, height: h, margin: const EdgeInsets.only(left: 4), decoration: BoxDecoration(color: context.primary, borderRadius: BorderRadius.circular(3))),
          ]),
        ),
        const SizedBox(height: 22),
        if (type == 0) ...[
          const Text('Sales Trend', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          SizedBox(height: 190, child: _Trend(days: range == 2 ? 30 : 7)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _MiniCard(Icons.trending_up, 'Top Products', () => setState(() => type = 1))),
            const SizedBox(width: 10),
            Expanded(child: _MiniCard(Icons.account_balance_wallet_outlined, 'Payment Methods', () => setState(() => type = 2))),
          ]),
        ],
        if (type == 1) ..._topProducts(list),
        if (type == 2) ..._byMethod(list, total),
      ]),
    );
  }

  List<Widget> _topProducts(List list) {
    final qty = <String, int>{}, rev = <String, int>{};
    for (final sale in list) {
      for (final l in sale.lines) {
        qty[l.name] = (qty[l.name] ?? 0) + (l.qty as int);
        rev[l.name] = (rev[l.name] ?? 0) + (l.qty as int) * (l.price as int);
      }
    }
    final names = qty.keys.toList()..sort((a, b) => rev[b]!.compareTo(rev[a]!));
    if (names.isEmpty) return [const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No product sales in this period yet.', style: TextStyle(color: C.grey))))];
    return [
      for (final n in names)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(n, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text('${qty[n]} sold'),
          trailing: Text(ugx(rev[n]!), style: const TextStyle(fontWeight: FontWeight.w600)),
        )
    ];
  }

  List<Widget> _byMethod(List list, int total) {
    final m = <String, int>{};
    for (final x in list) {
      m[x.method] = (m[x.method] ?? 0) + (x.total as int);
    }
    final keys = m.keys.toList()..sort((a, b) => m[b]!.compareTo(m[a]!));
    if (keys.isEmpty) return [const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No payments in this period yet.', style: TextStyle(color: C.grey))))];
    return [
      for (final k in keys)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(children: [
            Row(children: [
              MethodIcon(k, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(k, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              Text(ugx(m[k]!), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: total == 0 ? 0 : m[k]! / total, minHeight: 6, backgroundColor: C.border)),
          ]),
        )
    ];
  }
}

class _MiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MiniCard(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: C.border), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(icon, color: context.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          ]),
        ),
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
          getDrawingHorizontalLine: (_) => const FlLine(color: C.border, strokeWidth: 1)),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
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

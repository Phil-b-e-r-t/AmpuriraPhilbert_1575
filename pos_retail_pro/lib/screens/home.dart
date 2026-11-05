import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_icons.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'inventory.dart';
import 'misc.dart';
import 'promotions.dart';
import 'receipt.dart';
import 'reports.dart';
import 'sales.dart';
import 'scanner.dart';
import 'settings.dart';
import 'staff.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int idx = 0;

  static const _dest = [
    (AppIcon(AppIcons.home), AppIcon(AppIcons.home), 'Home'),
    (AppIcon(AppIcons.cart), AppIcon(AppIcons.cart), 'Sales'),
    (AppIcon(AppIcons.inventory), AppIcon(AppIcons.inventory), 'Inventory'),
    (AppIcon(AppIcons.customers), AppIcon(AppIcons.customers), 'Customers'),
    (AppIcon(AppIcons.settings), AppIcon(AppIcons.settings), 'Settings'),
  ];

  Widget _banner(bool online) => online
      ? const SizedBox.shrink()
      : GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OfflinePage())),
          child: Container(
            width: double.infinity,
            color: C.amber,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 6, bottom: 6),
            child: const Text('Offline • sales and updates are saved on this device',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
        );

  @override
  Widget build(BuildContext context) {
    final online = context.select<AppState, bool>((s) => s.online);
    final pages = IndexedStack(index: idx, children: [
      HomePage(onGo: (i) => setState(() => idx = i)),
      const ProductSelectionPage(tab: true),
      const InventoryPage(tab: true),
      const CustomersPage(tab: true),
      const SettingsPage(tab: true),
    ]);
    final body = Column(children: [
      _banner(online),
      Expanded(child: MediaQuery.removePadding(context: context, removeTop: !online, child: pages)),
    ]);

    if (context.wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: idx,
            onDestinationSelected: (i) => setState(() => idx = i),
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.white,
            indicatorColor: context.primary.withValues(alpha: .12),
            selectedLabelTextStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.primary),
            unselectedLabelTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: C.grey),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: context.primary, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.storefront_rounded, color: Colors.white),
              ),
            ),
            destinations: [
              for (final d in _dest) NavigationRailDestination(icon: d.$1, selectedIcon: d.$2, label: Text(d.$3)),
            ],
          ),
          const VerticalDivider(width: 1, color: C.border),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => setState(() => idx = i),
        destinations: [
          for (final d in _dest) NavigationDestination(icon: d.$1, selectedIcon: d.$2, label: d.$3),
        ],
      ),
    );
  }
}

// ─────────────────────── Dashboard ───────────────────────
class HomePage extends StatelessWidget {
  final void Function(int) onGo;
  const HomePage({super.key, required this.onGo});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todays = s.sales.where((x) => !x.created.isBefore(today)).toList();
    final todayTotal = todays.fold<int>(0, (a, b) => a + b.total);
    final orders = todays.length;
    final avg = orders == 0 ? 0 : (todayTotal / orders).round();
    final yesterday = s.totalSince(today.subtract(const Duration(days: 1)), today);
    final pct = yesterday == 0 ? 0 : ((todayTotal - yesterday) / yesterday * 100).round();
    final greet = now.hour < 12 ? 'Good morning' : now.hour < 17 ? 'Good afternoon' : 'Good evening';
    final week = s.dailyTotals(7);
    final maxDay = week.fold<double>(0, (a, b) => a > b ? a : b);
    final lowCount = s.products.where((p) => p.low).length;
    final attention = s.alerts.where((a) => a.key != 'offline').take(3).toList();
    final initial = s.userName.isEmpty ? '?' : s.userName[0].toUpperCase();
    void push(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    Widget tile(String icon, String label, VoidCallback onTap) => AppCard(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          onTap: onTap,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: context.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)),
              child: AppIcon(icon, size: 22, color: context.primary),
            ),
            const SizedBox(height: 8),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        );

    Widget heroStat(String l, String v) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 3),
            Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
        );

    final actions = <Widget>[
      tile(AppIcons.cart, 'New Sale', () => onGo(1)),
      tile(AppIcons.scanQr, 'Scan & Sell', () => openSaleScanner(context)),
      tile(AppIcons.priceCheck, 'Price Check', () => openPriceCheck(context)),
      tile(AppIcons.inventory, 'Inventory', () => onGo(2)),
      tile(AppIcons.customers, 'Customers', () => onGo(3)),
      if (s.isOwner) ...[
        tile(AppIcons.reports, 'Reports', () => push(const ReportsPage())),
        tile(AppIcons.promotions, 'Promotions', () => push(const PromotionsPage())),
        tile(AppIcons.team, 'Team', () => push(const StaffPage())),
      ] else
        tile(AppIcons.alerts, 'Alerts', () => showNotifications(context)),
    ];

    return Scaffold(
      body: SafeArea(
        child: Centered(
          maxWidth: 1000,
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 28), children: [
            // ── header ──
            Row(children: [
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$greet · ${s.businessName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: C.grey)),
                const SizedBox(height: 2),
                Text(s.userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.5)),
              ])),
              Badge(
                isLabelVisible: s.unread > 0,
                label: Text('${s.unread}'),
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: C.border)),
                  child: IconButton(icon: const AppIcon(AppIcons.bell, size: 22, color: C.text), tooltip: 'Alerts', onPressed: () => showNotifications(context)),
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(radius: 21, backgroundColor: context.primary.withValues(alpha: .12), child: Text(initial, style: TextStyle(fontWeight: FontWeight.w800, color: context.primary))),
            ]),
            const SizedBox(height: 18),
            // ── today hero ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [context.primary, Color.lerp(context.primary, Colors.black, .38)!]),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Text("Today's sales", style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(20)),
                    child: Text('${pct >= 0 ? '↑' : '↓'} ${pct.abs()}% vs yesterday', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(ugx(todayTotal), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1)),
                const SizedBox(height: 18),
                SizedBox(
                  height: 64,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    for (var i = 0; i < week.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                            Container(
                              height: 6 + (maxDay <= 0 ? 0 : 38 * (week[i] / maxDay)),
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: i == week.length - 1 ? .95 : .35),
                                  borderRadius: BorderRadius.circular(5)),
                            ),
                            const SizedBox(height: 4),
                            Text(DateFormat('E').format(today.subtract(Duration(days: week.length - 1 - i))).substring(0, 1),
                                style: const TextStyle(color: Colors.white70, fontSize: 9.5)),
                          ]),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 14),
                Row(children: [heroStat('Orders', '$orders'), heroStat('Avg. sale', ugx(avg)), heroStat('Low stock', '$lowCount')]),
              ]),
            ),
            const SizedBox(height: 22),
            const SectionTitle('Quick actions'),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: .92,
              children: actions,
            ),
            if (attention.isNotEmpty) ...[
              const SizedBox(height: 22),
              SectionTitle('Needs attention',
                  trailing: TextButton(onPressed: () => showNotifications(context), child: const Text('View all'))),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(children: [
                  for (var i = 0; i < attention.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: C.border),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(children: [
                        CircleAvatar(
                            radius: 17,
                            backgroundColor: (attention[i].critical ? C.red : C.amber).withValues(alpha: .12),
                            child: Icon(attention[i].icon, size: 17, color: attention[i].critical ? C.red : C.amber)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(attention[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(attention[i].sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: C.grey)),
                        ])),
                      ]),
                    ),
                  ],
                ]),
              ),
            ],
            const SizedBox(height: 22),
            SectionTitle('Recent transactions',
                trailing: s.isOwner ? TextButton(onPressed: () => push(const ReportsPage()), child: const Text('View all')) : null),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: s.sales.isEmpty
                  ? const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No sales yet. Your first sale will appear here.', style: TextStyle(color: C.grey, fontSize: 12.5))))
                  : Column(children: [
                      for (var i = 0; i < s.sales.take(5).length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: C.border, indent: 12, endIndent: 12),
                        InkWell(
                          onTap: () => showReceipt(context, s.sales[i], s.businessName),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            child: Row(children: [
                              MethodIcon(s.sales[i].method, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(s.sales[i].customer, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                Text('${s.sales[i].method} · ${DateFormat('MMM d, hh:mm a').format(s.sales[i].created)}', style: const TextStyle(fontSize: 11, color: C.grey)),
                              ])),
                              Text(ugx(s.sales[i].total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                      ],
                    ]),
            ),
          ]),
        ),
      ),
    );
  }
}

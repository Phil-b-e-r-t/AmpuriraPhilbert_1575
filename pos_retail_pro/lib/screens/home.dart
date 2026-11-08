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

/// Three dots icon for the "More" tab (same stroke style as the other app icons).
const _moreSvg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000000" '
    'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
    '<circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/></svg>';

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
    (AppIcon(AppIcons.team), AppIcon(AppIcons.team), 'Customers'),
    (AppIcon(_moreSvg), AppIcon(_moreSvg), 'More'),
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
            indicatorColor: Colors.transparent,
            selectedLabelTextStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.primary),
            unselectedLabelTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: C.grey),
            selectedIconTheme: IconThemeData(size: 22, color: context.primary),
            unselectedIconTheme: const IconThemeData(size: 22, color: C.grey),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: context.primary, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.storefront_rounded, color: Colors.white),
              ),
            ),
            destinations: [
              for (final d in _dest) NavigationRailDestination(icon: d.$1, selectedIcon: d.$2, label: Text(d.$3)),
            ],
          ),
          const VerticalDivider(width: 1, color: C.divider),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.divider))),
        child: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: (i) => setState(() => idx = i),
          destinations: [
            for (final d in _dest) NavigationDestination(icon: d.$1, selectedIcon: d.$2, label: d.$3),
          ],
        ),
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
    final greet = now.hour < 12 ? 'Good Morning' : now.hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final week = s.dailyTotals(7);
    final maxDay = week.fold<double>(0, (a, b) => a > b ? a : b);
    final lowCount = s.products.where((p) => p.low).length;
    final attention = s.alerts.where((a) => a.key != 'offline').take(3).toList();
    void push(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    Widget tile(String icon, String label, VoidCallback onTap) => AppCard(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          onTap: onTap,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: context.primary.withValues(alpha: .12), shape: BoxShape.circle),
              child: AppIcon(icon, size: 21, color: context.primary),
            ),
            const SizedBox(height: 8),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
          ]),
        );

    Widget heroStat(String l, String v) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 3),
            Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
          ]),
        );

    Widget head(String t, {VoidCallback? onAll}) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Expanded(child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            if (onAll != null)
              InkWell(
                  onTap: onAll,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(padding: const EdgeInsets.all(4), child: Text('View All', style: TextStyle(fontSize: 12.5, color: context.primary)))),
          ]),
        );

    final actions = <Widget>[
      tile(AppIcons.cart, 'New Sale', () => onGo(1)),
      tile(AppIcons.inventory, 'Inventory', () => onGo(2)),
      tile(AppIcons.team, 'Customers', () => onGo(3)),
      if (s.isOwner) tile(AppIcons.reports, 'Reports', () => push(const ReportsPage())) else tile(AppIcons.alerts, 'Alerts', () => showNotifications(context)),
      tile(AppIcons.scanQr, 'Scan & Sell', () => openSaleScanner(context)),
      tile(AppIcons.priceCheck, 'Price Check', () => openPriceCheck(context)),
      if (s.isOwner) ...[
        tile(AppIcons.promotions, 'Promotions', () => push(const PromotionsPage())),
        tile(AppIcons.customers, 'Team', () => push(const StaffPage())),
      ],
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
                Text('$greet,\n${s.userName}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.25)),
                if (s.businessName.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(s.businessName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: C.grey))),
              ])),
              Badge(
                isLabelVisible: s.unread > 0,
                label: Text('${s.unread}'),
                child: IconButton(icon: const AppIcon(AppIcons.bell, size: 22, color: C.text), tooltip: 'Alerts', onPressed: () => showNotifications(context)),
              ),
              const SizedBox(width: 6),
              CircleAvatar(radius: 18, backgroundColor: context.primary, child: const AppIcon(AppIcons.customers, size: 18, color: Colors.white)),
            ]),
            const SizedBox(height: 18),
            // ── today hero ──
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(color: context.primary, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Today's Sales", style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                    const SizedBox(height: 8),
                    Text(ugx(todayTotal), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -.5)),
                    const SizedBox(height: 10),
                    Text('${pct >= 0 ? '↑' : '↓'} ${pct.abs()}% vs yesterday', style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                  ])),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 44,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      for (var i = 0; i < week.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Container(
                            width: 6,
                            height: 8 + (maxDay <= 0 ? 0 : 36 * (week[i] / maxDay)),
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: i == week.length - 1 ? .95 : .45),
                                borderRadius: BorderRadius.circular(2)),
                          ),
                        ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 12),
                Row(children: [heroStat('Orders', '$orders'), heroStat('Avg. sale', ugx(avg)), heroStat('Low stock', '$lowCount')]),
              ]),
            ),
            const SizedBox(height: 14),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: context.wide ? 4 : 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 92),
              children: actions,
            ),
            if (attention.isNotEmpty) ...[
              const SizedBox(height: 22),
              head('Needs attention', onAll: () => showNotifications(context)),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(children: [
                  for (var i = 0; i < attention.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: C.divider),
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
            head('Recent Transactions', onAll: s.isOwner ? () => push(const ReportsPage()) : null),
            if (s.sales.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No sales yet. Your first sale will appear here.', style: TextStyle(color: C.grey, fontSize: 12.5))))
            else
              Column(children: [
                for (var i = 0; i < s.sales.take(5).length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: C.divider),
                  InkWell(
                    onTap: () => showReceipt(context, s.sales[i], s.businessName),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(children: [
                        MethodIcon(s.sales[i].method, size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.sales[i].customer, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
                          Text(s.sales[i].method, style: const TextStyle(fontSize: 11, color: C.grey)),
                        ])),
                        const SizedBox(width: 8),
                        Text(ugx(s.sales[i].total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 14),
                        SizedBox(
                          width: 60,
                          child: Text(
                              DateTime(s.sales[i].created.year, s.sales[i].created.month, s.sales[i].created.day) == today
                                  ? DateFormat('hh:mm a').format(s.sales[i].created)
                                  : DateFormat('MMM d').format(s.sales[i].created),
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontSize: 11, color: C.grey)),
                        ),
                      ]),
                    ),
                  ),
                ],
              ]),
          ]),
        ),
      ),
    );
  }
}

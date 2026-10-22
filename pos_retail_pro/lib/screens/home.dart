import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'inventory.dart';
import 'misc.dart';
import 'reports.dart';
import 'sales.dart';
import 'settings.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int idx = 0;

  @override
  Widget build(BuildContext context) {
    final online = context.select<AppState, bool>((s) => s.online);
    return Scaffold(
      body: Column(children: [
        if (!online)
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OfflinePage())),
            child: Container(
              width: double.infinity,
              color: C.amber,
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 6, bottom: 6),
              child: const Text('Working offline • sales will sync automatically',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: !online,
            child: IndexedStack(index: idx, children: [
              HomePage(onGo: (i) => setState(() => idx = i)),
              const ProductSelectionPage(tab: true),
              const InventoryPage(tab: true),
              const CustomersPage(tab: true),
              const SettingsPage(tab: true),
            ]),
          ),
        ),
      ]),
      bottomNavigationBar: NavigationBar(
        height: 64,
        backgroundColor: Colors.white,
        selectedIndex: idx,
        onDestinationSelected: (i) => setState(() => idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: 'Sales'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Inventory'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Customers'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final void Function(int) onGo;
  const HomePage({super.key, required this.onGo});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayTotal = s.totalSince(today);
    final yesterday = s.totalSince(today.subtract(const Duration(days: 1)), today);
    final pct = yesterday == 0 ? 0 : ((todayTotal - yesterday) / yesterday * 100).round();
    final greet = now.hour < 12 ? 'Good morning' : now.hour < 17 ? 'Good afternoon' : 'Good evening';

    Widget tile(IconData i, String label, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 88,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.border)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircleAvatar(
                    radius: 20,
                    backgroundColor: context.primary.withValues(alpha: .1),
                    child: Icon(i, size: 22, color: context.primary)),
                const SizedBox(height: 8),
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: Text('$greet,\n${s.userName} 👋',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.3))),
            Badge(
              isLabelVisible: s.unread > 0,
              label: Text('${s.unread}'),
              child: IconButton(
                  icon: const Icon(Icons.notifications_none),
                  onPressed: () => showNotifications(context)),
            ),
            const SizedBox(width: 6),
            CircleAvatar(
                radius: 14,
                backgroundColor: C.border,
                child: const Icon(Icons.person, size: 16, color: C.grey)),
          ]),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: C.navy, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Today's Sales", style: TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 6),
                Text(ugx(todayTotal),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('${pct >= 0 ? '↑' : '↓'} ${pct.abs()}%',
                    style: TextStyle(
                        color: pct >= 0 ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ])),
              for (final h in [16.0, 26.0, 36.0])
                Container(
                    width: 6,
                    height: h,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .6), borderRadius: BorderRadius.circular(3))),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            tile(Icons.shopping_cart_outlined, 'New Sale', () => onGo(1)),
            const SizedBox(width: 10),
            tile(Icons.inventory_2_outlined, 'Inventory', () => onGo(2)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            tile(Icons.people_outline, 'Customers', () => onGo(3)),
            const SizedBox(width: 10),
            tile(Icons.bar_chart, 'Reports',
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsPage()))),
          ]),
          const SizedBox(height: 22),
          Row(children: [
            const Expanded(
                child: Text('Recent Transactions',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
            GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsPage())),
                child: Text('View All',
                    style: TextStyle(fontSize: 12, color: context.primary, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 8),
          for (final x in s.sales.take(3)) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                MethodIcon(x.method, size: 24),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(x.method == 'Cash' ? 'Cash Sale' : x.method == 'Card' ? 'Card Payment' : x.method,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(ugx(x.total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(DateFormat('hh:mm a').format(x.created),
                      style: const TextStyle(fontSize: 11, color: C.grey)),
                ]),
              ]),
            ),
            const Divider(height: 1, color: C.border),
          ],
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

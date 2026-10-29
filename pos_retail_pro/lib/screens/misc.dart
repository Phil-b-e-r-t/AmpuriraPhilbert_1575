import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

// ───────────────────────── Overlay / Notifications ─────────────────────────
void showNotifications(BuildContext context) {
  Widget row(IconData i, String t, String sub, String when) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          CircleAvatar(backgroundColor: context.primary.withValues(alpha: .1), child: Icon(i, size: 18, color: context.primary)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(sub, style: const TextStyle(fontSize: 12, color: C.grey)),
          ])),
          Text(when, style: const TextStyle(fontSize: 11, color: C.grey)),
        ]),
      );
  // These are sample items. Hook them to real events (low stock, payments, sync) later.
  showSheet(
      context,
      'Notifications',
      Column(children: [
        row(Icons.inventory_2_outlined, 'Low stock: Sprite 500ml', 'Only 12 units left', '2m ago'),
        const Divider(height: 1, color: C.border),
        row(Icons.credit_card, 'Payment received', 'UGX 120,000 via Card', '15m ago'),
        const Divider(height: 1, color: C.border),
        row(Icons.check, 'Local data saved', 'Sales are stored on this device', '1h ago'),
        const SizedBox(height: 14),
        Builder(
            builder: (ctx) => PrimaryButton('Mark all as read', outlined: true, onTap: () {
                  context.read<AppState>().markAllRead();
                  Navigator.pop(ctx);
                })),
      ]));
}

// ───────────────────────── 11. Offline Mode ─────────────────────────
class OfflinePage extends StatelessWidget {
  const OfflinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(children: [
          const Spacer(),
          CircleAvatar(radius: 52, backgroundColor: C.amber.withValues(alpha: .15), child: const Icon(Icons.wifi_off, size: 56, color: C.amber)),
          const SizedBox(height: 32),
          Text(s.online ? "You're back online" : "You're Offline", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          const Text(
              'Your products, customers, and sales are stored on this device and remain available offline. Sign in while online at least once. Internet is also needed for PayPal payments.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: C.grey, height: 1.5)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: C.green.withValues(alpha: .1), borderRadius: BorderRadius.circular(22)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle, size: 18, color: C.green),
              const SizedBox(width: 8),
              Text(
                s.online ? 'Internet connection available' : 'Local data is ready',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.green),
              ),
            ]),
          ),
          const Spacer(),
          PrimaryButton('Retry Connection', icon: Icons.refresh, onTap: () async {
            await context.read<AppState>().recheck();
            if (context.mounted && context.read<AppState>().online) Navigator.pop(context);
          }),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }
}

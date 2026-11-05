import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'promotions.dart';
import 'staff.dart';

// ─────────────────────── Settings ───────────────────────
class SettingsPage extends StatelessWidget {
  final bool tab;
  const SettingsPage({super.key, this.tab = false});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    Widget item(IconData i, String t, String sub, VoidCallback onTap) => ListTile(
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: context.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)),
            child: Icon(i, size: 20, color: context.primary),
          ),
          title: Text(t, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          subtitle: Text(sub, style: const TextStyle(fontSize: 11.5, color: C.grey)),
          trailing: const Icon(Icons.chevron_right, color: C.grey),
          onTap: onTap,
        );
    Widget group(List<Widget> items) => AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: C.border, indent: 68),
              items[i],
            ],
          ]),
        );
    final initial = s.userName.isEmpty ? '?' : s.userName[0].toUpperCase();

    return Scaffold(
      appBar: appBar(context, 'Settings', back: !tab),
      body: Centered(
        maxWidth: 640,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              CircleAvatar(radius: 28, backgroundColor: context.primary.withValues(alpha: .12), child: Text(initial, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.primary))),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(s.userEmail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.grey)),
                const SizedBox(height: 8),
                Pill(s.isOwner ? 'Owner' : 'Cashier', context.primary),
              ])),
            ]),
          ),
          const SizedBox(height: 18),
          if (s.isOwner) ...[
            const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: Text('BUSINESS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: C.grey, letterSpacing: .8))),
            group([
              item(Icons.storefront_outlined, 'Business profile', s.businessName, () => go(const BusinessProfilePage())),
              item(Icons.credit_card, 'Payment methods', '${s.methods.length} enabled', () => go(const PaymentMethodsPage())),
              item(Icons.local_offer_outlined, 'Promotions & discounts', '${s.promotions.where((p) => p.live).length} active', () => go(const PromotionsPage())),
              item(Icons.groups_outlined, 'Staff & roles', '${s.staff.length} team members', () => go(const StaffPage())),
            ]),
            const SizedBox(height: 18),
          ],
          const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: Text('ACCOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: C.grey, letterSpacing: .8))),
          group([
            item(Icons.lock_reset, 'Change password', 'Send a reset link to your email', () async {
              final err = await context.read<AppState>().sendPasswordReset(s.userEmail);
              if (context.mounted) context.snack(err ?? 'Password reset email sent to ${s.userEmail}');
            }),
            item(Icons.info_outline, 'About', 'POS Retail Pro 1.1.0', () => showAboutDialog(context: context, applicationName: 'POS Retail Pro', applicationVersion: '1.1.0')),
          ]),
          const SizedBox(height: 22),
          PrimaryButton('Log out', outlined: true, color: C.red, icon: Icons.logout, onTap: () async {
            await context.read<AppState>().logout();
            if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
          }),
        ]),
      ),
    );
  }
}

// ─────────────────────── Business profile ───────────────────────
class BusinessProfilePage extends StatefulWidget {
  const BusinessProfilePage({super.key});
  @override
  State<BusinessProfilePage> createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends State<BusinessProfilePage> {
  late final name = TextEditingController(text: context.read<AppState>().businessName);
  late String type = context.read<AppState>().businessType;
  late Color color = context.read<AppState>().themeColor;
  static const swatches = [C.blue, C.navy, C.green, Color(0xFF7C3AED), Color(0xFFEA580C), C.red];
  static const types = ['Retail Store', 'Restaurant', 'Pharmacy', 'Supermarket', 'Salon', 'Other'];

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBar(context, 'Business Profile'),
        body: Centered(
          maxWidth: 560,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const FieldLabel('Business name'),
                AppField('My Store', controller: name),
                const FieldLabel('Business type'),
                DropdownButtonFormField<String>(
                  initialValue: types.contains(type) ? type : types.first,
                  decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border))),
                  items: types.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => type = v ?? type),
                ),
                const FieldLabel('Theme colour'),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final c in swatches)
                    GestureDetector(
                      onTap: () => setState(() => color = c),
                      child: CircleAvatar(radius: 18, backgroundColor: c, child: color == c ? const Icon(Icons.check, color: Colors.white, size: 18) : null),
                    ),
                ]),
              ]),
            ),
            const SizedBox(height: 20),
            PrimaryButton('Save', onTap: () async {
              await context.read<AppState>().saveProfile(name.text.trim().isEmpty ? 'My Store' : name.text.trim(), type, color);
              if (context.mounted) Navigator.pop(context);
            }),
          ]),
        ),
      );
}

/// Which payment methods the cashier can choose at the till.
/// Server addresses, keys and database settings are NOT shown here: they are configured
/// on the backend / at build time and are never visible to the app user.
class PaymentMethodsPage extends StatelessWidget {
  const PaymentMethodsPage({super.key});

  static const _desc = {
    'Cash': 'Always available',
    'Card': 'Credit / debit card',
    'Mobile Money': 'MTN / Airtel',
    'Bank Transfer': 'Confirm when the transfer arrives',
    'PayPal': 'Online payment',
  };

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: appBar(context, 'Payment Methods'),
      body: Centered(
        maxWidth: 560,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
              child: Text('Choose the ways customers can pay at the till.', style: TextStyle(fontSize: 12.5, color: C.grey))),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final m in s.backendMethods)
                SwitchListTile(
                  secondary: Icon(methodIcon(m), color: C.grey),
                  title: Text(m, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  subtitle: Text(_desc[m] ?? '', style: const TextStyle(fontSize: 11.5)),
                  value: s.isMethodEnabled(m),
                  onChanged: m == 'Cash' ? null : (v) => s.setMethodEnabled(m, v),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

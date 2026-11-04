import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'promotions.dart';
import 'staff.dart';

// ─────────────────────── 10. Settings ───────────────────────
class SettingsPage extends StatelessWidget {
  final bool tab;
  const SettingsPage({super.key, this.tab = false});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    Widget item(IconData i, String t, VoidCallback onTap) => Column(children: [
          ListTile(
              leading: Icon(i, size: 20, color: C.grey),
              title: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              trailing: const Icon(Icons.chevron_right, color: C.grey),
              onTap: onTap),
          const Divider(height: 1, color: C.border, indent: 20, endIndent: 20),
        ]);
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    return Scaffold(
      appBar: appBar(context, 'Settings', back: !tab),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(children: [
            CircleAvatar(radius: 30, backgroundColor: context.primary.withValues(alpha: .1), child: Icon(Icons.person, size: 32, color: context.primary)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.userName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${s.userEmail} • ${s.role}', style: const TextStyle(fontSize: 12, color: C.grey)),
            ])),
          ]),
        ),
        const Divider(height: 1, color: C.border),
        if (s.isOwner) ...[
          item(Icons.storefront_outlined, 'Business Profile', () => go(const BusinessProfilePage())),
          item(Icons.credit_card, 'Payment Methods', () => go(const PaymentMethodsPage())),
          item(Icons.local_offer_outlined, 'Promotions & Discounts', () => go(const PromotionsPage())),
          item(Icons.people_outline, 'Staff & Roles', () => go(const StaffPage())),
        ],
        item(Icons.lock_reset, 'Change Password', () async {
          final err = await context.read<AppState>().sendPasswordReset(s.userEmail);
          if (context.mounted) context.snack(err ?? 'Password reset email sent to ${s.userEmail}');
        }),
        item(Icons.info_outline, 'About', () => showAboutDialog(context: context, applicationName: 'POS Retail Pro', applicationVersion: '1.1.0')),
        Padding(
          padding: const EdgeInsets.all(20),
          child: PrimaryButton('Log out', outlined: true, color: C.red, onTap: () async {
            await context.read<AppState>().logout();
            if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
          }),
        ),
      ]),
    );
  }
}

// ─────────────────────── 12. Business Profile ───────────────────────
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
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const FieldLabel('Business Name'),
          AppField('My Store', controller: name),
          const FieldLabel('Business Type'),
          DropdownButtonFormField<String>(
            initialValue: types.contains(type) ? type : types.first,
            decoration: InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            items: types.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => type = v ?? type),
          ),
          const FieldLabel('Logo'),
          Row(children: [
            Container(
                width: 76,
                height: 74,
                decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
                child: Icon(Icons.storefront, color: color, size: 34)),
            const SizedBox(width: 16),
            // To enable logo upload add the image_picker package.
            TextButton(onPressed: () => context.snack('Add image_picker to enable logo upload'), child: const Text('Change')),
          ]),
          const FieldLabel('Theme Color'),
          Wrap(spacing: 12, children: [
            for (final c in swatches)
              GestureDetector(
                onTap: () => setState(() => color = c),
                child: CircleAvatar(radius: 16, backgroundColor: c, child: color == c ? const Icon(Icons.check, color: Colors.white, size: 16) : null),
              ),
          ]),
          const SizedBox(height: 30),
          PrimaryButton('Save', onTap: () async {
            await context.read<AppState>().saveProfile(name.text.trim().isEmpty ? 'My Store' : name.text.trim(), type, color);
            if (context.mounted) Navigator.pop(context);
          }),
        ]),
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
      body: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
        const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text('Choose the ways customers can pay at the till.', style: TextStyle(fontSize: 12, color: C.grey))),
        for (final m in s.backendMethods)
          SwitchListTile(
            secondary: Icon(methodIcon(m), color: C.grey),
            title: Text(m, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            subtitle: Text(_desc[m] ?? '', style: const TextStyle(fontSize: 11)),
            value: s.isMethodEnabled(m),
            onChanged: m == 'Cash' ? null : (v) => s.setMethodEnabled(m, v),
          ),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

// ─────────────────────── User Management: team & roles (owner only) ───────────────────────
class StaffPage extends StatelessWidget {
  const StaffPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!s.isOwner) {
      return Scaffold(
          appBar: appBar(context, 'Staff & Roles'),
          body: const Center(child: Text('Only owners can manage the team.', style: TextStyle(color: C.grey))));
    }
    final me = s.userEmail.toLowerCase();

    Future<void> run(Future<String?> f) async {
      final err = await f;
      if (err != null && context.mounted) context.snack(err);
    }

    return Scaffold(
      appBar: appBar(context, 'Staff & Roles'),
      floatingActionButton: FloatingActionButton(
        backgroundColor: context.primary,
        foregroundColor: Colors.white,
        onPressed: () => showSheet(context, 'Add Team Member', const _StaffForm()),
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 90), children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
          child: const Text(
              'Owners can manage inventory, promotions, reports and the team. Cashiers can sell, scan, look up prices and view alerts.\n\n'
              'A team member gets the role listed here when they sign in or create an account with the same email. '
              'Anyone who is not listed is treated as a cashier.',
              style: TextStyle(fontSize: 12, color: C.grey, height: 1.5)),
        ),
        const SizedBox(height: 10),
        for (final m in s.staff) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
                backgroundColor: context.primary.withValues(alpha: .1),
                child: Icon(m.role == 'owner' ? Icons.verified_user_outlined : Icons.person_outline, color: context.primary)),
            title: Text(m.email == me ? '${m.name} (you)' : m.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('${m.email} · ${m.role == 'owner' ? 'Owner' : 'Cashier'}', style: const TextStyle(fontSize: 11)),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'owner' || v == 'cashier') run(s.setStaffRole(m, v));
                if (v == 'remove') run(s.removeStaff(m));
              },
              itemBuilder: (_) => [
                if (m.role != 'owner') const PopupMenuItem(value: 'owner', child: Text('Make owner')),
                if (m.role != 'cashier') const PopupMenuItem(value: 'cashier', child: Text('Make cashier')),
                if (m.email != me) const PopupMenuItem(value: 'remove', child: Text('Remove', style: TextStyle(color: C.red))),
              ],
            ),
          ),
          const Divider(height: 1, color: C.border),
        ],
      ]),
    );
  }
}

class _StaffForm extends StatefulWidget {
  const _StaffForm();
  @override
  State<_StaffForm> createState() => _StaffFormState();
}

class _StaffFormState extends State<_StaffForm> {
  final name = TextEditingController(), email = TextEditingController();
  String role = 'cashier';
  String? err;
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      busy = true;
      err = null;
    });
    final e = await context.read<AppState>().addStaff(name.text, email.text, role);
    if (!mounted) return;
    if (e != null) {
      setState(() {
        err = e;
        busy = false;
      });
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const FieldLabel('Full name'),
        AppField('e.g. Sarah Nakato', controller: name),
        const FieldLabel('Email they sign in with'),
        AppField('name@email.com', controller: email, type: TextInputType.emailAddress),
        const FieldLabel('Role'),
        SegTabs(const ['Cashier', 'Owner'], role == 'owner' ? 1 : 0, (i) => setState(() => role = i == 1 ? 'owner' : 'cashier')),
        if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: const TextStyle(color: C.red, fontSize: 12))),
        const SizedBox(height: 20),
        PrimaryButton('Add Member', loading: busy, onTap: busy ? null : _save),
      ]);
}

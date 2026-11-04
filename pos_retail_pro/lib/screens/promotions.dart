import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

// ─────────────────────── Discounts & Promotions (owner only) ───────────────────────
class PromotionsPage extends StatelessWidget {
  const PromotionsPage({super.key});

  String _status(Promotion p) {
    if (!p.active) return 'Paused';
    if (p.expired) return 'Expired';
    if (p.ends == null) return 'No end date';
    return 'Ends ${DateFormat('MMM d, yyyy').format(p.ends!)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!s.isOwner) {
      return Scaffold(
          appBar: appBar(context, 'Promotions'),
          body: const Center(child: Text('Only owners can manage promotions.', style: TextStyle(color: C.grey))));
    }
    String scope(Promotion p) {
      if (p.cartLevel) return 'Whole cart · code ${p.code}';
      final m = s.products.where((x) => x.id == p.productId);
      return m.isEmpty ? 'Item removed' : m.first.name;
    }

    return Scaffold(
      appBar: appBar(context, 'Promotions & Discounts'),
      floatingActionButton: FloatingActionButton(
        backgroundColor: context.primary,
        foregroundColor: Colors.white,
        onPressed: () => showSheet(context, 'New Promotion', const _PromoForm()),
        child: const Icon(Icons.add),
      ),
      body: s.promotions.isEmpty
          ? const Center(
              child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                      'No promotions yet.\nTap + to discount an item automatically, or create a promo code for the whole cart.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: C.grey, height: 1.5))))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
              itemCount: s.promotions.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: C.border),
              itemBuilder: (_, i) {
                final p = s.promotions[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${p.name} — ${p.label}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('${scope(p)}\n${_status(p)}', style: TextStyle(fontSize: 11, color: p.live ? C.grey : C.red)),
                  isThreeLine: true,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Switch(value: p.active, onChanged: (v) => s.setPromotionActive(p, v)),
                    IconButton(
                        icon: const Icon(Icons.delete_outline, color: C.red, size: 20),
                        tooltip: 'Delete',
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                        title: const Text('Delete promotion?'),
                                        content: Text(p.name),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: C.red))),
                                        ],
                                      )) ??
                              false;
                          if (ok) await s.deletePromotion(p);
                        }),
                  ]),
                );
              },
            ),
    );
  }
}

class _PromoForm extends StatefulWidget {
  const _PromoForm();
  @override
  State<_PromoForm> createState() => _PromoFormState();
}

class _PromoFormState extends State<_PromoForm> {
  final name = TextEditingController(), value = TextEditingController(), code = TextEditingController();
  int kindIdx = 0; // 0 = percent, 1 = amount
  String scope = ''; // '' = whole cart (needs a code), otherwise a product id
  DateTime? ends;
  String? err;
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    value.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context,
        initialDate: ends ?? now.add(const Duration(days: 7)),
        firstDate: now,
        lastDate: now.add(const Duration(days: 1095)));
    if (d != null) setState(() => ends = DateTime(d.year, d.month, d.day, 23, 59, 59));
  }

  Future<void> _save() async {
    final v = int.tryParse(value.text.trim());
    if (v == null) {
      setState(() => err = 'Enter the discount as a whole number');
      return;
    }
    setState(() {
      busy = true;
      err = null;
    });
    final e = await context.read<AppState>().addPromotion(
        name: name.text,
        kind: kindIdx == 0 ? 'percent' : 'amount',
        value: v,
        code: code.text,
        productId: scope,
        ends: ends);
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
  Widget build(BuildContext context) {
    final products = context.read<AppState>().products;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const FieldLabel('Promotion name'),
      AppField('e.g. Weekend special', controller: name),
      const FieldLabel('Discount type'),
      SegTabs(const ['Percent %', 'Amount (UGX)'], kindIdx, (i) => setState(() => kindIdx = i)),
      const FieldLabel('Discount value'),
      AppField(kindIdx == 0 ? 'e.g. 10' : 'e.g. 500', controller: value, type: TextInputType.number),
      const FieldLabel('Applies to'),
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: scope,
        decoration: InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        items: [
          const DropdownMenuItem(value: '', child: Text('Whole cart (needs a promo code)')),
          for (final p in products) DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => setState(() => scope = v ?? ''),
      ),
      if (scope.isEmpty) ...[
        const FieldLabel('Promo code'),
        AppField('e.g. SAVE10', controller: code),
      ] else
        const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Applied automatically to this item at the till.', style: TextStyle(fontSize: 11, color: C.grey))),
      const FieldLabel('End date (optional)'),
      PrimaryButton(ends == null ? 'No end date — tap to set one' : 'Ends ${DateFormat('MMM d, yyyy').format(ends!)}',
          outlined: true, icon: Icons.event_outlined, onTap: _pickDate),
      if (ends != null)
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setState(() => ends = null), child: const Text('Clear end date'))),
      if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: const TextStyle(color: C.red, fontSize: 12))),
      const SizedBox(height: 20),
      PrimaryButton('Save Promotion', loading: busy, onTap: busy ? null : _save),
    ]);
  }
}

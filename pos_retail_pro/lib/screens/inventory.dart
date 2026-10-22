import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

// ───────────────────────── 7. Inventory Management ─────────────────────────
class InventoryPage extends StatefulWidget {
  final bool tab;
  const InventoryPage({super.key, this.tab = false});
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  int tabIdx = 0;
  String q = '';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final list = s.products.where((p) {
      final okTab = tabIdx == 0 || (tabIdx == 1 && p.low && p.stock > 0) || (tabIdx == 2 && p.stock == 0);
      return okTab && p.name.toLowerCase().contains(q.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: appBar(context, 'Inventory', back: !widget.tab),
      floatingActionButton: !s.isOwner ? null : FloatingActionButton(
        backgroundColor: context.primary,
        foregroundColor: Colors.white,
        onPressed: () => showSheet(context, 'Add Item', const _AddItemForm()),
        child: const Icon(Icons.add),
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 10), child: SegTabs(const ['All', 'Low Stock', 'Out of Stock'], tabIdx, (i) => setState(() => tabIdx = i))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: AppField('Search inventory...', icon: Icons.search, onChanged: (v) => setState(() => q = v))),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: C.border),
            itemBuilder: (_, i) {
              final p = list[i];
              return InkWell(
                onTap: !s.isOwner ? null : () => showSheet(context, p.name, _EditStock(p)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: [
                    ProductImage(p.image, w: 28, h: 48),
                    const SizedBox(width: 18),
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('Stock: ${p.stock}    Reorder: ${p.reorder}', style: TextStyle(fontSize: 11, color: p.low ? C.red : C.grey)),
                    ])),
                    const Icon(Icons.chevron_right, color: C.grey),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _EditStock extends StatefulWidget {
  final Product p;
  const _EditStock(this.p);
  @override
  State<_EditStock> createState() => _EditStockState();
}

class _EditStockState extends State<_EditStock> {
  late final c = TextEditingController(text: '${widget.p.stock}');
  String? err;
  bool busy = false;
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => busy = true);
    final e = await context.read<AppState>().updateStock(widget.p, int.tryParse(c.text) ?? widget.p.stock);
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
        Text('Price: ${ugx(widget.p.price)}', style: const TextStyle(color: C.grey, fontSize: 12)),
        const FieldLabel('Stock quantity'),
        AppField('0', controller: c, type: TextInputType.number),
        if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: const TextStyle(color: C.red, fontSize: 12))),
        const SizedBox(height: 18),
        PrimaryButton('Update Stock', loading: busy, onTap: busy ? null : _save),
      ]);
}

// Overlay / Add Item
class _AddItemForm extends StatefulWidget {
  const _AddItemForm();
  @override
  State<_AddItemForm> createState() => _AddItemFormState();
}

class _AddItemFormState extends State<_AddItemForm> {
  final n = TextEditingController(), p = TextEditingController(), st = TextEditingController();
  String cat = 'Drinks';
  String? err;
  bool busy = false;
  @override
  void dispose() {
    n.dispose();
    p.dispose();
    st.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = int.tryParse(p.text), stock = int.tryParse(st.text);
    if (n.text.trim().isEmpty || price == null || stock == null) {
      setState(() => err = 'Fill in name, price and stock');
      return;
    }
    setState(() {
      busy = true;
      err = null;
    });
    final e = await context.read<AppState>().addProduct(n.text.trim(), price, stock, cat);
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
        const FieldLabel('Item name'),
        AppField('e.g. Coca Cola 500ml', controller: n),
        const FieldLabel('Price (UGX)'),
        AppField('0', controller: p, type: TextInputType.number),
        const FieldLabel('Stock quantity'),
        AppField('0', controller: st, type: TextInputType.number),
        const FieldLabel('Category'),
        DropdownButtonFormField<String>(
          initialValue: cat,
          decoration: InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
          items: const ['Drinks', 'Food', 'Snacks', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => cat = v ?? cat),
        ),
        if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: const TextStyle(color: C.red, fontSize: 12))),
        const SizedBox(height: 20),
        PrimaryButton('Save Item', loading: busy, onTap: busy ? null : _save),
      ]);
}

// ───────────────────────── 8. Customer Management ─────────────────────────
class CustomersPage extends StatefulWidget {
  final bool tab;
  const CustomersPage({super.key, this.tab = false});
  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final list = s.customers.where((c) => c.name.toLowerCase().contains(q.toLowerCase()) || c.phone.contains(q)).toList();
    return Scaffold(
      appBar: appBar(context, 'Customers', back: !widget.tab),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 6), child: AppField('Search customers...', icon: Icons.search, onChanged: (v) => setState(() => q = v))),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: C.border),
            itemBuilder: (_, i) {
              final c = list[i];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(backgroundColor: context.primary.withValues(alpha: .1), child: Icon(Icons.person, color: context.primary)),
                title: Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(c.phone, style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: C.grey),
                onTap: () {
                  s.setCustomer(c);
                  context.snack('${c.name} selected for the next sale');
                },
              );
            },
          ),
        ),
        SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: PrimaryButton('+ Add Customer', onTap: () => showSheet(context, 'Add Customer', const _AddCustomerForm())))),
      ]),
    );
  }
}

class _AddCustomerForm extends StatefulWidget {
  const _AddCustomerForm();
  @override
  State<_AddCustomerForm> createState() => _AddCustomerFormState();
}

class _AddCustomerFormState extends State<_AddCustomerForm> {
  final n = TextEditingController(), p = TextEditingController(), e = TextEditingController();
  String? err;
  bool busy = false;
  @override
  void dispose() {
    n.dispose();
    p.dispose();
    e.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (n.text.trim().isEmpty || p.text.trim().isEmpty) {
      setState(() => err = 'Name and phone are required');
      return;
    }
    setState(() {
      busy = true;
      err = null;
    });
    final r = await context.read<AppState>().addCustomer(n.text.trim(), p.text.trim(), e.text.trim());
    if (!mounted) return;
    if (r != null) {
      setState(() {
        err = r;
        busy = false;
      });
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const FieldLabel('Full name'),
        AppField('e.g. John Mwangi', controller: n),
        const FieldLabel('Phone number'),
        AppField('+256 7XX XXX XXX', controller: p, type: TextInputType.phone),
        const FieldLabel('Email (optional)'),
        AppField('name@email.com', controller: e, type: TextInputType.emailAddress),
        if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: const TextStyle(color: C.red, fontSize: 12))),
        const SizedBox(height: 20),
        PrimaryButton('Save Customer', loading: busy, onTap: busy ? null : _save),
      ]);
}

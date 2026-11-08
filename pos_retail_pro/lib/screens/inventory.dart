import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_icons.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'scanner.dart';

// ─────────────────────── Inventory ───────────────────────
class InventoryPage extends StatefulWidget {
  final bool tab;
  const InventoryPage({super.key, this.tab = false});
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  int tabIdx = 0;
  String q = '';

  void _open(Product p, bool owner) => showSheet(context, p.name, owner ? _ProductForm(product: p) : _ProductInfo(p));

  /// Scan a barcode: open the product if it exists, otherwise (owners) start adding it.
  Future<void> _scan() async {
    final code = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const ScannerPage(title: 'Scan product')));
    if (code == null || !mounted) return;
    final s = context.read<AppState>();
    final p = s.productByBarcode(code);
    if (p != null) {
      _open(p, s.isOwner);
    } else if (s.isOwner) {
      showSheet(context, 'Add Item', _ProductForm(barcode: code));
    } else {
      context.snack('No product found for "$code"');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final query = q.trim().toLowerCase();
    final lowCount = s.products.where((p) => p.low && p.stock > 0).length;
    final outCount = s.products.where((p) => p.stock <= 0).length;
    final value = s.products.fold<int>(0, (a, p) => a + p.price * p.stock);
    final list = s.products.where((p) {
      final okTab = tabIdx == 0 || (tabIdx == 1 && p.low && p.stock > 0) || (tabIdx == 2 && p.stock == 0);
      return okTab && (p.name.toLowerCase().contains(query) || p.barcode.toLowerCase().contains(query));
    }).toList();

    return Scaffold(
      appBar: appBar(context, 'Inventory', back: !widget.tab, actions: [
        IconButton(icon: const Icon(Icons.qr_code_scanner), tooltip: 'Scan product', onPressed: _scan),
      ]),
      floatingActionButton: !s.isOwner
          ? null
          : FloatingActionButton(
              backgroundColor: context.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: const CircleBorder(),
              tooltip: 'Add item',
              onPressed: () => showSheet(context, 'Add Item', const _ProductForm()),
              child: const Icon(Icons.add),
            ),
      body: Centered(
        maxWidth: 900,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: SegTabs(['All (${s.products.length})', 'Low ($lowCount)', 'Out ($outCount)'], tabIdx, (i) => setState(() => tabIdx = i)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: AppField('Search name or barcode', icon: Icons.search, soft: true, onChanged: (v) => setState(() => q = v)),
          ),
          if (s.isOwner)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 18, color: context.primary),
                  const SizedBox(width: 10),
                  const Text('Stock value (at selling price)', style: TextStyle(fontSize: 12, color: C.grey)),
                  const Spacer(),
                  Text(ugx(value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(Icons.inventory_2_outlined, 'No items found', 'Add products, or change the search and filter.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: C.divider),
                    itemBuilder: (_, i) {
                      final p = list[i];
                      final out = p.stock <= 0;
                      return InkWell(
                        onTap: () => _open(p, s.isOwner),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(children: [
                            ProductImage(p.image, name: p.name, w: 34, h: 56),
                            const SizedBox(width: 16),
                            Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text('Stock: ${p.stock}    Reorder: ${p.reorder}', style: const TextStyle(fontSize: 12, color: C.grey)),
                              const SizedBox(height: 6),
                              Wrap(spacing: 6, runSpacing: 4, children: [
                                Pill(p.category, C.grey),
                                if (out) const Pill('Out of stock', C.red) else if (p.low) Pill('Low · ${p.stock} left', C.amber),
                              ]),
                              if (p.barcode.isNotEmpty)
                                Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Row(children: [
                                      const Icon(Icons.qr_code_2, size: 12, color: C.grey),
                                      const SizedBox(width: 4),
                                      Text(p.barcode, style: const TextStyle(fontSize: 10.5, color: C.grey)),
                                    ])),
                            ])),
                            const SizedBox(width: 8),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(ugx(s.unitPrice(p)), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              if (s.unitDiscount(p) > 0)
                                Text(ugx(p.price), style: const TextStyle(fontSize: 10.5, color: C.hint, decoration: TextDecoration.lineThrough)),
                            ]),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 20, color: C.hint),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

/// Read-only product card (cashiers).
class _ProductInfo extends StatelessWidget {
  final Product p;
  const _ProductInfo(this.p);
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    Widget row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [Text(l, style: const TextStyle(fontSize: 12.5, color: C.grey)), const Spacer(), Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))]));
    return Column(children: [
      row('Price', ugx(s.unitPrice(p))),
      if (s.unitDiscount(p) > 0) row('Regular price', ugx(p.price)),
      row('In stock', '${p.stock}'),
      row('Category', p.category),
      if (p.barcode.isNotEmpty) row('Barcode', p.barcode),
    ]);
  }
}

/// Add a new item, or edit an existing one (price, stock, reorder level, category, barcode).
class _ProductForm extends StatefulWidget {
  final Product? product;
  final String barcode;
  const _ProductForm({this.product, this.barcode = ''});
  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  late final n = TextEditingController(text: widget.product?.name ?? '');
  late final p = TextEditingController(text: widget.product == null ? '' : '${widget.product!.price}');
  late final st = TextEditingController(text: widget.product == null ? '' : '${widget.product!.stock}');
  late final re = TextEditingController(text: '${widget.product?.reorder ?? 10}');
  late final bc = TextEditingController(text: widget.product?.barcode ?? widget.barcode);
  late String cat = widget.product?.category ?? 'Drinks';
  String? err;
  bool busy = false;
  bool get editing => widget.product != null;

  @override
  void dispose() {
    n.dispose();
    p.dispose();
    st.dispose();
    re.dispose();
    bc.dispose();
    super.dispose();
  }

  Future<void> _scanCode() async {
    final code = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const ScannerPage(title: 'Scan product code')));
    if (code != null && mounted) setState(() => bc.text = code);
  }

  Future<void> _save() async {
    final price = int.tryParse(p.text.trim()), stock = int.tryParse(st.text.trim()), reorder = int.tryParse(re.text.trim());
    if (n.text.trim().isEmpty || price == null || stock == null || reorder == null) {
      setState(() => err = 'Fill in name, price, stock and reorder level');
      return;
    }
    setState(() {
      busy = true;
      err = null;
    });
    final s = context.read<AppState>();
    final e = editing
        ? await s.updateProduct(widget.product!,
            name: n.text, price: price, stock: stock, reorder: reorder, category: cat, barcode: bc.text)
        : await s.addProduct(n.text, price, stock, cat, barcode: bc.text, reorder: reorder);
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

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
                  title: const Text('Delete item?'),
                  content: Text('${widget.product!.name} will be removed from inventory. Past sales and receipts are kept.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: C.red))),
                  ],
                )) ??
        false;
    if (!ok || !mounted) return;
    final e = await context.read<AppState>().deleteProduct(widget.product!);
    if (!mounted) return;
    if (e != null) {
      setState(() => err = e);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cats = <String>{'Drinks', 'Food', 'Snacks', 'Other', ...s.products.map((e) => e.category), cat}.toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const FieldLabel('Item name'),
      AppField('e.g. Coca Cola 500ml', controller: n),
      const FieldLabel('Barcode / QR code (optional)'),
      AppField('Scan or type the code',
          controller: bc,
          suffix: IconButton(icon: const Icon(Icons.qr_code_scanner, size: 20), tooltip: 'Scan', onPressed: _scanCode)),
      const FieldLabel('Price (UGX)'),
      AppField('0', controller: p, type: TextInputType.number),
      Row(children: [
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const FieldLabel('Stock quantity'),
          AppField('0', controller: st, type: TextInputType.number),
        ])),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const FieldLabel('Low-stock alert at'),
          AppField('10', controller: re, type: TextInputType.number),
        ])),
      ]),
      const FieldLabel('Category'),
      DropdownButtonFormField<String>(
        initialValue: cat,
        decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border, width: 1.2))),
        items: cats.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (v) => setState(() => cat = v ?? cat),
      ),
      if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: const TextStyle(color: C.red, fontSize: 12))),
      const SizedBox(height: 20),
      PrimaryButton(editing ? 'Save changes' : 'Save Item', loading: busy, onTap: busy ? null : _save),
      if (editing) ...[
        const SizedBox(height: 10),
        PrimaryButton('Delete item', outlined: true, color: C.red, onTap: busy ? null : _delete),
      ],
    ]);
  }
}

// ─────────────────────── Customers ───────────────────────
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: PrimaryButton('Add Customer',
              icon: Icons.add, height: 46, onTap: () => showSheet(context, 'Add Customer', const _AddCustomerForm())),
        ),
      ),
      body: Centered(
        maxWidth: 900,
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 6), child: AppField('Search customers', icon: Icons.search, soft: true, onChanged: (v) => setState(() => q = v))),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(Icons.people_outline, 'No customers yet', 'Add customers to attach them to sales.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: C.divider),
                    itemBuilder: (_, i) {
                      final c = list[i];
                      return InkWell(
                        onTap: () {
                          s.setCustomer(c);
                          context.snack('${c.name} selected for the next sale');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(children: [
                            const CircleAvatar(radius: 18, backgroundColor: C.hint, child: AppIcon(AppIcons.customers, size: 20, color: Colors.white)),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 3),
                              Text(c.phone, style: const TextStyle(fontSize: 12, color: C.grey)),
                            ])),
                            if (s.customer?.id == c.id) const Pill('Selected', C.green) else const Icon(Icons.chevron_right, size: 20, color: C.hint),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
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

import 'dart:convert';
import 'package:intl/intl.dart';

class Product {
  final String id;
  String name, category, image, barcode;
  int price, stock, reorder;
  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.reorder = 10,
    this.category = 'Other',
    this.image = '',
    this.barcode = '',
  });

  factory Product.fromMap(Map<String, Object?> m) => Product(
        id: m['id'] as String,
        name: m['name'] as String,
        price: m['price'] as int,
        stock: m['stock'] as int,
        reorder: (m['reorder'] as int?) ?? 10,
        category: (m['category'] as String?) ?? 'Other',
        image: (m['image'] as String?) ?? '',
        barcode: (m['barcode'] as String?) ?? '',
      );

  Map<String, Object?> toMap() => {
        'id': id, 'name': name, 'price': price, 'stock': stock,
        'reorder': reorder, 'category': category, 'image': image,
        'barcode': barcode,
      };

  bool get low => stock <= reorder;
}

class Customer {
  final String id;
  final String name, phone, email;
  Customer({required this.id, required this.name, required this.phone, this.email = ''});

  factory Customer.fromMap(Map<String, Object?> m) => Customer(
        id: m['id'] as String,
        name: m['name'] as String,
        phone: m['phone'] as String,
        email: (m['email'] as String?) ?? '',
      );

  Map<String, Object?> toMap() => {'id': id, 'name': name, 'phone': phone, 'email': email};
}

/// A discount rule.
///  • productId set  → applies automatically to that product (per unit).
///  • productId empty → whole-cart discount, applied when its [code] is entered at checkout.
class Promotion {
  final String id;
  String name, code, kind, productId; // kind: 'percent' | 'amount'
  int value;
  bool active;
  DateTime? ends;
  Promotion({
    required this.id,
    required this.name,
    required this.kind,
    required this.value,
    this.code = '',
    this.productId = '',
    this.active = true,
    this.ends,
  });

  bool get cartLevel => productId.isEmpty;
  bool get expired => ends != null && DateTime.now().isAfter(ends!);
  bool get live => active && !expired;

  /// Discount in UGX this promotion gives on [amount] (never more than the amount).
  int discountFor(int amount) {
    final d = kind == 'percent' ? (amount * value / 100).round() : value;
    if (d < 0) return 0;
    return d > amount ? amount : d;
  }

  String get label =>
      kind == 'percent' ? '$value% off' : 'UGX ${NumberFormat('#,###').format(value)} off';

  factory Promotion.fromJson(Map<String, dynamic> j) => Promotion(
        id: j['id'] as String,
        name: j['name'] as String,
        kind: (j['kind'] as String?) ?? 'percent',
        value: (j['value'] as int?) ?? 0,
        code: (j['code'] as String?) ?? '',
        productId: (j['productId'] as String?) ?? '',
        active: (j['active'] as bool?) ?? true,
        ends: j['ends'] == null ? null : DateTime.fromMillisecondsSinceEpoch(j['ends'] as int),
      );

  Map<String, Object?> toJson() => {
        'id': id, 'name': name, 'kind': kind, 'value': value, 'code': code,
        'productId': productId, 'active': active,
        'ends': ends?.millisecondsSinceEpoch,
      };
}

/// Someone on the team and the role they get when they sign in with [email].
class StaffMember {
  final String id;
  String name, email, role; // role: 'owner' | 'cashier'
  StaffMember({required this.id, required this.name, required this.email, required this.role});

  factory StaffMember.fromJson(Map<String, dynamic> j) => StaffMember(
        id: j['id'] as String,
        name: j['name'] as String,
        email: (j['email'] as String).toLowerCase(),
        role: (j['role'] as String?) ?? 'cashier',
      );

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'email': email, 'role': role};
}

class SaleLine {
  final String productId, name;
  final int price, qty, listPrice; // price = unit price actually charged (after promotions)
  SaleLine(this.productId, this.name, this.price, this.qty, {int? listPrice})
      : listPrice = listPrice ?? price;
  Map<String, Object?> toJson() => {
        'productId': productId, 'name': name, 'price': price, 'qty': qty,
        'listPrice': listPrice,
      };
  factory SaleLine.fromJson(Map<String, dynamic> j) => SaleLine(
        j['productId'], j['name'], j['price'], j['qty'],
        listPrice: j['listPrice'] as int?,
      );
}

class Sale {
  final String id, receipt, method, customer, cashier;
  final int total, tax, discount;
  final DateTime created;
  final List<SaleLine> lines;
  final String? paypalRef;
  bool synced;
  Sale({
    required this.id,
    required this.receipt,
    required this.method,
    required this.customer,
    required this.total,
    required this.tax,
    required this.created,
    required this.lines,
    this.discount = 0,
    this.cashier = '',
    this.paypalRef,
    this.synced = false,
  });

  /// Amount before discounts and tax.
  int get subtotal => total - tax + discount;

  factory Sale.fromMap(Map<String, Object?> m) => Sale(
        id: m['id'] as String,
        receipt: m['receipt'] as String,
        method: m['method'] as String,
        customer: m['customer'] as String,
        total: m['total'] as int,
        tax: m['tax'] as int,
        discount: (m['discount'] as int?) ?? 0,
        cashier: (m['cashier'] as String?) ?? '',
        created: DateTime.fromMillisecondsSinceEpoch(m['created'] as int),
        synced: m['synced'] == 1,
        paypalRef: m['paypal_ref'] as String?,
        lines: (jsonDecode(m['items'] as String) as List)
            .map((e) => SaleLine.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  factory Sale.fromServer(Map<String, dynamic> j) => Sale(
        id: j['id'] as String,
        receipt: j['receipt'] as String,
        method: j['method'] as String,
        customer: (j['customer'] as String?) ?? 'Walk-in Customer',
        total: j['total'] as int,
        tax: j['tax'] as int,
        discount: (j['discount'] as int?) ?? 0,
        cashier: (j['cashier'] as String?) ?? '',
        created: DateTime.parse(j['created'] as String).toLocal(),
        paypalRef: j['paypalRef'] as String?,
        synced: true,
        lines: ((j['lines'] as List?) ?? [])
            .map((e) => SaleLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  Map<String, Object?> toMap() => {
        'id': id, 'receipt': receipt, 'method': method, 'customer': customer,
        'total': total, 'tax': tax, 'discount': discount, 'cashier': cashier,
        'created': created.millisecondsSinceEpoch,
        'synced': synced ? 1 : 0, 'paypal_ref': paypalRef,
        'items': jsonEncode(lines.map((e) => e.toJson()).toList()),
      };

  Map<String, Object?> toJson() => {
        'id': id, 'receipt': receipt, 'method': method, 'customer': customer,
        'total': total, 'tax': tax, 'discount': discount, 'cashier': cashier,
        'created': created.toUtc().toIso8601String(),
        'paypalRef': paypalRef, 'lines': lines.map((e) => e.toJson()).toList(),
      };
}

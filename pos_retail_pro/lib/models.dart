import 'dart:convert';

class Product {
  final String id;
  String name, category, image;
  int price, stock, reorder;
  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.reorder = 10,
    this.category = 'Other',
    this.image = '',
  });

  factory Product.fromMap(Map<String, Object?> m) => Product(
        id: m['id'] as String,
        name: m['name'] as String,
        price: m['price'] as int,
        stock: m['stock'] as int,
        reorder: m['reorder'] as int,
        category: m['category'] as String,
        image: (m['image'] as String?) ?? '',
      );

  Map<String, Object?> toMap() => {
        'id': id, 'name': name, 'price': price, 'stock': stock,
        'reorder': reorder, 'category': category, 'image': image,
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

class SaleLine {
  final String productId, name;
  final int price, qty;
  SaleLine(this.productId, this.name, this.price, this.qty);
  Map<String, Object?> toJson() =>
      {'productId': productId, 'name': name, 'price': price, 'qty': qty};
  factory SaleLine.fromJson(Map<String, dynamic> j) =>
      SaleLine(j['productId'], j['name'], j['price'], j['qty']);
}

class Sale {
  final String id, receipt, method, customer;
  final int total, tax;
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
    this.paypalRef,
    this.synced = false,
  });

  factory Sale.fromMap(Map<String, Object?> m) => Sale(
        id: m['id'] as String,
        receipt: m['receipt'] as String,
        method: m['method'] as String,
        customer: m['customer'] as String,
        total: m['total'] as int,
        tax: m['tax'] as int,
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
        created: DateTime.parse(j['created'] as String).toLocal(),
        paypalRef: j['paypalRef'] as String?,
        synced: true,
        lines: ((j['lines'] as List?) ?? [])
            .map((e) => SaleLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  Map<String, Object?> toMap() => {
        'id': id, 'receipt': receipt, 'method': method, 'customer': customer,
        'total': total, 'tax': tax, 'created': created.millisecondsSinceEpoch,
        'synced': synced ? 1 : 0, 'paypal_ref': paypalRef,
        'items': jsonEncode(lines.map((e) => e.toJson()).toList()),
      };

  Map<String, Object?> toJson() => {
        'id': id, 'receipt': receipt, 'method': method, 'customer': customer,
        'total': total, 'tax': tax, 'created': created.toUtc().toIso8601String(),
        'paypalRef': paypalRef, 'lines': lines.map((e) => e.toJson()).toList(),
      };
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'models.dart';

/// Android/iOS: SQLite file.  Chrome/Edge (web): browser storage.  Same API for both.
const seedDemoData = true; // demo data now comes from the server (SEED_DEMO in server/.env)

class Db {
  static Database? _d;
  static Future<Database> get d async => _d ??= await _open();

  // ───────── demo data (shared by both back-ends) ─────────
  static Map<String, List<Map<String, Object?>>> _seedData() {
    final products = [
      Product(id: 'p1', name: 'Coca Cola 500ml', price: 2500, stock: 50, reorder: 20, category: 'Drinks', image: 'assets/images/coke.png'),
      Product(id: 'p2', name: 'Sprite 500ml', price: 2500, stock: 40, reorder: 20, category: 'Drinks', image: 'assets/images/sprite.png'),
      Product(id: 'p3', name: 'Water 500ml', price: 1500, stock: 100, reorder: 30, category: 'Drinks', image: 'assets/images/water.png'),
      Product(id: 'p4', name: 'Bread', price: 3000, stock: 30, reorder: 10, category: 'Food', image: 'assets/images/bread.png'),
      Product(id: 'p5', name: 'Chips', price: 2000, stock: 45, reorder: 15, category: 'Snacks', image: 'assets/images/chips.png'),
    ];
    final customers = [
      Customer(id: 'c1', name: 'John Mwangi', phone: '+256 700 123 456'),
      Customer(id: 'c2', name: 'Sarah Nakato', phone: '+256 772 987 654'),
      Customer(id: 'c3', name: 'David Kato', phone: '+256 703 456 789'),
      Customer(id: 'c4', name: 'Aisha Namuindwa', phone: '+256 751 234 567'),
      Customer(id: 'c5', name: 'Peter Ssemanda', phone: '+256 787 654 321'),
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sales = <Sale>[];
    void sale(DateTime when, int total, String method) {
      final n = sales.length + 1;
      sales.add(Sale(
        id: 'seed$n', receipt: '#INV-${n.toString().padLeft(5, '0')}', method: method,
        customer: 'Walk-in Customer', total: total, tax: (total * 0.18 / 1.18).round(),
        created: when, lines: [], synced: true,
      ));
    }
    final past = [1450000, 1100000, 1300000, 900000, 1600000, 1200000];
    for (var i = 0; i < past.length; i++) {
      sale(today.subtract(Duration(days: past.length - i)).add(const Duration(hours: 14)), past[i], 'Cash');
    }
    sale(today.add(const Duration(hours: 8, minutes: 30)), 1005000, 'Bank Transfer');
    sale(today.add(const Duration(hours: 9, minutes: 15)), 80000, 'Mobile Money');
    sale(today.add(const Duration(hours: 9, minutes: 50)), 120000, 'Card');
    sale(today.add(const Duration(hours: 10, minutes: 24)), 45000, 'Cash');
    return {
      'products': products.map((e) => e.toMap()).toList(),
      'customers': customers.map((e) => e.toMap()).toList(),
      'sales': sales.map((e) => e.toMap()).toList(),
    };
  }

  // ───────── native (SQLite) ─────────
  static Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'pos_retail_pro.db');
    return openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute(
          'CREATE TABLE products(id TEXT PRIMARY KEY, name TEXT, price INTEGER, stock INTEGER, reorder INTEGER, category TEXT, image TEXT)');
      await db.execute(
          'CREATE TABLE customers(id TEXT PRIMARY KEY, name TEXT, phone TEXT, email TEXT)');
      await db.execute(
          'CREATE TABLE sales(id TEXT PRIMARY KEY, receipt TEXT, total INTEGER, tax INTEGER, method TEXT, customer TEXT, created INTEGER, synced INTEGER, items TEXT, paypal_ref TEXT)');
      if (seedDemoData) {
        final b = db.batch();
        _seedData().forEach((table, rows) {
          for (final r in rows) {
            b.insert(table, r);
          }
        });
        await b.commit(noResult: true);
      }
    });
  }

  // ───────── web (browser storage) ─────────
  static Future<List<Map<String, Object?>>> _wl(String t) async {
    final sp = await SharedPreferences.getInstance();
    if (!(sp.getBool('web_init') ?? false)) {
      final seed = seedDemoData
          ? _seedData()
          : <String, List<Map<String, Object?>>>{'products': [], 'customers': [], 'sales': []};
      for (final e in seed.entries) {
        await sp.setString('tbl_${e.key}', jsonEncode(e.value));
      }
      await sp.setBool('web_init', true);
    }
    final raw = sp.getString('tbl_$t') ?? '[]';
    return (jsonDecode(raw) as List).map((e) => Map<String, Object?>.from(e as Map)).toList();
  }

  static Future<void> _ws(String t, List<Map<String, Object?>> rows) async =>
      (await SharedPreferences.getInstance()).setString('tbl_$t', jsonEncode(rows));

  static Future<void> _wUpsert(String t, Map<String, Object?> row) async {
    final rows = await _wl(t);
    final i = rows.indexWhere((r) => r['id'] == row['id']);
    if (i >= 0) {
      rows[i] = row;
    } else {
      rows.add(row);
    }
    await _ws(t, rows);
  }

  // ───────── public API (same for every platform) ─────────
  static Future<List<Product>> products() async {
    if (kIsWeb) {
      final r = (await _wl('products')).map(Product.fromMap).toList();
      r.sort((a, b) => a.name.compareTo(b.name));
      return r;
    }
    return (await (await d).query('products', orderBy: 'name')).map(Product.fromMap).toList();
  }

  static Future<List<Customer>> customers() async {
    if (kIsWeb) {
      final r = (await _wl('customers')).map(Customer.fromMap).toList();
      r.sort((a, b) => a.name.compareTo(b.name));
      return r;
    }
    return (await (await d).query('customers', orderBy: 'name')).map(Customer.fromMap).toList();
  }

  static Future<List<Sale>> sales() async {
    if (kIsWeb) {
      final r = (await _wl('sales')).map(Sale.fromMap).toList();
      r.sort((a, b) => b.created.compareTo(a.created));
      return r;
    }
    return (await (await d).query('sales', orderBy: 'created DESC')).map(Sale.fromMap).toList();
  }

  static Future<void> saveProduct(Product x) async => kIsWeb
      ? _wUpsert('products', x.toMap())
      : (await d).insert('products', x.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<void> saveCustomer(Customer x) async => kIsWeb
      ? _wUpsert('customers', x.toMap())
      : (await d).insert('customers', x.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<void> markSynced(String id) async {
    if (kIsWeb) {
      final rows = await _wl('sales');
      for (final r in rows) {
        if (r['id'] == id) r['synced'] = 1;
      }
      await _ws('sales', rows);
      return;
    }
    await (await d).update('sales', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  /// Replaces the local copy with what the server sent. Sales still waiting to upload are kept.
  static Future<void> replaceAll({
    required List<Product> products,
    required List<Customer> customers,
    required List<Sale> sales,
  }) async {
    if (kIsWeb) {
      await _ws('products', products.map((e) => e.toMap()).toList());
      await _ws('customers', customers.map((e) => e.toMap()).toList());
      final keep = (await _wl('sales')).where((r) => r['synced'] != 1).toList();
      final ids = keep.map((r) => r['id']).toSet();
      await _ws('sales', [...keep, ...sales.where((s) => !ids.contains(s.id)).map((e) => e.toMap())]);
      return;
    }
    final db = await d;
    await db.transaction((t) async {
      await t.delete('products');
      await t.delete('customers');
      await t.delete('sales', where: 'synced = 1');
      for (final x in products) {
        await t.insert('products', x.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final x in customers) {
        await t.insert('customers', x.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final x in sales) {
        await t.insert('sales', x.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Saves the sale and reduces stock together.
  static Future<void> saveSale(Sale s, List<Product> changed) async {
    if (kIsWeb) {
      await _wUpsert('sales', s.toMap());
      for (final x in changed) {
        await _wUpsert('products', x.toMap());
      }
      return;
    }
    final db = await d;
    await db.transaction((t) async {
      await t.insert('sales', s.toMap());
      for (final x in changed) {
        await t.update('products', {'stock': x.stock}, where: 'id = ?', whereArgs: [x.id]);
      }
    });
  }
}

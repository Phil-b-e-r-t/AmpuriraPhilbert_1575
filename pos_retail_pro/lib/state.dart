import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'api.dart';
import 'db.dart';
import 'models.dart';
import 'theme.dart';

/// Set API_BASE_URL at build time for a deployed server. Local web and mobile
/// clients use this development machine's Wi-Fi address.
const _configuredApiBase = String.fromEnvironment('API_BASE_URL');
const _staleLanApiBase = 'http://192.168.1.10:3000';
const _oldWebApiBase = 'http://localhost:3000';
const defaultApiBase = _configuredApiBase != ''
    ? _configuredApiBase
    : 'http://192.168.206.31:3000';
const taxRate = 0.18;

class AppState extends ChangeNotifier {
  List<Product> products = [];
  List<Customer> customers = [];
  List<Sale> sales = [];
  final Map<String, int> cart = {};
  Customer? customer; // null = Walk-in
  String method = 'Cash';
  bool online = true;
  int unread = 3;

  // session
  bool loggedIn = false;
  String userName = '', userEmail = '', role = 'cashier';
  bool get isOwner => role == 'owner';

  // settings
  Color themeColor = C.blue;
  String businessName = 'My Store';
  String businessType = 'Retail Store';
  String apiBase = defaultApiBase;

  static const _secure = FlutterSecureStorage();
  SharedPreferences? _prefs;
  StreamSubscription? _sub;
  Timer? _timer;
  bool _syncing = false;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    themeColor = Color(_prefs!.getInt('theme') ?? C.blue.toARGB32());
    businessName = _prefs!.getString('bizName') ?? businessName;
    businessType = _prefs!.getString('bizType') ?? businessType;
    final savedApiBase = _prefs!.getString('apiBase');
    if (savedApiBase == _staleLanApiBase ||
        (kIsWeb && savedApiBase == _oldWebApiBase)) {
      apiBase = defaultApiBase;
      await _prefs!.setString('apiBase', apiBase);
    } else {
      apiBase = savedApiBase ?? apiBase;
    }
    Api.base = apiBase;
    await _restoreSession();
    await reload(); // local cache = works offline
    final conn = Connectivity();
    online =
        !(await conn.checkConnectivity()).contains(ConnectivityResult.none);
    _sub = conn.onConnectivityChanged.listen((r) {
      final on = !r.contains(ConnectivityResult.none);
      if (on != online) {
        online = on;
        notifyListeners();
        if (on) sync();
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => sync());
    sync();
  }

  Future<void> reload() async {
    products = await Db.products();
    customers = await Db.customers();
    sales = await Db.sales();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> recheck() async {
    online = !(await Connectivity().checkConnectivity())
        .contains(ConnectivityResult.none);
    notifyListeners();
    if (online) sync();
  }

  String get _connectionError =>
      'Cannot reach the server. Check that it is running and verify the server address.';

  // ───────── session / login ─────────
  bool _expired(String jwt) {
    try {
      final payload = jsonDecode(utf8.decode(
          base64Url.decode(base64Url.normalize(jwt.split('.')[1])))) as Map;
      return DateTime.now().millisecondsSinceEpoch / 1000 >=
          (payload['exp'] as num);
    } catch (_) {
      return true;
    }
  }

  void _applyUser(Map u) {
    userName = (u['name'] ?? '') as String;
    userEmail = (u['email'] ?? '') as String;
    role = (u['role'] ?? 'cashier') as String;
  }

  Future<void> _restoreSession() async {
    try {
      final t = await _secure.read(key: 'token');
      final u = await _secure.read(key: 'user');
      if (t != null && u != null && !_expired(t)) {
        Api.token = t;
        _applyUser(jsonDecode(u) as Map);
        loggedIn = true;
      }
    } catch (_) {}
  }

  /// Returns null on success, or an error message to show.
  Future<String?> login(String email, String password,
      {bool remember = true}) async {
    try {
      final r =
          await Api.post('/auth/login', {'email': email, 'password': password})
              as Map;
      Api.token = r['token'] as String;
      _applyUser(r['user'] as Map);
      loggedIn = true;
      if (remember) {
        await _secure.write(key: 'token', value: Api.token);
        await _secure.write(key: 'user', value: jsonEncode(r['user']));
      } else {
        await _clearStored();
      }
      notifyListeners();
      sync();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return _connectionError;
    }
  }

  Future<String?> register(String name, String email, String password) async {
    try {
      final r = await Api.post('/auth/register', {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
      }) as Map;
      final user = r['user'] as Map;
      Api.token = r['token'] as String;
      _applyUser(user);
      loggedIn = true;
      await _secure.write(key: 'token', value: Api.token);
      await _secure.write(key: 'user', value: jsonEncode(user));
      notifyListeners();
      sync();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return _connectionError;
    }
  }

  Future<void> _clearStored() async {
    try {
      await _secure.delete(key: 'token');
      await _secure.delete(key: 'user');
    } catch (_) {}
  }

  Future<void> logout() async {
    Api.token = null;
    loggedIn = false;
    cart.clear();
    customer = null;
    await _clearStored();
    notifyListeners();
  }

  // ───────── settings ─────────
  Future<void> saveProfile(String name, String type, Color color) async {
    businessName = name;
    businessType = type;
    themeColor = color;
    await _prefs?.setString('bizName', name);
    await _prefs?.setString('bizType', type);
    await _prefs?.setInt('theme', color.toARGB32());
    notifyListeners();
  }

  Future<void> saveApiBase(String url) async {
    apiBase = url.trim().replaceAll(RegExp(r'/+$'), '');
    Api.base = apiBase;
    await _prefs?.setString('apiBase', apiBase);
    notifyListeners();
    sync();
  }

  void markAllRead() {
    unread = 0;
    notifyListeners();
  }

  // ───────── cart ─────────
  void addToCart(Product p) {
    final q = cart[p.id] ?? 0;
    if (q < p.stock) {
      cart[p.id] = q + 1;
      notifyListeners();
    }
  }

  void changeQty(Product p, int delta) {
    final q = (cart[p.id] ?? 0) + delta;
    if (q <= 0) {
      cart.remove(p.id);
    } else if (q <= p.stock) {
      cart[p.id] = q;
    }
    notifyListeners();
  }

  List<MapEntry<Product, int>> get lines => [
        for (final p in products)
          if (cart.containsKey(p.id)) MapEntry(p, cart[p.id]!)
      ];
  int get cartCount => cart.values.fold(0, (a, b) => a + b);
  int get subtotal => lines.fold(0, (a, e) => a + e.key.price * e.value);
  int get tax => (subtotal * taxRate).round();
  int get total => subtotal + tax;

  void setCustomer(Customer? c) {
    customer = c;
    notifyListeners();
  }

  void setMethod(String m) {
    method = m;
    notifyListeners();
  }

  // ───────── sale (always saved locally first = offline safe) ─────────
  Future<Sale> completeSale(String methodName, {String? paypalRef}) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final sale = Sale(
      id: id,
      // unique across devices (date + 4 chars of the id)
      receipt:
          '#INV-${DateFormat('yyMMdd').format(now)}-${id.substring(0, 4).toUpperCase()}',
      method: methodName,
      customer: customer?.name ?? 'Walk-in Customer',
      total: total,
      tax: tax,
      created: now,
      paypalRef: paypalRef,
      lines: [
        for (final e in lines)
          SaleLine(e.key.id, e.key.name, e.key.price, e.value)
      ],
    );
    final changed = <Product>[];
    for (final e in lines) {
      e.key.stock -= e.value;
      changed.add(e.key);
    }
    await Db.saveSale(sale, changed);
    sales.insert(0, sale);
    cart.clear();
    customer = null;
    notifyListeners();
    sync(); // does nothing when offline
    return sale;
  }

  int get pendingSync => sales.where((s) => !s.synced).length;

  /// 1) upload sales not yet on the server (safe to repeat)  2) download the latest catalog + sales.
  Future<void> sync() async {
    if (!online || !loggedIn || _syncing) return;
    _syncing = true;
    try {
      for (final s in sales.where((x) => !x.synced).toList()) {
        await Api.post('/sales', s.toJson());
        s.synced = true;
        await Db.markSynced(s.id);
      }
      await _pull();
    } on ApiException catch (e) {
      if (e.status == 401) await logout();
    } catch (_) {
      // server unreachable: try again on the next timer tick / reconnect
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _pull() async {
    if (sales.any((s) => !s.synced)) {
      return; // never overwrite stock while sales are waiting
    }
    final p = await Api.get('/products') as List;
    final c = await Api.get('/customers') as List;
    final s = await Api.get('/sales?days=35') as List;
    await Db.replaceAll(
      products: p
          .map((e) => Product.fromMap(Map<String, Object?>.from(e as Map)))
          .toList(),
      customers: c
          .map((e) => Customer.fromMap(Map<String, Object?>.from(e as Map)))
          .toList(),
      sales: s
          .map((e) => Sale.fromServer(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
    await reload();
  }

  // ───────── inventory / customers (need the server; return an error message or null) ─────────
  String? _needOnline() =>
      (!online || !loggedIn) ? 'Connect to the internet to change this.' : null;

  Future<String?> addProduct(
      String name, int price, int stock, String category) async {
    final e = _needOnline();
    if (e != null) return e;
    try {
      final j = await Api.post('/products', {
        'name': name,
        'price': price,
        'stock': stock,
        'category': category
      }) as Map;
      final p = Product.fromMap(Map<String, Object?>.from(j));
      await Db.saveProduct(p);
      products
        ..add(p)
        ..sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
      return null;
    } on ApiException catch (x) {
      return x.message;
    } catch (_) {
      return 'Server not reachable.';
    }
  }

  Future<String?> updateStock(Product p, int stock) async {
    final e = _needOnline();
    if (e != null) return e;
    try {
      await Api.put('/products/${p.id}', {'stock': stock});
      final cur = products.firstWhere((x) => x.id == p.id, orElse: () => p);
      cur.stock = stock;
      await Db.saveProduct(cur);
      notifyListeners();
      return null;
    } on ApiException catch (x) {
      return x.message;
    } catch (_) {
      return 'Server not reachable.';
    }
  }

  Future<String?> addCustomer(String name, String phone, String email) async {
    final e = _needOnline();
    if (e != null) return e;
    try {
      final j = await Api.post(
          '/customers', {'name': name, 'phone': phone, 'email': email}) as Map;
      final c = Customer.fromMap(Map<String, Object?>.from(j));
      await Db.saveCustomer(c);
      customers
        ..add(c)
        ..sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
      return null;
    } on ApiException catch (x) {
      return x.message;
    } catch (_) {
      return 'Server not reachable.';
    }
  }

  // ───────── reports (computed from the synced local copy) ─────────
  int totalSince(DateTime from, [DateTime? to]) => sales
      .where((s) =>
          !s.created.isBefore(from) && (to == null || s.created.isBefore(to)))
      .fold(0, (a, s) => a + s.total);

  /// Totals for the last [n] days, oldest first.
  List<double> dailyTotals(int n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (var i = n - 1; i >= 0; i--)
        totalSince(today.subtract(Duration(days: i)),
                today.subtract(Duration(days: i - 1)))
            .toDouble()
    ];
  }
}

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'api.dart';
import 'db.dart';
import 'models.dart';
import 'theme.dart';

/// The API URL is only used for optional PayPal checkout.
const defaultApiBase = String.fromEnvironment('API_BASE_URL');
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
  String? firebaseAuthError;

  // settings
  Color themeColor = C.blue;
  String businessName = 'My Store';
  String businessType = 'Retail Store';
  String apiBase = defaultApiBase;

  SharedPreferences? _prefs;
  StreamSubscription? _sub;

  Future<void> init({String? firebaseAuthError}) async {
    this.firebaseAuthError = firebaseAuthError;
    _prefs = await SharedPreferences.getInstance();
    themeColor = Color(_prefs!.getInt('theme') ?? C.blue.toARGB32());
    businessName = _prefs!.getString('bizName') ?? businessName;
    businessType = _prefs!.getString('bizType') ?? businessType;
    apiBase = _prefs!.getString('apiBase') ?? apiBase;
    Api.base = apiBase;
    await _restoreSession();
    await reload();
    final conn = Connectivity();
    online =
        !(await conn.checkConnectivity()).contains(ConnectivityResult.none);
    _sub = conn.onConnectivityChanged.listen((r) {
      final on = !r.contains(ConnectivityResult.none);
      if (on != online) {
        online = on;
        notifyListeners();
      }
    });
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
    super.dispose();
  }

  Future<void> recheck() async {
    online = !(await Connectivity().checkConnectivity())
        .contains(ConnectivityResult.none);
    notifyListeners();
  }

  // ───────── session / login ─────────
  Future<void> _restoreSession() async {
    if (firebaseAuthError != null) return;
    final user = await FirebaseAuth.instance.authStateChanges().first;
    if (user != null) _applyFirebaseUser(user);
  }

  /// Returns null on success, or an error message to show.
  Future<String?> login(String email, String password) async {
    if (firebaseAuthError != null) return firebaseAuthError;
    try {
      final result = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email.trim(), password: password);
      final user = result.user;
      if (user == null) return 'Firebase sign-in did not return a user.';
      _applyFirebaseUser(user);
      return null;
    } on FirebaseAuthException catch (error) {
      return _authError(error);
    }
  }

  Future<String?> register(String name, String email, String password) async {
    if (firebaseAuthError != null) return firebaseAuthError;
    try {
      final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = result.user;
      if (user == null) {
        return 'Firebase account creation did not return a user.';
      }
      await user.updateDisplayName(name.trim());
      _applyFirebaseUser(user);
      return null;
    } on FirebaseAuthException catch (error) {
      return _authError(error);
    }
  }

  Future<String?> signInWithGoogle() async {
    if (firebaseAuthError != null) return firebaseAuthError;
    try {
      final provider = GoogleAuthProvider();
      final result = kIsWeb
          ? await FirebaseAuth.instance.signInWithPopup(provider)
          : await FirebaseAuth.instance.signInWithProvider(provider);
      final user = result.user;
      if (user == null) return 'Google sign-in did not return a user.';
      _applyFirebaseUser(user);
      return null;
    } on FirebaseAuthException catch (error) {
      return _authError(error);
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    if (firebaseAuthError != null) return firebaseAuthError;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (error) {
      return _authError(error);
    }
  }

  String _authError(FirebaseAuthException error) => switch (error.code) {
        'invalid-email' => 'Enter a valid email address.',
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' =>
          'The email or password is incorrect.',
        'email-already-in-use' => 'An account already exists for this email.',
        'weak-password' => 'Choose a stronger password.',
        'network-request-failed' =>
          'Connect to the internet to sign in or create an account.',
        'popup-closed-by-user' ||
        'cancelled-popup-request' =>
          'Google sign-in was cancelled.',
        _ => error.message ?? 'Authentication failed (${error.code}).',
      };

  void _applyFirebaseUser(User user) {
    userName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (user.email ?? 'User');
    userEmail = user.email ?? '';
    role = 'owner';
    loggedIn = true;
    Api.token = null;
    notifyListeners();
  }

  Future<void> logout() async {
    if (firebaseAuthError == null) await FirebaseAuth.instance.signOut();
    Api.token = null;
    loggedIn = false;
    cart.clear();
    customer = null;
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
    return sale;
  }

  // ───────── inventory / customers (saved locally on this device) ─────────

  Future<String?> addProduct(
      String name, int price, int stock, String category) async {
    final product = Product(
      id: const Uuid().v4(),
      name: name,
      price: price,
      stock: stock,
      category: category,
    );
    await Db.saveProduct(product);
    products
      ..add(product)
      ..sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    return null;
  }

  Future<String?> updateStock(Product p, int stock) async {
    p.stock = stock;
    await Db.saveProduct(p);
    notifyListeners();
    return null;
  }

  Future<String?> addCustomer(String name, String phone, String email) async {
    final customer = Customer(
      id: const Uuid().v4(),
      name: name,
      phone: phone,
      email: email,
    );
    await Db.saveCustomer(customer);
    customers
      ..add(customer)
      ..sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    return null;
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

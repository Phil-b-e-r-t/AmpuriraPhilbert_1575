import 'dart:async';
import 'dart:convert';
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

/// Server address for optional PayPal checkout. It is fixed at build time
/// (--dart-define API_BASE_URL=... / Vercel env var) and is NEVER shown to,
/// or editable by, the person using the app.
const defaultApiBase = String.fromEnvironment('API_BASE_URL');
const taxRate = 0.18;
const allPaymentMethods = ['Cash', 'Card', 'Mobile Money', 'Bank Transfer', 'PayPal'];

/// Something the owner/cashier should know about (low stock, expiring promo, offline...).
class AppAlert {
  final String key, title, sub;
  final IconData icon;
  final bool critical;
  const AppAlert(this.key, this.icon, this.title, this.sub, {this.critical = false});
}

class AppState extends ChangeNotifier {
  List<Product> products = [];
  List<Customer> customers = [];
  List<Sale> sales = [];
  List<Promotion> promotions = [];
  List<StaffMember> staff = [];
  final Map<String, int> cart = {};
  Customer? customer; // null = Walk-in
  Promotion? appliedCode; // whole-cart promo code entered at checkout
  String method = 'Cash';
  bool online = true;

  // session
  bool loggedIn = false;
  String userName = '', userEmail = '', role = 'cashier';
  bool get isOwner => role == 'owner';
  String? firebaseAuthError;

  // settings
  Color themeColor = C.blue;
  String businessName = 'My Store';
  String businessType = 'Retail Store';
  final Set<String> disabledMethods = {};
  final Set<String> _seenAlerts = {};

  /// Fixed at build time; not user-editable.
  String get apiBase => defaultApiBase;
  bool get paypalAvailable => defaultApiBase.isNotEmpty;

  SharedPreferences? _prefs;
  StreamSubscription? _sub;

  Future<void> init({String? firebaseAuthError}) async {
    this.firebaseAuthError = firebaseAuthError;
    _prefs = await SharedPreferences.getInstance();
    themeColor = Color(_prefs!.getInt('theme') ?? C.blue.toARGB32());
    businessName = _prefs!.getString('bizName') ?? businessName;
    businessType = _prefs!.getString('bizType') ?? businessType;
    // Older versions let people type a server address. Remove any saved value.
    await _prefs!.remove('apiBase');
    Api.base = defaultApiBase;
    _loadLocalConfig();
    await _restoreSession();
    await reload();
    final conn = Connectivity();
    online = !(await conn.checkConnectivity()).contains(ConnectivityResult.none);
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
    _refresh();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> recheck() async {
    online = !(await Connectivity().checkConnectivity()).contains(ConnectivityResult.none);
    notifyListeners();
  }

  // ───────── small local stores (promotions, staff, alert state) ─────────
  List<Map<String, dynamic>> _readList(String key) {
    try {
      final raw = _prefs?.getString(key);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeList(String key, List<Map<String, Object?>> rows) async {
    await _prefs?.setString(key, jsonEncode(rows));
  }

  void _loadLocalConfig() {
    staff = _readList('staff').map(StaffMember.fromJson).toList();
    promotions = _readList('promotions').map(Promotion.fromJson).toList();
    _seenAlerts
      ..clear()
      ..addAll(_prefs?.getStringList('seenAlerts') ?? const []);
    disabledMethods
      ..clear()
      ..addAll(_prefs?.getStringList('disabledMethods') ?? const []);
  }

  Future<void> _saveStaff() => _writeList('staff', staff.map((e) => e.toJson()).toList());
  Future<void> _savePromotions() => _writeList('promotions', promotions.map((e) => e.toJson()).toList());

  void _refresh() {
    _seenAlerts.retainAll(alerts.map((a) => a.key).toSet());
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
      _applyFirebaseUser(user, displayName: name.trim());
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

  void _applyFirebaseUser(User user, {String? displayName}) {
    final name = (displayName ?? user.displayName)?.trim();
    userName = name != null && name.isNotEmpty ? name : (user.email ?? 'User');
    userEmail = user.email ?? '';
    _resolveRole();
    loggedIn = true;
    Api.token = null;
    notifyListeners();
  }

  /// Role comes from the team list (Settings > Staff & Roles).
  ///  • First account ever used on this device becomes the owner.
  ///  • Anyone not on the team list gets cashier access (least privilege).
  void _resolveRole() {
    final email = userEmail.toLowerCase();
    if (staff.isEmpty) {
      staff.add(StaffMember(id: const Uuid().v4(), name: userName, email: email, role: 'owner'));
      unawaited(_saveStaff());
      role = 'owner';
      return;
    }
    final match = staff.where((x) => x.email == email);
    role = match.isEmpty ? 'cashier' : match.first.role;
  }

  Future<void> logout() async {
    if (firebaseAuthError == null) await FirebaseAuth.instance.signOut();
    Api.token = null;
    loggedIn = false;
    role = 'cashier';
    cart.clear();
    customer = null;
    appliedCode = null;
    notifyListeners();
  }

  // ───────── settings ─────────
  Future<void> saveProfile(String name, String type, Color color) async {
    if (!isOwner) return;
    businessName = name;
    businessType = type;
    themeColor = color;
    await _prefs?.setString('bizName', name);
    await _prefs?.setString('bizType', type);
    await _prefs?.setInt('theme', color.toARGB32());
    notifyListeners();
  }

  // ───────── payment methods ─────────
  /// Methods the backend supports. Card/PayPal only exist when the server is configured.
  List<String> get backendMethods => [
        for (final m in allPaymentMethods)
          if (paypalAvailable || (m != 'Card' && m != 'PayPal')) m
      ];
  bool isMethodEnabled(String m) => !disabledMethods.contains(m);

  /// What the cashier can actually choose at the till.
  List<String> get methods => [for (final m in backendMethods) if (isMethodEnabled(m)) m];
  String get payMethod => methods.contains(method) ? method : 'Cash';

  Future<void> setMethodEnabled(String m, bool on) async {
    if (!isOwner || m == 'Cash') return; // cash is always available
    on ? disabledMethods.remove(m) : disabledMethods.add(m);
    await _prefs?.setStringList('disabledMethods', disabledMethods.toList());
    notifyListeners();
  }

  // ───────── alerts ─────────
  List<AppAlert> get alerts {
    final out = <AppAlert>[];
    for (final p in products) {
      if (p.stock <= 0) {
        out.add(AppAlert('out:${p.id}', Icons.remove_shopping_cart_outlined,
            'Out of stock: ${p.name}', 'Restock needed', critical: true));
      } else if (p.low) {
        out.add(AppAlert('low:${p.id}:${p.stock}', Icons.inventory_2_outlined,
            'Low stock: ${p.name}', 'Only ${p.stock} left (reorder at ${p.reorder})'));
      }
    }
    final soon = DateTime.now().add(const Duration(days: 3));
    for (final x in promotions) {
      if (x.live && x.ends != null && x.ends!.isBefore(soon)) {
        out.add(AppAlert('promo:${x.id}', Icons.local_offer_outlined,
            'Promotion ending soon: ${x.name}', 'Ends ${DateFormat('MMM d').format(x.ends!)}'));
      }
    }
    if (!online) {
      out.add(const AppAlert('offline', Icons.wifi_off, 'You are offline',
          'Sales are saved on this device. PayPal needs internet.'));
    }
    out.sort((a, b) => (b.critical ? 1 : 0).compareTo(a.critical ? 1 : 0));
    return out;
  }

  int get unread => alerts.where((a) => !_seenAlerts.contains(a.key)).length;

  Future<void> markAllRead() async {
    _seenAlerts
      ..clear()
      ..addAll(alerts.map((a) => a.key));
    await _prefs?.setStringList('seenAlerts', _seenAlerts.toList());
    notifyListeners();
  }

  // ───────── promotions & discounts ─────────
  /// Best live promotion for a product (largest saving per unit).
  Promotion? promoFor(Product p) {
    Promotion? best;
    var bestSaving = 0;
    for (final x in promotions) {
      if (!x.live || x.productId != p.id) continue;
      final d = x.discountFor(p.price);
      if (d > bestSaving) {
        best = x;
        bestSaving = d;
      }
    }
    return best;
  }

  int unitDiscount(Product p) => promoFor(p)?.discountFor(p.price) ?? 0;

  /// The price the customer actually pays per unit.
  int unitPrice(Product p) => p.price - unitDiscount(p);

  Future<String?> addPromotion({
    required String name,
    required String kind,
    required int value,
    String code = '',
    String productId = '',
    DateTime? ends,
  }) async {
    if (!isOwner) return 'Only owners can manage promotions';
    if (name.trim().isEmpty) return 'Enter a promotion name';
    if (value <= 0) return 'Enter a discount greater than 0';
    if (kind == 'percent' && value > 100) return 'A percentage cannot be more than 100';
    final c = code.trim().toUpperCase();
    if (productId.isEmpty) {
      if (!RegExp(r'^[A-Z0-9]{3,20}$').hasMatch(c)) {
        return 'Promo code must be 3-20 letters or numbers';
      }
      if (promotions.any((x) => x.cartLevel && x.code == c)) return 'That code is already in use';
    }
    promotions.insert(
        0,
        Promotion(
          id: const Uuid().v4(),
          name: name.trim(),
          kind: kind,
          value: value,
          code: productId.isEmpty ? c : '',
          productId: productId,
          ends: ends,
        ));
    await _savePromotions();
    _refresh();
    return null;
  }

  Future<void> setPromotionActive(Promotion p, bool on) async {
    if (!isOwner) return;
    p.active = on;
    if (!p.live && appliedCode?.id == p.id) appliedCode = null;
    await _savePromotions();
    _refresh();
  }

  Future<void> deletePromotion(Promotion p) async {
    if (!isOwner) return;
    promotions.removeWhere((x) => x.id == p.id);
    if (appliedCode?.id == p.id) appliedCode = null;
    await _savePromotions();
    _refresh();
  }

  /// Returns null when the code was accepted, otherwise a message.
  String? applyCode(String raw) {
    final code = raw.trim().toUpperCase();
    if (code.isEmpty) return 'Enter a promo code';
    final m = promotions.where((x) => x.cartLevel && x.live && x.code == code);
    if (m.isEmpty) return 'That code is invalid or has expired';
    appliedCode = m.first;
    notifyListeners();
    return null;
  }

  void clearCode() {
    appliedCode = null;
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
    if (cart.isEmpty) appliedCode = null;
    notifyListeners();
  }

  List<MapEntry<Product, int>> get lines => [
        for (final p in products)
          if (cart.containsKey(p.id)) MapEntry(p, cart[p.id]!)
      ];
  int get cartCount => cart.values.fold(0, (a, b) => a + b);

  /// Price list total before any discount.
  int get subtotal => lines.fold(0, (a, e) => a + e.key.price * e.value);

  /// Savings from product promotions.
  int get productDiscount => lines.fold(0, (a, e) => a + unitDiscount(e.key) * e.value);

  /// Savings from the promo code (applied after product promotions).
  int get codeDiscount {
    final c = appliedCode;
    if (c == null || !c.live) return 0;
    return c.discountFor(subtotal - productDiscount);
  }

  int get discount => productDiscount + codeDiscount;
  int get taxable => subtotal - discount;
  int get tax => (taxable * taxRate).round();
  int get total => taxable + tax;

  void setCustomer(Customer? c) {
    customer = c;
    notifyListeners();
  }

  void setMethod(String m) {
    method = m;
    notifyListeners();
  }

  // ───────── barcode / QR lookups ─────────
  Product? productByBarcode(String code) {
    final c = code.trim();
    if (c.isEmpty) return null;
    for (final p in products) {
      if (p.barcode == c) return p;
    }
    return null;
  }

  /// Adds the scanned product to the cart at its current (promotional) price.
  /// The returned text is shown on the scanner screen; it starts with 'Added' on success.
  String addByBarcode(String code) {
    final p = productByBarcode(code);
    if (p == null) return 'No product found for "${code.trim()}"';
    if (p.stock <= 0) return '${p.name} is out of stock';
    if ((cart[p.id] ?? 0) >= p.stock) return 'Only ${p.stock} of ${p.name} in stock';
    addToCart(p);
    final promo = unitDiscount(p) > 0 ? ' (promo)' : '';
    return 'Added ${p.name} · ${ugx(unitPrice(p))}$promo  ×${cart[p.id]}';
  }

  // ───────── sale (always saved locally first = offline safe) ─────────
  Future<Sale> completeSale(String methodName, {String? paypalRef}) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final totalDiscount = discount, saleTax = tax, saleTotal = total;
    final sale = Sale(
      id: id,
      // unique across devices (date + 4 chars of the id)
      receipt: '#INV-${DateFormat('yyMMdd').format(now)}-${id.substring(0, 4).toUpperCase()}',
      method: methodName,
      customer: customer?.name ?? 'Walk-in Customer',
      cashier: userName,
      total: saleTotal,
      tax: saleTax,
      discount: totalDiscount,
      created: now,
      paypalRef: paypalRef,
      lines: [
        for (final e in lines)
          SaleLine(e.key.id, e.key.name, unitPrice(e.key), e.value, listPrice: e.key.price)
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
    appliedCode = null;
    _refresh();
    return sale;
  }

  // ───────── inventory (saved locally on this device) ─────────
  String? _validateProduct(String name, int price, int stock, int reorder, String barcode, String? exceptId) {
    if (!isOwner) return 'Only owners can change inventory';
    if (name.trim().isEmpty) return 'Enter the item name';
    if (price <= 0) return 'Price must be greater than 0';
    if (stock < 0) return 'Stock cannot be negative';
    if (reorder < 0) return 'Reorder level cannot be negative';
    final b = barcode.trim();
    if (b.isNotEmpty && products.any((p) => p.barcode == b && p.id != exceptId)) {
      return 'Another item already uses this barcode';
    }
    return null;
  }

  Future<String?> addProduct(String name, int price, int stock, String category,
      {String barcode = '', int reorder = 10}) async {
    final err = _validateProduct(name, price, stock, reorder, barcode, null);
    if (err != null) return err;
    final product = Product(
      id: const Uuid().v4(),
      name: name.trim(),
      price: price,
      stock: stock,
      reorder: reorder,
      category: category,
      barcode: barcode.trim(),
    );
    await Db.saveProduct(product);
    products
      ..add(product)
      ..sort((a, b) => a.name.compareTo(b.name));
    _refresh();
    return null;
  }

  Future<String?> updateProduct(Product p,
      {required String name,
      required int price,
      required int stock,
      required int reorder,
      required String category,
      required String barcode}) async {
    final err = _validateProduct(name, price, stock, reorder, barcode, p.id);
    if (err != null) return err;
    p
      ..name = name.trim()
      ..price = price
      ..stock = stock
      ..reorder = reorder
      ..category = category
      ..barcode = barcode.trim();
    await Db.saveProduct(p);
    products.sort((a, b) => a.name.compareTo(b.name));
    final q = cart[p.id];
    if (q != null && q > p.stock) {
      if (p.stock <= 0) {
        cart.remove(p.id);
      } else {
        cart[p.id] = p.stock;
      }
    }
    _refresh();
    return null;
  }

  Future<String?> deleteProduct(Product p) async {
    if (!isOwner) return 'Only owners can change inventory';
    await Db.deleteProduct(p.id);
    products.removeWhere((x) => x.id == p.id);
    cart.remove(p.id);
    promotions.removeWhere((x) => x.productId == p.id);
    await _savePromotions();
    _refresh();
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

  // ───────── team / user management ─────────
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<String?> addStaff(String name, String email, String newRole) async {
    if (!isOwner) return 'Only owners can manage the team';
    final e = email.trim().toLowerCase();
    if (name.trim().isEmpty) return 'Enter a name';
    if (!_emailRe.hasMatch(e)) return 'Enter a valid email address';
    if (staff.any((x) => x.email == e)) return 'This email is already on the team';
    staff.add(StaffMember(id: const Uuid().v4(), name: name.trim(), email: e, role: newRole));
    staff.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await _saveStaff();
    notifyListeners();
    return null;
  }

  Future<String?> setStaffRole(StaffMember m, String newRole) async {
    if (!isOwner) return 'Only owners can manage the team';
    if (m.role == 'owner' && newRole != 'owner' && staff.where((x) => x.role == 'owner').length <= 1) {
      return 'There must be at least one owner';
    }
    m.role = newRole;
    if (m.email == userEmail.toLowerCase()) role = newRole;
    await _saveStaff();
    notifyListeners();
    return null;
  }

  Future<String?> removeStaff(StaffMember m) async {
    if (!isOwner) return 'Only owners can manage the team';
    if (m.email == userEmail.toLowerCase()) return 'You cannot remove yourself';
    if (m.role == 'owner' && staff.where((x) => x.role == 'owner').length <= 1) {
      return 'There must be at least one owner';
    }
    staff.removeWhere((x) => x.id == m.id);
    await _saveStaff();
    notifyListeners();
    return null;
  }

  // ───────── reports (computed from the local copy) ─────────
  int totalSince(DateTime from, [DateTime? to]) => sales
      .where((s) => !s.created.isBefore(from) && (to == null || s.created.isBefore(to)))
      .fold(0, (a, s) => a + s.total);

  /// Totals for the last [n] days, oldest first.
  List<double> dailyTotals(int n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (var i = n - 1; i >= 0; i--)
        totalSince(today.subtract(Duration(days: i)), today.subtract(Duration(days: i - 1))).toDouble()
    ];
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Brand panel: gradient with the logo, name and (on large screens) the key selling points.
class _BrandPanel extends StatelessWidget {
  final bool compact;
  const _BrandPanel({this.compact = false});

  @override
  Widget build(BuildContext context) {
    const points = [
      (Icons.qr_code_scanner, 'Fast checkout with barcode & QR scanning'),
      (Icons.inventory_2_outlined, 'Live inventory with low-stock alerts'),
      (Icons.local_offer_outlined, 'Discounts, promo codes and promotions'),
      (Icons.bar_chart_rounded, 'Sales reports and receipts in one place'),
      (Icons.wifi_off_rounded, 'Keeps selling when the internet drops'),
    ];
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(32, compact ? MediaQuery.of(context).padding.top + 24 : 48, 32, compact ? 24 : 48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [context.primary, Color.lerp(context.primary, Colors.black, .45)!]),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Image.asset('assets/images/logo.png',
                errorBuilder: (_, __, ___) => Icon(Icons.storefront_rounded, size: 38, color: context.primary)),
          ),
          const SizedBox(height: 20),
          const Text('POS Retail Pro', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.8)),
          const SizedBox(height: 8),
          Text('Sell faster. Stock smarter.\nManage your business anytime, anywhere.',
              textAlign: compact ? TextAlign.center : TextAlign.start,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
          if (!compact) ...[
            const SizedBox(height: 36),
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(10)),
                    child: Icon(p.$1, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text(p.$2, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500))),
                ]),
              ),
          ],
        ],
      ),
    );
  }
}

/// Shared frame for login / sign-up: split screen on large displays, simple form on phones.
class _AuthFrame extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> children;
  const _AuthFrame({required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    final wide = context.wide;
    final form = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24), children: [
          Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -.8)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 13.5, color: C.grey)),
          const SizedBox(height: 28),
          ...children,
        ]),
      ),
    );
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context))),
      body: SafeArea(child: wide ? Row(children: [const Expanded(child: _BrandPanel()), Expanded(child: form)]) : form),
    );
  }
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cta = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Welcome', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -.8)),
          const SizedBox(height: 8),
          const Text('Sign in to start selling, or create an account for your store.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: C.grey, height: 1.5)),
          const SizedBox(height: 28),
          PrimaryButton('Sign in', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()))),
          const SizedBox(height: 12),
          PrimaryButton('Create account', outlined: true, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupPage()))),
          const SizedBox(height: 28),
          const Text('© 2026 Ampurira Philbert · ampuriraphilbert@gmail.com', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: C.grey)),
        ]),
      ),
    );
    return Scaffold(
      backgroundColor: Colors.white,
      body: context.wide
          ? Row(children: [const Expanded(child: _BrandPanel()), Expanded(child: Center(child: cta))])
          : Column(children: [
              const _BrandPanel(compact: true),
              Expanded(child: SafeArea(top: false, child: Center(child: SingleChildScrollView(child: cta)))),
            ]),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _hide = true, _busy = false;

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final id = _id.text.trim();
    if (id.isEmpty || _pw.text.isEmpty) {
      context.snack('Enter your email and password.');
      return;
    }
    setState(() => _busy = true);
    final err = await context.read<AppState>().login(id, _pw.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      context.snack(err);
      return;
    }
    // main.dart swaps the first screen to the app; just close the login page.
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  Future<void> _googleLogin() async {
    setState(() => _busy = true);
    final error = await context.read<AppState>().signInWithGoogle();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      context.snack(error);
      return;
    }
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  Future<void> _forgotPassword() async {
    final email = _id.text.trim();
    if (email.isEmpty) {
      context.snack('Enter your email address first.');
      return;
    }
    final error = await context.read<AppState>().sendPasswordReset(email);
    if (!mounted) return;
    context.snack(error ?? 'Password reset email sent.');
  }

  @override
  Widget build(BuildContext context) {
    final authError = context.watch<AppState>().firebaseAuthError;
    return _AuthFrame(
      title: 'Sign in',
      subtitle: 'Welcome back. Enter your details to continue.',
      children: [
        if (authError != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.red.withValues(alpha: .08), borderRadius: BorderRadius.circular(10)),
            child: Text(authError, style: const TextStyle(fontSize: 12, color: C.red)),
          ),
        AppField('Email', icon: Icons.mail_outline, controller: _id, type: TextInputType.emailAddress),
        const SizedBox(height: 14),
        AppField('Password',
            icon: Icons.lock_outline,
            controller: _pw,
            obscure: _hide,
            onSubmitted: (_) => _busy ? null : _login(),
            suffix: IconButton(
                icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                onPressed: () => setState(() => _hide = !_hide))),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
              onTap: _busy ? null : _forgotPassword,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text('Forgot password?', style: TextStyle(fontSize: 12.5, color: context.primary, fontWeight: FontWeight.w600)),
              )),
        ),
        const SizedBox(height: 18),
        PrimaryButton('Sign in', loading: _busy, onTap: _busy ? null : _login),
        const SizedBox(height: 20),
        const Row(children: [
          Expanded(child: Divider(color: C.border)),
          Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('OR', style: TextStyle(fontSize: 11, color: C.grey))),
          Expanded(child: Divider(color: C.border)),
        ]),
        const SizedBox(height: 20),
        PrimaryButton('Continue with Google', icon: Icons.g_mobiledata, outlined: true, color: C.text, loading: _busy, onTap: _busy ? null : _googleLogin),
        const SizedBox(height: 24),
        Center(
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupPage())),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text.rich(TextSpan(
                  text: "Don't have an account? ",
                  style: const TextStyle(fontSize: 12.5, color: C.grey),
                  children: [TextSpan(text: 'Sign up', style: TextStyle(color: context.primary, fontWeight: FontWeight.w700))])),
            ),
          ),
        ),
      ],
    );
  }
}

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _hidePassword = true, _hideConfirmation = true, _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty || _confirmPassword.text.isEmpty) {
      context.snack('Complete all fields to create your account');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      context.snack('Enter a valid email address');
      return;
    }
    if (password.length < 8) {
      context.snack('Password must be at least 8 characters');
      return;
    }
    if (password != _confirmPassword.text) {
      context.snack('Passwords do not match');
      return;
    }

    setState(() => _busy = true);
    final error = await context.read<AppState>().register(name, email, password);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      context.snack(error);
      return;
    }
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) => _AuthFrame(
        title: 'Create account',
        subtitle: 'Set up your store in less than a minute.',
        children: [
          AppField('Full name', icon: Icons.person_outline, controller: _name),
          const SizedBox(height: 14),
          AppField('Email', icon: Icons.mail_outline, controller: _email, type: TextInputType.emailAddress),
          const SizedBox(height: 14),
          AppField('Password',
              icon: Icons.lock_outline,
              controller: _password,
              obscure: _hidePassword,
              suffix: IconButton(
                icon: Icon(_hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                onPressed: () => setState(() => _hidePassword = !_hidePassword),
              )),
          const SizedBox(height: 14),
          AppField('Confirm password',
              icon: Icons.lock_outline,
              controller: _confirmPassword,
              obscure: _hideConfirmation,
              onSubmitted: (_) => _busy ? null : _register(),
              suffix: IconButton(
                icon: Icon(_hideConfirmation ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                onPressed: () => setState(() => _hideConfirmation = !_hideConfirmation),
              )),
          const SizedBox(height: 24),
          PrimaryButton('Create account', loading: _busy, onTap: _busy ? null : _register),
          const SizedBox(height: 20),
          Center(
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text.rich(TextSpan(
                  text: 'Already have an account? ',
                  style: const TextStyle(fontSize: 12.5, color: C.grey),
                  children: [TextSpan(text: 'Sign in', style: TextStyle(color: context.primary, fontWeight: FontWeight.w700))],
                )),
              ),
            ),
          ),
        ],
      );
}

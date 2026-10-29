import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              const Spacer(flex: 3),
              // Optional: upload your logo as assets/images/logo.png
              Image.asset('assets/images/logo.png',
                  width: 78,
                  height: 78,
                  errorBuilder: (_, __, ___) => Icon(
                      Icons.shopping_cart_outlined,
                      size: 78,
                      color: context.primary)),
              const SizedBox(height: 20),
              const Text('POS Retail Pro',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: C.navy)),
              const SizedBox(height: 12),
              const Text('Manage your business anytime,\nanywhere.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: C.grey, height: 1.5)),
              const Spacer(flex: 4),
              PrimaryButton('Get Started',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LoginPage()))),
              const SizedBox(height: 32),
              const Text('2026 Ampurira Philbert ampuriraphilbert@gmail.com',
                  style: TextStyle(fontSize: 11, color: C.grey)),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      );
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
    // main.dart now swaps the first screen to the app; just close the login page.
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

  Widget _social(String label, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: PrimaryButton(label,
            icon: icon,
            outlined: true,
            color: C.text,
            loading: _busy,
            onTap: _busy ? null : _googleLogin),
      );

  void _openSignup() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const SignupPage()));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context))),
        body: SafeArea(
          child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                const Text('Login',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('Sign in to your account',
                    style: TextStyle(fontSize: 12, color: C.grey)),
                if (context.watch<AppState>().firebaseAuthError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      context.watch<AppState>().firebaseAuthError!,
                      style: const TextStyle(fontSize: 12, color: C.red),
                    ),
                  ),
                const SizedBox(height: 24),
                AppField('Email',
                    icon: Icons.mail_outline,
                    controller: _id,
                    type: TextInputType.emailAddress),
                const SizedBox(height: 14),
                AppField('Password',
                    icon: Icons.lock_outline,
                    controller: _pw,
                    obscure: _hide,
                    suffix: IconButton(
                        icon: Icon(
                            _hide
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18),
                        onPressed: () => setState(() => _hide = !_hide))),
                const SizedBox(height: 10),
                Row(children: [
                  const Spacer(),
                  InkWell(
                      onTap: _busy ? null : _forgotPassword,
                      borderRadius: BorderRadius.circular(4),
                      hoverColor: context.primary.withValues(alpha: .08),
                      child: Text('Forgot password?',
                          style: TextStyle(
                              fontSize: 12,
                              color: context.primary,
                              fontWeight: FontWeight.w500))),
                ]),
                const SizedBox(height: 22),
                PrimaryButton('Login',
                    loading: _busy, onTap: _busy ? null : _login),
                const SizedBox(height: 22),
                const Row(children: [
                  Expanded(child: Divider(color: C.border)),
                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR',
                          style: TextStyle(fontSize: 11, color: C.grey))),
                  Expanded(child: Divider(color: C.border)),
                ]),
                const SizedBox(height: 22),
                _social('Continue with Google', Icons.g_mobiledata),
                const SizedBox(height: 24),
                Center(
                    child: InkWell(
                  onTap: _openSignup,
                  borderRadius: BorderRadius.circular(4),
                  hoverColor: context.primary.withValues(alpha: .08),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text.rich(TextSpan(
                        text: "Don't have an account? ",
                        style: const TextStyle(fontSize: 12, color: C.grey),
                        children: [
                          TextSpan(
                              text: 'Sign Up',
                              style: TextStyle(
                                  color: context.primary,
                                  fontWeight: FontWeight.w600))
                        ])),
                  ),
                )),
              ]),
        ),
      );
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
    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        _confirmPassword.text.isEmpty) {
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
    final error =
        await context.read<AppState>().register(name, email, password);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      context.snack(error);
      return;
    }
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const Text('Create account',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Sign up to get started',
                  style: TextStyle(fontSize: 12, color: C.grey)),
              const SizedBox(height: 24),
              AppField('Full name',
                  icon: Icons.person_outline, controller: _name),
              const SizedBox(height: 14),
              AppField('Email',
                  icon: Icons.mail_outline,
                  controller: _email,
                  type: TextInputType.emailAddress),
              const SizedBox(height: 14),
              AppField('Password',
                  icon: Icons.lock_outline,
                  controller: _password,
                  obscure: _hidePassword,
                  suffix: IconButton(
                    icon: Icon(
                        _hidePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18),
                    onPressed: () =>
                        setState(() => _hidePassword = !_hidePassword),
                  )),
              const SizedBox(height: 14),
              AppField('Confirm password',
                  icon: Icons.lock_outline,
                  controller: _confirmPassword,
                  obscure: _hideConfirmation,
                  suffix: IconButton(
                    icon: Icon(
                        _hideConfirmation
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18),
                    onPressed: () =>
                        setState(() => _hideConfirmation = !_hideConfirmation),
                  )),
              const SizedBox(height: 24),
              PrimaryButton('Create Account',
                  loading: _busy, onTap: _busy ? null : _register),
              const SizedBox(height: 20),
              Center(
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(4),
                  hoverColor: context.primary.withValues(alpha: .08),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text.rich(TextSpan(
                      text: 'Already have an account? ',
                      style: const TextStyle(fontSize: 12, color: C.grey),
                      children: [
                        TextSpan(
                            text: 'Login',
                            style: TextStyle(
                                color: context.primary,
                                fontWeight: FontWeight.w600)),
                      ],
                    )),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

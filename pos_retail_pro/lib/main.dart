import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/auth.dart';
import 'screens/home.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.init();
  runApp(ChangeNotifierProvider.value(value: state, child: const PosApp()));
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    final color = context.select<AppState, Color>((s) => s.themeColor);
    final loggedIn = context.select<AppState, bool>((s) => s.loggedIn);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'POS Retail Pro',
      theme: buildTheme(color),
      home: loggedIn ? const HomeShell() : const SplashPage(),
    );
  }
}

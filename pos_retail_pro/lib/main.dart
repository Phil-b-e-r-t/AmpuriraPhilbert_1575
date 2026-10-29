import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/auth.dart';
import 'screens/home.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? firebaseAuthError;
  if (!FirebaseConfig.isConfigured) {
    firebaseAuthError =
        'Firebase is not configured. Follow the Firebase setup steps in README.md.';
  } else {
    try {
      await Firebase.initializeApp(options: FirebaseConfig.currentPlatform);
    } on FirebaseException catch (error) {
      firebaseAuthError =
          'Firebase could not be initialized: ${error.message ?? error.code}';
    } on UnsupportedError catch (error) {
      firebaseAuthError = error.message;
    } catch (error) {
      // Never let a Firebase problem stop the app from opening (offline safe).
      firebaseAuthError = 'Firebase could not be initialized: $error';
    }
  }
  final state = AppState();
  await state.init(firebaseAuthError: firebaseAuthError);
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

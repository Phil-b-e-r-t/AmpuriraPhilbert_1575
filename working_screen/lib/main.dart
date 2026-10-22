import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/farm_selection.dart';

void main() {
  runApp(const TerraMoistApp());
}

/// Root Application Widget configuring theme and initial route.
class TerraMoistApp extends StatelessWidget {
  const TerraMoistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TerraMoist AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF2E7D32),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          primary: const Color(0xFF2E7D32),
        ),
        scaffoldBackgroundColor: const Color(0xFFF9FBF9),
        fontFamily: 'Roboto',
      ),
      // Define named routes to decouple navigation logic across separate files
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/farm_selection': (context) => const FarmSelectionScreen(),
      },
    );
  }
}
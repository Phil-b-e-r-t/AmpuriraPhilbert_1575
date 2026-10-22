import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Simulate initial loading sequence before navigating to Login
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Gradient Configuration
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F3818), Color(0xFF1B4D24)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // App Logo Icon Wrapper
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: const Icon(
                    Icons.water_drop_outlined,
                    size: 64,
                    color: Colors.greenAccent,
                  ),
                ),
                const SizedBox(height: 16),
                // App Brand Name with RichText for dual-color styling
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: 'TerraMoist ',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextSpan(
                        text: 'AI',
                        style: TextStyle(color: Colors.greenAccent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Smart Farming, Powered by Intelligence',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const Spacer(),
                // Loading Indicator Section
                const CircularProgressIndicator(
                  color: Colors.greenAccent,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Loading...',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Spacer(),
                // Tagline Footer
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Nurturing Today, Harvesting Tomorrow ',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                    ),
                    Icon(Icons.eco, color: Colors.greenAccent, size: 14),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
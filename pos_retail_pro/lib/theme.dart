import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Colours taken from the Figma file.
class C {
  static const navy = Color(0xFF1F3A5F);
  static const blue = Color(0xFF2563EB);
  static const text = Color(0xFF1F2937);
  static const grey = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const bg = Color(0xFFF9FAFB);
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFDC2626);
  static const amber = Color(0xFFF59E0B);
}

ThemeData buildTheme(Color primary) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: primary).copyWith(primary: primary),
    scaffoldBackgroundColor: Colors.white,
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: C.text, displayColor: C.text),
  );
}

String ugx(num v) => 'UGX ${NumberFormat('#,###').format(v)}';

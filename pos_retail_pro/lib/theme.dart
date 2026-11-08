import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Design tokens. One palette, one radius scale, one spacing scale used across the whole app.
/// Values follow the "business_transaction" Figma prototype (Inter, white screens, bordered tiles).
class C {
  static const navy = Color(0xFF1F3A5F); // titles / brand navy
  static const blue = Color(0xFF2563EB); // default brand colour (owner can change it)
  static const text = Color(0xFF1F2937);
  static const grey = Color(0xFF6B7280);
  static const hint = Color(0xFF9CA3AF); // placeholders, version text
  static const border = Color(0xFFDBE4F0); // tile / input outlines
  static const divider = Color(0xFFE5E7EB); // hairlines between list rows
  static const bg = Color(0xFFF3F4F6); // soft fills (search fields, inactive chips)
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFDC2626);
  static const amber = Color(0xFFD97706);
}

/// Screens wider than this get the tablet / desktop layout (side navigation, split POS).
const kWideBreakpoint = 900.0;

ThemeData buildTheme(Color primary) {
  final scheme = ColorScheme.fromSeed(seedColor: primary).copyWith(primary: primary, surface: Colors.white);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    splashFactory: InkRipple.splashFactory,
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: C.text, displayColor: C.text),
    dividerColor: C.divider,
    dividerTheme: const DividerThemeData(color: C.divider, thickness: 1, space: 1),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: C.text,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.text,
      contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 10.5,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
          color: s.contains(WidgetState.selected) ? primary : C.grey)),
      iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 22, color: s.contains(WidgetState.selected) ? primary : C.grey)),
    ),
  );
}

String ugx(num v) => 'UGX ${NumberFormat('#,###').format(v)}';

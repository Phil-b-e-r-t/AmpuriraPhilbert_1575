import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Design tokens. One palette, one radius scale, one spacing scale used across the whole app.
class C {
  static const navy = Color(0xFF0F172A); // headings / dark surfaces
  static const blue = Color(0xFF2563EB); // default brand colour (owner can change it)
  static const text = Color(0xFF0F172A);
  static const grey = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const bg = Color(0xFFF1F5F9); // app background; cards sit on it in white
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
    scaffoldBackgroundColor: C.bg,
    splashFactory: InkRipple.splashFactory,
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: C.text, displayColor: C.text),
    dividerColor: C.border,
    dividerTheme: const DividerThemeData(color: C.border, thickness: 1, space: 1),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: C.text,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.navy,
      contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: primary.withValues(alpha: .12),
      height: 66,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 11,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? primary : C.grey)),
      iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 23, color: s.contains(WidgetState.selected) ? primary : C.grey)),
    ),
  );
}

String ugx(num v) => 'UGX ${NumberFormat('#,###').format(v)}';

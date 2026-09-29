import 'package:flutter/material.dart';

const kCurrency = 'T'; // change freely, or make it a setting later
const kWeekStart = DateTime.monday; // e.g. DateTime.saturday

String money(double v) => v
    .round()
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF6C63FF),
    brightness: Brightness.dark,
  ).copyWith(surface: const Color(0xFF12131A));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF0D0E14),
    cardTheme: CardThemeData(
      color: const Color(0xFF1A1C26),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}

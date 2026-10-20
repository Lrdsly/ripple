import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

const kCurrency = 'تومان';
// Persian week starts on Saturday (شنبه).
const kWeekStart = DateTime.saturday;

// Persian palette: turquoise tile + warm gold + deep night-teal.
const kTurquoise = Color(0xFF14B8A6);
const kDeepTeal = Color(0xFF0B6E5F);
const kGold = Color(0xFFD9A441);
const kNight = Color(0xFF0C1517);
const kNightCard = Color(0xFF14211F);
const kPaper = Color(0xFFF7F3EB);
// Ice-blue light variant.
const kIceBg = Color(0xFFE9F2F9);
const kIceCard = Color(0xFFF7FBFE);
const kIceBlue = Color(0xFF1F7AB8);
const kIceNavy = Color(0xFF155E75);

const _faDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

String faDigits(String input) =>
    input.replaceAllMapped(RegExp(r'\d'), (m) => _faDigits[int.parse(m[0]!)]);

String money(double v) => v
    .round()
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// Persian-formatted amount: ۱٬۲۳۴٬۵۰۰
String moneyFa(double v) =>
    faDigits(v.round().toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => '٬',
        ));

/// Solar (Jalali) display helpers — dates are stored as Gregorian
/// [DateTime] internally but always shown in the solar calendar,
/// e.g. a file named `1404-07-05.md` shows as `۷/۵ مهر`.
String solarMd(DateTime d) {
  final j = Jalali.fromDateTime(d);
  return faDigits('${j.month}/${j.day}');
}

String solarMonthName(DateTime d) => Jalali.fromDateTime(d).formatter.mN;

TextTheme _vazir(TextTheme base) => base.apply(
      fontFamily: 'Vazirmatn',
      bodyColor: base.bodyLarge?.color,
      displayColor: base.displayLarge?.color,
    );

ThemeData buildTheme() => buildDarkTheme();

ThemeData buildDarkTheme() {
  var scheme = ColorScheme.fromSeed(
    seedColor: kTurquoise,
    brightness: Brightness.dark,
  ).copyWith(
    primary: kTurquoise,
    secondary: kGold,
    tertiary: const Color(0xFF7C8CF8),
    surface: kNightCard,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kNight,
  );
  return base.copyWith(
    textTheme: _vazir(base.textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
    ),
    cardTheme: CardThemeData(
      color: kNightCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kTurquoise,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      selectedColor: kTurquoise.withValues(alpha: 0.25),
      checkmarkColor: kTurquoise,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: kNightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kNightCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.white.withValues(alpha: 0.08),
    ),
  );
}

ThemeData buildLightTheme() {
  var scheme = ColorScheme.fromSeed(
    seedColor: kDeepTeal,
    brightness: Brightness.light,
  ).copyWith(
    primary: kDeepTeal,
    secondary: const Color(0xFF9A6B1F),
    surface: Colors.white,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kPaper,
  );
  return base.copyWith(
    textTheme: _vazir(base.textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w800, color: kDeepTeal),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: kDeepTeal.withValues(alpha: 0.12)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kDeepTeal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      selectedColor: kDeepTeal.withValues(alpha: 0.15),
      checkmarkColor: kDeepTeal,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kDeepTeal.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: kDeepTeal.withValues(alpha: 0.12),
    ),
  );
}

/// Crisp ice-blue light theme: same Vazirmatn + shapes, cooler palette.
ThemeData buildIceTheme() {
  var scheme = ColorScheme.fromSeed(
    seedColor: kIceBlue,
    brightness: Brightness.light,
  ).copyWith(
    primary: kIceBlue,
    secondary: kIceNavy,
    surface: kIceCard,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kIceBg,
  );
  return base.copyWith(
    textTheme: _vazir(base.textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w800, color: kIceNavy),
    ),
    cardTheme: CardThemeData(
      color: kIceCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: kIceBlue.withValues(alpha: 0.18)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kIceBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      selectedColor: kIceBlue.withValues(alpha: 0.15),
      checkmarkColor: kIceBlue,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: kIceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kIceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kIceBlue.withValues(alpha: 0.07),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: kIceNavy.withValues(alpha: 0.12),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kIceCard,
      indicatorColor: kIceBlue.withValues(alpha: 0.15),
    ),
  );
}

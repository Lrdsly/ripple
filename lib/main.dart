import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'core/theme.dart';
import 'ui/shell.dart';

void main() => runApp(ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const WalletApp(),
    ));

class WalletApp extends StatelessWidget {
  const WalletApp({super.key});
  @override
  Widget build(BuildContext context) {
    final choice = context.watch<AppState>().themeChoice;
    final light = switch (choice) {
      'ice' => buildIceTheme(),
      _ => buildLightTheme(),
    };
    return MaterialApp(
        title: 'مالی',
        debugShowCheckedModeBanner: false,
        theme: light,
        darkTheme: buildDarkTheme(),
        themeMode: choice == 'night'
            ? ThemeMode.dark
            : choice == 'system'
                ? ThemeMode.system
                : ThemeMode.light,
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fa', 'IR')],
        locale: const Locale('fa'),
        home: const AppShell(),
      );
  }
}

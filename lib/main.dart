import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'core/theme.dart';
import 'ui/home_page.dart';

void main() => runApp(ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const WalletApp(),
    ));

class WalletApp extends StatelessWidget {
  const WalletApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Wallet',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const HomePage(),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_store.dart';
import 'app_theme.dart';
import 'shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const SmartBudgetApp());
}

class SmartBudgetApp extends StatefulWidget {
  const SmartBudgetApp({super.key});

  @override
  State<SmartBudgetApp> createState() => _SmartBudgetAppState();
}

class _SmartBudgetAppState extends State<SmartBudgetApp> {
  final AppStore store = AppStore();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final dark = store.darkMode;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: dark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ));
        return AppStoreScope(
          store: store,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: '拾光账本',
            theme: buildTheme(dark: dark),
            home: const AppShell(),
          ),
        );
      },
    );
  }
}

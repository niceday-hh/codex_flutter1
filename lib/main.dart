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

  late bool _dark = store.darkMode;
  late final ThemeData _lightTheme = buildTheme();
  late final ThemeData _darkTheme = buildTheme(dark: true);

  @override
  void initState() {
    super.initState();
    store.addListener(_updateTheme);
  }

  void _updateTheme() {
    if (_dark != store.darkMode) setState(() => _dark = store.darkMode);
  }

  @override
  void dispose() {
    store.removeListener(_updateTheme);
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = _dark;
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
        theme: _lightTheme,
        darkTheme: _darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: const AppShell(),
      ),
    );
  }
}


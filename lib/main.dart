import 'dart:async';
import 'calendar/calendar_updates.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app_store.dart';
import 'app_theme.dart';
import 'shell.dart';
import 'voice/voice_engine_cache.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Paraformer-zh / FunASR'], await rootBundle.loadString('assets/licenses/FunASR_MODEL_LICENSE.txt'));
    yield LicenseEntryWithLineBreaks(['离线语音模型来源'], await rootBundle.loadString('assets/licenses/VOICE_NOTICE.txt'));
  });
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const SmartBudgetApp());
}

class SmartBudgetApp extends StatefulWidget {
  const SmartBudgetApp({super.key, this.voiceCache});
  final VoiceEngineCache? voiceCache;

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
    WidgetsBinding.instance.addObserver(CalendarUpdates.instance);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(CalendarUpdates.instance.autoCheck());
    });
  }

  void _updateTheme() {
    if (_dark != store.darkMode) setState(() => _dark = store.darkMode);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(CalendarUpdates.instance);
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
        home: AppShell(voiceCache: widget.voiceCache),
      ),
    );
  }
}



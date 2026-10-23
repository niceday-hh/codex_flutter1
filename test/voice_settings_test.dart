import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/app_store.dart';
import 'package:smart_budget/app_theme.dart';
import 'package:smart_budget/pages/profile_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('smart_budget/storage');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('voice preferences persist separately and do not rebuild note history', () async {
    String? saved;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'load') return saved;
      if (call.method == 'save') saved = call.arguments as String;
      return null;
    });
    final store = AppStore(); await store.ready;
    expect(store.keepVoiceModelInBackground, isTrue); expect(store.voiceBackgroundSeconds, 15);
    final notes = store.noteCatalog;
    store.setVoiceBackgroundSeconds(10); store.setKeepVoiceModelInBackground(false);
    expect(identical(notes, store.noteCatalog), isTrue);
    await store.flushPersistence(); store.dispose();
    final restored = AppStore(); await restored.ready;
    expect(restored.keepVoiceModelInBackground, isFalse); expect(restored.voiceBackgroundSeconds, 10);
    restored.dispose();
  });
  test('startup edits beat delayed disk restore and duration is bounded', () async {
    final load = Completer<String?>();
    Map<String, dynamic>? saved;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'load') return load.future;
      if (call.method == 'save') saved = jsonDecode(call.arguments as String) as Map<String, dynamic>;
      return null;
    });
    final store = AppStore();
    store.setKeepVoiceModelInBackground(false); store.setVoiceBackgroundSeconds(100);
    load.complete(jsonEncode({'keepVoiceModelInBackground': true, 'voiceBackgroundSeconds': 10}));
    await store.ready; await store.flushPersistence();
    expect(store.keepVoiceModelInBackground, isFalse); expect(store.voiceBackgroundSeconds, 30);
    expect(saved!['keepVoiceModelInBackground'], isFalse); expect(saved!['voiceBackgroundSeconds'], 30);
    store.dispose();
  });
  testWidgets('profile exposes the switch and short retention choices', (tester) async {
    tester.view.physicalSize = const Size(390, 844); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    late AppStore store; await tester.runAsync(() async { store = AppStore(); await store.ready; });
    await tester.pumpWidget(AppStoreScope(store: store,
      child: MaterialApp(theme: buildTheme(), home: const Scaffold(body: ProfilePage()))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('语音模型保留时长'));
    await tester.tap(find.text('语音模型保留时长')); await tester.pumpAndSettle();
    for (final seconds in [5, 10, 15, 30]) { expect(find.text('$seconds 秒'), findsOneWidget); }
    await tester.tap(find.text('10 秒')); await tester.pumpAndSettle();
    expect(store.voiceBackgroundSeconds, 10);
    await tester.ensureVisible(find.byType(Switch).last);
    await tester.tap(find.byType(Switch).last); await tester.pumpAndSettle();
    expect(store.keepVoiceModelInBackground, isFalse);
    expect(find.textContaining('已关闭保留'), findsOneWidget); expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink()); store.dispose();
  });
}

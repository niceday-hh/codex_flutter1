import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/app_store.dart';
import 'package:smart_budget/app_theme.dart';
import 'package:smart_budget/shell.dart';
import 'package:smart_budget/voice/voice_engine.dart';
import 'package:smart_budget/voice/voice_engine_cache.dart';
import 'voice_session_test.dart' show FakeVoiceEngine;

class PreparedEngine extends FakeVoiceEngine {
  int preparations = 0;
  bool fail = false;
  Completer<void>? prepareGate, closeGate;
  @override Future<void> prepare() async {
    preparations++;
    if (fail) throw StateError('model preparation failed');
    await prepareGate?.future;
  }
  @override Future<void> close() async {
    await closeGate?.future;
    await super.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  VoiceEngineCache cacheFor(List<PreparedEngine> engines, {PreparedEngine Function()? factory}) {
    final cache = VoiceEngineCache(backgroundRetention: Duration.zero, factory: () {
      final e = factory?.call() ?? PreparedEngine(); engines.add(e); return e;
    });
    cache.didChangeAppLifecycleState(AppLifecycleState.resumed);
    return cache;
  }
  Future<void> tick() => Future<void>.delayed(Duration.zero);

  test('foreground warm-up initializes once without starting the microphone', () async {
    final engines = <PreparedEngine>[]; final cache = cacheFor(engines);
    await Future.wait([cache.warmUp(), cache.warmUp(), cache.warmUp()]);
    expect(engines.length, 1); expect(engines.single.preparations, 1);
    expect(engines.single.starts, 0); expect(engines.single.stops, 0);
    final first = cache.acquire(); await first.prepare(); await first.start(); await first.stop(); await first.close();
    final second = cache.acquire(); await second.prepare(); await second.close();
    expect(engines.length, 1); expect(engines.single.preparations, 1);
    expect(engines.single.closed, isFalse); expect(engines.single.cancels, greaterThan(0));
    await cache.dispose(); expect(engines.single.closed, isTrue);
  });
  test('background frees the model and every foreground return preloads automatically', () async {
    final engines = <PreparedEngine>[]; final cache = cacheFor(engines);
    await cache.warmUp();
    cache.didChangeAppLifecycleState(AppLifecycleState.hidden);
    cache.didChangeAppLifecycleState(AppLifecycleState.paused); await tick();
    expect(engines.single.closed, isTrue);
    cache.didChangeAppLifecycleState(AppLifecycleState.resumed); await cache.warmUp();
    expect(engines.length, 2); expect(engines.last.preparations, 1); expect(engines.last.starts, 0);
    await cache.dispose();
  });
  test('inactive permission dialogs and app-internal navigation retain the foreground model', () async {
    final engines = <PreparedEngine>[]; final cache = cacheFor(engines);
    await cache.warmUp();
    cache.didChangeAppLifecycleState(AppLifecycleState.inactive);
    cache.didChangeAppLifecycleState(AppLifecycleState.resumed); await cache.warmUp();
    expect(engines.length, 1); expect(engines.single.preparations, 1); expect(engines.single.closed, isFalse);
    await cache.dispose();
  });
  test('a warm-up requested in background waits for a real foreground return', () async {
    final engines = <PreparedEngine>[]; final cache = cacheFor(engines);
    cache.didChangeAppLifecycleState(AppLifecycleState.paused); await cache.warmUp();
    expect(engines, isEmpty);
    cache.didChangeAppLifecycleState(AppLifecycleState.resumed); await cache.warmUp();
    expect(engines.length, 1); await cache.dispose();
  });
  test('rapid resume waits for old model disposal and ignores late old preparation', () async {
    final engines = <PreparedEngine>[];
    final oldPrepare = Completer<void>(), oldClose = Completer<void>();
    final cache = cacheFor(engines, factory: () => engines.isEmpty
      ? (PreparedEngine()..prepareGate = oldPrepare..closeGate = oldClose) : PreparedEngine());
    final warming = cache.warmUp(); await tick(); expect(engines.length, 1);
    cache.didChangeAppLifecycleState(AppLifecycleState.paused); await tick();
    cache.didChangeAppLifecycleState(AppLifecycleState.resumed); await tick();
    expect(engines.length, 1);
    oldClose.complete(); await cache.warmUp(); expect(engines.length, 2);
    oldPrepare.complete(); await warming; await tick();
    expect(engines.last.closed, isFalse); expect(engines.last.preparations, 1);
    await cache.dispose();
  });
  test('memory pressure frees idle model without a reload loop and voice can recover', () async {
    final engines = <PreparedEngine>[]; final cache = cacheFor(engines); await cache.warmUp();
    cache.didHaveMemoryPressure(); await tick(); expect(engines.single.closed, isTrue); expect(engines.length, 1);
    final lease = cache.acquire(); await lease.prepare(); expect(engines.length, 2);
    cache.didHaveMemoryPressure(); expect(engines.last.closed, isFalse);
    await lease.close(); await tick(); expect(engines.last.closed, isTrue); expect(engines.length, 2);
    await cache.dispose();
  });
  test('late failure of an old lease cannot evict the model prepared after resume', () async {
    final engines = <PreparedEngine>[];
    final gate = Completer<void>();
    final cache = cacheFor(engines, factory: () => engines.isEmpty
      ? (PreparedEngine()..prepareGate = gate) : PreparedEngine());
    final lease = cache.acquire();
    final oldPreparing = lease.prepare().then<void>((_) {}, onError: (_) {});
    await tick(); cache.didChangeAppLifecycleState(AppLifecycleState.paused); await tick();
    cache.didChangeAppLifecycleState(AppLifecycleState.resumed); await cache.warmUp(); await lease.prepare();
    gate.complete(); await oldPreparing;
    await lease.close(); await tick();
    expect(engines.length, 2); expect(engines.last.closed, isFalse);
    await cache.dispose();
  });
  test('failed preload is retired and can be retried before recording', () async {
    final engines = <PreparedEngine>[];
    final cache = cacheFor(engines, factory: () => PreparedEngine()..fail = engines.isEmpty);
    await cache.warmUp(); await tick(); expect(engines.single.closed, isTrue);
    await cache.warmUp(); expect(engines.length, 2); expect(engines.last.starts, 0);
    await cache.dispose();
  });
  test('close during decode discards old result and refreshes the foreground model', () async {
    final engines = <PreparedEngine>[]; final cache = cacheFor(engines); await cache.warmUp();
    final first = cache.acquire(); await first.prepare(); await first.start();
    engines.first.stopGate = Completer<String?>();
    final stopping = first.stop(); await tick(); await first.close(); await tick();
    expect(engines.first.closed, isTrue);
    engines.first.stopGate!.complete('奶茶18元'); expect(await stopping, isNull);
    await cache.warmUp(); expect(engines.length, 2);
    final second = cache.acquire(); await second.prepare(); await second.close();
    expect(engines.length, 2); await cache.dispose();
  });
  test('preparation and shutdown never construct a recorder or ask microphone permission', () async {
    const channel = MethodChannel('smart_budget/voice');
    var prepareCalls = 0, recorders = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'prepare'); prepareCalls++; return null;
    });
    final engine = ParaformerVoiceEngine(recorderFactory: () { recorders++; throw StateError('unexpected microphone creation'); });
    await expectLater(engine.prepare(), throwsStateError); await engine.close();
    expect(prepareCalls, 1); expect(recorders, 0);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });
  testWidgets('first frame and manual bookkeeping remain responsive while preloading is pending', (tester) async {
    tester.view.physicalSize = const Size(390, 844); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    late AppStore store; await tester.runAsync(() async { store = AppStore(); await store.ready; });
    final engines = <PreparedEngine>[]; final gate = Completer<void>();
    final cache = cacheFor(engines, factory: () => PreparedEngine()..prepareGate = gate);
    await tester.pumpWidget(AppStoreScope(store: store, child: MaterialApp(theme: buildTheme(), home: AppShell(voiceCache: cache))));
    await tester.pump(); expect(engines.length, 1); expect(engines.single.preparations, 1);
    expect(engines.single.starts, 0); expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_rounded)); await tester.pumpAndSettle();
    expect(find.text('记一笔'), findsOneWidget); expect(engines.single.closed, isFalse);
    await tester.tap(find.text('1')); await tester.pump(); expect(find.text('¥ 1'), findsOneWidget);
    gate.complete(); await tester.pump(); await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 2));
    expect(engines.single.closed, isFalse); expect(engines.single.preparations, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(tick); expect(engines.single.closed, isTrue); store.dispose();
  });
}


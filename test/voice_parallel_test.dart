import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:smart_budget/voice/voice_engine.dart';
import 'package:smart_budget/voice/voice_engine_cache.dart';
import 'package:smart_budget/voice/voice_session.dart';
import 'voice_session_test.dart' show FakeVoiceEngine;

class ColdEngine extends FakeVoiceEngine {
  final ready = Completer<void>();
  int preparations = 0;
  bool recording = false, captured = false;
  @override Future<void> prepare() async { preparations++; await ready.future; }
  @override Future<bool> start() async { starts++; recording = true; return true; }
  @override Future<String?> stop() async {
    stops++; recording = false; captured = true;
    await ready.future;
    return text;
  }
}

class TestRecorder implements AudioRecorder {
  int starts = 0, stops = 0, cancels = 0;
  String? path;
  Completer<bool>? permission;
  @override Future<bool> hasPermission({bool request = true}) async => permission == null ? true : permission!.future;
  @override Future<void> start(RecordConfig config, {required String path}) async {
    starts++; this.path = path;
    await File(path).writeAsBytes([1, 2, 3, 4]);
  }
  @override Future<String?> stop() async { stops++; return path; }
  @override Future<void> cancel() async { cancels++; }
  @override Future<void> dispose() async {}
  @override Stream<Amplitude> onAmplitudeChanged(Duration interval) => const Stream.empty();
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> tick() => Future<void>.delayed(Duration.zero);

  test('cold model does not block recording; release preserves audio until ready', () async {
    final engine = ColdEngine();
    final cache = VoiceEngineCache(factory: () => engine);
    cache.didChangeAppLifecycleState(AppLifecycleState.resumed);
    final warming = cache.warmUp(); await tick();
    final session = VoiceSession(cache.acquire());
    final preparing = session.prepare(); await tick();
    expect(session.modelPreparing, isTrue);
    await session.hold();
    expect(session.stage, VoiceStage.recording); expect(engine.recording, isTrue);
    expect(engine.ready.isCompleted, isFalse); expect(engine.preparations, 1);
    final recognizing = session.release(); await tick();
    expect(engine.recording, isFalse); expect(engine.captured, isTrue);
    expect(session.stage, VoiceStage.recognizing); expect(session.draft, isNull);
    engine.ready.complete(); await warming; await preparing; await recognizing;
    expect(session.stage, VoiceStage.review); expect(session.draft!.amount, 28.5);
    expect(engine.preparations, 1);
    await session.shutdown(); session.dispose(); await cache.dispose();
  });
  test('model finishing mid-sentence never resets recording state', () async {
    final engine = ColdEngine(); final session = VoiceSession(engine);
    final preparing = session.prepare(); await session.hold();
    engine.ready.complete(); await preparing;
    expect(session.stage, VoiceStage.recording); expect(session.modelPreparing, isFalse);
    await session.release(); expect(session.stage, VoiceStage.review);
    await session.shutdown(); session.dispose();
  });
  test('dismiss while captured audio awaits model never creates a late draft', () async {
    final engine = ColdEngine(); final session = VoiceSession(engine);
    final preparing = session.prepare(); await session.hold();
    final recognizing = session.release(); await tick();
    await session.shutdown();
    engine.ready.complete(); await preparing; await recognizing;
    expect(session.draft, isNull); expect(engine.closed, isTrue); session.dispose();
  });

  for (final stopFirst in [false, true]) {
    test('native recorder bypasses model preparation; stopFirst=$stopFirst', () async {
      const channel = MethodChannel('smart_budget/voice');
      final model = Completer<Map<String, String>?>();
      final directory = await Directory.systemTemp.createTemp('voice-parallel-');
      final recorder = TestRecorder();
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'recordDirectory') return directory.path;
        if (call.method == 'prepare') return model.future;
        throw StateError('Unexpected method');
      });
      final engine = ParaformerVoiceEngine(recorderFactory: () => recorder);
      try {
        expect(await engine.start(), isTrue);
        expect(recorder.starts, 1); expect(model.isCompleted, isFalse);
        expect(await File(recorder.path!).exists(), isTrue);
        if (stopFirst) {
          var completed = false;
          final stop = engine.stop().then<void>((_) { completed = true; }, onError: (Object _) { completed = true; });
          await tick(); expect(recorder.stops, 1); expect(completed, isFalse);
          model.complete(null); await stop;
          expect(await File(recorder.path!).exists(), isFalse);
          await engine.close();
        } else {
          // Closing an initializing model must not wait for the native job.
          await engine.close().timeout(const Duration(seconds: 1));
          expect(model.isCompleted, isFalse);
          expect(await File(recorder.path!).exists(), isFalse);
          model.complete(null); await tick();
        }
      } finally {
        if (!model.isCompleted) model.complete(null);
        await engine.close(); await tick();
        messenger.setMockMethodCallHandler(channel, null);
        await directory.delete(recursive: true);
      }
    });
  }

  testWidgets('grace period reuses model, stops mic, and does not extend on paused', (tester) async {
    final engines = <FakeVoiceEngine>[];
    final cache = VoiceEngineCache(clock: tester.binding.clock.now, factory: () {
      final engine = FakeVoiceEngine(); engines.add(engine); return engine;
    });
    cache.didChangeAppLifecycleState(AppLifecycleState.resumed); await cache.warmUp();
    cache.didChangeAppLifecycleState(AppLifecycleState.hidden); await tester.pump();
    expect(engines.single.cancels, 1); expect(engines.single.closed, isFalse);
    await tester.pump(const Duration(seconds: 10));
    cache.didChangeAppLifecycleState(AppLifecycleState.resumed); await cache.warmUp();
    expect(engines.length, 1);
    cache.didChangeAppLifecycleState(AppLifecycleState.hidden); await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    cache.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 6));
    expect(engines.first.closed, isTrue);
    cache.didChangeAppLifecycleState(AppLifecycleState.resumed); await cache.warmUp();
    expect(engines.length, 2); await cache.dispose();
  });
  testWidgets('retention disabled, shortened, detached or low memory releases promptly', (tester) async {
    for (final mode in ['disable', 'shorten', 'detach', 'memory']) {
      final engine = FakeVoiceEngine();
      final cache = VoiceEngineCache(factory: () => engine, clock: tester.binding.clock.now);
      cache.didChangeAppLifecycleState(AppLifecycleState.resumed); await cache.warmUp();
      cache.didChangeAppLifecycleState(AppLifecycleState.hidden); await tester.pump();
      if (mode == 'shorten') {
        await tester.pump(const Duration(seconds: 6));
        cache.setBackgroundRetention(const Duration(seconds: 5));
      } else if (mode == 'disable') {
        cache.setBackgroundRetention(Duration.zero);
      } else if (mode == 'detach') {
        cache.didChangeAppLifecycleState(AppLifecycleState.detached);
      } else {
        cache.didHaveMemoryPressure();
      }
      await tester.pump(); expect(engine.closed, isTrue, reason: mode);
      await cache.dispose();
    }
  });
  testWidgets('preparation can finish within grace and be reused on return', (tester) async {
    final engine = ColdEngine();
    final cache = VoiceEngineCache(factory: () => engine, clock: tester.binding.clock.now);
    cache.didChangeAppLifecycleState(AppLifecycleState.resumed);
    final warming = cache.warmUp(); await tester.pump();
    cache.didChangeAppLifecycleState(AppLifecycleState.hidden); await tester.pump();
    engine.ready.complete(); await warming;
    expect(engine.closed, isFalse);
    cache.didChangeAppLifecycleState(AppLifecycleState.resumed); await cache.warmUp();
    expect(engine.preparations, 1); await cache.dispose();
  });
  test('resume checks elapsed time even if background timer was suspended', () async {
    var now = DateTime(2026, 10, 23);
    final engines = <FakeVoiceEngine>[];
    final cache = VoiceEngineCache(clock: () => now, factory: () {
      final engine = FakeVoiceEngine(); engines.add(engine); return engine;
    });
    cache.didChangeAppLifecycleState(AppLifecycleState.resumed); await cache.warmUp();
    cache.didChangeAppLifecycleState(AppLifecycleState.hidden); await tick();
    now = now.add(const Duration(seconds: 20));
    cache.didChangeAppLifecycleState(AppLifecycleState.resumed); await cache.warmUp();
    expect(engines.first.closed, isTrue); expect(engines.length, 2);
    await cache.dispose();
  });
}

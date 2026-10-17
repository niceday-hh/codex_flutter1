import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/voice/voice_engine_cache.dart';
import 'voice_session_test.dart' show FakeVoiceEngine;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('manual-only cache construction and eviction never construct an engine', (tester) async {
    var created = 0;
    final cache = VoiceEngineCache(factory: () { created++; return FakeVoiceEngine(); });
    await cache.releaseIdle(); await tester.pump(const Duration(minutes: 1));
    expect(created, 0); await cache.dispose(); expect(created, 0);
  });
  testWidgets('successive voice sheets reuse one engine then idle timeout frees it', (tester) async {
    final engines = <FakeVoiceEngine>[];
    final cache = VoiceEngineCache(idleTimeout: const Duration(seconds: 45),
      factory: () { final e = FakeVoiceEngine(); engines.add(e); return e; });
    final first = cache.acquire(); await first.prepare(); await first.start(); await first.stop(); await first.close();
    expect(engines.single.cancels, greaterThan(0)); expect(engines.single.closed, isFalse);
    await tester.pump(const Duration(seconds: 20));
    final second = cache.acquire(); await second.prepare(); expect(engines.length, 1); await second.close();
    await tester.pump(const Duration(seconds: 44)); expect(engines.single.closed, isFalse);
    await tester.pump(const Duration(seconds: 2)); expect(engines.single.closed, isTrue);
    final third = cache.acquire(); await third.prepare(); expect(engines.length, 2);
    await third.close(); await cache.dispose();
  });
  testWidgets('opening manual input and memory pressure immediately evict idle engine', (tester) async {
    final engines = <FakeVoiceEngine>[];
    final cache = VoiceEngineCache(factory: () { final e = FakeVoiceEngine(); engines.add(e); return e; });
    var lease = cache.acquire(); await lease.prepare(); await lease.close(); await cache.releaseIdle();
    expect(engines.single.closed, isTrue);
    lease = cache.acquire(); await lease.prepare(); await lease.close();
    cache.didHaveMemoryPressure(); await tester.pump(); expect(engines.last.closed, isTrue);
    await cache.dispose();
  });
  testWidgets('background releases active model and resuming alone does not reload it', (tester) async {
    final engines = <FakeVoiceEngine>[];
    final cache = VoiceEngineCache(factory: () { final e = FakeVoiceEngine(); engines.add(e); return e; });
    final lease = cache.acquire(); await lease.prepare();
    cache.didChangeAppLifecycleState(AppLifecycleState.paused); await tester.pump();
    expect(engines.single.closed, isTrue);
    cache.didChangeAppLifecycleState(AppLifecycleState.resumed); await tester.pump(); expect(engines.length, 1);
    await lease.start(); expect(engines.length, 2);
    await lease.close(); await cache.dispose();
  });
  testWidgets('close during decoding discards the engine rather than reusing an in-flight request', (tester) async {
    final engines = <FakeVoiceEngine>[];
    final cache = VoiceEngineCache(factory: () { final e = FakeVoiceEngine(); engines.add(e); return e; });
    final first = cache.acquire(); await first.prepare(); await first.start();
    engines.single.stopGate = Completer<String?>(); final stopping = first.stop(); await tester.pump();
    await first.close(); await tester.pump(); expect(engines.single.closed, isTrue);
    engines.first.stopGate!.complete('奶茶18元'); expect(await stopping, isNull);
    final second = cache.acquire(); await second.prepare(); expect(engines.length, 2);
    await second.close(); await cache.dispose();
  });
}

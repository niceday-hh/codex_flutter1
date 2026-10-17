import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/voice/voice_engine_cache.dart';
import 'voice_session_test.dart' show FakeVoiceEngine;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('on-demand voice cache', () {
  test('manual-only cache construction and eviction never construct an engine', () async {
    var created = 0;
    final cache = VoiceEngineCache(factory: () { created++; return FakeVoiceEngine(); });
    await cache.releaseIdle(); await Future<void>.delayed(Duration.zero);
    expect(created, 0); await cache.dispose(); expect(created, 0);
  });
  test('successive voice sheets reuse one engine then idle timeout frees it', () async {
    final engines = <FakeVoiceEngine>[];
    final cache = VoiceEngineCache(idleTimeout: const Duration(milliseconds: 100),
      factory: () { final e = FakeVoiceEngine(); engines.add(e); return e; });
    final first = cache.acquire(); await first.prepare(); await first.start(); await first.stop(); await first.close();
    expect(engines.single.cancels, greaterThan(0)); expect(engines.single.closed, isFalse);
    final second = cache.acquire(); await second.prepare(); expect(engines.length, 1); await second.close();
    expect(engines.single.closed, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 200)); expect(engines.single.closed, isTrue);
    final third = cache.acquire(); await third.prepare(); expect(engines.length, 2);
    await third.close(); await cache.dispose();
  });
  test('opening manual input and memory pressure immediately evict idle engine', () async {
    final engines = <FakeVoiceEngine>[];
    final cache = VoiceEngineCache(factory: () { final e = FakeVoiceEngine(); engines.add(e); return e; });
    var lease = cache.acquire(); await lease.prepare(); await lease.close(); await cache.releaseIdle();
    expect(engines.single.closed, isTrue);
    lease = cache.acquire(); await lease.prepare(); await lease.close();
    cache.didHaveMemoryPressure(); await Future<void>.delayed(Duration.zero); expect(engines.last.closed, isTrue);
    await cache.dispose();
  });
  test('background releases active model and resuming alone does not reload it', () async {
    final engines = <FakeVoiceEngine>[];
    final cache = VoiceEngineCache(factory: () { final e = FakeVoiceEngine(); engines.add(e); return e; });
    final lease = cache.acquire(); await lease.prepare();
    cache.didChangeAppLifecycleState(AppLifecycleState.paused); await Future<void>.delayed(Duration.zero);
    expect(engines.single.closed, isTrue);
    cache.didChangeAppLifecycleState(AppLifecycleState.resumed); await Future<void>.delayed(Duration.zero); expect(engines.length, 1);
    await lease.start(); expect(engines.length, 2);
    await lease.close(); await cache.dispose();
  });
  test('close during decoding discards the engine rather than reusing an in-flight request', () async {
    final engines = <FakeVoiceEngine>[];
    final cache = VoiceEngineCache(factory: () { final e = FakeVoiceEngine(); engines.add(e); return e; });
    final first = cache.acquire(); await first.prepare(); await first.start();
    engines.single.stopGate = Completer<String?>(); final stopping = first.stop(); await Future<void>.delayed(Duration.zero);
    await first.close(); await Future<void>.delayed(Duration.zero); expect(engines.single.closed, isTrue);
    engines.first.stopGate!.complete('奶茶18元'); expect(await stopping, isNull);
    final second = cache.acquire(); await second.prepare(); expect(engines.length, 2);
    await second.close(); await cache.dispose();
  });
  }, timeout: const Timeout(Duration(seconds: 15)));
}

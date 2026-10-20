import 'dart:async';
import 'package:flutter/widgets.dart';
import 'voice_engine.dart';

// One foreground model, shared by every voice sheet. Preparation never opens
// the microphone and starts after the first frame or on foreground resume.
class VoiceEngineCache with WidgetsBindingObserver {
  VoiceEngineCache({VoiceEngine Function()? factory})
      : _factory = factory ?? ParaformerVoiceEngine.new {
    final state = WidgetsBinding.instance.lifecycleState;
    _background = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden || state == AppLifecycleState.detached;
    WidgetsBinding.instance.addObserver(this);
  }
  final VoiceEngine Function() _factory;
  VoiceEngine? _engine;
  Future<VoiceEngine>? _preparation;
  _VoiceLease? _active;
  Future<void> _transition = Future.value();
  int _generation = 0;
  bool _disposed = false, _background = false, _enabled = false, _evictOnRelease = false;

  Future<void> warmUp() async {
    if (_disposed) return;
    _enabled = true;
    if (_background) return;
    try { await _prepared(); } catch (_) {}
  }
  Future<VoiceEngine> _prepared() {
    if (_disposed || _background) return Future.error(StateError('语音已暂停'));
    return _preparation ??= _prepareCurrent();
  }
  Future<VoiceEngine> _prepareCurrent() async {
    final generation = _generation;
    await _transition;
    if (_disposed || _background || generation != _generation) throw StateError('语音准备已取消');
    final engine = _engine ??= _factory();
    try {
      await engine.prepare();
      if (_disposed || _background || generation != _generation || !identical(engine, _engine)) {
        throw StateError('语音准备已取消');
      }
      return engine;
    } catch (_) {
      if (identical(engine, _engine)) {
        _active?._reset();
        unawaited(_retire());
      }
      rethrow;
    }
  }
  VoiceEngine acquire() {
    if (_disposed || _background || _active != null) throw StateError('语音输入正在使用或已经暂停');
    return _active = _VoiceLease(this);
  }
  Future<VoiceEngine> _obtain(_VoiceLease lease) async {
    await _transition;
    if (_disposed || _background || !identical(_active, lease) || lease._closed) {
      throw StateError('语音已暂停，请返回应用后重试');
    }
    final engine = await _prepared();
    if (_disposed || _background || !identical(_active, lease) || lease._closed) {
      throw StateError('语音已暂停，请返回应用后重试');
    }
    return engine;
  }
  Future<void> _retire() {
    _generation++; _preparation = null; _evictOnRelease = false;
    final engine = _engine; _engine = null;
    final previous = _transition;
    return _transition = () async {
      await previous;
      if (engine != null) { try { await engine.close(); } catch (_) {} }
    }();
  }
  Future<void> _release(_VoiceLease lease) async {
    if (!identical(_active, lease)) return;
    _active = null;
    final pressure = _evictOnRelease;
    if (_disposed || _background || pressure || lease._decoding || lease._failed) {
      unawaited(_retire());
      if (_enabled && !_disposed && !_background && !pressure) unawaited(warmUp());
      return;
    }
    // Keep a healthy or still-preparing model, but stop the microphone.
    final engine = _engine;
    final previous = _transition;
    _transition = () async {
      await previous;
      if (engine != null) { try { await engine.cancel(); } catch (_) {} }
    }();
    await _transition;
  }
  @override
  void didHaveMemoryPressure() {
    // Respect memory pressure without immediately loading the model again.
    if (_active == null) { unawaited(_retire()); }
    else { _evictOnRelease = true; }
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _background = false;
      if (_enabled) unawaited(warmUp());
      return;
    }
    // A permission dialog or notification shade can be briefly inactive.
    if (state != AppLifecycleState.paused && state != AppLifecycleState.detached && state != AppLifecycleState.hidden) return;
    _background = true;
    _active?._reset();
    unawaited(_retire());
  }
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true; WidgetsBinding.instance.removeObserver(this);
    await _active?.close();
    await _retire();
  }
}

class _VoiceLease implements VoiceEngine {
  _VoiceLease(this.cache);
  final VoiceEngineCache cache;
  final _levels = StreamController<double>.broadcast();
  StreamSubscription<double>? _forward;
  Future<VoiceEngine>? _engine;
  Future<void>? _closing;
  bool _closed = false, _decoding = false, _failed = false;
  int _generation = 0;
  Future<VoiceEngine> _get() => _engine ??= cache._obtain(this);
  @override Stream<double> get levels => _levels.stream;
  void _reset() {
    _generation++; _engine = null;
    unawaited(_forward?.cancel()); _forward = null;
  }
  @override Future<void> prepare() async {
    final generation = _generation;
    try {
      final engine = await _get();
      if (_closed || generation != _generation) throw StateError('语音已暂停，请重新录音');
      _failed = false;
      _forward ??= engine.levels.listen((value) { if (!_levels.isClosed) _levels.add(value); });
    } catch (_) { _failed = true; rethrow; }
  }
  @override Future<bool> start() async {
    await prepare(); return (await _get()).start();
  }
  @override Future<String?> stop() async {
    final engine = _engine;
    if (engine == null || _closed) return null;
    final generation = _generation;
    _decoding = true;
    try {
      final text = await (await engine).stop();
      return _closed || generation != _generation ? null : text;
    } catch (_) { _failed = true; rethrow; }
    finally { _decoding = false; }
  }
  @override Future<void> cancel() async {
    final engine = _engine;
    if (engine != null) { try { await (await engine).cancel(); } catch (_) {} }
  }
  @override Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true; _generation++;
    await _forward?.cancel(); _forward = null;
    await cache._release(this);
    await _levels.close();
  }
}

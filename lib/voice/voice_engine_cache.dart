import 'dart:async';
import 'package:flutter/widgets.dart';
import 'voice_engine.dart';

// Constructing this cache does not construct a recorder, spawn an isolate, or
// load a model. A lease prepares it only after the user opens voice input.
class VoiceEngineCache with WidgetsBindingObserver {
  VoiceEngineCache({VoiceEngine Function()? factory,
      this.idleTimeout = const Duration(seconds: 45)})
      : _factory = factory ?? ParaformerVoiceEngine.new {
    WidgetsBinding.instance.addObserver(this);
  }
  final VoiceEngine Function() _factory;
  final Duration idleTimeout;
  VoiceEngine? _engine;
  _VoiceLease? _active;
  Timer? _expiry;
  Future<void> _transition = Future.value();
  bool _disposed = false, _background = false, _evictOnRelease = false;

  VoiceEngine acquire() {
    if (_disposed || _active != null) throw StateError('语音输入正在使用或已经关闭');
    _expiry?.cancel(); _expiry = null;
    return _active = _VoiceLease(this);
  }
  Future<VoiceEngine> _obtain(_VoiceLease lease) async {
    await _transition;
    if (_disposed || _background || !identical(_active, lease) || lease._closed) {
      throw StateError('语音已暂停，请返回应用后重试');
    }
    return _engine ??= _factory();
  }
  Future<void> _retire() {
    _expiry?.cancel(); _expiry = null;
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
    if (_disposed || _background || _evictOnRelease || !lease._ready || lease._decoding || lease._failed) {
      _evictOnRelease = false;
      // The microphone is cancelled by close immediately. Keep disposal on the
      // transition chain so a slow in-flight decode cannot block manual entry.
      unawaited(_retire()); return;
    }
    final engine = _engine;
    final previous = _transition;
    _transition = () async {
      await previous;
      if (engine != null) { try { await engine.cancel(); } catch (_) {} }
    }();
    await _transition;
    if (_active == null && !_disposed && !_background && identical(engine, _engine)) {
      _expiry = Timer(idleTimeout, () { unawaited(_retire()); });
    }
  }
  // Called when opening manual entry. It never initializes voice resources.
  Future<void> releaseIdle() async {
    if (_active == null) { await _retire(); }
    else { _evictOnRelease = true; }
  }
  @override
  void didHaveMemoryPressure() { unawaited(releaseIdle()); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) { _background = false; return; }
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
  bool _closed = false, _ready = false, _decoding = false, _failed = false;
  int _generation = 0;
  Future<VoiceEngine> _get() => _engine ??= cache._obtain(this);
  @override Stream<double> get levels => _levels.stream;
  void _reset() {
    _generation++; _engine = null; _ready = false;
    unawaited(_forward?.cancel()); _forward = null;
  }
  @override Future<void> prepare() async {
    final generation = _generation;
    try {
      final engine = await _get(); await engine.prepare();
      if (_closed || generation != _generation) throw StateError('语音已暂停，请重新录音');
      _ready = true; _failed = false;
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

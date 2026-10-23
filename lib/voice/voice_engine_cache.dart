import 'dart:async';
import 'package:flutter/widgets.dart';
import 'voice_engine.dart';

// One foreground model, shared by every voice sheet. Preparation never opens
// the microphone and starts after the first frame or on foreground resume.
class VoiceEngineCache with WidgetsBindingObserver {
  VoiceEngineCache({VoiceEngine Function()? factory,
      Duration backgroundRetention = const Duration(seconds: 15), DateTime Function()? clock})
      : _factory = factory ?? ParaformerVoiceEngine.new,
        _backgroundRetention = backgroundRetention, _clock = clock ?? DateTime.now {
    final state = WidgetsBinding.instance.lifecycleState;
    _background = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden || state == AppLifecycleState.detached;
    WidgetsBinding.instance.addObserver(this);
  }
  final VoiceEngine Function() _factory;
  final DateTime Function() _clock;
  Duration _backgroundRetention;
  Timer? _backgroundTimer;
  DateTime? _backgroundSince;

  void setBackgroundRetention(Duration duration) {
    final bounded = Duration(milliseconds: duration.inMilliseconds.clamp(0, 30000));
    if (_backgroundRetention == bounded) return;
    _backgroundRetention = bounded;
    if (_background) _scheduleBackgroundRelease();
  }
  void _scheduleBackgroundRelease() {
    _backgroundTimer?.cancel(); _backgroundTimer = null;
    if (_disposed || !_background || _engine == null) return;
    final elapsed = _clock().difference(_backgroundSince ?? _clock());
    final remaining = _backgroundRetention - elapsed;
    if (remaining <= Duration.zero) {
      _active?._reset(); unawaited(_retire());
    } else {
      _backgroundTimer = Timer(remaining, () {
        _backgroundTimer = null;
        if (_background && !_disposed) { _active?._reset(); unawaited(_retire()); }
      });
    }
  }

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
    final existing = _preparation;
    if (existing != null) return existing;
    final task = _preparation = _prepareCurrent();
    unawaited(task.then<void>((_) {}, onError: (Object _, StackTrace __) {
      if (identical(_preparation, task)) _preparation = null;
    }));
    return task;
  }
  Future<VoiceEngine> _prepareCurrent() async {
    final generation = _generation;
    await _transition;
    if (_disposed || _background || generation != _generation) throw StateError('语音准备已取消');
    final engine = _engine ??= _factory();
    try {
      await engine.prepare();
      if (_disposed || generation != _generation || !identical(engine, _engine)) {
        throw StateError('语音准备已取消');
      }
      return engine;
    } catch (_) {
      if (identical(engine, _engine)) {
        _preparation = null;
        // A model failure must not stop audio already being captured.
        if (_active == null) unawaited(_retire());
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
    // Hand out the recorder immediately; model readiness is awaited only by
    // prepare()/decode, never by microphone acquisition.
    return _engine ??= _factory();
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
    if (_disposed || pressure || lease._decoding || lease._failed ||
        (_background && _backgroundRetention <= Duration.zero)) {
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
    if (_active == null || _background) { _active?._reset(); unawaited(_retire()); }
    else { _evictOnRelease = true; }
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Android may suspend Dart timers while backgrounded. Check wall time
      // before reuse so a delayed timer cannot extend the chosen retention.
      final since = _backgroundSince;
      if (_background && since != null &&
          _clock().difference(since) >= _backgroundRetention && _engine != null) {
        _active?._reset(); unawaited(_retire());
      }
      _backgroundTimer?.cancel(); _backgroundTimer = null; _backgroundSince = null;
      _background = false;
      if (_enabled) unawaited(warmUp());
      return;
    }
    if (state == AppLifecycleState.detached) {
      _background = true; _backgroundTimer?.cancel(); _backgroundTimer = null;
      _active?._reset(); unawaited(_retire()); return;
    }
    // Permission dialogs do not restart the grace period or destroy the model.
    if (state != AppLifecycleState.paused && state != AppLifecycleState.hidden) return;
    if (_background) return; // hidden -> paused must not extend the deadline.
    _background = true; _backgroundSince = _clock();
    final decoding = _active?._decoding ?? false;
    _active?._reset();
    final engine = _engine;
    final previous = _transition;
    _transition = () async {
      await previous;
      if (engine != null) { try { await engine.cancel(); } catch (_) {} }
    }();
    if (decoding || _evictOnRelease) { unawaited(_retire()); }
    else { _scheduleBackgroundRelease(); }
  }
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true; _backgroundTimer?.cancel(); _backgroundTimer = null;
    WidgetsBinding.instance.removeObserver(this);
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
      await cache._prepared();
      if (_closed || generation != _generation) throw StateError('语音已暂停，请重新录音');
      _failed = false;
      _forward ??= engine.levels.listen((value) { if (!_levels.isClosed) _levels.add(value); });
    } catch (_) { if (!_closed && generation == _generation) _failed = true; rethrow; }
  }
  @override Future<bool> start() async {
    final generation = _generation;
    final engine = await _get();
    if (_closed || generation != _generation) return false;
    _forward ??= engine.levels.listen((value) { if (!_levels.isClosed) _levels.add(value); });
    return engine.start();
  }
  @override Future<String?> stop() async {
    final engine = _engine;
    if (engine == null || _closed) return null;
    final generation = _generation;
    _decoding = true;
    try {
      final text = await (await engine).stop();
      return _closed || generation != _generation ? null : text;
    } catch (_) { if (!_closed && generation == _generation) _failed = true; rethrow; }
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


import 'dart:async';
import 'package:flutter/foundation.dart';
import 'voice_engine.dart';
import 'voice_parser.dart';

enum VoiceStage { preparing, ready, starting, recording, recognizing, review, error }

class VoiceSession extends ChangeNotifier {
  VoiceSession(this.engine, {DateTime Function()? clock}) : clock = clock ?? DateTime.now;
  final VoiceEngine engine;
  final DateTime Function() clock;
  VoiceStage stage = VoiceStage.preparing;
  VoiceDraft? draft;
  String? error;
  double level = 0;
  int seconds = 0;
  bool _closed = false, _held = false;
  int _generation = 0;
  Timer? _timer;
  StreamSubscription<double>? _levels;
  Future<void>? _startTask;

  void _publish() { if (!_closed) notifyListeners(); }
  Future<void> prepare() async {
    stage = VoiceStage.preparing; error = null; _publish();
    try {
      await engine.prepare();
      if (_closed) return;
      stage = VoiceStage.ready;
      _levels ??= engine.levels.listen((value) { level = value; _publish(); });
    } catch (_) {
      if (_closed) return;
      stage = VoiceStage.error; error = '离线语音模型准备失败，请关闭后重试或重新安装完整版本';
    }
    _publish();
  }

  Future<void> hold() {
    if (_closed || ![VoiceStage.ready, VoiceStage.error].contains(stage)) return Future.value();
    _held = true;
    return _startTask = _start();
  }
  Future<void> _start() async {
    final generation = ++_generation;
    stage = VoiceStage.starting; error = null; draft = null; seconds = 0; _publish();
    try {
      final permitted = await engine.start();
      if (_closed || generation != _generation || !_held) {
        await engine.cancel();
        if (!_closed && generation == _generation) { stage = VoiceStage.ready; _publish(); }
        return;
      }
      if (!permitted) {
        _held = false; stage = VoiceStage.error;
        error = '请允许麦克风权限，然后按住说话'; _publish(); return;
      }
      stage = VoiceStage.recording; _publish();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        seconds++; _publish();
        if (seconds >= 30) unawaited(release());
      });
    } catch (_) {
      if (_closed || generation != _generation) return;
      _held = false; stage = VoiceStage.error; error = '录音启动失败，请检查麦克风权限后重试'; _publish();
    }
  }
  Future<void> release() async {
    _held = false;
    if (stage == VoiceStage.starting) { await _startTask; return; }
    if (_closed || stage != VoiceStage.recording) return;
    _timer?.cancel(); _timer = null;
    final generation = _generation;
    stage = VoiceStage.recognizing; _publish();
    try {
      final text = await engine.stop();
      if (_closed || generation != _generation) return;
      if (text == null || text.trim().isEmpty) throw StateError('未听清，请重新录音');
      draft = parseVoiceEntry(text, now: clock()); stage = VoiceStage.review;
    } catch (failure) {
      if (_closed || generation != _generation) return;
      error = '$failure'.replaceFirst('Bad state: ', ''); stage = VoiceStage.error;
    }
    _publish();
  }
  Future<void> cancelHold() async {
    _held = false; _generation++; _timer?.cancel(); _timer = null;
    await _startTask;
    await engine.cancel();
    if (!_closed) { stage = VoiceStage.ready; level = 0; _publish(); }
  }
  void rerecord() {
    if (stage != VoiceStage.review) return;
    draft = null; error = null; stage = VoiceStage.ready; _publish();
  }
  void edit(VoiceDraft value) { draft = value; _publish(); }
  Future<void> shutdown() async {
    if (_closed) return;
    _closed = true; _held = false; _generation++;
    _timer?.cancel(); await _levels?.cancel();
    await _startTask;
    await engine.close();
  }
  @override
  void dispose() { unawaited(shutdown()); super.dispose(); }
}

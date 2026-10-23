import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

abstract class VoiceEngine {
  Future<void> prepare();
  Future<bool> start();
  Future<String?> stop();
  Future<void> cancel();
  Future<void> close();
  Stream<double> get levels;
}

// Native asset extraction and FFI inference never run on the Flutter UI isolate.
class ParaformerVoiceEngine implements VoiceEngine {
  ParaformerVoiceEngine({AudioRecorder Function()? recorderFactory})
      : _recorderFactory = recorderFactory ?? AudioRecorder.new;
  static const _channel = MethodChannel('smart_budget/voice');
  final AudioRecorder Function() _recorderFactory;
  AudioRecorder? _recorder;
  final _levels = StreamController<double>.broadcast();
  StreamSubscription<Amplitude>? _amplitude;
  final _pending = <int, Completer<String>>{};
  ReceivePort? _responses;
  SendPort? _commands;
  Isolate? _worker;
  Future<void>? _preparing;
  Future<void>? _closing;
  String? _recordPath;
  String? _cacheDir;
  Completer<void>? _ready;
  int _modelGeneration = 0, _recordGeneration = 0;
  bool _closed = false;
  int _nextId = 0;
  @override
  Stream<double> get levels => _levels.stream;

  @override
  Future<void> prepare() {
    if (_closed) return Future.error(StateError('语音引擎已关闭'));
    return _preparing ??= _prepareWithRecovery();
  }
  Future<void> _prepareWithRecovery() async {
    final generation = ++_modelGeneration;
    try { await _prepare(generation).timeout(const Duration(seconds: 45)); }
    catch (_) {
      if (generation == _modelGeneration) _modelGeneration++;
      await _closeWorker();
      _preparing = null;
      rethrow;
    }
  }
  Future<void> _prepare(int generation) async {
    final files = await _channel.invokeMapMethod<String, String>('prepare');
    if (_closed || generation != _modelGeneration) throw StateError('语音已关闭');
    if (files == null) throw StateError('语音模型不可用，请重新安装完整版本');
    _cacheDir = files['recordDir'];
    final ready = _ready = Completer<void>();
    // Attach an error handler before spawning: cancellation can race the spawn.
    unawaited(ready.future.catchError((Object _) {}));
    _responses = ReceivePort();
    _responses!.listen((dynamic message) {
      final data = message as List;
      if (data[0] == 'ready') {
        _commands = data[1] as SendPort;
        if (!ready.isCompleted) ready.complete();
      } else if (data[0] == 'initError') {
        if (!ready.isCompleted) ready.completeError(StateError('${data[1]}'));
      } else {
        final completer = _pending.remove(data[1] as int);
        if (data[0] == 'error') { completer?.completeError(StateError('${data[2]}')); }
        else { completer?.complete('${data[2]}'); }
      }
    });
    final worker = await Isolate.spawn(_recognizerWorker,
      [_responses!.sendPort, files['model']!, files['tokens']!], debugName: 'paraformer-local-asr');
    if (_closed || generation != _modelGeneration) {
      worker.kill(priority: Isolate.immediate);
      throw StateError('语音准备已取消');
    }
    _worker = worker;
    await ready.future;
  }

  Future<String> _request(String action, String path) {
    final id = _nextId++;
    final result = Completer<String>();
    _pending[id] = result;
    _commands!.send([action, id, path]);
    return result.future.timeout(const Duration(seconds: 45), onTimeout: () {
      _pending.remove(id);
      throw StateError('语音识别超时，请重新打开语音输入');
    });
  }

  @override
  Future<bool> start() async {
    if (_closed) return false;
    final generation = ++_recordGeneration;
    // Recording never waits for model extraction or recognizer construction.
    unawaited(prepare().catchError((Object _) {}));
    final recorder = _recorder ??= _recorderFactory();
    if (!await recorder.hasPermission()) return false;
    if (_closed || generation != _recordGeneration) return false;
    final folder = _cacheDir ?? await _channel.invokeMethod<String>('recordDirectory');
    if (_closed || generation != _recordGeneration) return false;
    if (folder == null) throw StateError('无法创建录音目录');
    final path = '$folder/voice-${DateTime.now().microsecondsSinceEpoch}.wav';
    _recordPath = path;
    try {
      await recorder.start(const RecordConfig(encoder: AudioEncoder.wav,
        sampleRate: 16000, numChannels: 1, autoGain: true, noiseSuppress: true, echoCancel: true), path: path);
      if (_closed || generation != _recordGeneration) {
        await recorder.cancel(); await _deleteRecording(path); return false;
      }
      _amplitude = recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((a) {
        if (!_levels.isClosed) _levels.add(((a.current + 55) / 55).clamp(0.0, 1.0).toDouble());
      });
      return true;
    } catch (_) { await _deleteRecording(path); rethrow; }
  }

  @override
  Future<String?> stop() async {
    final generation = _recordGeneration;
    final recording = _recordPath;
    await _amplitude?.cancel(); _amplitude = null;
    final path = await _recorder?.stop();
    if (path == null || _closed || generation != _recordGeneration) {
      await _deleteRecording(recording); return null;
    }
    try {
      // Audio has already been closed safely, even if the model is still cold.
      await prepare();
      if (_closed || generation != _recordGeneration) return null;
      final text = await _request('decode', path);
      return _closed || generation != _recordGeneration ? null : text;
    } finally { await _deleteRecording(recording); }
  }
  Future<void> _deleteRecording(String? path) async {
    if (path == _recordPath) _recordPath = null;
    if (path != null) { try { await File(path).delete(); } catch (_) {} }
  }
  @override
  Future<void> cancel() async {
    _recordGeneration++;
    final path = _recordPath;
    await _amplitude?.cancel(); _amplitude = null;
    await _recorder?.cancel();
    await _deleteRecording(path);
  }
  Future<void> _closeWorker() async {
    final ready = _ready; _ready = null;
    if (ready != null && !ready.isCompleted) ready.completeError(StateError('语音准备已取消'));
    if (_commands != null) {
      try { await _request('close', '').timeout(const Duration(seconds: 3)); } catch (_) {}
    }
    for (final pending in _pending.values) {
      if (!pending.isCompleted) pending.completeError(StateError('语音输入已关闭'));
    }
    _pending.clear();
    _responses?.close(); _responses = null;
    _worker?.kill(); _worker = null; _commands = null;
  }
  @override
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    if (_closed) return;
    _closed = true; _modelGeneration++;
    // Do not wait for a cold model to finish before releasing it.
    try { await cancel(); } catch (_) {}
    await _closeWorker();
    try { await _recorder?.dispose(); } catch (_) {}
    await _levels.close();
  }
}

void _recognizerWorker(List<dynamic> args) {
  final output = args[0] as SendPort;
  sherpa.OfflineRecognizer? recognizer;
  try {
    sherpa.initBindings();
    recognizer = sherpa.OfflineRecognizer(sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(paraformer: sherpa.OfflineParaformerModelConfig(model: args[1] as String),
        tokens: args[2] as String, modelType: 'paraformer', numThreads: 2, debug: false)));
    final input = ReceivePort();
    output.send(['ready', input.sendPort]);
    input.listen((dynamic message) {
      final command = message as List;
      final id = command[1] as int;
      if (command[0] == 'close') {
        recognizer!.free(); input.close(); output.send(['done', id, '']); return;
      }
      sherpa.OfflineStream? stream;
      try {
        final wave = sherpa.readWave(command[2] as String);
        if (wave.samples.isEmpty || wave.sampleRate == 0) throw StateError('没有录到有效声音，请重试');
        if (wave.samples.length < wave.sampleRate * .35) throw StateError('录音太短，请完整说一句');
        // Do not decode silence: prevent a fabricated bookkeeping draft.
        var power = 0.0;
        for (final sample in wave.samples) { power += sample * sample; }
        if (power / wave.samples.length < .000001) throw StateError('声音太轻或未检测到语音，请重试');
        stream = recognizer!.createStream();
        stream.acceptWaveform(samples: wave.samples, sampleRate: wave.sampleRate);
        recognizer.decode(stream);
        output.send(['done', id, recognizer.getResult(stream).text]);
      } catch (error) { output.send(['error', id, '$error']); }
      finally { stream?.free(); }
    });
  } catch (error) { recognizer?.free(); output.send(['initError', '$error']); }
}


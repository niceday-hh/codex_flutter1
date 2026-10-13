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
  static const _channel = MethodChannel('smart_budget/voice');
  final _recorder = AudioRecorder();
  final _levels = StreamController<double>.broadcast();
  StreamSubscription<Amplitude>? _amplitude;
  final _pending = <int, Completer<String>>{};
  ReceivePort? _responses;
  SendPort? _commands;
  Isolate? _worker;
  Future<void>? _preparing;
  String? _recordPath;
  String? _cacheDir;
  bool _closed = false;
  int _nextId = 0;
  @override
  Stream<double> get levels => _levels.stream;

  @override
  Future<void> prepare() => _preparing ??= _prepare();
  Future<void> _prepare() async {
    final files = await _channel.invokeMapMethod<String, String>('prepare');
    if (_closed) return;
    if (files == null) throw StateError('语音模型不可用，请重新安装完整版本');
    _cacheDir = files['recordDir'];
    final ready = Completer<void>();
    _responses = ReceivePort();
    _responses!.listen((dynamic message) {
      final data = message as List;
      if (data[0] == 'ready') {
        _commands = data[1] as SendPort;
        ready.complete();
      } else if (data[0] == 'initError') {
        ready.completeError(StateError('${data[1]}'));
      } else {
        final completer = _pending.remove(data[1] as int);
        if (data[0] == 'error') { completer?.completeError(StateError('${data[2]}')); }
        else { completer?.complete('${data[2]}'); }
      }
    });
    _worker = await Isolate.spawn(_recognizerWorker,
      [_responses!.sendPort, files['model']!, files['tokens']!], debugName: 'paraformer-local-asr');
    await ready.future;
    if (_closed) await _closeWorker();
  }

  Future<String> _request(String action, String path) {
    final id = _nextId++;
    final result = Completer<String>();
    _pending[id] = result;
    _commands!.send([action, id, path]);
    return result.future;
  }

  @override
  Future<bool> start() async {
    await prepare();
    if (_closed || !await _recorder.hasPermission()) return false;
    if (_closed) return false;
    _recordPath = '$_cacheDir/voice-${DateTime.now().microsecondsSinceEpoch}.wav';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.wav,
      sampleRate: 16000, numChannels: 1, autoGain: true, noiseSuppress: true, echoCancel: true), path: _recordPath!);
    _amplitude = _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((a) {
      if (!_levels.isClosed) _levels.add(((a.current + 55) / 55).clamp(0.0, 1.0).toDouble());
    });
    return true;
  }

  @override
  Future<String?> stop() async {
    await _amplitude?.cancel(); _amplitude = null;
    final path = await _recorder.stop();
    if (path == null || _closed) { await _deleteRecording(); return null; }
    try { return await _request('decode', path); }
    finally { await _deleteRecording(); }
  }
  Future<void> _deleteRecording() async {
    final path = _recordPath; _recordPath = null;
    if (path != null) { try { await File(path).delete(); } catch (_) {} }
  }
  @override
  Future<void> cancel() async {
    await _amplitude?.cancel(); _amplitude = null;
    await _recorder.cancel();
    await _deleteRecording();
  }
  Future<void> _closeWorker() async {
    if (_commands != null) {
      try { await _request('close', ''); } catch (_) {}
    }
    _responses?.close(); _responses = null;
    _worker?.kill(); _worker = null; _commands = null;
  }
  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try { await cancel(); await _preparing; } catch (_) {}
    await _closeWorker();
    await _recorder.dispose(); await _levels.close();
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
        recognizer!.decode(stream);
        output.send(['done', id, recognizer!.getResult(stream).text]);
      } catch (error) { output.send(['error', id, '$error']); }
      finally { stream?.free(); }
    });
  } catch (error) { recognizer?.free(); output.send(['initError', '$error']); }
}

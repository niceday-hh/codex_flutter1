import 'dart:io';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

// The same Dart FFI/configuration used by the app, with the pinned real model.
void main() {
  sherpa.initBindings();
  final recognizer = sherpa.OfflineRecognizer(sherpa.OfflineRecognizerConfig(
    model: sherpa.OfflineModelConfig(paraformer: const sherpa.OfflineParaformerModelConfig(model: '.voice-model-cache/model.int8.onnx'),
      tokens: '.voice-model-cache/tokens.txt', modelType: 'paraformer', numThreads: 2, debug: false)));
  final stream = recognizer.createStream();
  try {
    final wave = sherpa.readWave('.voice-model-cache/test_wavs/0.wav');
    stream.acceptWaveform(samples: wave.samples, sampleRate: wave.sampleRate);
    recognizer.decode(stream);
    final text = recognizer.getResult(stream).text;
    print('Real Paraformer Mandarin smoke transcription: $text');
    if (!text.contains('研究') || !text.contains('感兴趣')) throw StateError('Unexpected Mandarin transcription');
  } finally { stream.free(); recognizer.free(); }
  final apk = File('build/app/outputs/flutter-apk/app-release.apk');
  if (apk.existsSync()) print('APK bytes: ${apk.lengthSync()}');
}

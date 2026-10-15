import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('smart_budget/storage');
  const voice = MethodChannel('smart_budget/voice');

  testWidgets('native iOS storage round trips and rejects corrupt replacement', (tester) async {
    final previous = await storage.invokeMethod<String>('load');
    final calendar = await storage.invokeMethod<String>('loadCalendar');
    try {
      const ledger = '{"entries":[],"monthlyBudget":4321,"note":"午饭，牛肉面"}';
      await storage.invokeMethod<void>('save', ledger);
      await storage.invokeMethod<void>('saveCalendar', '{"automatic":true}');
      expect(await storage.invokeMethod<String>('load'), ledger);
      expect(await storage.invokeMethod<String>('loadCalendar'), '{"automatic":true}');
      await expectLater(storage.invokeMethod<void>('save', '{broken'), throwsA(isA<PlatformException>()));
      expect(await storage.invokeMethod<String>('load'), ledger);
    } finally {
      await storage.invokeMethod<void>('save', previous ?? '{"entries":[]}');
      await storage.invokeMethod<void>('saveCalendar', calendar ?? '{}');
    }
  });

  testWidgets('bundled Paraformer runs real iOS FFI inference offline', (tester) async {
    final files = await voice.invokeMapMethod<String, String>('prepare');
    expect(files, isNotNull);
    expect(await File(files!['model']!).length(), 227330205);
    expect(await File(files['tokens']!).exists(), isTrue);
    // CI deliberately packages a fixed upstream sample; production builds omit it.
    final sample = File(files['model']!).parent.uri.resolve('smoke.wav').toFilePath();
    expect(await File(sample).exists(), isTrue,
        reason: 'Prepare the CI model with --include-smoke-audio');
    sherpa.initBindings();
    final recognizer = sherpa.OfflineRecognizer(sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        paraformer: sherpa.OfflineParaformerModelConfig(model: files['model']!),
        tokens: files['tokens']!, modelType: 'paraformer', numThreads: 2,
      ),
    ));
    final stream = recognizer.createStream();
    try {
      final wave = sherpa.readWave(sample);
      expect(wave.samples, isNotEmpty);
      stream.acceptWaveform(samples: wave.samples, sampleRate: wave.sampleRate);
      recognizer.decode(stream);
      expect(recognizer.getResult(stream).text.trim(), isNotEmpty);
    } finally {
      stream.free();
      recognizer.free();
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}

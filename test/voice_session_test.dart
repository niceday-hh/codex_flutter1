import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/voice/voice_engine.dart';
import 'package:smart_budget/voice/voice_session.dart';

class FakeVoiceEngine implements VoiceEngine {
  FakeVoiceEngine({this.text = '今天午饭花了二十八块五，备注牛肉面'});
  String text;
  bool permission = true, closed = false;
  int starts = 0, stops = 0, cancels = 0;
  Completer<bool>? startGate;
  Completer<String?>? stopGate;
  final signal = StreamController<double>.broadcast();
  @override Stream<double> get levels => signal.stream;
  @override Future<void> prepare() async {}
  @override Future<bool> start() async { starts++;return startGate == null ? permission : startGate!.future; }
  @override Future<String?> stop() async { stops++;return stopGate == null ? text : stopGate!.future; }
  @override Future<void> cancel() async { cancels++; }
  @override Future<void> close() async { closed = true; await signal.close(); }
}
void main() {
  test('release creates a draft, rerecord clears it, close releases engine', () async {
    final engine=FakeVoiceEngine();final session=VoiceSession(engine);
    await session.prepare();expect(session.stage,VoiceStage.ready);
    await session.hold();expect(session.stage,VoiceStage.recording);
    await session.release();expect(session.stage,VoiceStage.review);expect(session.draft!.amount,28.5);
    session.rerecord();expect(session.draft,isNull);expect(session.stage,VoiceStage.ready);
    await session.shutdown();expect(engine.closed,isTrue);session.dispose();
  });
  test('early finger release while permission waits cancels the eventual recording', () async {
    final engine=FakeVoiceEngine()..startGate=Completer<bool>();final session=VoiceSession(engine);
    await session.prepare();final holding=session.hold();final release=session.release();
    engine.startGate!.complete(true);await holding;await release;
    expect(session.stage,VoiceStage.ready);expect(engine.cancels,1);expect(engine.stops,0);
    await session.shutdown();session.dispose();
  });
  test('permission refusal and empty transcription never produce a saved draft', () async {
    final engine=FakeVoiceEngine()..permission=false;final session=VoiceSession(engine);
    await session.prepare();await session.hold();expect(session.stage,VoiceStage.error);expect(session.draft,isNull);
    engine.permission=true;engine.text='';await session.hold();await session.release();
    expect(session.stage,VoiceStage.error);expect(session.draft,isNull);await session.shutdown();session.dispose();
  });
  test('dismissal during recognition ignores a late result', () async {
    final engine=FakeVoiceEngine()..stopGate=Completer<String?>();final session=VoiceSession(engine);
    await session.prepare();await session.hold();final recognizing=session.release();
    await session.shutdown();engine.stopGate!.complete('工资到账8000元');await recognizing;
    expect(session.draft,isNull);expect(engine.closed,isTrue);session.dispose();
  });
}

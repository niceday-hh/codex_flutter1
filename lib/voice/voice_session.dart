import 'dart:async';
import 'package:flutter/foundation.dart';
import '../notes/note_catalog.dart';
import 'voice_engine.dart';
import 'voice_parser.dart';

enum VoiceStage { preparing, ready, starting, recording, recognizing, review, error }
enum VoiceField { amount, type, category, note, date }

class VoiceSession extends ChangeNotifier {
  VoiceSession(this.engine, {DateTime Function()? clock, this.loadNotes}) : clock = clock ?? DateTime.now;
  final VoiceEngine engine;
  final DateTime Function() clock;
  final Future<NoteCatalog> Function()? loadNotes;
  final Set<VoiceField> editedFields = {};
  int _parseGeneration = 0;
  bool reparsing = false;
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
      stage = VoiceStage.error; error = '离线语音准备失败，请按住说话重试；仍失败可重新打开语音输入';
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
    stage = VoiceStage.starting; error = null; draft = null; seconds = 0;
    editedFields.clear(); _parseGeneration++; _publish();
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
      final notes = await _notes();
      if (_closed || generation != _generation) return;
      final parsed = await _parse(text, notes);
      if (_closed || generation != _generation) return;
      draft = parsed; stage = VoiceStage.review;
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
    draft = null; error = null; editedFields.clear(); _parseGeneration++; reparsing = false;
    stage = VoiceStage.ready; _publish();
  }
  Future<NoteCatalog?> _notes() async {
    final loader = loadNotes;
    if (loader == null) return null;
    try { return await loader().timeout(const Duration(seconds: 5)); }
    catch (_) { return null; } // History is optional; recognition must remain usable.
  }
  Future<VoiceDraft> _parse(String text, NoteCatalog? notes, {bool? incomeOverride, String? noteOverride}) {
    final input = (text: text, now: clock(), expense: notes?.expense ?? <NoteChoice>[],
      income: notes?.income ?? <NoteChoice>[], incomeOverride: incomeOverride, noteOverride: noteOverride);
    // Pass only plain note statistics, never NoteCatalog's cached Futures.
    return input.expense.length + input.income.length >= 200
      ? compute(_parseVoiceDraft, input, debugLabel: 'parse-personal-voice-draft')
      : Future.value(_parseVoiceDraft(input));
  }
  void edit(VoiceDraft value, {required Set<VoiceField> fields}) {
    editedFields.addAll(fields); draft = value; _publish();
  }
  Future<void> reparseText(String text) async {
    if (_closed || stage != VoiceStage.review || text.trim().isEmpty) return;
    final generation = ++_parseGeneration;
    reparsing = true; _publish();
    final notes = await _notes();
    if (_closed || generation != _parseGeneration || stage != VoiceStage.review) return;
    final previous = draft!;
    var parsed = await _parse(text, notes,
      incomeOverride: editedFields.contains(VoiceField.type) ? previous.isIncome : null,
      noteOverride: editedFields.contains(VoiceField.note) ? previous.note : null);
    if (_closed || generation != _parseGeneration || stage != VoiceStage.review) return;
    final current = draft!;
    if (editedFields.contains(VoiceField.amount) && current.amount != null) parsed = parsed.copyWith(amount: current.amount);
    if (editedFields.contains(VoiceField.category)) parsed = parsed.copyWith(category: current.category);
    if (editedFields.contains(VoiceField.date)) parsed = parsed.copyWith(date: current.date);
    draft = parsed; reparsing = false; _publish();
  }
  Future<void> shutdown() async {
    if (_closed) return;
    _closed = true; _held = false; _generation++; _parseGeneration++;
    _timer?.cancel(); await _levels?.cancel();
    await _startTask;
    await engine.close();
  }
  @override
  void dispose() { unawaited(shutdown()); super.dispose(); }
}

typedef _VoiceParseInput = ({String text, DateTime now, List<NoteChoice> expense,
  List<NoteChoice> income, bool? incomeOverride, String? noteOverride});
VoiceDraft _parseVoiceDraft(_VoiceParseInput input) => parseVoiceEntry(input.text, now: input.now,
  catalog: NoteCatalog.fromChoices(expense: input.expense, income: input.income),
  incomeOverride: input.incomeOverride, noteOverride: input.noteOverride);

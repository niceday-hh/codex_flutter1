import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/models.dart';
import 'package:smart_budget/notes/note_catalog.dart';
import 'package:smart_budget/voice/voice_parser.dart';
import 'package:smart_budget/voice/voice_session.dart';
import 'voice_session_test.dart' show FakeVoiceEngine;

void main() {
  final now = DateTime(2026, 10, 17, 16);
  LedgerEntry entry(String note, String category, {bool income = false, int days = 0}) => LedgerEntry(
    id: '$note-$category-$days', title: note, category: category, amount: 20,
    isIncome: income, date: now.subtract(Duration(days: days)), note: note);
  VoiceDraft parse(String text, List<LedgerEntry> entries) =>
    parseVoiceEntry(text, now: now, catalog: NoteCatalog(entries));

  test('complete personal history supplies category and separates income from expense', () {
    final entries = [entry('盒马', '餐饮', days: 500),
      for (var i = 0; i < 80; i++) entry('其他商家$i', '购物', days: i),
      entry('盒马', '兼职', income: true)];
    final draft = parse('盒马花了58元', entries);
    expect(draft.category, '餐饮'); expect(draft.categoryReason, contains('历史备注「盒马」'));
    expect(parse('盒马收入58元', entries).category, '兼职');
    expect(parse('不存在的商家58元', entries).category, '其他');
  });
  test('spoken category and concrete current purpose take priority over merchant history', () {
    final entries = [entry('盒马', '餐饮'), entry('小象买菜', '餐饮')];
    expect(parse('盒马58元，分类购物', entries).category, '购物');
    expect(parse('盒马买纸巾28元', entries).category, '日用');
    expect(parse('小象买菜38元', entries).category, '餐饮');
    expect(parse('盒马买冰箱3000元', entries).category, '居家');
  });
  test('ambiguous history offers alternatives and category counts resolve a clear preference', () {
    final entries = [entry('盒马', '餐饮'), entry('盒马', '日用')];
    final draft = parse('盒马58元', entries);
    expect(draft.category, '其他'); expect(draft.categorySuggestions.length, 2);
    expect(draft.warnings.any((w) => w.contains('歧义')), isTrue);
    entries.addAll([for (var i = 1; i <= 12; i++) entry('盒马', '餐饮', days: i)]);
    final catalog = NoteCatalog(entries);
    expect(catalog.expense.single.categoryUsage['餐饮']!.count, 13);
    expect(parse('盒马58元', entries).category, '餐饮');
    expect(parse('盒马58元', entries).copyWith(category: '日用').warnings, isEmpty);
  });
  test('longer names and parenthesized merchant branches are matched literally', () {
    final entries = [entry('盒马', '购物'), entry('盒马鲜生（万象城店）', '餐饮')];
    expect(parse('盒马鲜生花58元', entries).category, '餐饮');
    expect(parse('盒马58元', [entry('马', '餐饮')]).category, '其他');
  });
  test('remark supplies purpose without leaking remark quantities or income into fields', () {
    final draft = parse('花28元，备注牛肉面', []);
    expect(draft.category, '餐饮'); expect(draft.note, '牛肉面');
    final reversed = parse('备注牛肉面，花了28元', []);
    expect(reversed.amount, 28); expect(reversed.note, '牛肉面');
    expect(parse('午饭28元，备注买了2杯咖啡', []).amount, 28);
    expect(parse('买纸巾16元，备注工资', []).isIncome, isFalse);
    expect(parse('花58元，备注盒马', [entry('盒马', '餐饮')]).category, '餐饮');
  });
  test('manual field corrections clear only the warnings they resolve', () {
    final draft = parse('不知道是什么', []);
    expect(draft.warnings.length, 2);
    final amountFixed = draft.copyWith(amount: 28);
    expect(amountFixed.warnings, ['用途不明确，请选择分类']);
    expect(amountFixed.copyWith(category: '餐饮').warnings, isEmpty);
    expect(parse('奶茶18元，地铁6元', []).copyWith(amount: 24).warnings, isEmpty);
    expect(parse('2月31日午饭28元', []).copyWith(date: now).warnings, isEmpty);
  });
  test('reparse uses history and preserves manually corrected amount category and date', () async {
    final engine = FakeVoiceEngine(text: '盒码58元');
    final session = VoiceSession(engine, clock: () => now,
      loadNotes: () async => NoteCatalog([entry('盒马', '餐饮')]));
    await session.prepare(); await session.hold(); await session.release();
    await session.reparseText('盒马58元');
    expect(session.draft!.category, '餐饮'); expect(session.draft!.rawText, '盒马58元');
    final yesterday = now.subtract(const Duration(days: 1));
    session.edit(session.draft!.copyWith(amount: 60, category: '日用', date: yesterday),
      fields: {VoiceField.amount, VoiceField.category, VoiceField.date});
    await session.reparseText('盒马99元');
    expect(session.draft!.amount, 60); expect(session.draft!.category, '日用');
    expect(session.draft!.date, yesterday); expect(session.draft!.warnings, isEmpty);
    session.edit(session.draft!.copyWith(note: ''), fields: {VoiceField.note});
    await session.reparseText('盒马99元'); expect(session.draft!.note, '');
    session.rerecord(); expect(session.editedFields, isEmpty);
    await session.shutdown(); session.dispose();
  });
  test('large histories parse off the UI isolate without sending picker Future caches', () async {
    final catalog = NoteCatalog([entry('盒马', '餐饮'),
      for (var i=0;i<250;i++) entry('商家$i','购物')]);
    await catalog.prepare(false, '餐饮');
    final session = VoiceSession(FakeVoiceEngine(text: '盒马58元'), clock: () => now,
      loadNotes: () async => catalog);
    await session.prepare(); await session.hold(); await session.release();
    expect(session.draft!.category, '餐饮'); expect(session.draft!.amount, 58);
    await session.shutdown(); session.dispose();
  });
}

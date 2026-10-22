import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/voice/voice_parser.dart';

void main() {
  final now = DateTime(2026, 10, 22, 20, 31);
  VoiceDraft parse(String text, {DateTime? clock}) => parseVoiceEntry(text, now: clock ?? now);
  void dateIs(VoiceDraft draft, int year, int month, int day) {
    expect([draft.date.year, draft.date.month, draft.date.day], [year, month, day]);
  }

  test('Chinese, mixed, spaced and numeric absolute dates', () {
    for (final date in ['十月一号', '10月一号', '十月1日', '10月 1号', '10月1',
      '二〇二六年十月一日', '二零二六年10月1号', '2026-10-01', '2026/10/01', '２０２６年１０月１日']) {
      final draft = parse('$date 买纸巾16元');
      dateIs(draft, 2026, 10, 1);
      expect(draft.amount, 16, reason: date);
      expect(draft.category, '日用');
      expect(draft.note, '纸巾');
      expect(draft.warnings, isEmpty, reason: date);
    }
  });
  test('calendar arithmetic crosses years, months and leap days', () {
    dateIs(parse('去年十二月三十一号买纸巾16元'), 2025, 12, 31);
    dateIs(parse('上个月十五号买纸巾16元'), 2026, 9, 15);
    dateIs(parse('本月五号买纸巾16元'), 2026, 10, 5);
    dateIs(parse('三天前买纸巾16元'), 2026, 10, 19);
    dateIs(parse('上个月十五号买纸巾16元', clock: DateTime(2026, 1, 2)), 2025, 12, 15);
    dateIs(parse('三天前买纸巾16元', clock: DateTime(2026, 1, 2)), 2025, 12, 30);
    dateIs(parse('昨天买纸巾16元', clock: DateTime(2024, 3, 1)), 2024, 2, 29);
    dateIs(parse('二〇二四年二月二十九号买纸巾16元'), 2024, 2, 29);
  });
  test('week expressions and explicit dates cannot silently override each other', () {
    dateIs(parse('上星期一午饭28元'), 2026, 10, 12);
    dateIs(parse('上周星期一午饭28元'), 2026, 10, 12);
    dateIs(parse('本周一午饭28元'), 2026, 10, 19);
    dateIs(parse('星期五午饭28元'), 2026, 10, 16);
    final conflict = parse('10月1号星期一午饭28元');
    dateIs(conflict, 2026, 10, 1);
    expect(conflict.warnings, contains('日期表述存在冲突，请核对记账日期'));
    expect(parse('10月1号星期四午饭28元').warnings, isEmpty);
    expect(parse('昨天前天午饭28元').warnings, contains('日期表述存在冲突，请核对记账日期'));
  });
  test('invalid, vague and future dates require review', () {
    for (final text in ['二月三十一号', '二〇二五年二月二十九号', '上个月三十一号', '前几天', '上周末', '十五号']) {
      final draft = parse('$text 午饭28元');
      expect(draft.warnings, contains('日期不明确，请核对'), reason: text);
      expect(draft.amount, 28);
    }
    expect(parse('十二月一号午饭28元').warnings, contains('日期在未来，请核对日期和年份'));
    expect(parse('明天午饭28元').warnings, contains('日期在未来，请核对日期和年份'));
    expect(parse('午饭28元').warnings, isEmpty);
  });
  test('object and billing dates stay in notes without changing payment date', () {
    final movie = parse('今天买了明天的电影票50元');
    dateIs(movie, 2026, 10, 22);
    expect(movie.note, contains('明天的电影票'));
    expect(movie.warnings, isEmpty);
    final bill = parse('交了上个月的电费100元');
    dateIs(bill, 2026, 10, 22);
    expect(bill.note, contains('上个月的电费'));
    expect(bill.warnings, isEmpty);
    final train = parse('昨天买了10月25号的火车票300元');
    dateIs(train, 2026, 10, 21);
    expect(train.amount, 300);
    expect(train.warnings, isEmpty);
  });
  test('date corrections discard rejected alternatives', () {
    dateIs(parse('不是昨天，是前天买纸巾16元'), 2026, 10, 20);
    dateIs(parse('10月1号，不对，改成10月2号买纸巾16元'), 2026, 10, 2);
    expect(parse('10月1号，不对，改成10月2号买纸巾16元').warnings, isEmpty);
  });
  test('durations, quantities, discounts and clocks do not become money', () {
    final cases = {'停车30分钟，花了5元': 5.0, '停车三十分钟，花了五元': 5.0,
      '打车3公里花了15元': 15.0, '买2杯咖啡，实付18元': 18.0,
      '买衣服打八折，实付80元': 80.0, '上午十点打车23元': 23.0,
      '10:30打车23元': 23.0, '咖啡二十八点五元': 28.5, '支付三元五角二分': 3.52};
    for (final c in cases.entries) {
      final draft = parse(c.key);
      expect(draft.amount, c.value, reason: c.key);
      expect(draft.warnings.where((w) => w.contains('多个金额')), isEmpty, reason: c.key);
    }
    for (final text in ['停车30分钟', '收到2件快递', '买两杯咖啡', '买衣服打八折']) {
      expect(parse(text).amount, isNull, reason: text);
    }
    expect(parse('停车30分钟，花了5元').note, contains('30分钟'));
  });
  test('receipt of goods is not receipt of money', () {
    for (final text in ['收到快递，付了运费12元', '收到外卖花了28元', '收到2件快递，运费12元']) {
      expect(parse(text).isIncome, isFalse, reason: text);
    }
    for (final text in ['收到工资8000元', '收到500元', '收到红包200元', '退款十二元', '报销交通费50元']) {
      expect(parse(text).isIncome, isTrue, reason: text);
    }
    expect(parse('收到工资8000元，花了28元').warnings, contains('同时提到收款和付款，请核对收支类型与金额'));
  });
  test('rejected purposes, types and amounts do not contaminate accepted clause', () {
    final purpose = parse('不是买药，是买纸巾20元');
    expect(purpose.category, '日用');
    expect(purpose.note, '纸巾');
    expect(purpose.isIncome, isFalse);
    expect(parse('不是收入，是支出20元买纸巾').isIncome, isFalse);
    expect(parse('不是支出，是收入500元').isIncome, isTrue);
    expect(parse('不是20元，是25元买纸巾').amount, 25);
    expect(parse('还没收到工资，买奶茶18元').isIncome, isFalse);
    expect(parse('不是买药而是买纸巾20元').category, '日用');
    expect(parse('午饭28元，不对，改成25元').amount, 25);
  });
  test('explicit remarks and manually corrected dates remain independent', () {
    final draft = parse('昨天午饭28元，备注明天的活动');
    dateIs(draft, 2026, 10, 21);
    expect(draft.note, '明天的活动');
    final corrected = parse('十二月一号午饭28元').copyWith(date: DateTime(2025, 12, 1));
    expect(corrected.warnings.where((w) => w.contains('日期')), isEmpty);
  });
}

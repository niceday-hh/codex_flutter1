import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/voice/voice_parser.dart';

void main() {
  final now = DateTime(2026, 10, 13, 20, 31);
  VoiceDraft parse(String text) => parseVoiceEntry(text, now: now);
  test('spoken cents, decimals and Chinese shorthand preserve money', () {
    final cases = {'午饭花了二十八块五，备注牛肉面':28.5, '地铁六元':6.0,
      '支付一百零五元三角二分':105.32, '花了五毛钱':.5, '付了三毛五':.35,
      '咖啡二十八点五元':28.5, '买衣服一百二十元':120.0, '衣服花了一百二':120.0,
      '房租一千五百元':1500.0, '收入一万零五元':10005.0, '午饭28.50元':28.5,
      '花了２８．５０元':28.5, '收到工资8,000元':8000.0};
    for (final c in cases.entries) { expect(parse(c.key).amount, c.value, reason: c.key); }
  });
  test('specific category wins over generic buying and home use', () {
    final cases = {'喝奶茶18元':'餐饮','午饭花28元':'餐饮','喝的花了12元':'餐饮',
      '吃的28元':'餐饮','买纸巾16元':'日用','家用的花了38元':'日用','买家具800元':'居家',
      '买冰箱3000元':'居家','交房租1500元':'住房','买衣服120元':'服饰','买东西50元':'购物',
      '买药32元':'医疗','打车23元':'交通','买猫粮99元':'宠物'};
    for (final c in cases.entries) { expect(parse(c.key).category, c.value, reason:c.key); }
  });
  test('income and refunds, expense negation and explicit categories', () {
    for (final text in ['收到工资8000元','工资到账八千元','退款十二元','报销交通费50元','收到奖金500元']) {
      expect(parse(text).isIncome, isTrue, reason:text);
    }
    expect(parse('收到工资8000元').category, '工资');
    expect(parse('退款十二元').category, '退款');
    expect(parse('报销交通费50元').category, '报销');
    expect(parse('还没收到工资，买奶茶18元').isIncome, isFalse);
    expect(parse('给别人转了50元').isIncome, isFalse);
    expect(parse('买奶茶18元，分类购物').category, '购物');
  });
  test('notes do not contaminate amount or category', () {
    final draft = parse('今天午饭花了二十八块五，备注牛肉面');
    expect(draft.note, '牛肉面'); expect(draft.category, '餐饮'); expect(draft.amount,28.5);
    expect(parse('买纸巾16元，备注工资').isIncome, isFalse);
    expect(parse('午饭28元，备注买了2杯咖啡').amount, 28);
    expect(parse('买纸巾16元').note, '纸巾');
  });
  test('dates and quantities are not mistaken for money', () {
    expect(parse('昨天午饭28元').date.day,12);
    expect(parse('前天午饭28元').date.day,11);
    expect(parse('10月1日买纸巾16元').date, DateTime(2026,10,1,20,31));
    expect(parse('买两杯奶茶18元').amount,18);
    expect(parse('买两杯奶茶').amount,isNull);
    expect(parse('上午十点打车23元').amount,23);
    expect(parse('上周星期一午饭28元').date.day,5);
    expect(parse('2月31日午饭28元').warnings,contains('日期不明确，请核对'));
  });
  test('ambiguous multiple transactions require a reviewed total', () {
    final ambiguous = parse('奶茶18元，地铁6元');
    expect(ambiguous.amount,isNull);expect(ambiguous.warnings,isNotEmpty);
    expect(parse('奶茶18元，蛋糕12元，一共30元').amount,30);
    expect(parse('午饭28元，不对，改成25元').amount,25);
    expect(parse('奶茶').amount,isNull);
    expect(parse('奶茶0元').warnings,isNotEmpty);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/insights/insight_engine.dart';
import 'package:smart_budget/models.dart';

LedgerEntry e(int day, double amount, {int month = 9, String category = '餐饮', String note = '', bool income = false}) => LedgerEntry(
  id: '$month-$day-$amount-$note', title: category, category: category,
  amount: amount, isIncome: income, date: DateTime(2026, month, day, 12), note: note);
InsightReport report(List<LedgerEntry> es, {DateTime? start, DateTime? end, DateTime? now, bool income = false}) => analyzeInsights(
  entries: es, start: start ?? DateTime(2026,9,1), end: end ?? DateTime(2026,10,1),
  now: now ?? DateTime(2026,9,14,18), income: income, monthlyBudget: 1000);
SpendingInsight item(InsightReport r, String id) => r.items.firstWhere((e) => e.id == id);

void main() {
  test('partial month uses preceding equal days, excludes future and opposite mode', () {
    final r = report([e(1,100), e(14,100), e(15,999),e(1,999,income:true),
      e(18,100,month:8),e(31,100,month:8),e(17,999,month:8)]);
    expect(r.count,2); expect(r.days,14);
    expect(item(r,'change').value,'+0.0%');
    expect(item(r,'change').entries.length,4);
  });
  test('missing baseline does not manufacture a growth rate', () {
    expect(item(report([e(1,10)]),'change').ready,isFalse);
    expect(report([e(15,10)], now:DateTime(2026,8,31)).days,0);
  });
  test('frequency and average decomposition sums to the amount difference', () {
    final r = report([e(1,20),e(2,20),e(3,20),e(31,10,month:8),e(30,10,month:8)]);
    expect(item(r,'frequency').summary,contains('¥15.00'));
    expect(item(r,'frequency').summary,contains('¥25.00'));
  });
  test('weekend calculation divides by calendar exposure rather than total share', () {
    final es = [for (var d=1;d<=14;d++) e(d,10)];
    expect(item(report(es),'rhythm').value,'1.00 倍');
  });
  test('MAD uses prior same-category observations and skips zero dispersion', () {
    final baseline = [for(var i=0;i<10;i++) e(i+1,10+i.toDouble(),month:8)];
    final r = report([...baseline,e(1,200),e(2,12),e(3,900,category:'购物')]);
    expect(item(r,'unusual').entries.map((e)=>e.amount),[200]);
    expect(item(report([for(var i=1;i<=9;i++)e(i,10,month:8),e(1,999)]),'unusual').ready,isFalse);
  });
  test('recurrence needs notes and repeated intervals with stable amounts', () {
    final r = report([e(1,30,month:7,note:'会员'),e(1,30,month:8,note:'会员'),e(1,30,note:'会员'),
      e(2,50,month:7),e(2,50,month:8),e(2,50)]);
    expect(item(r,'recurring').value,'1 组');
    expect(item(r,'recurring').entries.length,3);
  });
  test('budget scenario only runs in current month with enough recorded days', () {
    final es=[for(var d=1;d<=14;d++)e(d,10)];
    expect(report(es).projected,300);
    expect(report(es,start:DateTime(2026,9,7),end:DateTime(2026,9,14)).projected,isNull);
    expect(report([e(1,100)]).projected,isNull);
    final ir=report([e(1,100,income:true)],income:true);
    expect(ir.items.any((i)=>i.id=='budget'),isFalse);
  });
  test('empty, leap day, year boundary and nonfinite records are safe', () {
    expect(report([]).count,0);
    expect(report([e(1,double.nan),e(1,double.infinity),e(1,-1)]).count,0);
    expect(report([],start:DateTime(2024,2,1),end:DateTime(2024,3,1),now:DateTime(2026)).days,29);
    expect(report([],start:DateTime(2025,12,29),end:DateTime(2026,1,5),now:DateTime(2026,2)).days,7);
  });
}

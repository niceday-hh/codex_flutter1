import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/app_store.dart';
import 'package:smart_budget/app_theme.dart';
import 'package:smart_budget/calendar/date_context.dart';
import 'package:smart_budget/calendar/spending_calendar.dart';
import 'package:smart_budget/insights/insight_engine.dart';
import 'package:smart_budget/insights/insight_guide.dart';
import 'package:smart_budget/models.dart';
import 'package:smart_budget/widgets/common.dart';

void main() {
  test('holiday, makeup and solar term coexist; unsupported years are unknown', () {
    expect(dateContext(DateTime(2026,9,20)).makeup,isTrue);
    expect(dateContext(DateTime(2026,9,25)).holiday,'中秋');
    expect(dateContext(DateTime(2026,5,5)).holiday,'劳动');
    expect(dateContext(DateTime(2026,5,5)).term,'立夏');
    expect(dateContext(DateTime(2026,4,5)).labels,containsAll(['清明假期','清明 · 节气']));
    expect(dateContext(DateTime(2027,5,1)).known,isFalse);
    expect(dateContext(DateTime(2027,5,1)).holiday,isNull);
    var terms=0,holidays=0,makeups=0;
    for(var d=DateTime(2026);d.year==2026;d=d.add(const Duration(days:1))) {
      final info=dateContext(d);
      if(info.term!=null)terms++;
      if(info.holiday!=null)holidays++;
      if(info.makeup)makeups++;
    }
    expect(terms,24);expect(holidays,33);expect(makeups,6);
  });
  test('calendar foreground contrast remains readable throughout both gradients', () {
    for(final dark in [false,true]) {
      for(var i=0;i<=100;i++) {
        final a=calendarInk(dark).computeLuminance(), b=calendarTint(dark,i/100).computeLuminance();
        expect(((a>b?a:b)+.05)/((a>b?b:a)+.05),greaterThanOrEqualTo(4.5));
      }
    }
  });
  test('category percentages use category totals and guard zero', () {
    expect(categoryShare(25,100),'（25.0%）');
    expect(categoryShare(20,40),'（50.0%）');
    expect(categoryShare(0,0),'（—）');
  });
  test('overview is based on actual category proportions', () {
    final r=analyzeInsights(entries:[
      LedgerEntry(id:'1',title:'餐饮',category:'餐饮',amount:60,isIncome:false,date:DateTime(2026,9,1)),
      LedgerEntry(id:'2',title:'购物',category:'购物',amount:40,isIncome:false,date:DateTime(2026,9,2)),
    ],start:DateTime(2026,9),end:DateTime(2026,10),now:DateTime(2026,9,18));
    expect(overviewText(r),contains('餐饮为主，占 60.0%'));
    expect(overviewText(r),contains('暂缺可比较'));
    expect(reportEntries(r).length,2);
  });
  for(final dark in [false,true]) {
    testWidgets('calendar selects dates and hides heatmap on phone dark=$dark', (tester) async {
      tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      final store=AppStore();
      await tester.runAsync(()=>Future<void>.delayed(Duration.zero));
      store.importCsv('日期,类型,分类,金额,备注\n2026/9/25 12:00,支出,餐饮,100,团圆饭\n2026/9/25 12:00,收入,工资,300,工资',replace:true);
      await tester.pumpWidget(AppStoreScope(store:store,child:MaterialApp(theme:buildTheme(dark:dark),home:Scaffold(body:SingleChildScrollView(child:SpendingCalendar(anchor:DateTime(2026,9),entries:store.entries,income:false))))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('calendar-day-25')));await tester.pumpAndSettle();
      expect(find.textContaining('已记支出 ¥100.00'),findsOneWidget);
      expect(find.text('团圆饭'),findsOneWidget);
      expect(find.text('工资'),findsNothing);
      expect(tester.takeException(),isNull);
      store.setHideAmounts(true);await tester.pumpAndSettle();
      expect(find.text('热力已隐藏'),findsOneWidget);
      expect(find.textContaining('¥100.00'),findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());store.dispose();
    });
  }
}

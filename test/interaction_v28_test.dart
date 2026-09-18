import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/app_store.dart';
import 'package:smart_budget/app_theme.dart';
import 'package:smart_budget/models.dart';
import 'package:smart_budget/calendar/period_calendar.dart';
import 'package:smart_budget/calendar/spending_calendar.dart';
import 'package:smart_budget/widgets/note_picker.dart';
import 'package:smart_budget/widgets/sorted_entries.dart';

LedgerEntry entry(String id, double amount, DateTime date, {bool income=false, String note='咖啡', String category='餐饮'}) => LedgerEntry(id:id,title:note,category:category,amount:amount,isIncome:income,date:date,note:note);
void main() {
  test('sort covers every item, stable ties and does not mutate store order', () {
    final entries = List<LedgerEntry>.unmodifiable([entry('b',10,DateTime(2026,2)),entry('a',10,DateTime(2026,2)),entry('c',100,DateTime(2026,1))]);
    expect(sortEntries(entries,EntryOrder.highest).map((e)=>e.id),['c','a','b']);
    expect(sortEntries(entries,EntryOrder.lowest).map((e)=>e.id),['a','b','c']);
    expect(sortEntries(entries,EntryOrder.newest).map((e)=>e.id),['a','b','c']);
    expect(sortEntries(entries,EntryOrder.oldest).map((e)=>e.id),['c','a','b']);
    expect(entries.first.id,'b');
  });
  test('all notes are retained, trimmed, deduplicated and income isolated', () {
    final entries = [for(var i=0;i<80;i++) entry('$i',1,DateTime(2026,1,i+1),note:'备注$i'),entry('a',1,DateTime(2026,9),note:' 备注0 ',category:'购物'),entry('b',1,DateTime(2026),income:true,note:'工资')];
    final notes=collectNotes(entries,false);
    expect(notes.length,80);
    final n=notes.singleWhere((n)=>n.text=='备注0');
    expect(n.count,2);expect(n.categories,{'餐饮','购物'});expect(n.latest,DateTime(2026,9));
    expect(collectNotes(entries,true).single.text,'工资');
  });
  test('cross-year week and global range exclude outside dates and income', () {
    final totals=calendarTotals([entry('a',10,DateTime(2025,12,29)),entry('b',20,DateTime(2026,1,1)),entry('c',99,DateTime(2026,1,5)),entry('d',88,DateTime(2026,1,1),income:true)],DateTime(2025,12,29),DateTime(2026,1,5),false);
    expect(totals.values.toList(),[10,20]);
  });
  testWidgets('all notes search reaches notes beyond former limit and confirms selection', (tester) async {
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    String? result;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(builder:(context)=>TextButton(onPressed:() async { result=await showNotePicker(context,entries:[for(var i=0;i<80;i++) entry('$i',1,DateTime(2026),note:'备注$i',category:'购物')],income:false,category:'餐饮',initial:'原备注'); },child:const Text('打开'))))));
    await tester.tap(find.text('打开'));await tester.pumpAndSettle();
    await tester.tap(find.text('全部'));await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.enterText(find.byType(TextField).first,'备注79');await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile,'备注79'));await tester.pumpAndSettle();
    await tester.tap(find.text('使用此备注'));await tester.pumpAndSettle();
    expect(result,'备注79');expect(tester.takeException(),isNull);
  });
  for(final period in [0,2,3]) {
    testWidgets('calendar period $period renders and opens selected month', (tester) async {
      tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      final store=AppStore();await tester.runAsync(()=>Future<void>.delayed(Duration.zero));
      await tester.pumpWidget(AppStoreScope(store:store,child:MaterialApp(theme:buildTheme(),home:Scaffold(body:SingleChildScrollView(child:PeriodCalendar(start:DateTime(2026),end:period==0?DateTime(2026,1,8):period==2?DateTime(2026,4):DateTime(2027),periodIndex:period,entries:[entry('a',100,DateTime(2026,1,2))],income:false))))));
      await tester.pumpAndSettle();expect(tester.takeException(),isNull);
      if(period!=0) {
        expect(find.text('1月 ›'),findsOneWidget);
        expect(find.text('${period==2?3:12}月 ›'),findsOneWidget);
        await tester.tap(find.text('1月 ›'));await tester.pumpAndSettle();
        expect(find.byType(SpendingCalendar),findsOneWidget);expect(tester.takeException(),isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());store.dispose();
    });
  }
}

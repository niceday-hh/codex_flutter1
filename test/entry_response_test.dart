import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/app_store.dart';
import 'package:smart_budget/app_theme.dart';
import 'package:smart_budget/entry_amount.dart';
import 'package:smart_budget/models.dart';
import 'package:smart_budget/notes/note_catalog.dart';
import 'package:smart_budget/pages/add_page.dart';
import 'package:smart_budget/widgets/animated_amount.dart';
import 'package:smart_budget/widgets/note_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('amount publishes synchronously and preserves arithmetic, decimals and digit limit', () {
    final amount=EntryAmountController();var notifications=0;
    amount.addListener(()=>notifications++);
    for(final key in ['1','2','.','3','+','4']) amount.press(key);
    expect(amount.value.expression,'12.3+4');expect(amount.value.amount,16.3);expect(notifications,6);
    amount.press('⌫');amount.press('-');amount.press('2');
    expect(amount.value.expression,'12.3-2');expect(amount.value.amount,10.3);
    final before=amount.value;amount.press('无效');expect(identical(before,amount.value),isTrue);
    amount.dispose();
    final limit=EntryAmountController();for(var i=0;i<10;i++)limit.press('9');
    expect(limit.value.expression,'999999999');limit.dispose();
    final decimal=EntryAmountController();for(final key in ['.','.','5','+','.','5']) decimal.press(key);
    expect(decimal.value.expression,'0.5+0.5');expect(decimal.value.amount,1);decimal.dispose();
  });

  test('async note history and sorted modes are complete, cached and refreshed after changes', () async {
    final store=AppStore();await store.ready;
    final csv=StringBuffer('日期,类型,分类,金额,备注\n');
    for(var i=0;i<600;i++)csv.writeln('2026/10/1 12:00,支出,餐饮,1,备注$i');
    store.importCsv(csv.toString(),replace:true);
    final catalog=await store.loadNoteCatalog();expect(catalog.expense.length,600);
    final prepared=await catalog.prepare(false,'餐饮');
    expect(identical(prepared,await catalog.prepare(false,'餐饮')),isTrue);
    for(var order=0;order<3;order++)expect(prepared.view(order,true).length,600);
    store.setHideAmounts(true);expect(identical(catalog,await store.loadNoteCatalog()),isTrue);
    store.addEntry(title:'最新',category:'餐饮',amount:2,isIncome:false,date:DateTime(2026,10,12),note:'最新');
    final changed=await store.loadNoteCatalog();expect(identical(catalog,changed),isFalse);
    expect((await changed.prepare(false,'餐饮')).view(1,true).first.text,'最新');
    await store.flushPersistence();store.dispose();
  });

  testWidgets('numeric contact updates next frame, leaves page controls unchanged, and saves latest value', (tester) async {
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    late AppStore store;await tester.runAsync(() async {store=AppStore();await store.ready;});
    var saves=0;
    await tester.pumpWidget(AppStoreScope(store:store,child:MaterialApp(theme:buildTheme(),home:AddPage(onSaved:()=>saves++))));
    await tester.pumpAndSettle();
    final grid=tester.widget<GridView>(find.byType(GridView));
    final noteTarget=tester.widget<GestureDetector>(find.byKey(const ValueKey('entry-note-target')));
    final gesture=await tester.startGesture(tester.getCenter(find.text('1')));
    await tester.pump(); // Finger remains down: no tap-up or animation wait.
    expect(find.text('¥ 1'),findsOneWidget);
    expect(identical(grid,tester.widget<GridView>(find.byType(GridView))),isTrue);
    expect(identical(noteTarget,tester.widget<GestureDetector>(find.byKey(const ValueKey('entry-note-target')))),isTrue);
    await gesture.up();await tester.pump();expect(find.text('¥ 1'),findsOneWidget);
    for(final key in ['2','3','+','4']){await tester.tap(find.text(key));await tester.pump();}
    expect(find.text('¥ 127'),findsOneWidget);expect(find.text('¥ 12'),findsNothing);
    // Delete is an icon in the unchanged keypad.
    await tester.tap(find.byIcon(Icons.backspace_outlined));await tester.pump();
    expect(find.text('¥ 123'),findsOneWidget);
    await tester.tap(find.text('5'));await tester.pump();expect(find.text('¥ 128'),findsOneWidget);
    final confirm=await tester.startGesture(tester.getCenter(find.text('完成')));
    await tester.pump();expect(saves,0);await confirm.up();await tester.pumpAndSettle();
    expect(saves,1);expect(store.entries.first.amount,128);expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());store.dispose();
  });

  testWidgets('note target covers full row including blank edge padding', (tester) async {
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    late AppStore store;await tester.runAsync(() async {store=AppStore();await store.ready;});
    await tester.pumpWidget(AppStoreScope(store:store,child:MaterialApp(theme:buildTheme(),home:AddPage(onSaved:(){}))));
    await tester.pumpAndSettle();final target=find.byKey(const ValueKey('entry-note-target'));
    final rect=tester.getRect(target);expect(rect.height,greaterThanOrEqualTo(48));
    await tester.tapAt(Offset(rect.left+rect.width/2,rect.top+2));await tester.pump();
    expect(find.text('选个备注'),findsOneWidget);
    // Let the real-zone restore callbacks reach the widget test's fake clock.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip),findsWidgets);expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());store.dispose();
  });

  testWidgets('note sheet opens before history resolves and retains draft, tabs and all notes', (tester) async {
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final history=Completer<NoteCatalog>();String? result;
    await tester.pumpWidget(MaterialApp(theme:buildTheme(),home:Scaffold(body:Builder(builder:(context)=>TextButton(onPressed:() async {
      result=await showNotePicker(context,income:false,category:'餐饮',initial:'',loadCatalog:()=>history.future);
    },child:const Text('打开'))))));
    await tester.tap(find.text('打开'));await tester.pump();
    expect(find.text('选个备注'),findsOneWidget);expect(find.byType(CircularProgressIndicator),findsOneWidget);
    await tester.pump(const Duration(milliseconds:180));
    await tester.enterText(find.byType(TextField).last,'自己填写');await tester.pump();
    final catalog=NoteCatalog([for(var i=0;i<80;i++)LedgerEntry(id:'$i',title:'备注$i',category:'购物',amount:1,isIncome:false,date:DateTime(2026),note:'备注$i')]);
    history.complete(catalog);await tester.pumpAndSettle();
    expect(find.text('自己填写'),findsOneWidget);await tester.tap(find.text('全部'));await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first,'备注79');await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile,'备注79'));await tester.pumpAndSettle();
    await tester.tap(find.text('使用此备注'));await tester.pumpAndSettle();expect(result,'备注79');
    expect(tester.takeException(),isNull);
  });

  testWidgets('late history completion after dismiss does not reopen or update disposed sheet', (tester) async {
    final history=Completer<NoteCatalog>();late BuildContext page;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(builder:(context){page=context;return TextButton(onPressed:()=>showNotePicker(context,income:false,category:'餐饮',initial:'',loadCatalog:()=>history.future),child:const Text('打开'));}))));
    await tester.tap(find.text('打开'));await tester.pump();
    Navigator.of(page).pop();await tester.pump(const Duration(milliseconds:200));
    history.complete(NoteCatalog([]));await tester.pumpAndSettle();
    expect(find.text('选个备注'),findsNothing);expect(tester.takeException(),isNull);
  });

  testWidgets('amount pulse never shows stale numbers and obeys reduced motion', (tester) async {
    var reduced=false,text='¥ 1';
    Widget app()=>MaterialApp(home:MediaQuery(data:MediaQueryData(disableAnimations:reduced),child:Scaffold(body:AnimatedAmount(text:text,style:const TextStyle(fontSize:30)))));
    await tester.pumpWidget(app());text='¥ 12';await tester.pumpWidget(app());
    expect(find.text('¥ 12'),findsOneWidget);expect(find.text('¥ 1'),findsNothing);
    expect(tester.widget<Transform>(find.descendant(of:find.byType(AnimatedAmount),matching:find.byType(Transform))).transform.storage[0],greaterThan(1));
    text='¥ 123';await tester.pumpWidget(app());expect(find.text('¥ 123'),findsOneWidget);
    await tester.pump(const Duration(milliseconds:110));
    expect(tester.widget<Transform>(find.descendant(of:find.byType(AnimatedAmount),matching:find.byType(Transform))).transform.storage[0],1);
    reduced=true;text='¥ 1234';await tester.pumpWidget(app());
    expect(tester.widget<Transform>(find.descendant(of:find.byType(AnimatedAmount),matching:find.byType(Transform))).transform.storage[0],1);expect(tester.takeException(),isNull);
  });
}

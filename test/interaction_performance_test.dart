import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/app_store.dart';
import 'package:smart_budget/app_theme.dart';
import 'package:smart_budget/models.dart';
import 'package:smart_budget/pages/add_page.dart';
import 'package:smart_budget/widgets/active_store_scope.dart';
import 'package:smart_budget/widgets/note_picker.dart';

class ReadCountingNotes extends ListBase<NoteChoice> {
  ReadCountingNotes(this.items);
  final List<NoteChoice> items;
  int reads = 0;
  @override
  int get length => items.length;
  @override
  set length(int _) => throw UnsupportedError('read only');
  @override
  NoteChoice operator [](int i) { reads++; return items[i]; }
  @override
  void operator []=(int i, NoteChoice value) => throw UnsupportedError('read only');
}

class StoreProbe extends StatelessWidget {
  const StoreProbe({super.key, required this.onBuild});
  final void Function(int) onBuild;
  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    onBuild(store.entries.length);
    return Text('${store.entries.length}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('smart_budget/storage');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('preference changes reuse ledger and complete note snapshots; mutations invalidate them', () async {
    final store=AppStore(); await store.ready;
    final entries=store.entries, catalog=store.noteCatalog, notes=store.notesForCategory('餐饮',income:false);
    store.setHideAmounts(true);store.setDarkMode(true);store.setBudget(5000);
    expect(identical(entries,store.entries),isTrue);
    expect(identical(catalog,store.noteCatalog),isTrue);
    expect(identical(notes,store.notesForCategory('餐饮',income:false)),isTrue);
    store.addEntry(title:'新备注',category:'餐饮',amount:1,isIncome:false,date:DateTime.now(),note:'新备注');
    expect(identical(catalog,store.noteCatalog),isFalse);
    expect(store.noteCatalog.expense.any((n)=>n.text=='新备注'),isTrue);
    final id=store.entries.firstWhere((e)=>e.note=='新备注').id;
    store.updateEntry(id,note:'改名');
    expect(store.noteCatalog.expense.any((n)=>n.text=='新备注'),isFalse);
    expect(store.noteCatalog.expense.any((n)=>n.text=='改名'),isTrue);
    store.deleteEntry(id);
    expect(store.noteCatalog.expense.any((n)=>n.text=='改名'),isFalse);
    await store.flushPersistence();store.dispose();
  });

  test('large cold restore retains startup edits and coalesces saves without dropping disk records', () async {
    final load=Completer<String?>();
    final saved=<Map<String,dynamic>>[];
    messenger.setMockMethodCallHandler(channel,(call) async {
      if(call.method=='load') return load.future;
      if(call.method=='save') saved.add(jsonDecode(call.arguments as String) as Map<String,dynamic>);
      return null;
    });
    final disk=[for(var i=0;i<1500;i++) LedgerEntry(id:'disk$i',title:'历史$i',category:'餐饮',amount:1,isIncome:false,date:DateTime(2026,9,1),note:'历史$i').toJson()];
    final store=AppStore();
    for(var i=0;i<10;i++) store.addEntry(title:'刚记$i',category:'餐饮',amount:2,isIncome:false,date:DateTime(2026,10,8),note:'刚记$i');
    store.setHideAmounts(true);
    load.complete(jsonEncode({'entries':disk,'hideAmounts':false}));
    await store.ready;await store.flushPersistence();
    expect(store.entries.length,1510);expect(store.hideAmounts,isTrue);
    expect(saved.length,1);expect((saved.single['entries'] as List).length,1510);
    expect(store.noteCatalog.expense.length,1510);
    store.dispose();
  });

  test('preference-only restore does not replay startup additions twice', () async {
    final load=Completer<String?>();
    messenger.setMockMethodCallHandler(channel,(call) async {
      if(call.method=='load') return load.future;
      return null;
    });
    final store=AppStore();final initial=store.entries.length;
    store.addEntry(title:'刚记',category:'餐饮',amount:2,isIncome:false,date:DateTime.now());
    load.complete(jsonEncode({'monthlyBudget':6000}));
    await store.ready;await store.flushPersistence();
    expect(store.entries.length,initial+1);expect(store.monthlyBudget,6000);
    store.dispose();
  });

  test('saves stay ordered when edits arrive during an unfinished write', () async {
    final writing=Completer<void>(), release=Completer<void>();
    final saves=<Map<String,dynamic>>[];
    var active=0,maxActive=0;
    messenger.setMockMethodCallHandler(channel,(call) async {
      if(call.method=='load')return jsonEncode({'entries':[]});
      if(call.method=='save') {
        active++;if(active>maxActive)maxActive=active;
        saves.add(jsonDecode(call.arguments as String) as Map<String,dynamic>);
        if(saves.length==1){writing.complete();await release.future;}
        active--;
      }
      return null;
    });
    final store=AppStore();await store.ready;
    store.addEntry(title:'咖啡',category:'餐饮',amount:10,isIncome:false,date:DateTime.now(),note:'咖啡');
    await writing.future;
    store.updateEntry(store.entries.single.id,amount:25,note:'早餐');
    store.setDarkMode(true);release.complete();await store.flushPersistence();
    expect(maxActive,1);expect(saves.length,2);
    final row=(saves.last['entries'] as List).single as Map;
    expect(row['amount'],25);expect(row['note'],'早餐');expect(saves.last['darkMode'],true);
    store.dispose();
  });

  testWidgets('draft typing and selecting do not rescan all historical notes', (tester) async {
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final entries=[for(var i=0;i<2500;i++) LedgerEntry(id:'$i',title:'备注$i',category:'餐饮',amount:1,isIncome:false,date:DateTime(2026),note:'备注$i')];
    final notes=ReadCountingNotes(collectNotes(entries,false));
    await tester.pumpWidget(MaterialApp(theme:buildTheme(),home:Scaffold(body:NotePicker(notes:notes,category:'餐饮',initial:''))));
    await tester.pumpAndSettle();final before=notes.reads;
    await tester.enterText(find.byType(TextField).last,'新备注');await tester.pumpAndSettle();
    expect(notes.reads,before);expect(find.text('使用此备注'),findsOneWidget);
    await tester.tap(find.byType(ChoiceChip).first);await tester.pumpAndSettle();expect(notes.reads,before);
    await tester.tap(find.text('全部'));await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first,'备注2499');await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile,'备注2499'),findsOneWidget);expect(tester.takeException(),isNull);
  });

  testWidgets('numeric input reuses category grid and retains expense, income, note and keypad controls', (tester) async {
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final store=AppStore();await tester.runAsync(()=>store.ready);
    await tester.pumpWidget(AppStoreScope(store:store,child:MaterialApp(theme:buildTheme(),home:AddPage(onSaved:(){}))));
    await tester.pumpAndSettle();final grid=tester.widget<GridView>(find.byType(GridView));
    await tester.tap(find.text('1'));await tester.pumpAndSettle();
    expect(identical(grid,tester.widget<GridView>(find.byType(GridView))),isTrue);
    expect(find.text('¥ 1'),findsOneWidget);expect(find.text('备注：点击填写备注'),findsOneWidget);
    await tester.tap(find.text('收入'));await tester.pumpAndSettle();expect(find.text('工资'),findsOneWidget);
    await tester.tap(find.text('完成'));await tester.pumpAndSettle();
    expect(store.entries.first.isIncome,isTrue);expect(store.entries.first.amount,1);
    expect(tester.takeException(),isNull);
    await tester.runAsync(()=>store.flushPersistence());await tester.pumpWidget(const SizedBox.shrink());store.dispose();
  });

  testWidgets('retained hidden page refreshes once on return and keeps its state', (tester) async {
    final store=AppStore();await tester.runAsync(()=>store.ready);
    final active=ValueNotifier<bool>(true);var builds=0,lastCount=0;
    final probe=StoreProbe(onBuild:(count){builds++;lastCount=count;});
    await tester.pumpWidget(MaterialApp(home:ValueListenableBuilder<bool>(valueListenable:active,builder:(_,value,__)=>ActiveStoreScope(store:store,active:value,child:probe))));
    await tester.pumpAndSettle();active.value=false;await tester.pumpAndSettle();final baseline=builds;
    store.addEntry(title:'新增',category:'餐饮',amount:1,isIncome:false,date:DateTime.now());await tester.pumpAndSettle();
    expect(builds,baseline);
    active.value=true;await tester.pumpAndSettle();expect(builds,baseline+1);expect(lastCount,store.entries.length);
    await tester.runAsync(()=>store.flushPersistence());await tester.pumpWidget(const SizedBox.shrink());active.dispose();store.dispose();
  });
}

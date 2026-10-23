import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/app_store.dart';
import 'package:smart_budget/app_theme.dart';
import 'package:smart_budget/shell.dart';
import 'package:smart_budget/voice/voice_sheet.dart';
import 'package:smart_budget/voice/voice_engine_cache.dart';
import 'voice_session_test.dart' show FakeVoiceEngine;
import 'voice_parallel_test.dart' show ColdEngine;

void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    // AppStore.ready and the platform restore callbacks were created in the
    // real async zone; let them finish before advancing the widget fake clock.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }
  Future<AppStore> build(WidgetTester tester, FakeVoiceEngine engine) async {
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    late AppStore store;await tester.runAsync(() async {store=AppStore();await store.ready;});
    await tester.pumpWidget(MaterialApp(theme:buildTheme(),home:Scaffold(body:Builder(builder:(c)=>TextButton(
      onPressed:()=>showVoiceEntry(c,store,engine:engine),child:const Text('打开语音'))))));
    await tester.tap(find.text('打开语音'));await tester.pumpAndSettle();return store;
  }
  Future<void> record(WidgetTester tester) async {
    final pointer=await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('voice-record'))));
    await tester.pump();expect(find.textContaining('正在聆听'),findsOneWidget);
    await pointer.up();await settle(tester);
  }
  testWidgets('cold sheet records immediately and waits only after release', (tester) async {
    final engine=ColdEngine();final store=await build(tester,engine);final before=store.entries.length;
    expect(find.text('模型准备中，可以先说话'),findsOneWidget);
    final pointer=await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('voice-record'))));
    await tester.pump();
    expect(find.textContaining('正在聆听'),findsOneWidget);expect(engine.starts,1);
    expect(engine.ready.isCompleted,isFalse);
    await pointer.up();await tester.pump();
    expect(find.text('已录好，正在准备识别…'),findsOneWidget);expect(engine.captured,isTrue);
    expect(store.entries.length,before);
    engine.ready.complete();await settle(tester);
    expect(find.text('确认这笔账'),findsOneWidget);expect(find.text('¥ 28.50'),findsOneWidget);
    expect(store.entries.length,before);
    await tester.tap(find.byTooltip('关闭语音输入'));await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());store.dispose();
  });
  testWidgets('release reviews the parsed draft; confirm saves exactly once', (tester) async {
    final engine=FakeVoiceEngine();final store=await build(tester,engine);final before=store.entries.length;
    await record(tester);
    expect(find.text('确认这笔账'),findsOneWidget);expect(find.text('¥ 28.50'),findsOneWidget);
    expect(find.text('牛肉面'),findsOneWidget);expect(store.entries.length,before);
    await tester.tap(find.byKey(const ValueKey('voice-confirm')));await tester.pumpAndSettle();
    expect(store.entries.length,before+1);expect(store.entries.first.amount,28.5);
    expect(store.entries.first.category,'餐饮');expect(store.entries.first.note,'牛肉面');
    await tester.pump();expect(engine.closed,isTrue);expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());store.dispose();
  });
  testWidgets('rerecord discards old fields; drag dismiss never saves', (tester) async {
    final engine=FakeVoiceEngine();final store=await build(tester,engine);final before=store.entries.length;
    await record(tester);await tester.tap(find.byKey(const ValueKey('voice-rerecord')));await tester.pumpAndSettle();
    expect(find.text('¥ 28.50'),findsNothing);
    engine.text='收到工资8000元';await record(tester);expect(find.text('¥ 8000.00'),findsOneWidget);
    await tester.drag(find.text('下拉关闭'),const Offset(0,500));await tester.pumpAndSettle();
    expect(find.text('确认这笔账'),findsNothing);expect(store.entries.length,before);await tester.pump();expect(engine.closed,isTrue);
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());store.dispose();
  });
  testWidgets('missing amount requires input and cannot save incomplete draft', (tester) async {
    final engine=FakeVoiceEngine(text:'买两杯奶茶');final store=await build(tester,engine);final before=store.entries.length;
    await record(tester);expect(find.text('补充金额'),findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('voice-confirm')));await tester.pumpAndSettle();
    expect(find.text('修改金额'),findsOneWidget);expect(store.entries.length,before);
    await tester.tap(find.text('取消'));await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('关闭语音输入'));await tester.pumpAndSettle();
    expect(store.entries.length,before);expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());store.dispose();
  });
  testWidgets('sliding back cancels the picker and tapping plus keeps manual entry', (tester) async {
    late AppStore store;await tester.runAsync(() async {store=AppStore();await store.ready;});
    final voiceCache = VoiceEngineCache(factory: () => FakeVoiceEngine());
    voiceCache.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpWidget(AppStoreScope(store:store,child:MaterialApp(theme:buildTheme(),home:AppShell(voiceCache:voiceCache))));
    await tester.pumpAndSettle();
    final origin = tester.getCenter(find.byKey(const ValueKey('entry-launcher')));
    final pointer = await tester.startGesture(origin);
    await pointer.moveTo(origin + const Offset(0, -40));await tester.pumpAndSettle();
    expect(find.text('语音记账'),findsOneWidget);expect(find.text('手动记账'),findsOneWidget);
    await pointer.moveTo(origin);await pointer.up();await tester.pumpAndSettle();
    expect(find.text('语音记账'),findsNothing);
    await tester.tap(find.byKey(const ValueKey('entry-launcher')));await tester.pumpAndSettle();
    expect(find.text('记一笔'),findsOneWidget);expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());store.dispose();
  });
  testWidgets('release over voice opens the existing sheet without recording or saving', (tester) async {
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    late AppStore store;await tester.runAsync(() async {store=AppStore();await store.ready;});
    final engine=FakeVoiceEngine();
    final voiceCache=VoiceEngineCache(factory:()=>engine);
    voiceCache.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpWidget(AppStoreScope(store:store,child:MaterialApp(theme:buildTheme(),home:AppShell(voiceCache:voiceCache))));
    await tester.pumpAndSettle();final before=store.entries.length;
    final origin=tester.getCenter(find.byKey(const ValueKey('entry-launcher')));
    final pointer=await tester.startGesture(origin);
    await pointer.moveTo(origin+const Offset(0,-40));await tester.pumpAndSettle();
    await pointer.moveTo(tester.getCenter(find.byKey(const ValueKey('entry-voice-target'))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('voice-record')),findsNothing);expect(engine.starts,0);
    await pointer.up();await settle(tester);
    expect(find.byKey(const ValueKey('voice-record')),findsOneWidget);
    expect(engine.starts,0);expect(store.entries.length,before);
    await record(tester);expect(engine.starts,1);expect(store.entries.length,before);
    await tester.tap(find.byKey(const ValueKey('voice-confirm')));await settle(tester);
    expect(store.entries.length,before+1);expect(store.entries.first.amount,28.5);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());store.dispose();
  });
  testWidgets('correct original text uses personal notes and opens the complete note picker without saving', (tester) async {
    final engine=FakeVoiceEngine(text:'盒码58元');final store=await build(tester,engine);
    store.addEntry(title:'盒马',category:'餐饮',amount:20,isIncome:false,date:DateTime(2026,1,1),note:'盒马');
    final before=store.entries.length;await record(tester);
    await tester.tap(find.byKey(const ValueKey('voice-edit-original')));await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField),'盒马58元');await tester.tap(find.text('确定'));
    await settle(tester);await tester.pump(const Duration(milliseconds:300));
    expect(find.text('根据历史备注「盒马」推荐'),findsOneWidget);expect(store.entries.length,before);
    await tester.ensureVisible(find.text('备注'));await tester.tap(find.text('备注'));await settle(tester);
    expect(find.text('选个备注'),findsOneWidget);expect(find.text('全部'),findsOneWidget);
    await tester.tap(find.text('使用此备注'));await settle(tester);expect(store.entries.length,before);
    await tester.tap(find.byTooltip('关闭语音输入'));await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());store.dispose();
  });
  testWidgets('correcting amount clears stale warning and survives reparsing', (tester) async {
    final engine=FakeVoiceEngine(text:'午饭');final store=await build(tester,engine);await record(tester);
    expect(find.text('未识别到金额，请补充'),findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('voice-confirm')));await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField),'28');await tester.tap(find.text('确定'));
    await settle(tester);await tester.pump(const Duration(milliseconds:300));
    expect(find.text('未识别到金额，请补充'),findsNothing);
    await tester.tap(find.byKey(const ValueKey('voice-edit-original')));await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField),'午饭99元');await tester.tap(find.text('确定'));
    await settle(tester);await tester.pump(const Duration(milliseconds:300));
    expect(find.text('¥ 28.00'),findsOneWidget);expect(find.text('¥ 99.00'),findsNothing);
    await tester.tap(find.byTooltip('关闭语音输入'));await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());store.dispose();
  });
}



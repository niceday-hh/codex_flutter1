import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/app_store.dart';
import 'package:smart_budget/app_theme.dart';
import 'package:smart_budget/shell.dart';
import 'package:smart_budget/voice/voice_sheet.dart';
import 'voice_session_test.dart' show FakeVoiceEngine;

void main() {
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
    await pointer.up();await tester.pumpAndSettle();
  }
  testWidgets('release reviews the parsed draft; confirm saves exactly once', (tester) async {
    final engine=FakeVoiceEngine();final store=await build(tester,engine);final before=store.entries.length;
    await record(tester);
    expect(find.text('确认这笔账'),findsOneWidget);expect(find.text('¥ 28.50'),findsOneWidget);
    expect(find.text('牛肉面'),findsOneWidget);expect(store.entries.length,before);
    await tester.tap(find.byKey(const ValueKey('voice-confirm')));await tester.pumpAndSettle();
    expect(store.entries.length,before+1);expect(store.entries.first.amount,28.5);
    expect(store.entries.first.category,'餐饮');expect(store.entries.first.note,'牛肉面');
    expect(engine.closed,isTrue);expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());store.dispose();
  });
  testWidgets('rerecord discards old fields; drag dismiss never saves', (tester) async {
    final engine=FakeVoiceEngine();final store=await build(tester,engine);final before=store.entries.length;
    await record(tester);await tester.tap(find.byKey(const ValueKey('voice-rerecord')));await tester.pumpAndSettle();
    expect(find.text('¥ 28.50'),findsNothing);
    engine.text='收到工资8000元';await record(tester);expect(find.text('¥ 8000.00'),findsOneWidget);
    await tester.drag(find.text('下拉关闭'),const Offset(0,500));await tester.pumpAndSettle();
    expect(find.text('确认这笔账'),findsNothing);expect(store.entries.length,before);expect(engine.closed,isTrue);
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
  testWidgets('long pressing plus opens voice menu and tapping plus keeps manual entry', (tester) async {
    late AppStore store;await tester.runAsync(() async {store=AppStore();await store.ready;});
    await tester.pumpWidget(AppStoreScope(store:store,child:MaterialApp(theme:buildTheme(),home:const AppShell())));
    await tester.pumpAndSettle();
    await tester.longPress(find.byIcon(Icons.add_rounded));await tester.pumpAndSettle();
    expect(find.text('语音记账'),findsOneWidget);expect(find.text('记一笔'),findsNothing);
    await tester.tapAt(const Offset(10,10));await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded));await tester.pumpAndSettle();
    expect(find.text('记一笔'),findsOneWidget);expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());store.dispose();
  });
}

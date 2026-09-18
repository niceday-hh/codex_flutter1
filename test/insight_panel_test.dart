import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/app_store.dart';
import 'package:smart_budget/app_theme.dart';
import 'package:smart_budget/insights/insight_panel.dart';

void main() {
  testWidgets('insight explorer fits a phone, filters, drills down and hides amounts', (tester) async {
    tester.view.physicalSize = const Size(390,844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store=AppStore();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    store.importCsv('日期,类型,分类,金额,备注\n2026/9/1 12:00,支出,餐饮,123.45,午饭',replace:true);
    await tester.pumpWidget(AppStoreScope(store:store,child:MaterialApp(theme:buildTheme(),
      home:Scaffold(body:SingleChildScrollView(child:InsightPanel(start:DateTime(2026,9),end:DateTime(2026,10),income:false))))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深入分析与方法'));
    await tester.pumpAndSettle();
    expect(find.text('消费洞察实验室'),findsOneWidget);
    await tester.ensureVisible(find.text('结构'));
    await tester.tap(find.text('结构'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('消费集中度'));
    await tester.tap(find.text('消费集中度'));
    await tester.pumpAndSettle();
    expect(find.text('如何计算'),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.pageBack(); await tester.pumpAndSettle();
    store.setHideAmounts(true); await tester.pumpAndSettle();
    expect(find.text('••••'),findsWidgets);
    expect(find.textContaining('¥123.45'),findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}

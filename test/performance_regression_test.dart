import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/app_store.dart';
import 'package:smart_budget/app_theme.dart';
import 'package:smart_budget/pages/home_page.dart';
import 'package:smart_budget/widgets/common.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cached month snapshots reflect edits, moves, deletes and CSV replacement', () async {
    final store = AppStore();
    await Future<void>.delayed(Duration.zero);
    store.clearEntries();
    final month = DateTime(2026, 9);
    expect(store.entriesForMonth(month), isEmpty);
    store.addEntry(title: '餐饮', category: '餐饮', amount: 12,
        isIncome: false, date: DateTime(2026, 9, 10));
    final id = store.entries.single.id;
    expect(store.expenseForMonth(month), 12);
    store.updateEntry(id, amount: 25);
    expect(store.expenseForMonth(month), 25);
    store.updateEntry(id, date: DateTime(2026, 10, 1));
    expect(store.entriesForMonth(month), isEmpty);
    expect(store.entriesForMonth(DateTime(2026, 10)).single.id, id);
    store.deleteEntry(id);
    expect(store.entries, isEmpty);
    store.importCsv('日期,类型,分类,金额,备注\n2026/9/1 12:00,支出,餐饮,8,午饭', replace: true);
    expect(store.expenseForMonth(month), 8);
    store.clearEntries();
    expect(store.entriesForMonth(month), isEmpty);
    store.dispose();
  });

  testWidgets('a busy day builds visible ledger rows lazily', (tester) async {
    final store = AppStore();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    final now = DateTime.now();
    final csv = StringBuffer('日期,类型,分类,金额,备注\n');
    for (var i = 0; i < 1000; i++) {
      csv.writeln('${now.year}/${now.month}/1 12:00,支出,餐饮,1,记录$i');
    }
    store.importCsv(csv.toString(), replace: true);
    await tester.pumpWidget(AppStoreScope(store: store,
      child: MaterialApp(theme: buildTheme(), home: const Scaffold(body: HomePage()))));
    await tester.pumpAndSettle();
    expect(find.byType(EntryRow).evaluate().length, lessThan(40));
    expect(find.byType(EntryRow), findsWidgets);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.byType(EntryRow).evaluate().length, lessThan(40));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}

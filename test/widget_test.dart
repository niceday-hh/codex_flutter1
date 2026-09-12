import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/main.dart';

void main() {
  testWidgets('shows Shiguang ledger shell and primary navigation', (tester) async {
    await tester.pumpWidget(const SmartBudgetApp());
    await tester.pumpAndSettle();

    expect(find.text('拾光账本'), findsOneWidget);
    for (final label in const ['明细', '报表', '预算', '我的']) {
      expect(find.text(label), findsAtLeastNWidgets(1));
    }
  });

  testWidgets('primary tabs switch through a single IndexedStack', (tester) async {
    await tester.pumpWidget(const SmartBudgetApp());
    await tester.pumpAndSettle();

    final stackFinder = find.byType(IndexedStack);
    expect(stackFinder, findsOneWidget);
    expect(tester.widget<IndexedStack>(stackFinder).index, 0);

    for (final entry in const <String, int>{
      '报表': 1,
      '预算': 2,
      '我的': 3,
      '明细': 0,
    }.entries) {
      await tester.tap(find.text(entry.key).last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<IndexedStack>(stackFinder).index,
        entry.value,
        reason: 'switching to ${entry.key} should paint only tab ${entry.value}',
      );
    }
  });
}

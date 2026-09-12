import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/main.dart';

void main() {
  testWidgets('shows Shiguang ledger shell and primary navigation', (tester) async {
    await tester.pumpWidget(const SmartBudgetApp());
    await tester.pumpAndSettle();

    expect(find.text('拾光账本'), findsOneWidget);

    // v2.3 keeps all primary pages mounted so tab switching is immediate and
    // scroll state is preserved. Page headings can therefore coexist with the
    // matching bottom-navigation labels in the widget tree.
    for (final label in const ['明细', '报表', '预算', '我的']) {
      expect(find.text(label), findsAtLeastNWidgets(1));
    }
  });
}

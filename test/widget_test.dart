import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/main.dart';

void main() {
  testWidgets('shows Shiguang ledger shell and primary navigation', (tester) async {
    await tester.pumpWidget(const SmartBudgetApp());
    await tester.pumpAndSettle();

    expect(find.text('拾光账本'), findsOneWidget);
    expect(find.text('明细'), findsOneWidget);
    // v2.3 keeps tab pages mounted for fast switching, so the report page title
    // and bottom navigation label may both exist in the widget tree.
    expect(find.text('报表'), findsAtLeastNWidgets(1));
    expect(find.text('预算'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}

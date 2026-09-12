import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/main.dart';

void main() {
  testWidgets('shows Shiguang ledger home', (tester) async {
    await tester.pumpWidget(const SmartBudgetApp());
    await tester.pumpAndSettle();
    expect(find.text('拾光账本'), findsOneWidget);
    expect(find.text('明细'), findsOneWidget);
    expect(find.text('报表'), findsOneWidget);
    expect(find.text('预算'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}

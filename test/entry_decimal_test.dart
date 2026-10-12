import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/app_store.dart';
import 'package:smart_budget/app_theme.dart';
import 'package:smart_budget/entry_amount.dart';
import 'package:smart_budget/pages/add_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each operand accepts at most two decimals without hidden digits', () {
    final controller = EntryAmountController();
    addTearDown(controller.dispose);
    for (final key in '12.345678'.split('')) { controller.press(key); }
    expect(controller.value.expression, '12.34');
    expect(controller.value.amount, 12.34);
    expect(controller.value.displayAmount, '12.34');
    final before = controller.value;
    controller.press('9');
    expect(identical(before, controller.value), isTrue);
    for (final key in '+0.2099'.split('')) { controller.press(key); }
    expect(controller.value.expression, '12.34+0.20');
    expect(controller.value.amount, 12.54);
    expect(evaluateAmount('0.1+0.2'), 0.3);
    expect(evaluateAmount('0.3-0.2'), 0.1);
    expect(evaluateAmount('0.01-0.03'), 0.02);
  });

  test('backspace crosses the decimal point with no invisible extra step', () {
    for (final source in ['12.34', '12.30', '12.00']) {
      final controller = EntryAmountController();
      for (final key in source.split('')) { controller.press(key); }
      expect(controller.value.displayAmount, source);
      for (final expected in [source.substring(0, 4), '12', '1', '']) {
        controller.press('⌫');
        expect(controller.value.expression, expected);
        expect(controller.value.displayAmount, expected.isEmpty ? '0' : expected);
      }
      controller.press('⌫');
      expect(controller.value.amount, 0);
      controller.dispose();
    }
  });

  test('decimal deletion retains operators and supports re-entering a fraction', () {
    final controller = EntryAmountController();
    addTearDown(controller.dispose);
    for (final key in '12+0.01'.split('')) { controller.press(key); }
    for (final expected in ['12+0.0', '12+0', '12+', '12', '1', '']) {
      controller.press('⌫');
      expect(controller.value.expression, expected);
    }
    for (final key in '12.'.split('')) { controller.press(key); }
    controller.press('⌫');
    expect(controller.value.expression, '1');
    for (final key in '.50'.split('')) { controller.press(key); }
    expect(controller.value.displayAmount, '1.50');
    expect(controller.value.amount, 1.5);
    for (var i = 0; i < 5; i++) { controller.press('⌫'); }
    controller.press('.');
    controller.press('⌫');
    expect(controller.value.expression, '');
  });

  testWidgets('fraction and backspace update on contact and save only displayed cents', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late AppStore store;
    await tester.runAsync(() async { store = AppStore(); await store.ready; });
    await tester.pumpWidget(AppStoreScope(store: store, child: MaterialApp(
      theme: buildTheme(), home: AddPage(onSaved: () {}))));
    await tester.pumpAndSettle();
    for (final key in '12.3456'.split('')) {
      await tester.tap(find.text(key));
      await tester.pump();
    }
    expect(find.text('12.34'), findsOneWidget);
    expect(find.text('¥ 12.34'), findsOneWidget);
    for (final value in ['12.3', '12', '1']) {
      final gesture = await tester.startGesture(tester.getCenter(find.byIcon(Icons.backspace_outlined)));
      await tester.pump();
      expect(find.text('¥ $value'), findsOneWidget);
      await gesture.up();
      await tester.pump();
      expect(find.text('¥ $value'), findsOneWidget);
    }
    for (final key in '.309'.split('')) {
      await tester.tap(find.text(key));
      await tester.pump();
    }
    expect(find.text('¥ 1.30'), findsOneWidget);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(store.entries.first.amount, 1.3);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}

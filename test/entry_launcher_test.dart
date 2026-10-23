import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/app_theme.dart';
import 'package:smart_budget/widgets/entry_launcher.dart';

void main() {
  var manual = 0, voice = 0, backgroundBuilds = 0;
  final launcher = find.byKey(const ValueKey('entry-launcher'));
  final left = find.byKey(const ValueKey('entry-manual-target'));
  final right = find.byKey(const ValueKey('entry-voice-target'));
  Future<void> build(WidgetTester tester, {Size size = const Size(390, 844),
      bool dark = false, double textScale = 1, bool reduceMotion = false}) async {
    manual = 0; voice = 0; backgroundBuilds = 0;
    tester.view.physicalSize = size; tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: buildTheme(dark: dark),
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale), disableAnimations: reduceMotion), child: child!),
      home: Scaffold(body: Builder(builder: (_) {
        backgroundBuilds++; return const Center(child: Text('账单明细'));
      }), bottomNavigationBar: SafeArea(child: SizedBox(height: 78,
        child: Center(child: EntryLauncher(onManual: () => manual++, onVoice: () => voice++)))))));
    await tester.pumpAndSettle();
  }
  Future<TestGesture> open(WidgetTester tester) async {
    final origin = tester.getCenter(launcher);
    final gesture = await tester.startGesture(origin);
    await gesture.moveTo(origin + const Offset(0, -30));
    await tester.pumpAndSettle();
    expect(left, findsOneWidget); expect(right, findsOneWidget);
    return gesture;
  }

  testWidgets('tap still enters manual; upward drag opens without a long press', (tester) async {
    await build(tester);
    await tester.tap(launcher); expect(manual, 1); expect(voice, 0);
    final gesture = await open(tester);
    expect(manual, 1); expect(voice, 0);
    await gesture.cancel(); await tester.pumpAndSettle();
    expect(left, findsNothing); expect(manual, 1);
  });
  for (final side in ['manual', 'voice']) {
    testWidgets('one continuous drag to $side launches only on release', (tester) async {
      await build(tester);
      final initialBuilds = backgroundBuilds;
      final gesture = await open(tester);
      await gesture.moveTo(tester.getCenter(side == 'manual' ? left : right));
      await tester.pumpAndSettle();
      expect(find.text(side == 'manual' ? '松手进入手动记账' : '松手进入语音记账'), findsOneWidget);
      expect(manual, 0); expect(voice, 0); expect(backgroundBuilds, initialBuilds);
      await gesture.up(); await tester.pumpAndSettle();
      expect(manual, side == 'manual' ? 1 : 0);
      expect(voice, side == 'voice' ? 1 : 0);
      expect(left, findsNothing); expect(right, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('changing target selects the final target, not the first one crossed', (tester) async {
    await build(tester); final gesture = await open(tester);
    await gesture.moveTo(tester.getCenter(left)); await tester.pumpAndSettle();
    await gesture.moveTo(tester.getCenter(right)); await tester.pumpAndSettle();
    expect(find.text('松手进入语音记账'), findsOneWidget);
    await gesture.up(); await tester.pumpAndSettle();
    expect(manual, 0); expect(voice, 1);
  });
  for (final cancelAt in ['plus', 'outside', 'gap']) {
    testWidgets('release at $cancelAt cancels without opening either screen', (tester) async {
      await build(tester); final origin = tester.getCenter(launcher);
      final gesture = await open(tester);
      await gesture.moveTo(tester.getCenter(right)); await tester.pumpAndSettle();
      final point = cancelAt == 'plus' ? origin : cancelAt == 'outside'
          ? const Offset(5, 100) : Offset(origin.dx, tester.getCenter(right).dy);
      await gesture.moveTo(point); await tester.pumpAndSettle();
      await gesture.up(); await tester.pumpAndSettle();
      expect(manual, 0); expect(voice, 0); expect(right, findsNothing);
      await tester.tap(launcher); expect(manual, 1);
    });
  }
  testWidgets('cancelled pointer and downward drag never become manual taps', (tester) async {
    await build(tester); final gesture = await open(tester);
    await gesture.moveTo(tester.getCenter(right));
    await gesture.cancel(); await tester.pumpAndSettle();
    expect(manual, 0); expect(voice, 0);
    await tester.drag(launcher, const Offset(30, 25)); await tester.pumpAndSettle();
    expect(manual, 0); expect(voice, 0); expect(right, findsNothing);
  });
  testWidgets('a second finger cannot choose a target for the active pointer', (tester) async {
    await build(tester); final gesture = await open(tester);
    final other = await tester.startGesture(tester.getCenter(right), pointer: 99);
    await other.up(); await tester.pumpAndSettle();
    expect(manual, 0); expect(voice, 0);
    await gesture.moveTo(tester.getCenter(left)); await gesture.up(); await tester.pumpAndSettle();
    expect(manual, 1); expect(voice, 0);
  });
  testWidgets('system back cancels picker before navigation', (tester) async {
    await build(tester); final gesture = await open(tester);
    await tester.binding.handlePopRoute(); await tester.pumpAndSettle();
    expect(right, findsNothing);
    await gesture.up(); await tester.pumpAndSettle();
    expect(manual, 0); expect(voice, 0);
    expect(find.text('账单明细'), findsOneWidget);
  });
  testWidgets('backgrounding during release animation invalidates pending navigation', (tester) async {
    await build(tester); final gesture = await open(tester);
    await gesture.moveTo(tester.getCenter(right)); await tester.pumpAndSettle();
    await gesture.up();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(manual, 0); expect(voice, 0); expect(right, findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('resizing and unmounting clean up overlay and the active pointer', (tester) async {
    await build(tester); var gesture = await open(tester);
    tester.view.physicalSize = const Size(844, 390); await tester.pumpAndSettle();
    await gesture.up(); await tester.pumpAndSettle();
    expect(right, findsNothing); expect(manual, 0); expect(voice, 0);
    gesture = await open(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await gesture.up(); await tester.pumpAndSettle();
    expect(right, findsNothing); expect(tester.takeException(), isNull);
  });
  testWidgets('a fast diagonal drag can release without waiting for opening animation', (tester) async {
    await build(tester); final origin = tester.getCenter(launcher);
    final gesture = await tester.startGesture(origin);
    await gesture.moveTo(origin + const Offset(94, -170));
    await gesture.up(); await tester.pumpAndSettle();
    expect(voice, 1); expect(manual, 0); expect(right, findsNothing);
  });
  testWidgets('accessibility offers both choices without requiring a drag', (tester) async {
    await build(tester); final semantics = tester.ensureSemantics();
    final node = tester.getSemantics(launcher);
    tester.binding.pipelineOwner.semanticsOwner!.performAction(node.id, SemanticsAction.longPress);
    await tester.pumpAndSettle();
    await tester.tap(right); await tester.pumpAndSettle();
    expect(voice, 1); expect(manual, 0);
    semantics.dispose();
  });
  for (final size in [const Size(320, 640), const Size(844, 390)]) {
    testWidgets('dark enlarged-text targets fit $size with reduced motion', (tester) async {
      await build(tester, size: size, dark: true, textScale: 1.6, reduceMotion: true);
      final gesture = await open(tester);
      final screen = Offset.zero & size;
      expect(screen.contains(tester.getRect(left).topLeft), isTrue);
      expect(screen.contains(tester.getRect(right).bottomRight), isTrue);
      await gesture.moveTo(tester.getCenter(right)); await gesture.up(); await tester.pumpAndSettle();
      expect(voice, 1); expect(tester.takeException(), isNull);
    });
  }
}

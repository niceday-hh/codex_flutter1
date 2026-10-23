import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';
import '../app_theme.dart';

enum _EntryChoice { manual, voice }

/// Tracks one pointer from the original + hit target, even outside that target.
/// The overlay is visual feedback, not a second gesture that must be tapped.
class EntryLauncher extends StatefulWidget {
  const EntryLauncher({super.key, required this.onManual, required this.onVoice});
  final VoidCallback onManual, onVoice;

  @override
  State<EntryLauncher> createState() => _EntryLauncherState();
}

class _EntryLauncherState extends State<EntryLauncher>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _anchorKey = GlobalKey();
  final _selection = ValueNotifier<_EntryChoice?>(null);
  late final AnimationController _animation;
  OverlayEntry? _entry;
  RenderBox? _overlayBox;
  _PickerLayout? _layout;
  int? _pointer;
  Offset _down = Offset.zero;
  bool _moved = false, _closing = false;
  int _operation = 0;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 90));
    WidgetsBinding.instance.addObserver(this);
  }

  void _downEvent(PointerDownEvent event) {
    if (_pointer != null || _closing || _entry != null ||
        event.buttons != kPrimaryButton) return;
    _pointer = event.pointer;
    _down = event.position;
    _moved = false;
  }

  void _moveEvent(PointerMoveEvent event) {
    if (event.pointer != _pointer || _closing) return;
    final delta = event.position - _down;
    if (delta.distance > kTouchSlop) _moved = true;
    // No long-press timer: upward travel opens the picker immediately.
    if (_entry == null && delta.dy <= -22) _open();
    if (_entry != null) _track(event.position);
  }

  void _upEvent(PointerUpEvent event) {
    if (event.pointer != _pointer || _closing) return;
    if (_entry != null) {
      _track(event.position);
      unawaited(_finish(_selection.value));
    } else {
      final tapped = !_moved && (event.position - _down).distance <= kTouchSlop;
      _pointer = null;
      if (tapped) widget.onManual();
    }
  }

  void _cancelEvent(PointerCancelEvent event) {
    if (event.pointer == _pointer) unawaited(_finish(null));
  }

  void _open() {
    if (_entry != null || _closing) return;
    final anchor = _anchorKey.currentContext?.findRenderObject();
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject();
    if (anchor is! RenderBox || overlayBox is! RenderBox) return;
    _overlayBox = overlayBox;
    final origin = overlayBox.globalToLocal(anchor.localToGlobal(anchor.size.center(Offset.zero)));
    _layout = _PickerLayout(overlayBox.size, origin, MediaQuery.paddingOf(context));
    _selection.value = null;
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    _entry = OverlayEntry(builder: (_) => Theme(data: theme,
      child: MediaQuery(data: media, child: _buildOverlay())));
    overlay.insert(_entry!);
    if (media.disableAnimations) {
      _animation.value = 1;
    } else {
      _animation.forward(from: 0);
    }
    HapticFeedback.lightImpact();
    setState(() {}); // Updates only this button's back-navigation guard.
  }

  void _track(Offset globalPosition) {
    final box = _overlayBox;
    final layout = _layout;
    if (box == null || layout == null) return;
    final point = box.globalToLocal(globalPosition);
    _EntryChoice? selected;
    // A deliberate neutral/cancel zone always wins over target hysteresis.
    if ((point - layout.origin).distance > 44 && point.dy < layout.origin.dy - 48) {
      for (final choice in _EntryChoice.values) {
        final rect = layout.target(choice);
        final margin = _selection.value == choice ? 8.0 : 0.0;
        if (rect.inflate(margin).contains(point)) {
          selected = choice;
          break;
        }
      }
    }
    if (selected == _selection.value) return;
    _selection.value = selected;
    if (selected != null) HapticFeedback.selectionClick();
  }

  Future<void> _finish(_EntryChoice? choice) async {
    if (_closing) return;
    _closing = true;
    _pointer = null;
    final operation = ++_operation;
    if (_entry != null && !MediaQuery.disableAnimationsOf(context)) {
      try { await _animation.reverse().orCancel; }
      on TickerCanceled { return; }
    }
    if (!mounted || operation != _operation) return;
    _removeOverlay();
    _closing = false;
    setState(() {});
    if (choice == _EntryChoice.manual) widget.onManual();
    if (choice == _EntryChoice.voice) widget.onVoice();
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    _overlayBox = null;
    _layout = null;
  }

  void _abort({bool rebuild = true}) {
    _operation++; // Invalidates any pending release-to-navigate continuation.
    _pointer = null;
    _closing = false;
    _animation.stop(canceled: true);
    _removeOverlay();
    if (rebuild && mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && (_pointer != null || _entry != null)) _abort();
  }

  @override
  void didChangeMetrics() {
    if (_pointer != null || _entry != null) _abort();
  }

  void _accessibleChoice(_EntryChoice choice) {
    // Additional fingers cannot activate a target while the drag is in flight.
    if (_pointer == null) unawaited(_finish(choice));
  }

  Widget _buildOverlay() {
    final layout = _layout!;
    return Material(type: MaterialType.transparency, child: Stack(children: [
      ModalBarrier(color: Colors.transparent, dismissible: true,
        semanticsLabel: '取消记账方式选择', onDismiss: () => unawaited(_finish(null))),
      AnimatedBuilder(animation: _animation, builder: (_, child) => Opacity(
        opacity: Curves.easeOutCubic.transform(_animation.value), child: child),
        child: Stack(children: [
          // Preserve the light bottom dock from the preview. Block all taps
          // behind the picker through the full-screen barrier above.
          Positioned(left: 0, top: 0, right: 0,
            bottom: math.max(0.0, layout.size.height - layout.origin.dy + 39),
            child: const IgnorePointer(child: ColoredBox(color: Color(0x880E171B)))),
          Positioned(left: layout.origin.dx - 31, top: layout.origin.dy - 31,
            child: const IgnorePointer(child: _PlusDisc(expanded: true))),
          Positioned(left: 16, right: 16, top: layout.targetY - 96,
            child: IgnorePointer(child: ValueListenableBuilder<_EntryChoice?>(
              valueListenable: _selection,
              builder: (_, value, __) => Text(value == null ? '滑向功能，松手进入' :
                  value == _EntryChoice.manual ? '松手进入手动记账' : '松手进入语音记账',
                textAlign: TextAlign.center, maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w600, shadows: [Shadow(color: Colors.black26, blurRadius: 8)]))))),
          for (final choice in _EntryChoice.values)
            Positioned.fromRect(rect: layout.target(choice),
              child: AnimatedBuilder(animation: _animation,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, 14 * (1 - _animation.value)),
                  child: Transform.scale(scale: 0.86 + 0.14 * Curves.easeOutBack.transform(_animation.value), child: child)),
                child: ValueListenableBuilder<_EntryChoice?>(valueListenable: _selection,
                  builder: (_, selected, __) => _ChoiceTarget(
                    key: ValueKey('entry-${choice.name}-target'),
                    voice: choice == _EntryChoice.voice, selected: selected == choice,
                    onTap: () => _accessibleChoice(choice))))),
          Positioned(left: 16, right: 16, top: layout.origin.dy - 64,
            child: const IgnorePointer(child: Text('滑回＋或移出按钮可取消',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 12,
                shadows: [Shadow(color: Colors.black26, blurRadius: 8)])))),
        ])),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(canPop: _entry == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _entry != null) _abort();
      },
      child: Semantics(
        button: true, label: '记一笔', hint: '轻点手动记账，按住上滑选择手动或语音',
        onTap: widget.onManual, onLongPress: _open,
        customSemanticsActions: {const CustomSemanticsAction(label: '语音记账'): widget.onVoice},
        child: Listener(key: const ValueKey('entry-launcher'), behavior: HitTestBehavior.opaque,
          onPointerDown: _downEvent, onPointerMove: _moveEvent,
          onPointerUp: _upEvent, onPointerCancel: _cancelEvent,
          child: SizedBox(key: _anchorKey, width: 70, height: 70,
            child: const Center(child: _PlusDisc())))));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _abort(rebuild: false);
    _animation.dispose();
    _selection.dispose();
    super.dispose();
  }
}

class _PickerLayout {
  _PickerLayout(this.size, this.origin, EdgeInsets padding) {
    final available = size.width - padding.left - padding.right;
    final center = padding.left + available / 2;
    final separation = math.min(94.0, available / 4);
    width = math.min(132.0, available / 2 - 20);
    leftX = center - separation;
    rightX = center + separation;
    targetY = math.max(padding.top + 110, origin.dy - 170);
  }
  final Size size;
  final Offset origin;
  late final double leftX, rightX, targetY, width;
  Rect target(_EntryChoice choice) => Rect.fromCenter(
    center: Offset(choice == _EntryChoice.manual ? leftX : rightX, targetY + 12),
    width: width, height: 132);
}

class _PlusDisc extends StatelessWidget {
  const _PlusDisc({this.expanded = false});
  final bool expanded;
  @override
  Widget build(BuildContext context) => Container(
    width: expanded ? 62 : 54, height: expanded ? 62 : 54,
    decoration: BoxDecoration(shape: BoxShape.circle,
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFFFC457), AppPalette.primary]),
      border: Border.all(color: Colors.white.withValues(alpha: 0.82), width: 2),
      boxShadow: [BoxShadow(color: AppPalette.primary.withValues(alpha: expanded ? 0.42 : 0.28),
        blurRadius: expanded ? 25 : 18, offset: const Offset(0, 8))]),
    child: const Icon(Icons.add_rounded, size: 34, color: AppPalette.ink));
}

class _ChoiceTarget extends StatelessWidget {
  const _ChoiceTarget({super.key, required this.voice, required this.selected, required this.onTap});
  final bool voice, selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = voice ? AppPalette.mint : AppPalette.primary;
    final ink = voice ? const Color(0xFF147D70) : AppPalette.primaryDeep;
    final tint = voice ? AppPalette.mintSoft : AppPalette.primarySoft;
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 110);
    return Semantics(button: true, selected: selected, excludeSemantics: true,
      label: voice ? '语音记账' : '手动记账', onTap: onTap,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedScale(scale: selected ? 1.13 : 1, duration: duration, curve: Curves.easeOutCubic,
            child: AnimatedContainer(duration: duration, width: 88, height: 88,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Colors.white, selected ? Color.lerp(tint, color, 0.12)! : tint]),
                border: Border.all(color: selected ? color : Colors.white.withValues(alpha: 0.9),
                  width: selected ? 3 : 1.5),
                boxShadow: [BoxShadow(color: selected ? color.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.12),
                  blurRadius: selected ? 24 : 12, spreadRadius: selected ? 3 : 0,
                  offset: const Offset(0, 5))]),
              child: Icon(voice ? Icons.mic_none_rounded : Icons.edit_note_rounded, size: 40, color: ink))),
          const SizedBox(height: 12),
          Flexible(child: Text(voice ? '语音记账' : '手动记账', textAlign: TextAlign.center,
            maxLines: 2, style: TextStyle(color: Colors.white, fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              shadows: const [Shadow(color: Colors.black26, blurRadius: 8)]))),
        ])));
  }
}

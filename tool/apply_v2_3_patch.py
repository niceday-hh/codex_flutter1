#!/usr/bin/env python3
from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'Patch target not found: {label}')
    return text.replace(old, new, 1)


# Version
pubspec = Path('pubspec.yaml')
text = pubspec.read_text()
text = re.sub(r'^version:\s*[^\n]+$', 'version: 2.3.0+5', text, count=1, flags=re.M)
pubspec.write_text(text)

# Home: negative balance color/sign + amount keypad overwrite-on-first-input.
home = Path('lib/pages/home_page.dart')
text = home.read_text()
text = replace_once(
    text,
    """                        value: store.displayMoney(income - expense),\n                        color: AppPalette.primaryDeep,\n""",
    """                        value: _balanceText(store, income - expense),\n                        color: income - expense < 0\n                            ? const Color(0xFFD95B67)\n                            : AppPalette.primaryDeep,\n""",
    'home balance metric',
)
text = replace_once(
    text,
    """class _AmountQuickEditorState extends State<_AmountQuickEditor> {\n  late String _value;\n""",
    """class _AmountQuickEditorState extends State<_AmountQuickEditor> {\n  late String _value;\n  bool _replaceOnNextInput = true;\n""",
    'amount editor selection state',
)
pattern = re.compile(
    r"  void _press\(String key\) \{.*?\n  \}\n\n  @override\n  Widget build",
    re.S,
)
replacement = """  void _press(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (key == '⌫') {
        if (_replaceOnNextInput) {
          _value = '0';
          _replaceOnNextInput = false;
          return;
        }
        if (_value.isNotEmpty) {
          _value = _value.substring(0, _value.length - 1);
        }
        if (_value.isEmpty) _value = '0';
        return;
      }
      if (key == '.') {
        if (_replaceOnNextInput) {
          _value = '0.';
          _replaceOnNextInput = false;
          return;
        }
        if (!_value.contains('.')) _value = '$_value.';
        return;
      }
      if (_replaceOnNextInput) {
        _value = key;
        _replaceOnNextInput = false;
        return;
      }
      final dot = _value.indexOf('.');
      if (dot >= 0 && _value.length - dot > 2) return;
      if (_value == '0') {
        _value = key;
      } else if (_value.replaceAll('.', '').length < 9) {
        _value += key;
      }
    });
  }

  @override
  Widget build"""
text, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit('Patch target not found: amount editor _press')
text = replace_once(
    text,
    """              child: Text(\n                '¥ $_value',\n""",
    """              child: Text(\n                '¥ $_value',\n""",
    'amount display',
)
helper_anchor = """String _trimAmount(double value) =>\n    value.toStringAsFixed(2).replaceFirst(RegExp(r'\\.?0+$'), '');\n\nclass _SummaryCell"""
helper_replacement = """String _trimAmount(double value) =>\n    value.toStringAsFixed(2).replaceFirst(RegExp(r'\\.?0+$'), '');\n\nString _balanceText(AppStore store, double value) {\n  if (store.hideAmounts) return '••••';\n  if (value < 0) return '-${store.displayMoney(value.abs())}';\n  return store.displayMoney(value);\n}\n\nclass _SummaryCell"""
text = replace_once(text, helper_anchor, helper_replacement, 'balance helper')
home.write_text(text)

# Shell: keep all tabs alive but add a very short fade/scale transition.
shell = Path('lib/shell.dart')
text = shell.read_text()
text = replace_once(
    text,
    "import 'pages/stats_page.dart';",
    "import 'pages/stats_page_v23.dart';",
    'stats page import',
)
old_stack = """            child: IndexedStack(\n              index: _index,\n              sizing: StackFit.expand,\n              children: _pages,\n            ),\n"""
new_stack = """            child: Stack(\n              fit: StackFit.expand,\n              children: List.generate(_pages.length, (pageIndex) {\n                final active = pageIndex == _index;\n                return IgnorePointer(\n                  ignoring: !active,\n                  child: TickerMode(\n                    enabled: active,\n                    child: AnimatedOpacity(\n                      opacity: active ? 1 : 0,\n                      duration: const Duration(milliseconds: 145),\n                      curve: Curves.easeOutCubic,\n                      child: AnimatedScale(\n                        scale: active ? 1 : 0.995,\n                        duration: const Duration(milliseconds: 145),\n                        curve: Curves.easeOutCubic,\n                        alignment: Alignment.center,\n                        child: _pages[pageIndex],\n                      ),\n                    ),\n                  ),\n                );\n              }),\n            ),\n"""
text = replace_once(text, old_stack, new_stack, 'tab animation stack')
shell.write_text(text)

print('v2.3.0 source patches applied successfully.')

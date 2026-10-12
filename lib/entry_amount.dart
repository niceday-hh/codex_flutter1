import 'package:flutter/foundation.dart';

class AmountDraft {
  const AmountDraft(this.expression, this.amount);
  final String expression;
  final double amount;

  // Keep typed fractional zeros visible so deleting them also changes the label.
  String get displayAmount {
    if (RegExp(r'^\d+(?:\.\d*)?$').hasMatch(expression)) {
      final parts = expression.split('.');
      final integer = int.parse(parts.first).toString();
      return parts.length == 1 ? integer : '$integer.${parts.last}';
    }
    return amount.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

class EntryAmountController extends ValueNotifier<AmountDraft> {
  EntryAmountController() : super(const AmountDraft('', 0));

  void press(String key) {
    var expression = value.expression;
    if (key == '⌫') {
      if (expression.isEmpty) return;
      // A trailing separator is editing syntax, not an extra hidden digit.
      if (expression.endsWith('.')) {
        expression = expression.substring(0, expression.length - 1);
      }
      expression = expression.substring(0, expression.length - 1);
      if (expression.endsWith('.')) {
        expression = expression.substring(0, expression.length - 1);
      }
    } else if (key == '+' || key == '-') {
      if (expression.isEmpty) return;
      expression = expression.endsWith('+') || expression.endsWith('-')
          ? '${expression.substring(0, expression.length - 1)}$key' : '$expression$key';
    } else if (key == '.') {
      final segment = expression.split(RegExp(r'[+-]')).last;
      if (segment.contains('.')) return;
      expression += segment.isEmpty ? '0.' : '.';
    } else {
      if (!RegExp(r'^\d$').hasMatch(key) || expression.replaceAll(RegExp(r'[^0-9]'), '').length >= 9) return;
      final segment = expression.split(RegExp(r'[+-]')).last;
      final point = segment.indexOf('.');
      if (point >= 0 && segment.length - point - 1 >= 2) return;
      expression += key;
    }
    // Publish the authoritative new value synchronously, before haptics or animation.
    value = AmountDraft(expression, evaluateAmount(expression));
  }
}

double evaluateAmount(String expression) {
  if (expression.trim().isEmpty) return 0;
  final parts = expression.split(RegExp(r'(?=[+-])|(?<=[+-])'));
  var totalCents = 0;
  var operator = '+';
  for (final part in parts) {
    if (part == '+' || part == '-') { operator = part; continue; }
    // Each operand is limited to cents; integer arithmetic avoids binary drift.
    final number = ((double.tryParse(part) ?? 0) * 100).round();
    totalCents = operator == '+' ? totalCents + number : totalCents - number;
  }
  return totalCents.abs() / 100;
}

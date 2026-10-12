import 'package:flutter/foundation.dart';

class AmountDraft {
  const AmountDraft(this.expression, this.amount);
  final String expression;
  final double amount;
}

class EntryAmountController extends ValueNotifier<AmountDraft> {
  EntryAmountController() : super(const AmountDraft('', 0));

  void press(String key) {
    var expression = value.expression;
    if (key == '⌫') {
      if (expression.isEmpty) return;
      expression = expression.substring(0, expression.length - 1);
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
      expression += key;
    }
    // Publish the authoritative new value synchronously, before haptics or animation.
    value = AmountDraft(expression, evaluateAmount(expression));
  }
}

double evaluateAmount(String expression) {
  if (expression.trim().isEmpty) return 0;
  final parts = expression.split(RegExp(r'(?=[+-])|(?<=[+-])'));
  var total = 0.0, operator = '+';
  for (final part in parts) {
    if (part == '+' || part == '-') { operator = part; continue; }
    final number = double.tryParse(part) ?? 0;
    total = operator == '+' ? total + number : total - number;
  }
  return total.abs();
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.isIncome,
    required this.date,
    this.note = '',
  });

  final String id;
  final String title;
  final String category;
  final double amount;
  final bool isIncome;
  final DateTime date;
  final String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'isIncome': isIncome,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
        id: json['id'] as String,
        title: (json['title'] as String?) ?? '',
        category: (json['category'] as String?) ?? '其他',
        amount: (json['amount'] as num).toDouble(),
        isIncome: json['isIncome'] as bool,
        date: DateTime.parse(json['date'] as String),
        note: (json['note'] as String?) ?? '',
      );
}

class CategorySummary {
  const CategorySummary(this.name, this.amount, this.count);

  final String name;
  final double amount;
  final int count;
}

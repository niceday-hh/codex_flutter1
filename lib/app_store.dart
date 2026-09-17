import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'models.dart';

class AppStore extends ChangeNotifier {
  AppStore() {
    _seed();
    _restore();
  }

  static const _channel = MethodChannel('smart_budget/storage');

  final List<LedgerEntry> _entries = [];
  int _revision = 0;

  double monthlyBudget = 4000;
  int noteLimit = 12;
  bool hideAmounts = false;
  bool dailyReminder = true;
  bool darkMode = false;
  int reminderHour = 20;
  int reminderMinute = 30;
  final Map<String, double> categoryBudgets = {
    '餐饮': 1000,
    '交通': 500,
    '通讯': 300,
    '购物': 500,
    '日用': 200,
  };

  List<LedgerEntry>? _sortedEntries;
  final Map<(int, int), List<LedgerEntry>> _monthEntries = {};

  // Immutable snapshots are reused until the store changes.
  List<LedgerEntry> get entries => _sortedEntries ??= List.unmodifiable(
        List<LedgerEntry>.from(_entries)
          ..sort((a, b) => b.date.compareTo(a.date)),
      );

  List<LedgerEntry> entriesForMonth(DateTime month) =>
      _monthEntries.putIfAbsent((month.year, month.month), () =>
          List.unmodifiable(entries.where((e) =>
              e.date.year == month.year && e.date.month == month.month)));

  void _invalidateEntries() {
    _sortedEntries = null;
    _monthEntries.clear();
  }

  double incomeForMonth(DateTime month) => entriesForMonth(month)
      .where((e) => e.isIncome)
      .fold(0, (sum, e) => sum + e.amount);

  double expenseForMonth(DateTime month) => entriesForMonth(month)
      .where((e) => !e.isIncome)
      .fold(0, (sum, e) => sum + e.amount);

  double balanceForMonth(DateTime month) => incomeForMonth(month) - expenseForMonth(month);

  List<CategorySummary> categorySummaryForMonth(DateTime month, {bool income = false}) {
    final amounts = <String, double>{};
    final counts = <String, int>{};
    for (final item in entriesForMonth(month).where((e) => e.isIncome == income)) {
      amounts[item.category] = (amounts[item.category] ?? 0) + item.amount;
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }
    final result = amounts.entries
        .map((e) => CategorySummary(e.key, e.value, counts[e.key] ?? 0))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }

  List<String> notesForCategory(String category, {required bool income}) {
    final seen = <String>{};
    final notes = <String>[];
    for (final entry in entries.where((e) => e.category == category && e.isIncome == income)) {
      final note = entry.note.trim();
      if (note.isNotEmpty && seen.add(note)) {
        notes.add(note);
        if (notes.length >= noteLimit) break;
      }
    }
    return notes;
  }

  List<LedgerEntry> entriesForCategory(
    String category, {
    DateTime? month,
    bool? income,
  }) {
    Iterable<LedgerEntry> result = entries.where((e) => e.category == category);
    if (month != null) {
      result = result.where((e) => e.date.year == month.year && e.date.month == month.month);
    }
    if (income != null) result = result.where((e) => e.isIncome == income);
    return result.toList();
  }

  void addEntry({
    required String title,
    required String category,
    required double amount,
    required bool isIncome,
    required DateTime date,
    String note = '',
  }) {
    _entries.add(LedgerEntry(
      id: '${DateTime.now().microsecondsSinceEpoch}_${_revision++}',
      title: title,
      category: category,
      amount: amount,
      isIncome: isIncome,
      date: date,
      note: note,
    ));
    _changed();
  }

  void updateEntry(
    String id, {
    String? title,
    String? category,
    double? amount,
    bool? isIncome,
    DateTime? date,
    String? note,
  }) {
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index < 0) return;
    final current = _entries[index];
    _entries[index] = LedgerEntry(
      id: current.id,
      title: title ?? current.title,
      category: category ?? current.category,
      amount: amount ?? current.amount,
      isIncome: isIncome ?? current.isIncome,
      date: date ?? current.date,
      note: note ?? current.note,
    );
    _changed();
  }

  void deleteEntry(String id) {
    _entries.removeWhere((entry) => entry.id == id);
    _changed();
  }

  void setBudget(double value) {
    monthlyBudget = value.clamp(100, 9999999).toDouble();
    _changed();
  }

  void setCategoryBudget(String category, double value) {
    categoryBudgets[category] = value.clamp(0, 9999999).toDouble();
    _changed();
  }

  void setNoteLimit(int value) {
    noteLimit = value.clamp(4, 24);
    _changed();
  }

  void setHideAmounts(bool value) {
    hideAmounts = value;
    _changed();
  }

  void setDailyReminder(bool value) {
    dailyReminder = value;
    _changed();
  }

  void setDarkMode(bool value) {
    darkMode = value;
    _changed();
  }

  void setReminderTime(int hour, int minute) {
    reminderHour = hour;
    reminderMinute = minute;
    _changed();
  }

  void clearEntries() {
    _entries.clear();
    _changed();
  }

  String displayMoney(double value, {bool signed = false}) {
    if (hideAmounts) return '••••';
    final amount = _trimNumber(value.abs());
    if (!signed) return '¥$amount';
    final sign = value >= 0 ? '+' : '-';
    return '$sign¥$amount';
  }

  String exportCsv() {
    final rows = <List<String>>[
      const ['日期', '类型', '分类', '金额', '备注'],
      ...entries.map((entry) => [
            _formatCsvDate(entry.date),
            entry.isIncome ? '收入' : '支出',
            entry.category,
            _trimNumber(entry.amount),
            entry.note.isEmpty ? entry.title : entry.note,
          ]),
    ];
    return '\ufeff${rows.map((row) => row.map(_escapeCsv).join(',')).join('\r\n')}';
  }

  Future<bool> exportCsvToFile() async {
    final now = DateTime.now();
    final filename = '拾光账本_${now.year}${_two(now.month)}${_two(now.day)}.csv';
    try {
      final saved = await _channel.invokeMethod<bool>('saveCsv', {
        'filename': filename,
        'content': exportCsv(),
      });
      return saved ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> pickCsvFromFile() async {
    try {
      return await _channel.invokeMethod<String>('pickCsv');
    } catch (_) {
      return null;
    }
  }

  int importCsv(String raw, {required bool replace}) {
    var text = raw;
    if (text.startsWith('\ufeff')) text = text.substring(1);
    final firstLineEnd = text.indexOf(RegExp(r'[\r\n]'));
    final firstLine = firstLineEnd < 0 ? text : text.substring(0, firstLineEnd);
    final delimiter = firstLine.contains('\t') ? '\t' : ',';
    final rows = _parseDelimited(text, delimiter);
    if (rows.isEmpty) return 0;

    final header = rows.first.map((e) => e.trim()).toList();
    int indexOf(String name) => header.indexOf(name);
    final dateIndex = indexOf('日期');
    final typeIndex = indexOf('类型');
    final categoryIndex = indexOf('分类');
    final amountIndex = indexOf('金额');
    final noteIndex = indexOf('备注');
    if ([dateIndex, typeIndex, categoryIndex, amountIndex].any((i) => i < 0)) {
      throw const FormatException('CSV 必须包含：日期、类型、分类、金额、备注');
    }

    final imported = <LedgerEntry>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((cell) => cell.trim().isEmpty)) continue;
      if (row.length <= [dateIndex, typeIndex, categoryIndex, amountIndex, noteIndex].reduce((a, b) => a > b ? a : b)) {
        continue;
      }
      final amount = double.tryParse(row[amountIndex].trim());
      final date = _parseCsvDate(row[dateIndex].trim());
      if (amount == null || amount <= 0 || date == null) continue;
      final type = row[typeIndex].trim();
      final category = row[categoryIndex].trim().isEmpty ? '其他' : row[categoryIndex].trim();
      final note = noteIndex >= 0 && noteIndex < row.length ? row[noteIndex].trim() : '';
      imported.add(LedgerEntry(
        id: 'csv_${DateTime.now().microsecondsSinceEpoch}_${_revision++}_$i',
        title: note.isEmpty ? category : note,
        category: category,
        amount: amount,
        isIncome: type == '收入',
        date: date,
        note: note,
      ));
    }

    if (replace) _entries.clear();
    _entries.addAll(imported);
    _changed();
    return imported.length;
  }

  void _changed() {
    _invalidateEntries();
    notifyListeners();
    _persist();
  }

  Future<void> _restore() async {
    try {
      final raw = await _channel.invokeMethod<String>('load');
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data.containsKey('entries')) {
        final saved = (data['entries'] as List<dynamic>? ?? const [])
            .map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        _entries
          ..clear()
          ..addAll(saved);
      }
      monthlyBudget = (data['monthlyBudget'] as num?)?.toDouble() ?? monthlyBudget;
      noteLimit = (data['noteLimit'] as num?)?.toInt() ?? noteLimit;
      hideAmounts = data['hideAmounts'] as bool? ?? hideAmounts;
      dailyReminder = data['dailyReminder'] as bool? ?? dailyReminder;
      darkMode = data['darkMode'] as bool? ?? darkMode;
      reminderHour = (data['reminderHour'] as num?)?.toInt() ?? reminderHour;
      reminderMinute = (data['reminderMinute'] as num?)?.toInt() ?? reminderMinute;
      final savedBudgets = data['categoryBudgets'] as Map<String, dynamic>?;
      if (savedBudgets != null) {
        categoryBudgets
          ..clear()
          ..addAll(savedBudgets.map((key, value) => MapEntry(key, (value as num).toDouble())));
      }
      _invalidateEntries();
      notifyListeners();
    } catch (_) {
      // A preview host may not expose the Android persistence channel.
    }
  }

  Future<void> _persist() async {
    final payload = jsonEncode({
      'monthlyBudget': monthlyBudget,
      'noteLimit': noteLimit,
      'hideAmounts': hideAmounts,
      'dailyReminder': dailyReminder,
      'darkMode': darkMode,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
      'categoryBudgets': categoryBudgets,
      'entries': _entries.map((e) => e.toJson()).toList(),
    });
    try {
      await _channel.invokeMethod<void>('save', payload);
    } catch (_) {
      // Keep the UI responsive when persistence is unavailable.
    }
  }

  void _seed() {
    _entries.addAll([
      LedgerEntry(id: 'seed_salary', title: '月工资', category: '工资', amount: 5140, isIncome: true, date: DateTime(2026, 9, 5, 9, 0), note: '月工资'),
      LedgerEntry(id: 'seed_train', title: '高铁（泾县到合肥）', category: '交通', amount: 89, isIncome: false, date: DateTime(2026, 9, 10, 20, 10), note: '高铁（泾县到合肥）'),
      LedgerEntry(id: 'seed_fruit', title: '水果', category: '餐饮', amount: 6.99, isIncome: false, date: DateTime(2026, 9, 10, 18, 36), note: '水果'),
      LedgerEntry(id: 'seed_tofu', title: '臭豆腐', category: '餐饮', amount: 10, isIncome: false, date: DateTime(2026, 9, 9, 21, 12), note: '臭豆腐'),
      LedgerEntry(id: 'seed_chicken', title: '临榆炸鸡腿', category: '餐饮', amount: 13.3, isIncome: false, date: DateTime(2026, 9, 9, 19, 42), note: '临榆炸鸡腿'),
      LedgerEntry(id: 'seed_print', title: '打印材料（思迪）', category: '办公', amount: 15, isIncome: false, date: DateTime(2026, 9, 9, 17, 16), note: '打印材料（思迪）'),
      LedgerEntry(id: 'seed_elephant', title: '小象买菜', category: '餐饮', amount: 43.37, isIncome: false, date: DateTime(2026, 9, 9, 10, 5), note: '小象买菜'),
      LedgerEntry(id: 'seed_d1', title: '晚餐', category: '餐饮', amount: 45, isIncome: false, date: DateTime(2026, 9, 1, 19, 20), note: '晚餐'),
      LedgerEntry(id: 'seed_d3', title: '生活缴费', category: '日用', amount: 82, isIncome: false, date: DateTime(2026, 9, 3, 8, 15), note: '生活缴费'),
      LedgerEntry(id: 'seed_d5', title: '聚餐', category: '餐饮', amount: 134.08, isIncome: false, date: DateTime(2026, 9, 5, 20, 18), note: '聚餐'),
      LedgerEntry(id: 'seed_d7', title: '电话费', category: '通讯', amount: 35, isIncome: false, date: DateTime(2026, 9, 7, 9, 42), note: '电话费'),
      LedgerEntry(id: 'seed_d8', title: '多多买菜', category: '餐饮', amount: 30.19, isIncome: false, date: DateTime(2026, 9, 8, 18, 50), note: '多多买菜'),
    ]);
  }

  static String _escapeCsv(String value) {
    if (!value.contains(RegExp('[,"\\n\\r]'))) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  static List<List<String>> _parseDelimited(String text, String delimiter) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '"') {
        if (quoted && i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (!quoted && char == delimiter) {
        row.add(field.toString());
        field = StringBuffer();
      } else if (!quoted && (char == '\n' || char == '\r')) {
        if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(field.toString());
        rows.add(row);
        row = <String>[];
        field = StringBuffer();
      } else {
        field.write(char);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }

  static DateTime? _parseCsvDate(String value) {
    final match = RegExp(r'^(\d{4})[/-](\d{1,2})[/-](\d{1,2})(?:\s+(\d{1,2}):(\d{1,2}))?').firstMatch(value);
    if (match == null) return DateTime.tryParse(value);
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.tryParse(match.group(4) ?? '') ?? 0,
      int.tryParse(match.group(5) ?? '') ?? 0,
    );
  }

  static String _formatCsvDate(DateTime value) =>
      '${value.year}/${value.month}/${value.day} ${value.hour}:${_two(value.minute)}';

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _trimNumber(double value) {
    final text = value.toStringAsFixed(2);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

class AppStoreScope extends InheritedNotifier<AppStore> {
  const AppStoreScope({
    super.key,
    required AppStore store,
    required super.child,
  }) : super(notifier: store);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStoreScope>();
    assert(scope != null, 'AppStoreScope not found');
    return scope!.notifier!;
  }
}


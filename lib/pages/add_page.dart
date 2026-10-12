import 'package:flutter/gestures.dart';
import '../entry_amount.dart';
import '../widgets/animated_amount.dart';
import '../widgets/note_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_store.dart';
import '../app_theme.dart';
import '../widgets/common.dart';

class AddPage extends StatefulWidget {
  const AddPage({super.key, required this.onSaved});
  final VoidCallback onSaved;

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  bool _income = false;
  String _selectedCategory = '餐饮';
  DateTime _date = DateTime.now();
  final _amount = EntryAmountController();
  bool _editingNote = false;
  String _note = '';
  Object? _gridKey, _keypadKey;
  Widget? _grid, _keypad;

  @override
  void dispose() { _amount.dispose(); super.dispose(); }

  List<String> get _categories => _income ? incomeCategories : expenseCategories;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final quickNotes = store.notesForCategory(_selectedCategory, income: _income);
    final activeColor = _income ? AppPalette.mint : AppPalette.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(width: 46, height: 46, child: Icon(Icons.close_rounded, size: 30)),
                  ),
                  Expanded(
                    child: Text(
                      '记一笔',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 28),
                    ),
                  ),
                  GestureDetector(
                    onTap: _pickDate,
                    child: SizedBox(
                      width: 84,
                      height: 46,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_date.month.toString().padLeft(2, '0')}月${_date.day.toString().padLeft(2, '0')}日',
                          style: const TextStyle(color: AppPalette.primaryDeep, fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 112),
              child: PillTabs(
                labels: const ['支出', '收入'],
                index: _income ? 1 : 0,
                activeColor: activeColor,
                onChanged: (index) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _income = index == 1;
                    _selectedCategory = _income ? '工资' : '餐饮';
                  });
                },
              ),
            ),
            const SizedBox(height: 14),
            _categoryGrid(context),
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              padding: const EdgeInsets.fromLTRB(15, 13, 15, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 7)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<AmountDraft>(valueListenable: _amount,
                    builder: (context, draft, _) => Row(children: [
                      Expanded(child: Text(draft.expression.isEmpty ? '0' : draft.expression,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12))),
                      const SizedBox(width: 8),
                      AnimatedAmount(key: const ValueKey('entry-amount-value'),
                        text: store.hideAmounts ? '••••' : '¥ ${draft.displayAmount}',
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
                    ])),
                  Divider(height: 20, color: Theme.of(context).dividerColor),
                  GestureDetector(
                    key: const ValueKey('entry-note-target'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _editNote(context),
                    child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _note.isEmpty ? '备注：点击填写备注' : '备注：$_note',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _note.isEmpty ? Theme.of(context).textTheme.bodySmall?.color : null,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    )),
                  ),
                  if (quickNotes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: quickNotes.map((note) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _note = note),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Theme.of(context).dividerColor),
                                ),
                                child: Text(note, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _cachedKeypad(context, store, activeColor),
          ],
        ),
      ),
    );
  }

  Widget _categoryGrid(BuildContext context) {
    final key = (_income, _selectedCategory, Theme.of(context));
    if (key != _gridKey) {
      _gridKey = key;
      final categories = _categories;
      final selectedCategory = _selectedCategory;
      _grid = Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: GridView.builder(
                  key: ValueKey(_income),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  physics: const BouncingScrollPhysics(),
                  itemCount: categories.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisExtent: 78,
                    crossAxisSpacing: 7,
                    mainAxisSpacing: 6,
                  ),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final selected = category == selectedCategory;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategory = category);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CategoryAvatar(category: category, size: 48, selected: selected),
                          const SizedBox(height: 5),
                          Text(
                            category,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                              color: selected ? (selected ? colorForCategory(category) : null) : Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
    }
    return _grid!;
  }

  Widget _cachedKeypad(BuildContext context, AppStore store, Color activeColor) {
    final key = (store, activeColor, Theme.of(context));
    if (key != _keypadKey) {
      _keypadKey = key;
      _keypad = _Keypad(accentColor: activeColor, onKey: (key) => _handleKey(key, store));
    }
    return _keypad!;
  }

  Future<void> _pickDate() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 8),
      lastDate: DateTime(DateTime.now().year + 2),
      helpText: '选择记账日期',
      confirmText: '完成',
      cancelText: '取消',
    );
    if (picked != null && mounted) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute);
      });
    }
  }

  Future<void> _editNote(BuildContext context) async {
    if (_editingNote) return;
    _editingNote = true;
    final store = AppStoreScope.read(context);
    try {
      final value = await showNotePicker(context, loadCatalog: store.loadNoteCatalog,
        income: _income, category: _selectedCategory, initial: _note);
      if (value != null && mounted) setState(() => _note = value);
    } finally { _editingNote = false; }
  }

  void _handleKey(String key, AppStore store) {
    if (key == '完成') { _save(store); return; }
    if (key == '今天') {
      setState(() => _date = DateTime.now());
    } else {
      _amount.press(key);
    }
    HapticFeedback.selectionClick();
  }

  void _save(AppStore store) {
    final amount = _amount.value.amount;
    if (amount <= 0) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating, content: Text('请输入有效金额')),
      );
      return;
    }
    final now = DateTime.now();
    final date = DateTime(_date.year, _date.month, _date.day, now.hour, now.minute);
    store.addEntry(
      title: _note.isEmpty ? _selectedCategory : _note,
      category: _selectedCategory,
      amount: amount,
      isIncome: _income,
      date: date,
      note: _note,
    );
    HapticFeedback.mediumImpact();
    widget.onSaved();
  }

}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.accentColor, required this.onKey});
  final Color accentColor;
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['7', '8', '9', '今天'],
      ['4', '5', '6', '+'],
      ['1', '2', '3', '-'],
      ['.', '0', '⌫', '完成'],
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        children: keys.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: row.map((key) {
                final complete = key == '完成';
                final immediate = !complete && key != '今天';
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Semantics(button: true, label: key, onTap: () => onKey(key), excludeSemantics: true,
                      child: Listener(behavior: HitTestBehavior.opaque,
                        onPointerDown: immediate ? (event) { if (event.buttons == kPrimaryButton) onKey(key); } : null,
                        child: GestureDetector(behavior: HitTestBehavior.opaque,
                          excludeFromSemantics: true,
                          onTap: immediate ? null : () => onKey(key),
                          child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: complete ? accentColor : Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: key == '⌫'
                            ? const Icon(Icons.backspace_outlined, size: 22)
                            : Text(
                                key,
                                style: TextStyle(
                                  fontSize: key == '今天' || complete ? 15 : 20,
                                  fontWeight: complete ? FontWeight.w900 : FontWeight.w700,
                                  color: complete && accentColor == AppPalette.primary ? AppPalette.ink : null,
                                ),
                              ),
                      ),
                    ))),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}



import '../widgets/note_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_store.dart';
import '../app_theme.dart';
import '../models.dart';
import '../widgets/common.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late DateTime _month;
  List<LedgerEntry>? _cachedItems;
  double _expense = 0, _income = 0;
  List<({LedgerEntry? entry, DateTime date, double expense, bool first, bool last})> _rows = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _moveMonth(int offset) {
    HapticFeedback.selectionClick();
    setState(() => _month = DateTime(_month.year, _month.month + offset));
  }

  void _returnToCurrentMonth() {
    final now = DateTime.now();
    HapticFeedback.selectionClick();
    setState(() => _month = DateTime(now.year, now.month));
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final items = store.entriesForMonth(_month);
    if (!identical(items, _cachedItems)) {
      _cachedItems = items;
    var expense = 0.0;
    var income = 0.0;
    for (final item in items) {
      if (item.isIncome) {
        income += item.amount;
      } else {
        expense += item.amount;
      }
    }
    final rows = <({LedgerEntry? entry, DateTime date, double expense, bool first, bool last})>[];
    for (final group in _groupByDay(items).values) {
      final total = group.where((e) => !e.isIncome)
          .fold<double>(0, (sum, e) => sum + e.amount);
      rows.add((entry: null, date: group.first.date, expense: total, first: false, last: false));
      for (var i = 0; i < group.length; i++) {
        rows.add((entry: group[i], date: group[i].date, expense: 0,
          first: i == 0, last: i == group.length - 1));
      }
    }

      _expense = expense;
      _income = income;
      _rows = rows;
    }
    final expense = _expense, income = _income, rows = _rows;

    return CustomScrollView(
      key: const PageStorageKey<String>('home-scroll'),
      cacheExtent: 300,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '拾光账本',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(fontSize: 34),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '记录生活 · 让美好发生',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(letterSpacing: 1.2),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showSearch(context, store),
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.76),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context)
                                  .dividerColor
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                          child: const Icon(Icons.search_rounded, size: 26),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              MonthSwitcher(
                month: _month,
                onPrevious: () => _moveMonth(-1),
                onNext: () => _moveMonth(1),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: _isCurrentMonth
                    ? const SizedBox(key: ValueKey('current'), height: 16)
                    : Padding(
                        key: const ValueKey('return'),
                        padding: const EdgeInsets.only(top: 10, bottom: 6),
                        child: Center(
                          child: _ReturnChip(
                            label: '回到本月',
                            onTap: _returnToCurrentMonth,
                          ),
                        ),
                      ),
              ),
              WarmCard(
                padding: const EdgeInsets.fromLTRB(18, 19, 18, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryCell(
                        label: '${_month.month}月支出',
                        value: store.displayMoney(expense),
                        color: null,
                      ),
                    ),
                    _divider(context),
                    Expanded(
                      child: _SummaryCell(
                        label: '收入',
                        value: store.displayMoney(income),
                        color: AppPalette.mint,
                      ),
                    ),
                    _divider(context),
                    Expanded(
                      child: _SummaryCell(
                        label: '结余',
                        value: _balanceText(store, income - expense),
                        color: income - expense < 0
                            ? const Color(0xFFD95B67)
                            : AppPalette.primaryDeep,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
            ]),
          ),
        ),
        if (items.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 124),
            sliver: SliverToBoxAdapter(child: _EmptyMonth(month: _month)),
          )
        else ...[
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
            sliver: SliverToBoxAdapter(
              child: SectionTitle(title: '账单明细'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 124),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final row = rows[index];
                  final entry = row.entry;
                  if (entry == null) {
                    final date = row.date;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
                      child: Row(children: [
                        Expanded(child: Text(
                          '${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日  ${_weekday(date.weekday)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        )),
                        if (row.expense > 0) Text(
                          '支出 ${store.displayMoney(row.expense)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ]),
                    );
                  }
                  return DecoratedBox(
                    key: ValueKey(entry.id),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.vertical(
                        top: row.first ? const Radius.circular(20) : Radius.zero,
                        bottom: row.last ? const Radius.circular(20) : Radius.zero,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(children: [
                        EntryRow(
                          entry: entry,
                          amountText: _amountText(store, entry),
                          onCategoryTap: () => _editCategory(context, store, entry),
                          onContentTap: () => _editNote(context, store, entry),
                          onAmountTapAt: (position) =>
                              _editAmountPopover(context, store, entry, position),
                          onLongPress: () => _showEntryActions(context, store, entry),
                        ),
                        if (!row.last) Divider(
                          height: 1, indent: 60,
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
                        ),
                      ]),
                    ),
                  );
                },
                childCount: rows.length,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _amountText(AppStore store, LedgerEntry entry) {
    if (entry.isIncome) return store.displayMoney(entry.amount, signed: true);
    if (store.hideAmounts) return '••••';
    return '-${store.displayMoney(entry.amount)}';
  }

  Widget _divider(BuildContext context) => Container(
        width: 1,
        height: 54,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: Theme.of(context).dividerColor,
      );

  Map<String, List<LedgerEntry>> _groupByDay(List<LedgerEntry> items) {
    final map = <String, List<LedgerEntry>>{};
    for (final item in items) {
      final key = '${item.date.year}-${item.date.month}-${item.date.day}';
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }

  List<String> _recentCategories(AppStore store, bool income) {
    final seen = <String>{};
    final result = <String>[];
    for (final entry in store.entries) {
      if (entry.isIncome != income || !seen.add(entry.category)) continue;
      result.add(entry.category);
      if (result.length >= 6) break;
    }
    return result;
  }

  Future<void> _editCategory(
    BuildContext context,
    AppStore store,
    LedgerEntry entry,
  ) async {
    HapticFeedback.selectionClick();
    final categories = entry.isIncome ? incomeCategories : expenseCategories;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.74,
        child: _CategoryPickerSheet(
          categories: categories,
          current: entry.category,
          recent: _recentCategories(store, entry.isIncome),
          income: entry.isIncome,
        ),
      ),
    );
    if (selected == null || selected == entry.category) return;
    store.updateEntry(entry.id, category: selected);
    HapticFeedback.lightImpact();
  }

  Future<void> _editNote(
    BuildContext context,
    AppStore store,
    LedgerEntry entry,
  ) async {
    HapticFeedback.selectionClick();
    final initial = entry.note.isNotEmpty ? entry.note : entry.title;
    final value = await showNotePicker(context, loadCatalog: store.loadNoteCatalog,
      income: entry.isIncome, category: entry.category, initial: initial);
    if (value == null) return;
    final clean = value.trim();
    store.updateEntry(
      entry.id,
      title: clean.isEmpty ? entry.category : clean,
      note: clean,
    );
    HapticFeedback.lightImpact();
  }

  Future<void> _editAmountPopover(
    BuildContext context,
    AppStore store,
    LedgerEntry entry,
    Offset anchor,
  ) async {
    HapticFeedback.selectionClick();
    final value = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭金额编辑',
      barrierColor: Colors.black.withValues(alpha: 0.16),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final size = MediaQuery.sizeOf(dialogContext);
        final padding = MediaQuery.paddingOf(dialogContext);
        final width = (size.width - 28).clamp(286.0, 332.0).toDouble();
        const cardHeight = 414.0;
        final minTop = padding.top + 8;
        final maxTop = size.height - padding.bottom - cardHeight - 8;
        final preferredTop = anchor.dy < size.height * 0.55
            ? anchor.dy + 10
            : anchor.dy - cardHeight - 10;
        final top = maxTop <= minTop
            ? minTop
            : preferredTop.clamp(minTop, maxTop).toDouble();
        final maxLeft = size.width - width - 14;
        final left = (anchor.dx - width + 50)
            .clamp(14.0, maxLeft < 14 ? 14.0 : maxLeft)
            .toDouble();
        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                width: width,
                child: _AmountQuickEditor(
                  initial: _trimAmount(entry.amount),
                  isIncome: entry.isIncome,
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.97, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
    if (value == null) return;
    final amount = double.tryParse(value);
    if (amount == null || amount <= 0) return;
    store.updateEntry(entry.id, amount: amount);
    HapticFeedback.lightImpact();
  }

  Future<void> _showEntryActions(
    BuildContext context,
    AppStore store,
    LedgerEntry entry,
  ) async {
    HapticFeedback.mediumImpact();
    final action = await showModalBottomSheet<_EntryAction>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Row(
                  children: [
                    CategoryAvatar(category: entry.category, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.note.isEmpty ? entry.title : entry.note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${entry.category} · ${store.displayMoney(entry.amount)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _EntryActionTile(
                icon: Icons.category_rounded,
                label: '修改分类',
                onTap: () => Navigator.of(sheetContext)
                    .pop(_EntryAction.category),
              ),
              _EntryActionTile(
                icon: Icons.edit_note_rounded,
                label: '修改名称 / 备注',
                onTap: () => Navigator.of(sheetContext).pop(_EntryAction.note),
              ),
              _EntryActionTile(
                icon: Icons.payments_outlined,
                label: '修改金额',
                onTap: () => Navigator.of(sheetContext)
                    .pop(_EntryAction.amount),
              ),
              _EntryActionTile(
                icon: Icons.info_outline_rounded,
                label: '查看完整记录',
                onTap: () => Navigator.of(sheetContext)
                    .pop(_EntryAction.detail),
              ),
              Divider(color: Theme.of(context).dividerColor),
              _EntryActionTile(
                icon: Icons.delete_outline_rounded,
                label: '删除记录',
                danger: true,
                onTap: () => Navigator.of(sheetContext)
                    .pop(_EntryAction.delete),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case _EntryAction.category:
        await _editCategory(context, store, entry);
        break;
      case _EntryAction.note:
        await _editNote(context, store, entry);
        break;
      case _EntryAction.amount:
        final size = MediaQuery.sizeOf(context);
        await _editAmountPopover(
          context,
          store,
          entry,
          Offset(size.width - 42, size.height * 0.42),
        );
        break;
      case _EntryAction.detail:
        await _showEntryDetail(context, store, entry);
        break;
      case _EntryAction.delete:
        await _confirmDelete(context, store, entry);
        break;
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppStore store,
    LedgerEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这笔记录？'),
        content: Text(
          '“${entry.note.isEmpty ? entry.title : entry.note}” 删除后无法撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppPalette.danger),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    store.deleteEntry(entry.id);
    HapticFeedback.heavyImpact();
  }

  Future<void> _showEntryDetail(
    BuildContext context,
    AppStore store,
    LedgerEntry entry,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CategoryAvatar(category: entry.category, size: 62),
            const SizedBox(height: 12),
            Text(
              entry.note.isEmpty ? entry.title : entry.note,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '${entry.category} · ${entry.isIncome ? '收入' : '支出'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              store.displayMoney(entry.amount),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: entry.isIncome ? AppPalette.mint : null,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${entry.date.year}/${entry.date.month}/${entry.date.day} ${entry.date.hour.toString().padLeft(2, '0')}:${entry.date.minute.toString().padLeft(2, '0')}',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSearch(BuildContext context, AppStore store) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _SearchSheet(store: store),
    );
  }
}

enum _EntryAction { category, note, amount, detail, delete }

class _ReturnChip extends StatelessWidget {
  const _ReturnChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppPalette.primarySoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.my_location_rounded,
              size: 17,
              color: AppPalette.primaryDeep,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppPalette.primaryDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    required this.categories,
    required this.current,
    required this.recent,
    required this.income,
  });

  final List<String> categories;
  final String current;
  final List<String> recent;
  final bool income;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.categories
        .where((category) => category.contains(_query.trim()))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '修改分类',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                widget.income ? '收入' : '支出',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: '搜索分类',
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (_query.isEmpty && widget.recent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
            child: Text(
              '最近使用',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              itemCount: widget.recent.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = widget.recent[index];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(category),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 82),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: category == widget.current
                          ? colorForCategory(category).withValues(alpha: 0.18)
                          : Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emojiForCategory(category)),
                        const SizedBox(width: 7),
                        Text(
                          category,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Text(
            _query.isEmpty ? '全部分类' : '搜索结果',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    '没有找到分类',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisExtent: 82,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemBuilder: (context, index) {
                    final category = filtered[index];
                    final selected = category == widget.current;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(category),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CategoryAvatar(
                            category: category,
                            size: 48,
                            selected: selected,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: selected
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              color: selected
                                  ? colorForCategory(category)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}


class _AmountQuickEditor extends StatefulWidget {
  const _AmountQuickEditor({
    required this.initial,
    required this.isIncome,
  });

  final String initial;
  final bool isIncome;

  @override
  State<_AmountQuickEditor> createState() => _AmountQuickEditorState();
}

class _AmountQuickEditorState extends State<_AmountQuickEditor> {
  late String _value;
  bool _replaceOnNextInput = true;

  @override
  void initState() {
    super.initState();
    _value = widget.initial.isEmpty ? '0' : widget.initial;
  }

  void _press(String key) {
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
  Widget build(BuildContext context) {
    final accent = widget.isIncome ? AppPalette.mint : AppPalette.primary;
    final amount = double.tryParse(_value) ?? 0;
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫'];
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 414,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '快捷修改金额',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                '¥ $_value',
                textAlign: TextAlign.right,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  color: widget.isIncome ? AppPalette.mint : null,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: keys.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 7,
                  crossAxisSpacing: 7,
                  childAspectRatio: 1.85,
                ),
                itemBuilder: (context, index) {
                  final key = keys[index];
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _press(key),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: key == '⌫'
                            ? accent.withValues(alpha: 0.10)
                            : Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: key == '⌫'
                          ? const Icon(Icons.backspace_outlined, size: 21)
                          : Text(
                              key,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: amount > 0
                    ? () => Navigator.of(context).pop(_value)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: widget.isIncome ? Colors.white : AppPalette.ink,
                ),
                child: const Text(
                  '保存金额',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryActionTile extends StatelessWidget {
  const _EntryActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? AppPalette.danger
        : Theme.of(context).textTheme.bodyLarge?.color;
    return ListTile(
      minTileHeight: 58,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w800, color: color),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: color),
      onTap: onTap,
    );
  }
}

String _trimAmount(double value) =>
    value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

String _balanceText(AppStore store, double value) {
  if (store.hideAmounts) return '••••';
  if (value < 0) return '-${store.displayMoney(value.abs())}';
  return store.displayMoney(value);
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyMonth extends StatelessWidget {
  const _EmptyMonth({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 62),
      child: Column(
        children: [
          Container(
            width: 118,
            height: 118,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppPalette.primarySoft,
                  AppPalette.primary.withValues(alpha: 0.08),
                ],
              ),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 50,
              color: AppPalette.primary,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            '${month.month}月还没有账单',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 7),
          Text(
            '点击下方 + 开始记录',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _SearchSheet extends StatefulWidget {
  const _SearchSheet({required this.store});
  final AppStore store;

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim().toLowerCase();
    final results = widget.store.entries.where((entry) {
      if (query.isEmpty) return true;
      return entry.category.toLowerCase().contains(query) ||
          entry.title.toLowerCase().contains(query) ||
          entry.note.toLowerCase().contains(query);
    }).take(40).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: '搜索分类、备注或账单名称',
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        '没有找到相关账单',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  : ListView.separated(
                      cacheExtent: 520,
                      physics: const BouncingScrollPhysics(),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => Divider(
                        indent: 60,
                        color: Theme.of(context).dividerColor,
                      ),
                      itemBuilder: (_, index) {
                        final entry = results[index];
                        return EntryRow(
                          entry: entry,
                          amountText: entry.isIncome
                              ? widget.store.displayMoney(
                                  entry.amount,
                                  signed: true,
                                )
                              : widget.store.hideAmounts
                                  ? '••••'
                                  : '-${widget.store.displayMoney(entry.amount)}',
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String _weekday(int weekday) {
  const names = [
    '星期一',
    '星期二',
    '星期三',
    '星期四',
    '星期五',
    '星期六',
    '星期日',
  ];
  return names[weekday - 1];
}



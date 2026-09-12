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

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final items = store.entriesForMonth(_month);
    final expense = store.expenseForMonth(_month);
    final income = store.incomeForMonth(_month);
    final groups = _groupByDay(items);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 124),
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
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 34),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '记录生活 · 让美好发生',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: 1.2),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showSearch(context, store),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.8)),
                      ),
                      child: const Icon(Icons.search_rounded, size: 27),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              MonthSwitcher(
                month: _month,
                onPrevious: () => _moveMonth(-1),
                onNext: () => _moveMonth(1),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: _isCurrentMonth
                    ? const SizedBox(height: 16)
                    : Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              final now = DateTime.now();
                              setState(() => _month = DateTime(now.year, now.month));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppPalette.primarySoft,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_month_rounded, size: 17, color: AppPalette.primaryDeep),
                                  SizedBox(width: 7),
                                  Text('回到本月', style: TextStyle(fontWeight: FontWeight.w800, color: AppPalette.primaryDeep)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              WarmCard(
                padding: const EdgeInsets.fromLTRB(18, 19, 18, 18),
                child: Row(
                  children: [
                    Expanded(child: _SummaryCell(label: '${_month.month}月支出', value: store.displayMoney(expense), color: null)),
                    _divider(context),
                    Expanded(child: _SummaryCell(label: '收入', value: store.displayMoney(income), color: AppPalette.mint)),
                    _divider(context),
                    Expanded(child: _SummaryCell(label: '结余', value: store.displayMoney(income - expense), color: AppPalette.primaryDeep)),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              if (items.isEmpty)
                _EmptyMonth(month: _month)
              else ...[
                const SectionTitle(title: '账单明细'),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: Column(
                    key: ValueKey('${_month.year}-${_month.month}-${items.length}'),
                    children: groups.entries.map((group) {
                      final dayItems = group.value;
                      final date = dayItems.first.date;
                      final dayExpense = dayItems.where((e) => !e.isIncome).fold<double>(0, (sum, e) => sum + e.amount);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日  ${_weekday(date.weekday)}',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  if (dayExpense > 0)
                                    Text(
                                      '支出 ${store.displayMoney(dayExpense)}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                            WarmCard(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              child: Column(
                                children: [
                                  for (var i = 0; i < dayItems.length; i++) ...[
                                    EntryRow(
                                      key: ValueKey(dayItems[i].id),
                                      entry: dayItems[i],
                                      amountText: dayItems[i].isIncome
                                          ? store.displayMoney(dayItems[i].amount, signed: true)
                                          : store.hideAmounts
                                              ? '••••'
                                              : '-${store.displayMoney(dayItems[i].amount)}',
                                      onCategoryTap: () => _editCategory(context, store, dayItems[i]),
                                      onContentTap: () => _editName(context, store, dayItems[i]),
                                      onAmountTap: () => _editAmount(context, store, dayItems[i]),
                                      onLongPress: () => _showEntryActions(context, store, dayItems[i]),
                                    ),
                                    if (i != dayItems.length - 1)
                                      Divider(height: 1, indent: 58, color: Theme.of(context).dividerColor),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ],
    );
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

  Future<void> _editCategory(BuildContext context, AppStore store, LedgerEntry entry) async {
    HapticFeedback.selectionClick();
    final categories = entry.isIncome ? incomeCategories : expenseCategories;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.68,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: [
                    Expanded(child: Text('修改分类', style: Theme.of(context).textTheme.titleLarge)),
                    Text(entry.isIncome ? '收入' : '支出', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: categories.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisExtent: 80,
                    crossAxisSpacing: 5,
                    mainAxisSpacing: 5,
                  ),
                  itemBuilder: (_, index) {
                    final category = categories[index];
                    final selected = category == entry.category;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(sheetContext).pop(category),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CategoryAvatar(category: category, size: 49, selected: selected),
                          const SizedBox(height: 5),
                          Text(
                            category,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                              color: selected ? colorForCategory(category) : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || selected == entry.category) return;
    store.updateEntry(entry.id, category: selected);
    HapticFeedback.lightImpact();
  }

  Future<void> _editName(BuildContext context, AppStore store, LedgerEntry entry) async {
    HapticFeedback.selectionClick();
    final initial = entry.note.isNotEmpty ? entry.note : entry.title;
    final controller = TextEditingController(text: initial);
    controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('修改名称 / 备注', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('这里的内容也会写入 CSV 的“备注”列', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              maxLength: 80,
              onSubmitted: (value) => Navigator.of(sheetContext).pop(value),
              decoration: InputDecoration(
                hintText: '例如：小象买菜、地铁卡充值…',
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(controller.text),
                style: FilledButton.styleFrom(backgroundColor: AppPalette.primary, foregroundColor: AppPalette.ink),
                child: const Text('保存修改', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value == null) return;
    final clean = value.trim();
    store.updateEntry(entry.id, title: clean.isEmpty ? entry.category : clean, note: clean);
    HapticFeedback.lightImpact();
  }

  Future<void> _editAmount(BuildContext context, AppStore store, LedgerEntry entry) async {
    HapticFeedback.selectionClick();
    final controller = TextEditingController(text: _trimAmount(entry.amount));
    controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('修改金额', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              onSubmitted: (value) => Navigator.of(sheetContext).pop(value),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                prefixText: '¥ ',
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(controller.text),
                style: FilledButton.styleFrom(backgroundColor: AppPalette.primary, foregroundColor: AppPalette.ink),
                child: const Text('保存金额', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value == null) return;
    final amount = double.tryParse(value.trim());
    if (amount == null || amount <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入大于 0 的有效金额')));
      }
      return;
    }
    store.updateEntry(entry.id, amount: amount);
    HapticFeedback.lightImpact();
  }

  Future<void> _showEntryActions(BuildContext context, AppStore store, LedgerEntry entry) async {
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
                          Text(entry.note.isEmpty ? entry.title : entry.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text('${entry.category} · ${store.displayMoney(entry.amount)}', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _EntryActionTile(icon: Icons.category_rounded, label: '修改分类', onTap: () => Navigator.of(sheetContext).pop(_EntryAction.category)),
              _EntryActionTile(icon: Icons.edit_note_rounded, label: '修改名称 / 备注', onTap: () => Navigator.of(sheetContext).pop(_EntryAction.name)),
              _EntryActionTile(icon: Icons.payments_outlined, label: '修改金额', onTap: () => Navigator.of(sheetContext).pop(_EntryAction.amount)),
              _EntryActionTile(icon: Icons.info_outline_rounded, label: '查看完整记录', onTap: () => Navigator.of(sheetContext).pop(_EntryAction.detail)),
              Divider(color: Theme.of(context).dividerColor),
              _EntryActionTile(icon: Icons.delete_outline_rounded, label: '删除记录', danger: true, onTap: () => Navigator.of(sheetContext).pop(_EntryAction.delete)),
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
      case _EntryAction.name:
        await _editName(context, store, entry);
        break;
      case _EntryAction.amount:
        await _editAmount(context, store, entry);
        break;
      case _EntryAction.detail:
        await _showEntryDetail(context, store, entry);
        break;
      case _EntryAction.delete:
        await _confirmDelete(context, store, entry);
        break;
    }
  }

  Future<void> _confirmDelete(BuildContext context, AppStore store, LedgerEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这笔记录？'),
        content: Text('“${entry.note.isEmpty ? entry.title : entry.note}” 删除后无法撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('取消')),
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

  Future<void> _showEntryDetail(BuildContext context, AppStore store, LedgerEntry entry) async {
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
            Text(entry.note.isEmpty ? entry.title : entry.note, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('${entry.category} · ${entry.isIncome ? '收入' : '支出'}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Text(
              store.displayMoney(entry.amount),
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: entry.isIncome ? AppPalette.mint : null),
            ),
            const SizedBox(height: 12),
            Text('${entry.date.year}/${entry.date.month}/${entry.date.day} ${entry.date.hour.toString().padLeft(2, '0')}:${entry.date.minute.toString().padLeft(2, '0')}'),
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

enum _EntryAction { category, name, amount, detail, delete }

class _EntryActionTile extends StatelessWidget {
  const _EntryActionTile({required this.icon, required this.label, required this.onTap, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppPalette.danger : Theme.of(context).textTheme.bodyLarge?.color;
    return ListTile(
      minTileHeight: 56,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
      trailing: Icon(Icons.chevron_right_rounded, color: color),
      onTap: onTap,
    );
  }
}

String _trimAmount(double value) => value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12)),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.6, color: color),
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
                colors: [AppPalette.primarySoft, AppPalette.primary.withValues(alpha: 0.08)],
              ),
            ),
            child: const Icon(Icons.inventory_2_outlined, size: 50, color: AppPalette.primary),
          ),
          const SizedBox(height: 22),
          Text('${month.month}月还没有账单', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 7),
          Text('点击下方 + 开始记录', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 14)),
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
    }).take(30).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.viewInsetsOf(context).bottom + 24),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: results.isEmpty
                  ? Center(child: Text('没有找到相关账单', style: Theme.of(context).textTheme.bodySmall))
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => Divider(indent: 58, color: Theme.of(context).dividerColor),
                      itemBuilder: (_, index) {
                        final entry = results[index];
                        return EntryRow(
                          entry: entry,
                          amountText: entry.isIncome
                              ? widget.store.displayMoney(entry.amount, signed: true)
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
  const names = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
  return names[weekday - 1];
}

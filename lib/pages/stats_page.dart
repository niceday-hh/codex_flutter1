import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_store.dart';
import '../app_theme.dart';
import '../models.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  int _periodIndex = 1;
  bool _incomeMode = false;
  late DateTime _anchor;
  int _selectedPoint = 0;

  @override
  void initState() {
    super.initState();
    _anchor = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final range = _periodRange(_anchor, _periodIndex);
    final periodEntries = store.entries
        .where((entry) => _inRange(entry.date, range))
        .toList();
    final expense = periodEntries
        .where((entry) => !entry.isIncome)
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    final income = periodEntries
        .where((entry) => entry.isIncome)
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    final modeEntries = periodEntries
        .where((entry) => entry.isIncome == _incomeMode)
        .toList();
    final summaries = _categorySummary(modeEntries);
    final total = _incomeMode ? income : expense;
    final points = _buildPoints(range, modeEntries);
    final safeIndex = points.isEmpty
        ? 0
        : _selectedPoint.clamp(0, points.length - 1);
    final selected = points.isEmpty
        ? const _ReportPoint(label: '-', amount: 0, entries: [])
        : points[safeIndex];
    final current = _periodRange(DateTime.now(), _periodIndex);
    final isCurrent = _sameRange(range, current);

    return CustomScrollView(
      key: const PageStorageKey<String>('stats-scroll'),
      cacheExtent: 640,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 126),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text(
                '收支报表',
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(fontSize: 34),
              ),
              const SizedBox(height: 3),
              Text(
                '数字会记得生活的温度',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(letterSpacing: 1.2),
              ),
              const SizedBox(height: 22),
              PillTabs(
                labels: const ['周', '月', '季度', '年'],
                index: _periodIndex,
                onChanged: _changePeriod,
              ),
              const SizedBox(height: 14),
              _PeriodSwitcher(
                label: range.label,
                onPrevious: () => _movePeriod(-1),
                onNext: () => _movePeriod(1),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: isCurrent
                    ? const SizedBox(
                        key: ValueKey<String>('period-current'),
                        height: 14,
                      )
                    : Padding(
                        key: const ValueKey<String>('period-return'),
                        padding: const EdgeInsets.only(top: 9, bottom: 3),
                        child: Center(
                          child: _CurrentPeriodChip(
                            label: _returnLabel(_periodIndex),
                            onTap: _returnToCurrent,
                          ),
                        ),
                      ),
              ),
              PillTabs(
                labels: const ['支出分析', '收入分析'],
                index: _incomeMode ? 1 : 0,
                activeColor: _incomeMode ? AppPalette.mint : AppPalette.primary,
                onChanged: (index) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _incomeMode = index == 1;
                    _selectedPoint = 0;
                  });
                },
              ),
              const SizedBox(height: 16),
              WarmCard(
                child: Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: '支出',
                        value: store.displayMoney(expense),
                        color: null,
                      ),
                    ),
                    _metricDivider(context),
                    Expanded(
                      child: _Metric(
                        label: '收入',
                        value: store.displayMoney(income),
                        color: AppPalette.mint,
                      ),
                    ),
                    _metricDivider(context),
                    Expanded(
                      child: _Metric(
                        label: '结余',
                        value: store.displayMoney(income - expense),
                        color: AppPalette.primaryDeep,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              WarmCard(
                padding: const EdgeInsets.fromLTRB(17, 17, 17, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: (_incomeMode
                                    ? AppPalette.mint
                                    : AppPalette.primary)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            _incomeMode
                                ? Icons.show_chart_rounded
                                : Icons.bar_chart_rounded,
                            color: _incomeMode
                                ? AppPalette.mint
                                : AppPalette.primaryDeep,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_incomeMode ? '收入' : '支出'}趋势',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '总额 ${store.displayMoney(total)} · ${_averageLabel(points, total)} · ${modeEntries.length}笔',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _periodName(_periodIndex),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    RepaintBoundary(
                      child: InteractiveTrendChart(
                        points: points
                            .map(
                              (point) => TrendPoint(
                                label: point.label,
                                amount: point.amount,
                              ),
                            )
                            .toList(),
                        selectedIndex: safeIndex,
                        onSelected: (index) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedPoint = index);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    _NodeDetailCard(
                      point: selected,
                      store: store,
                      incomeMode: _incomeMode,
                      onOpenAll: () => _showEntriesSheet(
                        context,
                        selected.entries,
                        store,
                        '${selected.label} · ${store.displayMoney(selected.amount)}',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              WarmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(title: '${_incomeMode ? '收入' : '支出'}构成'),
                    const SizedBox(height: 16),
                    if (summaries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            '当前周期暂无分类数据',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          RepaintBoundary(
                            child: DonutChart(
                              items: summaries,
                              total: total,
                              centerLabel: _incomeMode ? '总收入' : '总支出',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              children: summaries
                                  .take(5)
                                  .map(
                                    (item) => _CompositionRow(
                                      item: item,
                                      total: total,
                                      onTap: () => _openCategory(
                                        context,
                                        item.name,
                                        modeEntries,
                                        store,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              WarmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(title: '${_incomeMode ? '收入' : '支出'}排行榜'),
                    const SizedBox(height: 8),
                    if (summaries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        child: Center(
                          child: Text(
                            '当前周期还没有数据',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      )
                    else
                      for (var i = 0; i < summaries.length; i++) ...[
                        _RankingRow(
                          rank: i + 1,
                          item: summaries[i],
                          max: summaries.first.amount,
                          amountText: store.displayMoney(summaries[i].amount),
                          onTap: () => _openCategory(
                            context,
                            summaries[i].name,
                            modeEntries,
                            store,
                          ),
                        ),
                        if (i != summaries.length - 1)
                          const SizedBox(height: 4),
                      ],
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  void _changePeriod(int index) {
    if (index == _periodIndex) return;
    HapticFeedback.selectionClick();
    setState(() {
      _periodIndex = index;
      _selectedPoint = 0;
    });
  }

  void _movePeriod(int offset) {
    HapticFeedback.selectionClick();
    setState(() {
      switch (_periodIndex) {
        case 0:
          _anchor = _anchor.add(Duration(days: 7 * offset));
          break;
        case 1:
          _anchor = DateTime(_anchor.year, _anchor.month + offset, 1);
          break;
        case 2:
          _anchor = DateTime(_anchor.year, _anchor.month + 3 * offset, 1);
          break;
        case 3:
          _anchor = DateTime(_anchor.year + offset, _anchor.month, 1);
          break;
      }
      _selectedPoint = 0;
    });
  }

  void _returnToCurrent() {
    HapticFeedback.selectionClick();
    setState(() {
      _anchor = DateTime.now();
      _selectedPoint = 0;
    });
  }

  _PeriodRange _periodRange(DateTime anchor, int periodIndex) {
    final day = DateTime(anchor.year, anchor.month, anchor.day);
    switch (periodIndex) {
      case 0:
        final start = day.subtract(Duration(days: day.weekday - 1));
        final end = start.add(const Duration(days: 7));
        final inclusiveEnd = end.subtract(const Duration(days: 1));
        final yearPrefix = start.year == inclusiveEnd.year
            ? '${start.year}年 '
            : '${start.year}年';
        return _PeriodRange(
          start: start,
          end: end,
          label:
              '$yearPrefix${start.month}/${start.day} - ${inclusiveEnd.month}/${inclusiveEnd.day}',
        );
      case 1:
        final start = DateTime(anchor.year, anchor.month, 1);
        return _PeriodRange(
          start: start,
          end: DateTime(anchor.year, anchor.month + 1, 1),
          label: '${anchor.year}年 ${anchor.month}月',
        );
      case 2:
        final quarter = ((anchor.month - 1) ~/ 3) + 1;
        final startMonth = (quarter - 1) * 3 + 1;
        return _PeriodRange(
          start: DateTime(anchor.year, startMonth, 1),
          end: DateTime(anchor.year, startMonth + 3, 1),
          label: '${anchor.year}年 第$quarter季度',
        );
      default:
        return _PeriodRange(
          start: DateTime(anchor.year, 1, 1),
          end: DateTime(anchor.year + 1, 1, 1),
          label: '${anchor.year}年',
        );
    }
  }

  List<_ReportPoint> _buildPoints(
    _PeriodRange range,
    List<LedgerEntry> entries,
  ) {
    switch (_periodIndex) {
      case 0:
        return List.generate(7, (index) {
          final date = range.start.add(Duration(days: index));
          final list = entries.where((entry) => _sameDay(entry.date, date)).toList();
          return _ReportPoint(
            label: '${date.month}/${date.day}',
            amount: _sum(list),
            entries: list,
          );
        });
      case 1:
        final days = range.end.subtract(const Duration(days: 1)).day;
        return List.generate(days, (index) {
          final date = DateTime(range.start.year, range.start.month, index + 1);
          final list = entries.where((entry) => _sameDay(entry.date, date)).toList();
          return _ReportPoint(
            label: '${index + 1}日',
            amount: _sum(list),
            entries: list,
          );
        });
      case 2:
        return List.generate(3, (index) {
          final month = range.start.month + index;
          final list = entries
              .where(
                (entry) =>
                    entry.date.year == range.start.year &&
                    entry.date.month == month,
              )
              .toList();
          return _ReportPoint(
            label: '$month月',
            amount: _sum(list),
            entries: list,
          );
        });
      default:
        return List.generate(12, (index) {
          final month = index + 1;
          final list = entries
              .where(
                (entry) =>
                    entry.date.year == range.start.year &&
                    entry.date.month == month,
              )
              .toList();
          return _ReportPoint(
            label: '$month月',
            amount: _sum(list),
            entries: list,
          );
        });
    }
  }

  List<CategorySummary> _categorySummary(List<LedgerEntry> entries) {
    final amounts = <String, double>{};
    final counts = <String, int>{};
    for (final entry in entries) {
      amounts[entry.category] = (amounts[entry.category] ?? 0) + entry.amount;
      counts[entry.category] = (counts[entry.category] ?? 0) + 1;
    }
    final summaries = amounts.entries
        .map(
          (item) => CategorySummary(
            item.key,
            item.value,
            counts[item.key] ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return summaries;
  }

  Future<void> _openCategory(
    BuildContext context,
    String category,
    List<LedgerEntry> entries,
    AppStore store,
  ) async {
    final matching = entries
        .where((entry) => entry.category == category)
        .toList();
    await _showEntriesSheet(
      context,
      matching,
      store,
      '$category · ${_incomeMode ? '收入' : '支出'}明细',
    );
  }

  Future<void> _showEntriesSheet(
    BuildContext context,
    List<LedgerEntry> entries,
    AppStore store,
    String title,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.74,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${entries.length} 笔',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Text(
                          '当前节点暂无明细',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                    : ListView.separated(
                        cacheExtent: 520,
                        physics: const BouncingScrollPhysics(),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => Divider(
                          indent: 60,
                          color: Theme.of(context).dividerColor,
                        ),
                        itemBuilder: (_, index) {
                          final entry = entries[index];
                          return EntryRow(
                            entry: entry,
                            amountText: entry.isIncome
                                ? store.displayMoney(entry.amount, signed: true)
                                : store.hideAmounts
                                    ? '••••'
                                    : '-${store.displayMoney(entry.amount)}',
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _inRange(DateTime value, _PeriodRange range) =>
      !value.isBefore(range.start) && value.isBefore(range.end);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _sameRange(_PeriodRange a, _PeriodRange b) =>
      a.start == b.start && a.end == b.end;

  static double _sum(List<LedgerEntry> entries) =>
      entries.fold(0, (sum, entry) => sum + entry.amount);

  String _averageLabel(List<_ReportPoint> points, double total) {
    if (points.isEmpty) return '均值 ¥0';
    return '均值 ¥${_trim(total / points.length)}';
  }

  static String _periodName(int index) => const ['周', '月', '季度', '年'][index];
  static String _returnLabel(int index) =>
      const ['回到本周', '回到本月', '回到本季度', '回到本年'][index];

  static String _trim(double value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  Widget _metricDivider(BuildContext context) => Container(
        width: 1,
        height: 58,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: Theme.of(context).dividerColor,
      );
}

class _PeriodRange {
  const _PeriodRange({
    required this.start,
    required this.end,
    required this.label,
  });
  final DateTime start;
  final DateTime end;
  final String label;
}

class _ReportPoint {
  const _ReportPoint({
    required this.label,
    required this.amount,
    required this.entries,
  });
  final String label;
  final double amount;
  final List<LedgerEntry> entries;
}

class _PeriodSwitcher extends StatelessWidget {
  const _PeriodSwitcher({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PeriodArrow(
          icon: Icons.chevron_left_rounded,
          onTap: onPrevious,
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              label,
              key: ValueKey(label),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontSize: 19),
            ),
          ),
        ),
        _PeriodArrow(
          icon: Icons.chevron_right_rounded,
          onTap: onNext,
        ),
      ],
    );
  }
}

class _PeriodArrow extends StatelessWidget {
  const _PeriodArrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 50,
        height: 50,
        child: Center(
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.76),
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Icon(icon, size: 26),
          ),
        ),
      ),
    );
  }
}

class _CurrentPeriodChip extends StatelessWidget {
  const _CurrentPeriodChip({required this.label, required this.onTap});
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

class _Metric extends StatelessWidget {
  const _Metric({
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
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _NodeDetailCard extends StatelessWidget {
  const _NodeDetailCard({
    required this.point,
    required this.store,
    required this.incomeMode,
    required this.onOpenAll,
  });

  final _ReportPoint point;
  final AppStore store;
  final bool incomeMode;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final accent = incomeMode ? AppPalette.mint : AppPalette.primary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpenAll,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accent.withValues(alpha: 0.16),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${point.label} · ${store.displayMoney(point.amount)}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  '${point.entries.length}笔',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
            if (point.entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '这个节点暂无记录',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              )
            else
              for (final entry in point.entries.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Row(
                    children: [
                      Text(emojiForCategory(entry.category)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.note.isEmpty ? entry.title : entry.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        store.displayMoney(entry.amount),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: entry.isIncome ? AppPalette.mint : null,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _CompositionRow extends StatelessWidget {
  const _CompositionRow({
    required this.item,
    required this.total,
    required this.onTap,
  });

  final CategorySummary item;
  final double total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = total <= 0 ? 0.0 : item.amount / total;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorForCategory(item.name),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
            Text(
              '${(ratio * 100).round()}%',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.rank,
    required this.item,
    required this.max,
    required this.amountText,
    required this.onTap,
  });

  final int rank;
  final CategorySummary item;
  final double max;
  final String amountText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (item.amount / max).clamp(0.0, 1.0).toDouble();
    final color = colorForCategory(item.name);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: rank <= 3 ? AppPalette.primaryDeep : null,
                ),
              ),
            ),
            CategoryAvatar(category: item.name, size: 42),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        amountText,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 7,
                      backgroundColor: color.withValues(alpha: 0.10),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.count} 笔',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

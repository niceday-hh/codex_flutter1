import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_store.dart';
import '../insights/insight_panel.dart';
import '../app_theme.dart';
import '../models.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/report_donut.dart';

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
    final expenseEntries = periodEntries.where((entry) => !entry.isIncome).toList();
    final incomeEntries = periodEntries.where((entry) => entry.isIncome).toList();
    final expense = _sum(expenseEntries);
    final income = _sum(incomeEntries);
    final balance = income - expense;
    final modeEntries = _incomeMode ? incomeEntries : expenseEntries;
    final total = _incomeMode ? income : expense;
    final summaries = _categorySummary(modeEntries);
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
      key: const PageStorageKey<String>('stats-v23-scroll'),
      cacheExtent: 720,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 126),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _ReportHero(incomeMode: _incomeMode),
              const SizedBox(height: 16),
              PillTabs(
                labels: const ['周', '月', '季度', '年'],
                index: _periodIndex,
                onChanged: _changePeriod,
              ),
              const SizedBox(height: 13),
              _PeriodSwitcher(
                label: range.label,
                onPrevious: () => _movePeriod(-1),
                onNext: () => _movePeriod(1),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: isCurrent
                    ? const SizedBox(
                        key: ValueKey<String>('period-current'),
                        height: 12,
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
                padding: const EdgeInsets.fromLTRB(17, 18, 17, 17),
                child: Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: '支出',
                        value: store.displayMoney(expense),
                        hint: '共 ${expenseEntries.length} 笔',
                        color: null,
                      ),
                    ),
                    _metricDivider(context),
                    Expanded(
                      child: _Metric(
                        label: '收入',
                        value: store.displayMoney(income),
                        hint: '共 ${incomeEntries.length} 笔',
                        color: AppPalette.mint,
                      ),
                    ),
                    _metricDivider(context),
                    Expanded(
                      child: _Metric(
                        label: '结余',
                        value: _balanceText(store, balance),
                        hint: balance < 0 ? '本期支出超过收入' : '收支平衡 · 生活更好',
                        color: balance < 0
                            ? const Color(0xFFD95B67)
                            : AppPalette.primaryDeep,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 17),
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
                            color: (_incomeMode ? AppPalette.mint : AppPalette.primary)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            Icons.insights_rounded,
                            color: _incomeMode ? AppPalette.mint : AppPalette.primaryDeep,
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _resolutionLabel(),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    RepaintBoundary(
                      child: InteractiveTrendChart(
                        points: points
                            .map((point) => TrendPoint(
                                  label: point.label,
                                  amount: point.amount,
                                ))
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
              const SizedBox(height: 17),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 385;
                  final composition = _CompositionCard(
                    summaries: summaries,
                    total: total,
                    incomeMode: _incomeMode,
                    onTapCategory: (category) => _openCategory(
                      context,
                      category,
                      modeEntries,
                      store,
                    ),
                    compact: twoColumns,
                  );
                  final insight = InsightPanel(
                    start: range.start, end: range.end, income: _incomeMode,
                  );
                  if (!twoColumns) {
                    return Column(
                      children: [
                        composition,
                        const SizedBox(height: 14),
                        insight,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: composition),
                      const SizedBox(width: 12),
                      Expanded(child: insight),
                    ],
                  );
                },
              ),
              const SizedBox(height: 17),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 385;
                  final ranking = _RankingCard(
                    summaries: summaries,
                    total: total,
                    store: store,
                    compact: twoColumns,
                    onTapCategory: (category) => _openCategory(
                      context,
                      category,
                      modeEntries,
                      store,
                    ),
                  );
                  final heatmap = _HeatMapCard(
                    anchor: _anchor,
                    entries: _heatMapEntries(store),
                    compact: twoColumns,
                  );
                  if (!twoColumns) {
                    return Column(
                      children: [
                        ranking,
                        const SizedBox(height: 14),
                        heatmap,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: ranking),
                      const SizedBox(width: 12),
                      Expanded(child: heatmap),
                    ],
                  );
                },
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
        default:
          _anchor = DateTime(_anchor.year + offset, _anchor.month, 1);
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
        return _PeriodRange(
          start: start,
          end: end,
          label: '${start.year}年 ${start.month}/${start.day} - ${inclusiveEnd.month}/${inclusiveEnd.day}',
        );
      case 1:
        return _PeriodRange(
          start: DateTime(anchor.year, anchor.month, 1),
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

  List<_ReportPoint> _buildPoints(_PeriodRange range, List<LedgerEntry> entries) {
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
              .where((entry) =>
                  entry.date.year == range.start.year &&
                  entry.date.month == month)
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
              .where((entry) =>
                  entry.date.year == range.start.year &&
                  entry.date.month == month)
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
        .map((entry) => CategorySummary(
              entry.key,
              entry.value,
              counts[entry.key] ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return summaries;
  }

  List<LedgerEntry> _heatMapEntries(AppStore store) {
    final monthStart = DateTime(_anchor.year, _anchor.month, 1);
    final monthEnd = DateTime(_anchor.year, _anchor.month + 1, 1);
    return store.entries
        .where((entry) =>
            !entry.isIncome &&
            !entry.date.isBefore(monthStart) &&
            entry.date.isBefore(monthEnd))
        .toList();
  }

  Future<void> _openCategory(
    BuildContext context,
    String category,
    List<LedgerEntry> entries,
    AppStore store,
  ) async {
    final matching = entries.where((entry) => entry.category == category).toList();
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
                  Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
                  Text('${entries.length} 笔', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Text('当前节点暂无明细', style: Theme.of(context).textTheme.bodySmall),
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
    final active = points.where((point) => point.entries.isNotEmpty).length;
    if (active == 0) return '日均 ¥0';
    return '日均 ¥${_trim(total / active)}';
  }

  String _resolutionLabel() => _periodIndex <= 1 ? '日' : '月';

  static String _returnLabel(int index) =>
      const ['回到本周', '回到本月', '回到本季度', '回到本年'][index];

  static String _trim(double value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  String _balanceText(AppStore store, double value) {
    if (store.hideAmounts) return '••••';
    if (value < 0) return '-${store.displayMoney(value.abs())}';
    return store.displayMoney(value);
  }

  Widget _metricDivider(BuildContext context) => Container(
        width: 1,
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 9),
        color: Theme.of(context).dividerColor,
      );
}

class _ReportHero extends StatelessWidget {
  const _ReportHero({required this.incomeMode});
  final bool incomeMode;

  @override
  Widget build(BuildContext context) {
    return WarmCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(20, 21, 18, 19),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFFFF7EA),
          const Color(0xFFFFFBF5),
          (incomeMode ? AppPalette.mintSoft : AppPalette.primarySoft)
              .withValues(alpha: 0.82),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '报表',
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(fontSize: 35),
                ),
                const SizedBox(height: 4),
                Text(
                  '洞察你的收支节奏',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 15.5),
                ),
                const SizedBox(height: 11),
                Text(
                  '记录生活 · 让每一份支出更有意义',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            width: 82,
            height: 82,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: Colors.white.withValues(alpha: 0.72),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.primary.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Icon(
              Icons.auto_graph_rounded,
              size: 42,
              color: incomeMode ? AppPalette.mint : AppPalette.primaryDeep,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodRange {
  const _PeriodRange({required this.start, required this.end, required this.label});
  final DateTime start;
  final DateTime end;
  final String label;
}

class _ReportPoint {
  const _ReportPoint({required this.label, required this.amount, required this.entries});
  final String label;
  final double amount;
  final List<LedgerEntry> entries;
}

class _PeriodSwitcher extends StatelessWidget {
  const _PeriodSwitcher({required this.label, required this.onPrevious, required this.onNext});
  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PeriodArrow(icon: Icons.chevron_left_rounded, onTap: onPrevious),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 140),
            child: Text(
              label,
              key: ValueKey(label),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19),
            ),
          ),
        ),
        _PeriodArrow(icon: Icons.chevron_right_rounded, onTap: onNext),
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
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.80),
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
            const Icon(Icons.calendar_month_rounded, size: 17, color: AppPalette.primaryDeep),
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
  const _Metric({required this.label, required this.value, required this.hint, required this.color});
  final String label;
  final String value;
  final String hint;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12)),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hint,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5),
        ),
      ],
    );
  }
}

class _NodeDetailCard extends StatelessWidget {
  const _NodeDetailCard({required this.point, required this.store, required this.incomeMode, required this.onOpenAll});
  final _ReportPoint point;
  final AppStore store;
  final bool incomeMode;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final accent = incomeMode ? AppPalette.mint : AppPalette.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpenAll,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.16)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${point.label} · ${store.displayMoney(point.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text('${point.entries.length}笔', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
              if (point.entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('这个节点暂无记录', style: Theme.of(context).textTheme.bodySmall),
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
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
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
      ),
    );
  }
}

class _CompositionCard extends StatelessWidget {
  const _CompositionCard({
    required this.summaries,
    required this.total,
    required this.incomeMode,
    required this.onTapCategory,
    required this.compact,
  });

  final List<CategorySummary> summaries;
  final double total;
  final bool incomeMode;
  final ValueChanged<String> onTapCategory;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visible = summaries.take(compact ? 4 : 5).toList();
    return WarmCard(
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${incomeMode ? '收入' : '支出'}构成',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: compact ? 17 : 20),
          ),
          const SizedBox(height: 12),
          if (summaries.isEmpty)
            SizedBox(
              height: compact ? 230 : 180,
              child: Center(child: Text('暂无分类数据', style: Theme.of(context).textTheme.bodySmall)),
            )
          else ...[
            Center(
              child: RepaintBoundary(
                child: ReportDonutChart(
                  items: summaries,
                  total: total,
                  size: compact ? 116 : 144,
                  centerLabel: incomeMode ? '本期收入' : '本期支出',
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < visible.length; index++)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onTapCategory(visible[index].name),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: reportPaletteColor(index),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            visible[index].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ),
                        Text(
                          '${total <= 0 ? 0 : (visible[index].amount / total * 100).round()}%',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}


class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.summaries,
    required this.total,
    required this.store,
    required this.compact,
    required this.onTapCategory,
  });

  final List<CategorySummary> summaries;
  final double total;
  final AppStore store;
  final bool compact;
  final ValueChanged<String> onTapCategory;

  @override
  Widget build(BuildContext context) {
    final visible = summaries.take(compact ? 5 : summaries.length).toList();
    return WarmCard(
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '支出排行榜',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: compact ? 17 : 20),
          ),
          const SizedBox(height: 8),
          if (visible.isEmpty)
            SizedBox(
              height: compact ? 225 : 150,
              child: Center(child: Text('当前周期暂无数据', style: Theme.of(context).textTheme.bodySmall)),
            )
          else
            for (var index = 0; index < visible.length; index++)
              _RankingRow(
                rank: index + 1,
                item: visible[index],
                total: total,
                max: visible.first.amount,
                amountText: store.displayMoney(visible[index].amount),
                compact: compact,
                onTap: () => onTapCategory(visible[index].name),
              ),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.rank,
    required this.item,
    required this.total,
    required this.max,
    required this.amountText,
    required this.compact,
    required this.onTap,
  });

  final int rank;
  final CategorySummary item;
  final double total;
  final double max;
  final String amountText;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (item.amount / max).clamp(0.0, 1.0).toDouble();
    final share = total <= 0 ? 0 : (item.amount / total * 100).round();
    final accent = reportPaletteColor(rank - 1);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 7 : 9, horizontal: 2),
          child: Row(
            children: [
              SizedBox(
                width: compact ? 22 : 28,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 11 : 13,
                    color: rank <= 3 ? accent : Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ),
              CategoryAvatar(category: item.name, size: compact ? 31 : 41),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: compact ? 11.5 : 13.5),
                          ),
                        ),
                        if (!compact)
                          Text(amountText, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: compact ? 5 : 6,
                        backgroundColor: accent.withValues(alpha: 0.10),
                        valueColor: AlwaysStoppedAnimation(accent),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text('$share%', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9.5, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        Text('${item.count}笔', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeatMapCard extends StatelessWidget {
  const _HeatMapCard({required this.anchor, required this.entries, required this.compact});
  final DateTime anchor;
  final List<LedgerEntry> entries;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final monthDays = DateTime(anchor.year, anchor.month + 1, 0).day;
    final startWeekday = DateTime(anchor.year, anchor.month, 1).weekday;
    final amounts = <int, double>{};
    for (final entry in entries) {
      amounts[entry.date.day] = (amounts[entry.date.day] ?? 0) + entry.amount;
    }
    final maxAmount = amounts.values.fold<double>(0, (maxValue, value) => value > maxValue ? value : maxValue);

    return WarmCard(
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '收支日历热力',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: compact ? 17 : 20),
          ),
          const SizedBox(height: 11),
          Row(
            children: const ['一', '二', '三', '四', '五', '六', '日']
                .map((label) => Expanded(
                      child: Center(
                        child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: compact ? 26 : 34,
              crossAxisSpacing: compact ? 3 : 5,
              mainAxisSpacing: compact ? 3 : 5,
            ),
            itemBuilder: (context, index) {
              final day = index - startWeekday + 2;
              if (day <= 0 || day > monthDays) return const SizedBox.shrink();
              final amount = amounts[day] ?? 0;
              final intensity = maxAmount <= 0 ? 0.0 : (amount / maxAmount).clamp(0.0, 1.0).toDouble();
              final background = amount <= 0
                  ? Theme.of(context).scaffoldBackgroundColor
                  : Color.lerp(const Color(0xFFFFF0D8), AppPalette.primary, intensity)!;
              return Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(compact ? 8 : 10),
                ),
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: compact ? 9.5 : 11,
                    fontWeight: FontWeight.w800,
                    color: intensity > 0.58 ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('支出较少', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9.5)),
              const Spacer(),
              ...List.generate(5, (index) {
                final intensity = index / 4;
                return Container(
                  width: compact ? 8 : 11,
                  height: compact ? 8 : 11,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: Color.lerp(const Color(0xFFFFF0D8), AppPalette.primary, intensity),
                    shape: BoxShape.circle,
                  ),
                );
              }),
              if (!compact) ...[
                const SizedBox(width: 6),
                Text('支出较多', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9.5)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}


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
  late DateTime _month;
  int _selectedPoint = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final allMonthEntries = store.entriesForMonth(_month);
    final expense = allMonthEntries.where((e) => !e.isIncome).fold<double>(0, (s, e) => s + e.amount);
    final income = allMonthEntries.where((e) => e.isIncome).fold<double>(0, (s, e) => s + e.amount);
    final points = _buildPoints(store);
    final safeIndex = points.isEmpty ? 0 : _selectedPoint.clamp(0, points.length - 1);
    final selected = points.isEmpty ? const _ReportPoint(label: '-', amount: 0, entries: []) : points[safeIndex];
    final summaries = store.categorySummaryForMonth(_month, income: _incomeMode);
    final total = _incomeMode ? income : expense;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 126),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('收支报表', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 34)),
          const SizedBox(height: 3),
          Text('数字会记得生活的温度', style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: 1.2)),
          const SizedBox(height: 22),
          PillTabs(
            labels: const ['周', '月', '季度', '年'],
            index: _periodIndex,
            onChanged: (index) {
              HapticFeedback.selectionClick();
              setState(() {
                _periodIndex = index;
                _selectedPoint = 0;
              });
            },
          ),
          const SizedBox(height: 16),
          MonthSwitcher(
            compact: true,
            month: _month,
            onPrevious: () => _moveMonth(-1),
            onNext: () => _moveMonth(1),
          ),
          const SizedBox(height: 16),
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
                Expanded(child: _Metric(label: '支出', value: store.displayMoney(expense), color: null)),
                _metricDivider(context),
                Expanded(child: _Metric(label: '收入', value: store.displayMoney(income), color: AppPalette.mint)),
                _metricDivider(context),
                Expanded(child: _Metric(label: '结余', value: store.displayMoney(income - expense), color: AppPalette.primaryDeep)),
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
                        color: (_incomeMode ? AppPalette.mint : AppPalette.primary).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        _incomeMode ? Icons.show_chart_rounded : Icons.bar_chart_rounded,
                        color: _incomeMode ? AppPalette.mint : AppPalette.primaryDeep,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_incomeMode ? '收入' : '支出'}趋势', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 2),
                          Text(
                            '总额 ${store.displayMoney(total)} · ${_averageLabel(points, total)} · ${_entryCount(points)}笔',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(_periodName(_periodIndex), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                InteractiveTrendChart(
                  points: points.map((e) => TrendPoint(label: e.label, amount: e.amount)).toList(),
                  selectedIndex: safeIndex,
                  onSelected: (index) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedPoint = index);
                  },
                ),
                const SizedBox(height: 8),
                _NodeDetailCard(
                  point: selected,
                  store: store,
                  incomeMode: _incomeMode,
                  onOpenAll: () => _showEntriesSheet(context, selected.entries, store, '${selected.label} · ${store.displayMoney(selected.amount)}'),
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
                    child: Center(child: Text('暂无分类数据', style: Theme.of(context).textTheme.bodySmall)),
                  )
                else
                  Row(
                    children: [
                      DonutChart(
                        items: summaries,
                        total: total,
                        centerLabel: _incomeMode ? '总收入' : '总支出',
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: summaries.take(5).map((item) {
                            final ratio = total <= 0 ? 0.0 : item.amount / total;
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _openCategory(context, store, item.name),
                              child: SizedBox(
                                height: 44,
                                child: Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: colorForCategory(item.name))),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
                                    Text('${(ratio * 100).round()}%', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
                                    const SizedBox(width: 2),
                                    const Icon(Icons.chevron_right_rounded, size: 17),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
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
                    child: Center(child: Text('这个月还没有数据', style: Theme.of(context).textTheme.bodySmall)),
                  )
                else
                  for (var i = 0; i < summaries.length; i++) ...[
                    _RankingRow(
                      item: summaries[i],
                      max: summaries.first.amount,
                      amountText: store.displayMoney(summaries[i].amount),
                      onTap: () => _openCategory(context, store, summaries[i].name),
                    ),
                    if (i != summaries.length - 1) const SizedBox(height: 6),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _moveMonth(int offset) {
    HapticFeedback.selectionClick();
    setState(() {
      _month = DateTime(_month.year, _month.month + offset);
      _selectedPoint = 0;
    });
  }

  List<_ReportPoint> _buildPoints(AppStore store) {
    final entries = store.entries.where((e) => e.isIncome == _incomeMode).toList();
    if (_periodIndex == 0) {
      final now = DateTime.now();
      final anchor = _month.year == now.year && _month.month == now.month
          ? DateTime(now.year, now.month, now.day)
          : DateTime(_month.year, _month.month, 1);
      final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
      return List.generate(7, (index) {
        final day = monday.add(Duration(days: index));
        final list = entries.where((e) => _sameDay(e.date, day)).toList();
        return _ReportPoint(label: '${day.day}日', amount: _sum(list), entries: list);
      });
    }
    if (_periodIndex == 1) {
      final days = DateTime(_month.year, _month.month + 1, 0).day;
      return List.generate(days, (index) {
        final day = index + 1;
        final list = entries.where((e) => e.date.year == _month.year && e.date.month == _month.month && e.date.day == day).toList();
        return _ReportPoint(label: '$day日', amount: _sum(list), entries: list);
      });
    }
    if (_periodIndex == 2) {
      final quarterStart = ((_month.month - 1) ~/ 3) * 3 + 1;
      return List.generate(3, (index) {
        final month = quarterStart + index;
        final list = entries.where((e) => e.date.year == _month.year && e.date.month == month).toList();
        return _ReportPoint(label: '$month月', amount: _sum(list), entries: list);
      });
    }
    return List.generate(12, (index) {
      final month = index + 1;
      final list = entries.where((e) => e.date.year == _month.year && e.date.month == month).toList();
      return _ReportPoint(label: '$month月', amount: _sum(list), entries: list);
    });
  }

  Future<void> _openCategory(BuildContext context, AppStore store, String category) async {
    final entries = store.entriesForCategory(category, month: _month, income: _incomeMode);
    await _showEntriesSheet(context, entries, store, '$category · ${_incomeMode ? '收入' : '支出'}明细');
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.72,
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
                    ? Center(child: Text('当前节点暂无明细', style: Theme.of(context).textTheme.bodySmall))
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => Divider(indent: 58, color: Theme.of(context).dividerColor),
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

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  static double _sum(List<LedgerEntry> entries) => entries.fold(0, (sum, e) => sum + e.amount);
  static int _entryCount(List<_ReportPoint> points) => points.fold(0, (sum, e) => sum + e.entries.length);

  String _averageLabel(List<_ReportPoint> points, double total) {
    if (points.isEmpty) return '均值 ¥0';
    final average = total / points.length;
    return '均值 ¥${_trim(average)}';
  }

  static String _periodName(int index) => const ['周', '月', '季度', '年'][index];
  static String _trim(double value) => value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  Widget _metricDivider(BuildContext context) => Container(
        width: 1,
        height: 58,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: Theme.of(context).dividerColor,
      );
}

class _ReportPoint {
  const _ReportPoint({required this.label, required this.amount, required this.entries});
  final String label;
  final double amount;
  final List<LedgerEntry> entries;
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.color});
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
          child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpenAll,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.8)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${point.label} · ${store.displayMoney(point.amount)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                Text('共 ${point.entries.length} 笔', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          const SizedBox(height: 6),
          if (point.entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('点击其他节点查看${incomeMode ? '收入' : '消费'}明细', style: Theme.of(context).textTheme.bodySmall),
            )
          else
            for (final entry in point.entries.take(4))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    CategoryAvatar(category: entry.category, size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.note.isEmpty ? entry.title : entry.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(store.displayMoney(entry.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.item,
    required this.max,
    required this.amountText,
    required this.onTap,
  });
  final CategorySummary item;
  final double max;
  final String amountText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = max <= 0 ? 0.0 : item.amount / max;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 70),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                CategoryAvatar(category: item.name, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                          Text(amountText, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                          const SizedBox(width: 5),
                          const Icon(Icons.chevron_right_rounded, size: 20),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: colorForCategory(item.name).withValues(alpha: 0.10),
                          valueColor: AlwaysStoppedAnimation(colorForCategory(item.name)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

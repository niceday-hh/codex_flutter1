import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_store.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'calendar_updates.dart';
import 'date_context.dart';
import 'spending_calendar.dart';

DateTime calendarDay(DateTime d) => DateTime(d.year, d.month, d.day);
Map<DateTime, double> calendarTotals(List<LedgerEntry> entries, DateTime start, DateTime end, bool income) {
  final totals = <DateTime,double>{};
  for (final e in entries) {
    if (e.isIncome != income || e.date.isBefore(start) || !e.date.isBefore(end)) continue;
    final day = calendarDay(e.date);
    totals[day] = (totals[day] ?? 0) + e.amount;
  }
  return totals;
}
class PeriodCalendar extends StatelessWidget {
  const PeriodCalendar({super.key, required this.start, required this.end,
    required this.periodIndex, required this.entries, required this.income});
  final DateTime start, end;
  final int periodIndex;
  final List<LedgerEntry> entries;
  final bool income;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: CalendarUpdates.instance,
    builder: (context, _) => _build(context));
  Widget _build(BuildContext context) {
    if (periodIndex == 1) return SpendingCalendar(key: ValueKey(start), anchor: start, entries: entries, income: income);
    final store = AppStoreScope.of(context);
    final totals = calendarTotals(entries, start, end, income);
    final maximum = totals.values.fold<double>(0, math.max);
    final total = totals.values.fold<double>(0, (a,b) => a+b);
    final months = <DateTime>[];
    for (var m = DateTime(start.year,start.month); m.isBefore(end); m = DateTime(m.year,m.month+1)) { months.add(m); }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final label = income ? '收入' : '支出';
    void open(DateTime date) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Scaffold(
        appBar: AppBar(title: Text('${date.year}年${date.month}月 · $label')),
        body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: SpendingCalendar(
          anchor: date, initialDay: date.day, heatMaximum: maximum, entries: entries, income: income)))));
    }
    Widget dayTile(DateTime date, {bool compact = false}) {
      final amount = totals[date];
      final info = dateContext(date);
      final mark = info.holiday != null || info.term != null || info.makeup;
      final tint = store.hideAmounts || amount == null ? Theme.of(context).colorScheme.surfaceContainerHighest : calendarTint(dark, maximum == 0 ? 0 : amount/maximum);
      final ink = store.hideAmounts || amount == null ? Theme.of(context).colorScheme.onSurface : calendarInk(dark);
      return Semantics(button: true, label: '${date.month}月${date.day}日，${info.labels.join('，')}，${amount == null ? '暂无记录' : store.displayMoney(amount)}',
        child: Tooltip(message: '${date.month}月${date.day}日 · ${info.labels.join(' · ')}', child: Material(color: tint, borderRadius: BorderRadius.circular(compact ? 4 : 10),
          child: InkWell(borderRadius: BorderRadius.circular(compact ? 4 : 10), onTap: () => open(date), child: Stack(alignment: Alignment.center, children: [
            Text('${date.day}', style: TextStyle(color: ink, fontSize: compact ? 10 : 13)),
            if (mark) Positioned(bottom: 2, child: Container(width: 3,height: 3,decoration: BoxDecoration(color: ink,shape: BoxShape.circle))),
          ])))));
    }
    Widget month(DateTime m, bool compact) {
      final days = DateTime(m.year,m.month+1,0).day;
      final offset = m.weekday-1;
      final monthTotal = totals.entries.where((e) => e.key.year == m.year && e.key.month == m.month).fold<double>(0,(s,e)=>s+e.value);
      return WarmCard(padding: EdgeInsets.all(compact ? 8 : 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(onTap: () => open(m), child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('${m.month}月 ›', style: TextStyle(fontWeight: FontWeight.w800, fontSize: compact ? 13 : 17)))),
        Text(store.displayMoney(monthTotal), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Row(children: [for(final d in const ['一','二','三','四','五','六','日']) Expanded(child: Center(child: Text(d, style: TextStyle(fontSize: compact ? 9 : 12))))]),
        const SizedBox(height: 5),
        GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: 42,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisExtent: (compact ? 21 : 36) * MediaQuery.textScalerOf(context).scale(1).clamp(1.0,1.6), crossAxisSpacing: 3, mainAxisSpacing: 3),
          itemBuilder: (_, i) { final day = i-offset+1; return day < 1 || day > days ? const SizedBox.shrink() : dayTile(DateTime(m.year,m.month,day), compact: compact); }),
      ]));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WarmCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${const ['每周','每月','季度','年度'][periodIndex]}$label全景', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('${store.displayMoney(total)} · ${totals.length} 天有记录', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(store.hideAmounts ? '金额已隐藏，热力颜色同步隐藏' : '同一时段统一色阶 · 颜色越深，金额越高', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Text('灰色为暂无记录；圆点表示假期、节气或补班。点日期查看详情，点月份放大。', style: Theme.of(context).textTheme.bodySmall),
        if (!store.hideAmounts) Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [const Text('少 '), for(var i=0;i<5;i++) Container(width: 22,height: 12,margin: const EdgeInsets.only(right: 4),color: calendarTint(dark,i/4)), const Text(' 多')])),
      ])),
      const SizedBox(height: 12),
      if (periodIndex == 0) WarmCard(child: Column(children: [for(var i=0;i<7;i++) Builder(builder: (_) {
        final date = DateTime(start.year,start.month,start.day+i);
        return ListTile(contentPadding: EdgeInsets.zero, leading: SizedBox(width: 42,height: 42,child: dayTile(date)), title: Text('${date.month}月${date.day}日 · ${const ['一','二','三','四','五','六','日'][date.weekday-1]}'),
          subtitle: Text(dateContext(date).labels.join(' · ')), trailing: Text(totals.containsKey(date) ? store.displayMoney(totals[date]!) : '暂无记录'), onTap: () => open(date));
      })])),
      if (periodIndex == 2) for(final m in months) Padding(padding: const EdgeInsets.only(bottom: 12), child: month(m,false)),
      if (periodIndex == 3) LayoutBuilder(builder: (_, c) {
        final columns = c.maxWidth >= 330 && MediaQuery.textScalerOf(context).scale(1) <= 1.2 ? 3 : 2;
        return Column(children: [for(var i=0;i<months.length;i+=columns) Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for(var j=0;j<columns;j++) ...[
          if (j>0) const SizedBox(width: 8), Expanded(child: i+j<months.length ? month(months[i+j],true) : const SizedBox.shrink()),
        ]]))]);
      }),
    ]);
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_store.dart';
import '../app_theme.dart';
import '../widgets/common.dart';
import 'insight_engine.dart';

class InsightPanel extends StatefulWidget {
  const InsightPanel({super.key, required this.start, required this.end, required this.income});
  final DateTime start, end;
  final bool income;
  @override
  State<InsightPanel> createState() => _InsightPanelState();
}

class _InsightPanelState extends State<InsightPanel> {
  Object? _key;
  late InsightReport _report;
  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final now = DateTime.now();
    final key = (store.entries, widget.start, widget.end, widget.income, store.monthlyBudget, (now.year, now.month, now.day, now.hour, now.minute));
    if (key != _key) {
      _key = key;
      _report = analyzeInsights(entries: store.entries, start: widget.start,
        end: widget.end, now: now, income: widget.income, monthlyBudget: store.monthlyBudget);
    }
    final hidden = store.hideAmounts;
    return WarmCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.auto_awesome_outlined, color: AppPalette.primaryDeep),
        const SizedBox(width: 8),
        Expanded(child: Text(widget.income ? '收入洞察' : '消费洞察', style: Theme.of(context).textTheme.titleLarge)),
      ]),
      const SizedBox(height: 8),
      Text('${_report.days} 天观察窗 · ${_report.count} 笔记录', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 12),
      for (final item in _report.items.take(3)) Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(hidden ? '••••' : item.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppPalette.primaryDeep)),
        ])),
      SizedBox(width: double.infinity, child: FilledButton.tonal(
        onPressed: () => Navigator.of(context).push(CupertinoPageRoute<void>(
          builder: (_) => _InsightExplorer(report: _report, income: widget.income))),
        child: const Text('深入分析与方法'))),
    ]));
  }
}

class _InsightExplorer extends StatefulWidget {
  const _InsightExplorer({required this.report, required this.income});
  final InsightReport report;
  final bool income;
  @override
  State<_InsightExplorer> createState() => _InsightExplorerState();
}
class _InsightExplorerState extends State<_InsightExplorer> {
  String _filter = '全部';
  double _reduction = .1;
  String _group(String id) {
    if (['change','drivers','frequency'].contains(id)) return '变化';
    if (['unusual','recurring'].contains(id)) return '线索';
    if (id == 'budget') return '预算';
    return '结构';
  }
  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final hidden = AppStoreScope.of(context).hideAmounts;
    final items = report.items.where((i) => _filter == '全部' || _group(i.id) == _filter).toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.income ? '收入洞察实验室' : '消费洞察实验室')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        Text('从变化、结构和线索理解账本', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        Text('${report.days} 个观察日 · ${report.recordDays} 天有记录 · ${report.count} 笔\n无记录日不一定是零消费；缺失记录会影响所有结论。分析仅在本地完成。',
          style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        Wrap(spacing: 8, children: [for (final group in ['全部','变化','结构','线索', if (!widget.income) '预算'])
          ChoiceChip(label: Text(group), selected: _filter == group,
            onSelected: (_) => setState(() => _filter = group))]),
        const SizedBox(height: 12),
        if (items.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('该维度暂时没有可分析的记录。')),
        for (final item in items) Padding(padding: const EdgeInsets.only(bottom: 14),
          child: WarmCard(onTap: () => _details(context, item, hidden), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(item.title, style: Theme.of(context).textTheme.titleMedium)),
                const Icon(Icons.chevron_right_rounded)]),
              const SizedBox(height: 8),
              Text(hidden ? '••••' : item.value,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                  color: item.ready ? AppPalette.primaryDeep : Theme.of(context).textTheme.bodySmall?.color)),
              const SizedBox(height: 8),
              Text(hidden ? '金额已隐藏；关闭“隐藏金额”后查看分析。' : item.summary),
              const SizedBox(height: 10),
              Text('查看依据、限制与账单', style: Theme.of(context).textTheme.bodySmall),
            ]))),
        if (!hidden && report.projected != null && (_filter == '全部' || _filter == '预算')) _scenario(report),
        const SizedBox(height: 8),
        TextButton.icon(onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true,
          builder: (_) => const SafeArea(child: Padding(padding: EdgeInsets.all(24), child: SingleChildScrollView(child: SelectableText(
            '方法与项目参考\n\nNIST：修正 Z 分数与 MAD，用于异常金额探索。\nhttps://www.itl.nist.gov/div898/handbook/eda/section3/eda35h.htm\n\nActual Budget：多维日期报表、消费对比及周期交易组织。\nhttps://actualbudget.org/docs/reports/\nhttps://actualbudget.org/docs/schedules/\n\n本应用独立实现，没有复制项目代码。样本门槛、周期账单容差和预算外推属于产品规则；不构成财务健康评级。集中度与变化分解为描述性数学工具。'))))),
          icon: const Icon(Icons.menu_book_outlined), label: const Text('方法与项目参考')),
      ]),
    );
  }
  Widget _scenario(InsightReport r) {
    final monthDays = DateTime.utc(r.start.year, r.start.month + 1, 1).difference(r.start).inDays;
    final remaining = monthDays - r.days;
    final saving = r.scenarioAmount / r.days * remaining * _reduction;
    return WarmCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('如果调整后续支出', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text('假设“${r.scenarioCategory}”在剩余 $remaining 天的日均支出降低 ${(_reduction * 100).round()}%'),
      Slider(value: _reduction, min: 0, max: .5, divisions: 10,
        label: '${(_reduction * 100).round()}%', onChanged: (v) => setState(() => _reduction = v)),
      Text('情景月末支出 ¥${(r.projected! - saving).toStringAsFixed(2)}\n后续少支出 ¥${saving.toStringAsFixed(2)}'),
      const SizedBox(height: 8),
      const Text('不回减已发生的支出；不假定房租、医疗等费用一定可以缩减。请自行判断可调整性。'),
    ]));
  }
  void _details(BuildContext context, SpendingInsight item, bool hidden) {
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: ListView.builder(padding: const EdgeInsets.all(20),
        itemCount: hidden ? 1 : item.entries.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(hidden ? '金额已隐藏' : item.value, style: Theme.of(context).textTheme.headlineSmall),
            if (!hidden) ...[
              const SizedBox(height: 16), Text(item.summary),
              const SizedBox(height: 20), const Text('如何计算', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8), Text(item.method),
              const SizedBox(height: 20), const Text('下一步', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8), Text(item.action),
              const SizedBox(height: 20), SelectableText('依据：${item.source}'),
              TextButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: item.source));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制依据'))); },
                icon: const Icon(Icons.copy_outlined), label: const Text('复制依据')),
              const Divider(), Text('关联账单 · ${item.entries.length} 笔（含说明中的对照或历史窗口）'),
              const SizedBox(height: 12),
            ],
          ]);
          final e = item.entries[index - 1];
          return ListTile(contentPadding: EdgeInsets.zero,
            title: Text(e.category), subtitle: Text('${e.date.year}/${e.date.month}/${e.date.day} · ${e.note}'),
            trailing: Text('¥${e.amount.toStringAsFixed(2)}'));
        }),
    )));
  }
}

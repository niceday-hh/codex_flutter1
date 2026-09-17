import 'dart:math' as math;
import '../models.dart';

DateTime insightDay(DateTime d) => DateTime.utc(d.year, d.month, d.day);
double _sum(Iterable<LedgerEntry> es) => es.fold(0.0, (s, e) => s + e.amount);
double _median(List<double> values) {
  final s = List<double>.of(values)..sort();
  final i = s.length ~/ 2;
  return s.length.isOdd ? s[i] : (s[i - 1] + s[i]) / 2;
}
String _money(double n) => '¥${n.toStringAsFixed(2)}';
String _date(DateTime d) => '${d.year}/${d.month}/${d.day}';

class SpendingInsight {
  const SpendingInsight(this.id, this.title, this.value, this.summary,
      this.method, this.action, this.entries, {this.source = '描述性统计与账本恒等式', this.ready = true});
  final String id, title, value, summary, method, action, source;
  final List<LedgerEntry> entries;
  final bool ready;
}

class InsightReport {
  const InsightReport(this.items, this.start, this.end, this.days, this.recordDays,
      this.count, this.projected, this.budget, this.scenarioCategory, this.scenarioAmount);
  final List<SpendingInsight> items;
  final DateTime start, end;
  final int days, recordDays, count;
  final double? projected;
  final double budget, scenarioAmount;
  final String scenarioCategory;
}

/// Pure, local analysis. Calendar-day arithmetic uses UTC dates to avoid DST drift.
InsightReport analyzeInsights({required List<LedgerEntry> entries,
  required DateTime start, required DateTime end, required DateTime now,
  bool income = false, double monthlyBudget = 0}) {
  final from = insightDay(start), until = insightDay(end);
  final tomorrow = insightDay(now).add(const Duration(days: 1));
  final observedEnd = until.isBefore(tomorrow) ? until : tomorrow;
  final days = math.max(0, observedEnd.difference(from).inDays);
  final previousStart = from.subtract(Duration(days: days));
  bool within(LedgerEntry e, DateTime a, DateTime b) {
    final d = insightDay(e.date);
    return !d.isBefore(a) && d.isBefore(b) && !e.date.isAfter(now);
  }
  final valid = entries.where((e) => e.amount.isFinite && e.amount > 0 && e.isIncome == income).toList();
  final current = valid.where((e) => within(e, from, observedEnd)).toList();
  final previous = valid.where((e) => within(e, previousStart, from)).toList();
  final total = _sum(current), oldTotal = _sum(previous);
  final recordDays = current.map((e) => insightDay(e.date)).toSet().length;
  final items = <SpendingInsight>[];
  final noun = income ? '收入' : '消费';
  void missing(String id, String title, String reason) => items.add(SpendingInsight(
      id, title, '数据不足', reason, '仅分析已记录且不晚于当前时刻的正金额账单。',
      '补全对应时段记录后再查看。', const [], ready: false));
  if (current.isEmpty || days == 0) {
    missing('empty', '等待可分析的记录', '所选时段尚无${income ? '收入' : '支出'}记录，或时段尚未开始。');
    return InsightReport(items, from, observedEnd, days, recordDays, current.length, null, monthlyBudget, '', 0);
  }
  final periodNote = '本期 ${_date(from)}—${_date(observedEnd.subtract(const Duration(days: 1)))}；对照 ${_date(previousStart)}—${_date(from.subtract(const Duration(days: 1)))}，均为 $days 个日历日。';
  if (previous.isEmpty || oldTotal <= 0) {
    missing('change', '等长时段对比', '紧邻本期之前的 $days 天没有可比较记录，不计算增长百分比。');
    missing('drivers', '变化来自哪里', '需要本期和对照时段的分类记录。');
    missing('frequency', '频次 × 单笔金额', '需要两个时段均有记录，才能分解总额变化。');
  } else {
    final delta = total - oldTotal;
    items.add(SpendingInsight('change', '等长时段对比', '${delta >= 0 ? '+' : ''}${(delta / oldTotal * 100).toStringAsFixed(1)}%',
      '$noun总额由 ${_money(oldTotal)} 变为 ${_money(total)}。',
      '$periodNote\n变化率 = (本期总额 − 对照总额) ÷ 对照总额。不把未结束的本月与完整上月直接比较。',
      '先核对两段记录是否完整，再检查一次性大额是否改变了趋势。', [...current, ...previous]));
    final changes = <String, double>{};
    for (final e in current) { changes[e.category] = (changes[e.category] ?? 0) + e.amount; }
    for (final e in previous) { changes[e.category] = (changes[e.category] ?? 0) - e.amount; }
    final ranked = changes.entries.toList()..sort((a,b) => b.value.abs().compareTo(a.value.abs()));
    final top = ranked.first;
    items.add(SpendingInsight('drivers', '变化来自哪里', top.key,
      ranked.take(3).map((e) => '${e.key} ${e.value >= 0 ? '+' : '-'}${_money(e.value.abs())}').join(' · '),
      '$periodNote\n各分类本期金额减对照金额；按绝对变化排序。分类差额之和等于总额变化，表示算术贡献，不表示因果。',
      '优先复核变化最大的分类，区分长期变化与一次性事项。',
      [...current, ...previous].where((e) => e.category == top.key).toList()));
    final a = total / current.length, b = oldTotal / previous.length;
    final frequency = (current.length - previous.length) * (a + b) / 2;
    final basket = (a - b) * (current.length + previous.length) / 2;
    items.add(SpendingInsight('frequency', '频次 × 单笔金额', '${previous.length} → ${current.length} 笔',
      '笔数变化贡献 ${_money(frequency)}；单笔均额变化贡献 ${_money(basket)}。',
      '$periodNote\n总额 = 笔数 × 单笔均额。对称分解：频次贡献 = Δ笔数 × 两期均额平均值；均额贡献 = Δ均额 × 两期笔数平均值。两项相加恰好等于总额变化。单笔金额不等于商品单价。',
      '若主要来自笔数，可观察购买频率；若来自均额，检查购买内容和大额事项。', [...current, ...previous]));
  }
  var weekends = 0;
  for (var d = from; d.isBefore(observedEnd); d = d.add(const Duration(days: 1))) {
    if (d.weekday >= 6) weekends++;
  }
  final weekdays = days - weekends;
  if (weekends < 2 || weekdays < 5 || current.length < 7) {
    missing('rhythm', '周末与工作日日均', '至少需要 2 个周末日、5 个工作日和 7 笔记录；不会用总额占比判断活跃程度。');
  } else {
    final we = _sum(current.where((e) => e.date.weekday >= 6)) / weekends;
    final wd = _sum(current.where((e) => e.date.weekday < 6)) / weekdays;
    items.add(SpendingInsight('rhythm', '周末与工作日日均', wd > 0 ? '${(we / wd).toStringAsFixed(2)} 倍' : '工作日基数为零',
      '周末 ${_money(we)}/日；工作日 ${_money(wd)}/日。',
      '分别除以本期 $weekends 个周末日和 $weekdays 个工作日，包含无记录日。周末仅指周六、周日，不校正节假日。无记录可能是漏记，差异不是显著性检验，也不代表冲动消费。',
      '连续观察多个周期，结合出行、聚餐或工作安排解释差异。', current));
  }
  final categories = <String, double>{};
  for (final e in current) { categories[e.category] = (categories[e.category] ?? 0) + e.amount; }
  final ranked = categories.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
  final hhi = categories.values.fold(0.0, (s,v) => s + (v / total) * (v / total));
  items.add(SpendingInsight('concentration', '$noun集中度', '${(ranked.take(3).fold(0.0, (s,e) => s + e.value) / total * 100).toStringAsFixed(1)}%',
    '前 ${math.min(3, ranked.length)} 类占比；等效均匀分类数 ${(1 / hhi).toStringAsFixed(1)}。',
    '集中度 H = Σ(分类金额占比²)，等效分类数 = 1/H。它表示当前分布相当于多少个金额相等的分类，只描述结构。分类口径会改变结果，不预设“80/20”，也没有越分散越健康的结论。',
    '从金额最大的分类开始复盘；房租等集中支出可能完全合理。', current));
  final historyStart = from.subtract(const Duration(days: 90));
  final history = valid.where((e) => within(e, historyStart, from)).toList();
  final byCategory = <String,List<double>>{};
  for (final e in history) { byCategory.putIfAbsent(e.category, () => []).add(e.amount); }
  final thresholds = <String,double>{};
  for (final group in byCategory.entries) {
    if (group.value.length < 8) continue;
    final median = _median(group.value);
    final mad = _median(group.value.map((v) => (v - median).abs()).toList());
    if (mad > 0) thresholds[group.key] = median + 3.5 * mad / 0.6745;
  }
  final unusual = current.where((e) => thresholds.containsKey(e.category) && e.amount > thresholds[e.category]!).toList()
    ..sort((a,b) => b.amount.compareTo(a.amount));
  final covered = current.where((e) => thresholds.containsKey(e.category)).length;
  if (covered == 0) {
    missing('unusual', '异常金额线索', '需本期之前 90 天内同分类至少 8 笔记录，且金额绝对偏差中位数不为零；当前没有可评估分类。');
  } else {
    items.add(SpendingInsight('unusual', '异常金额线索', '${unusual.length} 笔待复核',
      '已评估 $covered/${current.length} 笔；${unusual.isEmpty ? '可评估记录未触发高额阈值。' : '最大线索 ${unusual.first.category} ${_money(unusual.first.amount)}。'}',
      '同分类、之前 90 天作基线，至少 8 笔（产品样本门槛）。修正 Z = 0.6745 × (金额 − 中位数)/MAD，仅标记 Z > 3.5 的高额。MAD 为零时跳过。消费金额可能偏态，因此这是探索线索，不是统计显著结论；不删除记录。',
      '核对金额、分类、重复录入和一次性支出，再决定是否调整。', unusual,
      source: 'NIST · Detection of Outliers\nhttps://www.itl.nist.gov/div898/handbook/eda/section3/eda35h.htm'));
  }
  final recurring = <String,List<LedgerEntry>>{};
  for (final e in valid.where((e) => within(e, observedEnd.subtract(const Duration(days: 180)), observedEnd))) {
    final note = e.note.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (note.isNotEmpty) recurring.putIfAbsent('${e.category} · $note', () => []).add(e);
  }
  final matches = <LedgerEntry>[];
  final labels = <String>[];
  for (final g in recurring.entries) {
    final es = g.value..sort((a,b) => a.date.compareTo(b.date));
    if (es.length < 3 || !es.any((e) => within(e, from, observedEnd))) continue;
    if (es.map((e) => insightDay(e.date)).toSet().length != es.length) continue;
    final gaps = [for (var i = 1; i < es.length; i++) insightDay(es[i].date).difference(insightDay(es[i-1].date)).inDays.toDouble()];
    final gap = _median(gaps), amount = _median(es.map((e) => e.amount).toList());
    final weekly = gap >= 6 && gap <= 8;
    final monthly = gap >= 26 && gap <= 33;
    if ((!weekly && !monthly) || gaps.any((v) => (v-gap).abs() > (weekly ? 1 : 3)) || es.any((e) => (e.amount-amount).abs() > amount * .1)) continue;
    labels.add('${g.key} · 疑似${weekly ? '每周' : '每月'}');
    matches.addAll(es);
  }
  items.add(SpendingInsight('recurring', income ? '周期入账线索' : '疑似周期账单', '${labels.length} 组',
    labels.isEmpty ? '未发现满足规则的周期线索；无备注记录不参与。' : labels.take(3).join('\n'),
    '观察截至本期末（不超过今天）的 180 天。分类与规范化备注一致，至少 3 次不同日期；间隔中位数 6–8 天或 26–33 天，各间隔偏离中位数不超过 1/3 天；金额偏离中位数不超过 10%，且本期出现过。以上均为产品启发式，不是已确认订阅，可能漏掉不规则付款。',
    '逐笔确认是否为订阅、房租或固定收入；记录不包含商户标识，不能自动认定合同。', matches,
    source: '产品规则 · 参考 Actual Budget Schedules 的周期交易组织方式\nhttps://actualbudget.org/docs/schedules/'));
  double? projected;
  final isCurrentMonth = from == DateTime.utc(now.year, now.month, 1) && until == DateTime.utc(now.year, now.month + 1, 1);
  if (!income) {
    if (!isCurrentMonth || days < 7 || recordDays < 4) {
      missing('budget', '月末预算情景', '仅当前整月视图提供；至少经过 7 天并有 4 个记账日。其他周期不套用当前月预算。');
    } else {
      projected = total / days * until.difference(from).inDays;
      items.add(SpendingInsight('budget', '月末预算情景', _money(projected),
        monthlyBudget > 0 ? '按当前日均延续，${projected > monthlyBudget ? '高于' : '低于或等于'}月预算 ${_money(monthlyBudget)}。' : '尚无有效月预算。',
        '已记支出 ÷ 已经过日历天数 × 本月天数。今天可能尚未结束；无记录日按零计入。假设记录完整、后续日均稳定，未建模发薪日、固定账单与节假日；这是情景外推，不是保证或置信区间。',
        '用下方滑块模拟最大分类后续日均支出的降低幅度，不回减已经发生的支出。', current,
        source: '产品情景外推 · 参考 Actual Budget Spending Analysis\nhttps://actualbudget.org/docs/reports/'));
    }
  }
  return InsightReport(items, from, observedEnd, days, recordDays, current.length,
    projected, monthlyBudget, ranked.first.key, ranked.first.value);
}

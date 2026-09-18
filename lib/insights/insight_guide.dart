import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'insight_engine.dart';

const insightGuides = <String,(String,String,IconData)>{
  'change':('这段时间，比之前花得多吗？','把相同天数放在一起比较。例如之前花100元、这期花120元，就是增加20%。',Icons.compare_arrows),
  'drivers':('主要是哪一类变了？','像拆开一张总账，看看餐饮、购物等各自多了或少了多少。变化最大不等于最该削减。',Icons.account_tree_outlined),
  'frequency':('是买得更勤，还是每笔更多？','总金额像一个长方形：一边是记账笔数，另一边是每笔平均金额；任一边变大，总额都可能变大。',Icons.grid_view_outlined),
  'rhythm':('周末每天通常花多少？','周末和工作日天数不同，要比较“每天平均花费”。2倍表示周末日均约为工作日的两倍。',Icons.calendar_view_week_outlined),
  'concentration':('钱主要流向哪里？','想象把100元分给不同分类。最大的几块越大，支出越集中；房租占大头也可能很正常。',Icons.donut_small_outlined),
  'unusual':('有没有明显高于以往的账单？','把一笔账单与之前同类别的金额习惯比较。被标记只是值得看一眼，可能是旅行、大件或录入问题。',Icons.search_outlined),
  'recurring':('哪些账单可能隔一段时间就来？','像每月会员费：备注相同、金额接近、隔固定时间出现。只是候选，还需要你确认。',Icons.repeat_rounded),
  'budget':('按现在的节奏，月底可能花多少？','像观察水流速度估算一桶水：假设接下来每天花得差不多，估算整个月的金额。固定账单可能让估算偏离。',Icons.speed_rounded),
  'empty':('先留下一些记录','有账单后，才能看出金额、分类和时间上的特点。',Icons.edit_note),
};

List<LedgerEntry> reportEntries(InsightReport r) {
  final unique=<String,LedgerEntry>{};
  for(final i in r.items) { for(final e in i.entries) {
    final day=insightDay(e.date);
    if(!day.isBefore(r.start)&&day.isBefore(r.end)) unique[e.id]=e;
  }}
  return unique.values.toList();
}
Map<String,double> reportCategories(InsightReport r) {
  final values=<String,double>{};
  for(final e in reportEntries(r)) {values[e.category]=(values[e.category]??0)+e.amount;}
  return values;
}
String overviewText(InsightReport r, {bool income=false}) {
  final entries=reportEntries(r), noun=income?'收入':'支出';
  if(entries.isEmpty)return '暂时没有足够记录来描述本期特点。';
  final categories=reportCategories(r).entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
  final total=categories.fold<double>(0,(s,e)=>s+e.value);
  final top=categories.first, share=top.value/total;
  final change=r.items.where((i)=>i.id=='change'&&i.ready).firstOrNull;
  final rate=change==null?null:double.tryParse(change.value.replaceAll('%',''));
  final trend=rate==null?'暂缺可比较的前期记录':rate>0?'总额比等长前期增加 ${rate.toStringAsFixed(1)}%':rate<0?'总额比等长前期减少 ${rate.abs().toStringAsFixed(1)}%':'总额与等长前期持平';
  return '$noun以${top.key}为主，占 ${(share*100).toStringAsFixed(1)}%${share>=.5?'，超过本期一半':''}。$trend。已记 ${entries.length} 笔，单笔平均 ¥${(total/entries.length).toStringAsFixed(2)}。';
}

class InsightOverview extends StatelessWidget {
  const InsightOverview({super.key,required this.report,required this.hidden,required this.income});
  final InsightReport report;
  final bool hidden,income;
  @override
  Widget build(BuildContext context) {
    final categories=reportCategories(report).entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
    final total=categories.fold<double>(0,(s,e)=>s+e.value);
    return WarmCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('本期${income?'收入':'消费'}速写',style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:10),
      Text(hidden?'金额已隐藏，消费画像同步隐藏。':overviewText(report,income:income),style:const TextStyle(height:1.6)),
      if(!hidden&&total>0)...[
        const SizedBox(height:14),
        const Text('每100元流向哪里',style:TextStyle(fontWeight:FontWeight.w600)),
        const SizedBox(height:10),
        for(final c in categories.take(3)) GuideBar(label:c.key,value:c.value/total,text:'${(c.value/total*100).toStringAsFixed(1)}元'),
        if(categories.length>3) GuideBar(label:'其他分类',value:categories.skip(3).fold<double>(0,(s,e)=>s+e.value)/total,text:'${(categories.skip(3).fold<double>(0,(s,e)=>s+e.value)/total*100).toStringAsFixed(1)}元'),
      ],
      const SizedBox(height:8),
      Text('仅描述已记账单，不评价消费好坏；漏记会改变画像。',style:Theme.of(context).textTheme.bodySmall),
    ]));
  }
}
class GuideBar extends StatelessWidget {
  const GuideBar({super.key,required this.label,required this.value,required this.text});
  final String label,text;
  final double value;
  @override
  Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Column(children:[
    Row(children:[Expanded(child:Text(label)),Text(text)]),const SizedBox(height:5),
    ClipRRect(borderRadius:BorderRadius.circular(6),child:LinearProgressIndicator(value:value.clamp(0,1),minHeight:8,
      color:Theme.of(context).brightness==Brightness.dark?const Color(0xFF94BCA4):const Color(0xFF56856B),
      backgroundColor:Theme.of(context).brightness==Brightness.dark?const Color(0xFF293A32):const Color(0xFFE8EFE8))),
  ]));
}
class InsightGuide extends StatelessWidget {
  const InsightGuide({super.key,required this.item,required this.report});
  final SpendingInsight item;
  final InsightReport report;
  @override
  Widget build(BuildContext context) {
    final guide=insightGuides[item.id]??insightGuides['empty']!;
    final current=reportEntries(report);
    double sum(Iterable<LedgerEntry> es)=>es.fold(0.0,(s,e)=>s+e.amount);
    final bars=<(String,double)>[];
    String unit='元';
    if(item.id=='change'||item.id=='frequency') {
      final before=item.entries.where((e)=>insightDay(e.date).isBefore(report.start));
      final after=item.entries.where((e)=>!insightDay(e.date).isBefore(report.start));
      if(item.id=='frequency') {bars.addAll([('前期笔数',before.length.toDouble()),('本期笔数',after.length.toDouble())]);unit='笔';}
      else {bars.addAll([('等长前期',sum(before)),('本期',sum(after))]);}
    } else if(item.id=='rhythm') {
      var weekends=0;
      for(var d=report.start;d.isBefore(report.end);d=d.add(const Duration(days:1))) {if(d.weekday>=6)weekends++;}
      if(weekends>0&&report.days>weekends) bars.addAll([('周末日均',sum(current.where((e)=>e.date.weekday>=6))/weekends),('工作日日均',sum(current.where((e)=>e.date.weekday<6))/(report.days-weekends))]);
    } else if(item.id=='budget'&&report.projected!=null) {
      bars.addAll([('已记支出',sum(current)),('情景月末',report.projected!),('月预算',report.budget)]);
    } else if(item.id=='concentration'||item.id=='drivers') {
      final cats=reportCategories(report).entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
      bars.addAll(cats.take(3).map((e)=>(e.key,e.value)));
    }
    final max=bars.fold<double>(0,(s,b)=>b.$2>s?b.$2:s);
    return Container(padding:const EdgeInsets.all(16),margin:const EdgeInsets.symmetric(vertical:16),
      decoration:BoxDecoration(color:Theme.of(context).scaffoldBackgroundColor,borderRadius:BorderRadius.circular(18)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(guide.$3,color:Theme.of(context).textTheme.bodySmall?.color),const SizedBox(height:8),
        Text(guide.$1,style:const TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:8),Text(guide.$2,style:const TextStyle(height:1.5)),
        if(item.ready&&max>0)...[const SizedBox(height:14),
          if(item.id=='drivers') const Text('本期分类金额（变化差额见上方）'),
          for(final b in bars) GuideBar(label:b.$1,value:b.$2/max,text:'${b.$2.toStringAsFixed(unit=='笔'?0:2)}$unit'),
        ],
        if(item.id=='unusual'||item.id=='recurring')...[
          const SizedBox(height:12),
          Wrap(spacing:8,runSpacing:8,children:[for(final label in item.id=='unusual'?['同类历史','寻找高额','逐笔核对']:['备注相同','金额接近','间隔规律']) Chip(label:Text(label))]),
          const Text('满足线索 ≠ 已经确认；需要结合账单内容判断。'),
        ],
      ]));
  }
}

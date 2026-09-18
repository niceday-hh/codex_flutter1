import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_store.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'date_context.dart';
import 'calendar_updates.dart';
import 'calendar_settings.dart';

Color calendarTint(bool dark, double intensity) => Color.lerp(
  dark ? const Color(0xFF25332E) : const Color(0xFFF0F5EF),
  dark ? const Color(0xFF486951) : const Color(0xFFB1CBB5), intensity.clamp(0,1))!;
Color calendarInk(bool dark) => dark ? const Color(0xFFF4F7EF) : const Color(0xFF233D2A);

class SpendingCalendar extends StatefulWidget {
  const SpendingCalendar({super.key,required this.anchor,required this.entries,required this.income, this.initialDay, this.heatMaximum});
  final DateTime anchor;
  final List<LedgerEntry> entries;
  final bool income;
  final int? initialDay;
  final double? heatMaximum;
  @override
  State<SpendingCalendar> createState()=>_SpendingCalendarState();
}
class _SpendingCalendarState extends State<SpendingCalendar> {
  int? _selected;
  @override
  void didUpdateWidget(covariant SpendingCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anchor.year!=widget.anchor.year || oldWidget.anchor.month!=widget.anchor.month) _selected=null;
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: CalendarUpdates.instance,
    builder: (context, _) => _calendar(context));

  Widget _calendar(BuildContext context) {
    final store=AppStoreScope.of(context), anchor=widget.anchor;
    final dark=Theme.of(context).brightness==Brightness.dark, hidden=store.hideAmounts;
    final byDay=<int,List<LedgerEntry>>{};
    for(final e in widget.entries.where((e)=>e.date.year==anchor.year && e.date.month==anchor.month && e.isIncome==widget.income)) {
      byDay.putIfAbsent(e.date.day,()=>[]).add(e);
    }
    final totals=byDay.map((day,es)=>MapEntry(day,es.fold<double>(0,(s,e)=>s+e.amount)));
    final maximum=widget.heatMaximum ?? totals.values.fold<double>(0,math.max), total=totals.values.fold<double>(0,(s,v)=>s+v);
    final days=DateTime(anchor.year,anchor.month+1,0).day;
    final offset=DateTime(anchor.year,anchor.month,1).weekday-1;
    final selected=(_selected??widget.initialDay??1).clamp(1,days);
    final selectedDate=DateTime(anchor.year,anchor.month,selected), info=dateContext(DateTime(anchor.year,anchor.month,selected));
    final selectedEntries=byDay[selected]??[];
    final label=widget.income?'收入':'支出';
    return WarmCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('${anchor.year}年${anchor.month}月 · $label日历',style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:6),
      Text('颜色越深，已记$label越多 · 点日期看明细',style:Theme.of(context).textTheme.bodySmall),
      const SizedBox(height:14),
      Row(children:[for(final name in const ['一','二','三','四','五','六','日']) Expanded(child:Center(child:Text(name,style:Theme.of(context).textTheme.bodySmall)))]),
      const SizedBox(height:8),
      LayoutBuilder(builder:(context,c) {
        final scale=MediaQuery.textScalerOf(context).scale(1);
        return GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
          itemCount:((offset+days+6)~/7)*7,
          gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7,mainAxisExtent:56*scale.clamp(1.0,1.7),crossAxisSpacing:4,mainAxisSpacing:5),
          itemBuilder:(context,index) {
            final day=index-offset+1;
            if(day<1||day>days)return const SizedBox.shrink();
            final date=DateTime(anchor.year,anchor.month,day),meta=dateContext(DateTime(anchor.year,anchor.month,day));
            final amount=totals[day]??0;
            final intensity=hidden||maximum<=0?0.0:amount/maximum;
            return Semantics(button:true,selected:day==selected,label:'${date.month}月$day日 ${meta.labels.join('、')} ${hidden?'金额已隐藏':'$label ${amount.toStringAsFixed(2)}元'}',
              child:InkWell(key:ValueKey('calendar-day-$day'),borderRadius:BorderRadius.circular(10),onTap:()=>setState(()=>_selected=day),
                child:Container(decoration:BoxDecoration(color:calendarTint(dark,intensity),borderRadius:BorderRadius.circular(10),
                  border:Border.all(color:day==selected?calendarInk(dark):Colors.transparent,width:1.4)),
                  child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                    Text('$day',style:TextStyle(color:calendarInk(dark),fontSize:14,fontWeight:FontWeight.w700)),
                    const SizedBox(height:3),
                    FittedBox(fit:BoxFit.scaleDown,child:Padding(padding:const EdgeInsets.symmetric(horizontal:2),child:Text(
                      meta.holiday!=null && meta.term!=null?'休·${meta.term}':meta.holiday!=null?'休·${meta.holiday}':meta.shortLabel,
                      style:TextStyle(fontSize:9,color:calendarInk(dark))))),
                  ]))));
          });
      }),
      const SizedBox(height:10),
      Row(children:[Text(hidden?'热力已隐藏':'少',style:Theme.of(context).textTheme.bodySmall),const SizedBox(width:8),
        if(!hidden) ...[for(var i=0;i<5;i++) Container(width:16,height:8,margin:const EdgeInsets.only(right:4),decoration:BoxDecoration(color:calendarTint(dark,i/4),borderRadius:BorderRadius.circular(3))),Text('多',style:Theme.of(context).textTheme.bodySmall)],
        const Spacer(),Text('休：假期  补班：调休',style:Theme.of(context).textTheme.bodySmall?.copyWith(fontSize:10))]),
      const SizedBox(height:16),
      Text('${selectedDate.month}月$selected日 · ${info.labels.join(' / ')}',style:const TextStyle(fontWeight:FontWeight.w600)),
      const SizedBox(height:6),
      Text(hidden?'••••':'已记$label ¥${(totals[selected]??0).toStringAsFixed(2)} · 占本月${total>0?((totals[selected]??0)/total*100).toStringAsFixed(1):'0.0'}%'),
      const SizedBox(height:6),
      if(selectedEntries.isEmpty) const Text('当天暂无记录，不能据此认定没有收支。'),
      for(final e in selectedEntries.take(3)) Padding(padding:const EdgeInsets.only(top:6),child:Row(children:[
        Expanded(child:Text(e.note.isEmpty?e.category:e.note,maxLines:1,overflow:TextOverflow.ellipsis)),
        Text(hidden?'••••':'¥${e.amount.toStringAsFixed(2)}')])),
      if(selectedEntries.isNotEmpty) TextButton(onPressed:()=>showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,
        builder:(_)=>SafeArea(child:SizedBox(height:MediaQuery.sizeOf(context).height*.6,child:ListView.builder(padding:const EdgeInsets.all(20),itemCount:selectedEntries.length,itemBuilder:(_,i)=>EntryRow(entry:selectedEntries[i],amountText:hidden?'••••':'¥${selectedEntries[i].amount.toStringAsFixed(2)}'))))),child:Text('查看当天 ${selectedEntries.length} 笔账单')),
      const Divider(),
      Text('中国大陆放假调休 · 节气按北京时间\n${info.known ? '假期资料已收录' : '假期资料未收录'} · ${info.termsKnown ? '节气资料已收录' : '节气资料未收录'}\n节气不一定放假；颜色仅表示金额。',style:Theme.of(context).textTheme.bodySmall?.copyWith(fontSize:11)),
      TextButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CalendarSettings())),
        icon: const Icon(Icons.update), label: const Text('日期资料与更新')),
    ]));
  }
}

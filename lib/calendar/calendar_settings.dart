import 'package:flutter/material.dart';
import 'calendar_updates.dart';

class CalendarSettings extends StatefulWidget {
  const CalendarSettings({super.key});
  @override
  State<CalendarSettings> createState()=>_CalendarSettingsState();
}
class _CalendarSettingsState extends State<CalendarSettings> {
  int year=DateTime.now().year;
  final updates=CalendarUpdates.instance;
  @override
  void initState(){super.initState();updates.initialize();}
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('日期资料更新')),
    body:AnimatedBuilder(animation:updates,builder:(context,_)=>ListView(padding:const EdgeInsets.all(20),children:[
      const Text('假期与节气，按年份更新',style:TextStyle(fontSize:24,fontWeight:FontWeight.w700)),
      const SizedBox(height:12),
      const Text('只下载公开日期资料，不上传账单。更新成功后保存在本机，离线也可查看。'),
      SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('自动检查更新'),
        subtitle:const Text('默认关闭。开启后，在启动或回到前台时检查今年和下一年；每年最多每24小时尝试一次，不常驻后台。'),
        value:updates.automatic,onChanged:updates.busy?null:updates.setAutomatic),
      const SizedBox(height:16),
      DropdownButtonFormField<int>(initialValue:year,decoration:const InputDecoration(labelText:'选择年份'),
        items:[for(var y=DateTime.now().year+1;y>=2007;y--)DropdownMenuItem(value:y,child:Text('$y年'))],
        onChanged:updates.busy?null:(v)=>setState(()=>year=v!)),
      const SizedBox(height:16),
      FilledButton.icon(onPressed:updates.busy?null:()=>updates.check(year),icon:const Icon(Icons.refresh),label:Text(updates.busy?'正在检查…':'检查 $year 年资料')),
      if(updates.busy)const Padding(padding:EdgeInsets.symmetric(vertical:12),child:LinearProgressIndicator()),
      const SizedBox(height:16),
      Text('假期：${updates.holidays.containsKey(year)?'已缓存':year==2026?'内置资料':'未收录'}\n节气：${updates.terms.containsKey(year)?'已缓存':year==2026?'内置资料':'未收录'}'),
      const SizedBox(height:12),
      Text('最近尝试：${updates.checked[year]?.toLocal().toString().split('.').first??'尚未检查'}'),
      if(updates.saved['$year/假期']!=null)Text('假期成功更新：${updates.saved['$year/假期']}'),
      if(updates.saved['$year/节气']!=null)Text('节气成功更新：${updates.saved['$year/节气']}'),
      const SizedBox(height:12),Text(updates.messages[year]??'点击检查可获取所选年份的资料。'),
      if(updates.storageNotice.isNotEmpty)Text(updates.storageNotice),
      const Divider(height:32),
      const Text('资料来源',style:TextStyle(fontWeight:FontWeight.w700)),
      const SizedBox(height:8),
      const SelectableText('放假调休：NateScarlet/holiday-cn（第三方整理国务院公告，并非官方接口）。来源可能滞后或无法连接，失败时不会清空原资料。\nhttps://github.com/NateScarlet/holiday-cn\n\n节气：香港天文台年度公历与农历对照表，按北京时间。与假期独立获取。'),
      const SizedBox(height:12),
      for(final paper in updates.papers(year))SelectableText('原公告：$paper'),
    ])));
}

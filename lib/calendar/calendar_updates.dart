import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef CalendarFetch = Future<({int status, String body})> Function(Uri uri);
const solarNames = ['小寒','大寒','立春','雨水','惊蛰','春分','清明','谷雨','立夏','小满','芒种','夏至','小暑','大暑','立秋','处暑','白露','秋分','寒露','霜降','立冬','小雪','大雪','冬至'];
String simplifiedTerm(String s) => s.replaceAll('驚蟄','惊蛰').replaceAll('穀雨','谷雨').replaceAll('小滿','小满').replaceAll('芒種','芒种').replaceAll('處暑','处暑');

Map<int,({String name,bool off})> parseHolidayYear(String raw,int year) {
  final data=jsonDecode(raw) as Map<String,dynamic>;
  if(data['year']!=year) throw const FormatException('年份不匹配');
  final papers=(data['papers'] as List).cast<String>();
  if(papers.isEmpty || papers.any((p) {final u=Uri.parse(p);return u.scheme!='https'|| !(u.host=='gov.cn'||u.host.endsWith('.gov.cn'));})) throw const FormatException('缺少公告来源');
  final result=<int,({String name,bool off})>{};
  for(final row in data['days'] as List) {
    final s=row['date'] as String;
    if(!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s))throw const FormatException('日期格式');
    final d=DateTime.parse(s), name=row['name'] as String;
    if(d.year!=year || d.toIso8601String().substring(0,10)!=s || name.isEmpty || name.length>40 || row['isOffDay'] is! bool) throw const FormatException('日期字段');
    final key=d.month*100+d.day;
    if(result.containsKey(key))throw const FormatException('重复日期');
    result[key]=(name:name,off:row['isOffDay'] as bool);
  }
  if(result.isEmpty||result.length>366)throw const FormatException('暂无有效日期');
  return result;
}
Map<int,String> parseSolarYear(String raw,int year) {
  final result=<int,String>{};
  final dates=<String>{};
  for(final line in const LineSplitter().convert(raw)) {
    final m=RegExp(r'^(\d{4})年(\d{1,2})月(\d{1,2})日\s+\S+\s+星期\S\s+(\S+)\s*$').firstMatch(line.trim());
    if(m==null)continue;
    final y=int.parse(m[1]!),month=int.parse(m[2]!),day=int.parse(m[3]!);
    final term=simplifiedTerm(m[4]!);
    final date=DateTime(y,month,day);
    if(y!=year||date.month!=month||date.day!=day||!solarNames.contains(term)||!dates.add(term)||result.containsKey(month*100+day))throw const FormatException('节气日期');
    result[month*100+day]=term;
  }
  if(result.length!=24)throw const FormatException('节气不完整');
  return result;
}
Future<({int status,String body})> fetchCalendar(Uri uri) async {
  final client=HttpClient()..connectionTimeout=const Duration(seconds:10);
  try {
    return await (() async {
      final req=await client.getUrl(uri);
      req.followRedirects=false;
      final response=await req.close();
      final bytes=<int>[];
      await for(final chunk in response) {
        if(bytes.length+chunk.length>256000)throw const FormatException('资料过大');
        bytes.addAll(chunk);
      }
      return (status:response.statusCode,body:utf8.decode(bytes));
    })().timeout(const Duration(seconds:15));
  } finally {client.close(force:true);}
}

class CalendarUpdates extends ChangeNotifier with WidgetsBindingObserver {
  CalendarUpdates({CalendarFetch? fetch,Future<String?> Function()? read,Future<void> Function(String)? write,DateTime Function()? clock})
      : fetch=fetch??fetchCalendar,read=read??_read,write=write??_write,clock=clock??DateTime.now;
  static final instance=CalendarUpdates();
  static const _channel=MethodChannel('smart_budget/storage');
  static Future<String?> _read()=>_channel.invokeMethod<String>('loadCalendar');
  static Future<void> _write(String s)=>_channel.invokeMethod<void>('saveCalendar',s);
  final CalendarFetch fetch;
  final Future<String?> Function() read;
  final Future<void> Function(String) write;
  final DateTime Function() clock;
  final holidays=<int,Map<int,({String name,bool off})>>{};
  final terms=<int,Map<int,String>>{};
  final _holidayRaw=<String,String>{},_solarRaw=<String,String>{};
  final checked=<int,DateTime>{};
  final messages=<int,String>{};
  final saved=<String,String>{};
  bool automatic=false,busy=false;
  String storageNotice='';
  Future<void>? _initializing;
  Future<void> initialize()=>_initializing??=_load();
  Future<void> _load() async {
    try {
      final raw=await read();
      if(raw!=null) {
        final data=jsonDecode(raw) as Map<String,dynamic>;
        automatic=data['automatic']==true;
        for(final e in (data['holidays'] as Map<String,dynamic>? ?? {}).entries) {
          try {final y=int.parse(e.key);holidays[y]=parseHolidayYear(e.value as String,y);_holidayRaw[e.key]=e.value as String;} catch(_) {/* Ignore damaged cache only. */}
        }
        for(final e in (data['terms'] as Map<String,dynamic>? ?? {}).entries) {
          try {final y=int.parse(e.key);terms[y]=parseSolarYear(e.value as String,y);_solarRaw[e.key]=e.value as String;} catch(_) {/* Retain valid years. */}
        }
        for(final e in (data['checked'] as Map<String,dynamic>? ?? {}).entries) {final d=DateTime.tryParse(e.value.toString());if(d!=null)checked[int.parse(e.key)]=d;}
        for(final e in (data['messages'] as Map<String,dynamic>? ?? {}).entries) {messages[int.parse(e.key)]=e.value.toString();}
        for(final e in (data['saved'] as Map<String,dynamic>? ?? {}).entries) {saved[e.key]=e.value.toString();}
      }
    } catch(_) {storageNotice='本机日期缓存暂不可读取，继续使用内置资料。';}
    notifyListeners();
  }
  Future<void> _persist() async {
    try {await write(jsonEncode({'automatic':automatic,'holidays':_holidayRaw,'terms':_solarRaw,
      'checked':checked.map((y,d)=>MapEntry('$y',d.toIso8601String())),
      'messages':messages.map((y,s)=>MapEntry('$y',s)),'saved':saved}));storageNotice='';}
    catch(_) {storageNotice='保存失败；本次资料仅在当前运行中可用。';}
  }
  Future<void> setAutomatic(bool value) async {
    await initialize();automatic=value;await _persist();notifyListeners();
    if(value)await autoCheck();
  }
  Future<void> autoCheck() async {
    await initialize();
    if(!automatic||busy)return;
    final now=clock();
    for(final year in [now.year,now.year+1]) {
      if(!automatic)return;
      final last=checked[year];
      if(last==null||now.difference(last)>=const Duration(hours:24)||now.isBefore(last))await check(year);
    }
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state==AppLifecycleState.resumed)unawaited(autoCheck());
  }
  Future<void> check(int year) async {
    await initialize();
    if(busy||year<2007||year>clock().year+1)return;
    busy=true;notifyListeners();
    final results=<String>[];
    try {
      for(final kind in ['假期','节气']) {
        final uri=Uri.parse(kind=='假期'
          ?'https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/$year.json'
          :'https://www.hko.gov.hk/tc/gts/time/calendar/text/files/T${year}c.txt');
        try {
          final response=await fetch(uri);
          if(response.status==404) {results.add('$kind：来源暂无该年资料（不代表官方未公布）');continue;}
          if(response.status!=200) {results.add('$kind：服务器返回 ${response.status}，保留原资料');continue;}
          if(kind=='假期') {final parsed=parseHolidayYear(response.body,year);holidays[year]=parsed;_holidayRaw['$year']=response.body;}
          else {final parsed=parseSolarYear(response.body,year);terms[year]=parsed;_solarRaw['$year']=response.body;}
          saved['$year/$kind']=clock().toIso8601String();
          results.add('$kind：更新成功');
        } on FormatException {results.add('$kind：格式校验未通过，保留原资料');}
        on TypeError {results.add('$kind：格式校验未通过，保留原资料');}
        catch(_) {results.add('$kind：网络连接失败或超时，保留原资料');}
      }
      checked[year]=clock();messages[year]=results.join('\n');await _persist();
    } finally {busy=false;notifyListeners();}
  }
  List<String> papers(int year) {
    final raw=_holidayRaw['$year'];
    if(raw==null)return [];
    return ((jsonDecode(raw) as Map<String,dynamic>)['papers'] as List).cast<String>();
  }
}

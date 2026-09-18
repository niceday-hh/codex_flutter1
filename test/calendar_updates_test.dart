import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/calendar/calendar_updates.dart';
import 'package:smart_budget/calendar/date_context.dart';

void main() {
  final holiday=File('test/fixtures/calendar/holidays_2026.json').readAsStringSync();
  final solar=File('test/fixtures/calendar/solar_2027.txt').readAsStringSync();
  test('real sources parse holiday overrides and all 24 solar terms',(){
    final h=parseHolidayYear(holiday,2026),s=parseSolarYear(solar,2027);
    expect(h[920]!.off,isFalse);expect(h[925]!.name,'中秋节');expect(s.length,24);expect(s[204],'立春');
    expect(()=>parseHolidayYear(holiday,2027),throwsFormatException);
    expect(()=>parseSolarYear(solar,2026),throwsFormatException);
    expect(()=>parseSolarYear(solar.split('\n').take(20).join('\n'),2027),throwsFormatException);
    final bad=jsonDecode(holiday) as Map<String,dynamic>;
    (bad['days'] as List).add((bad['days'] as List).first);
    expect(()=>parseHolidayYear(jsonEncode(bad),2026),throwsFormatException);
  });
  test('partial success persists across restart and unknown holiday stays unknown',()async{
    String? saved;
    final u=CalendarUpdates(read:()async=>null,write:(s)async{saved=s;},clock:()=>DateTime(2026,12),
      fetch:(uri)async=>uri.host=='www.hko.gov.hk'?(status:200,body:solar):(status:404,body:''));
    await u.check(2027);
    expect(u.terms[2027]!.length,24);expect(u.holidays.containsKey(2027),isFalse);
    final restored=CalendarUpdates(read:()async=>saved,write:(_)async{});
    await restored.initialize();
    final context=dateContext(DateTime(2027,2,4),updates:restored);
    expect(context.term,'立春');expect(context.termsKnown,isTrue);expect(context.known,isFalse);
    expect(restored.messages[2027],contains('不代表官方未公布'));
    u.dispose();restored.dispose();
  });
  test('bad response, 404 and connection failure never erase a good cache',()async{
    var mode=0;
    final u=CalendarUpdates(read:()async=>null,write:(_)async{},clock:()=>DateTime(2026,9),fetch:(uri)async{
      if(uri.host!='raw.githubusercontent.com')return(status:404,body:'');
      if(mode==3)throw const SocketException('offline');
      return(status:mode==2?404:200,body:mode==1?'{}':holiday);
    });
    await u.check(2026);final cached=u.holidays[2026];
    for(mode=1;mode<=3;mode++) {await u.check(2026);expect(identical(u.holidays[2026],cached),isTrue);}
    expect(u.messages[2026],contains('网络连接失败'));
    u.dispose();
  });
  test('automatic is opt-in, rate-limited per year, retries tomorrow and follows rollover',()async{
    var count=0,now=DateTime(2026,12,31,10);
    final u=CalendarUpdates(read:()async=>null,write:(_)async{},clock:()=>now,
      fetch:(uri)async{count++;return(status:404,body:'');});
    await u.autoCheck();expect(count,0);
    await u.setAutomatic(true);expect(count,4);
    await u.autoCheck();expect(count,4);
    now=DateTime(2027,1,1,9);await u.autoCheck();expect(count,6); // new 2028, 2027 still throttled
    now=DateTime(2027,1,1,11);await u.autoCheck();expect(count,8);
    await u.setAutomatic(false);now=DateTime(2027,1,3);await u.autoCheck();expect(count,8);
    u.dispose();
  });
  test('save failure is visible rather than claiming durable success',()async{
    final u=CalendarUpdates(read:()async=>null,write:(_)async{throw const FileSystemException('disk full');},
      clock:()=>DateTime(2026),fetch:(uri)async=>(status:404,body:''));
    await u.check(2026);expect(u.storageNotice,contains('仅在当前运行中可用'));
    u.dispose();
  });
}

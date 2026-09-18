import 'calendar_updates.dart';
/// Mainland China 2026 published schedule; solar terms use HKO UTC+8 dates.
/// Unsupported years are explicitly unknown, never extrapolated as workdays.
class DateContext {
  const DateContext({required this.known, required this.weekend, this.holiday, this.term, this.makeup = false, bool? termsKnown}) : termsKnown = termsKnown ?? known;
  final bool known, weekend, makeup, termsKnown;
  final String? holiday, term;
  String get shortLabel => makeup ? '补班' : term ?? holiday ?? (weekend ? '周末' : '');
  List<String> get labels => [
    if (holiday != null) '$holiday假期', if (makeup) '调休补班',
    if (term != null) '$term · 节气', if (weekend && !makeup && holiday == null) '周末',
    if (!known) '该年假期资料未收录',
    if (!termsKnown) '该年节气资料未收录',
    if (known && !weekend && !makeup && holiday == null) '普通工作日',
  ];
}
DateContext _builtInContext(DateTime date) {
  final key = date.month * 100 + date.day;
  if (date.year != 2026) return DateContext(known:false,weekend:date.weekday>=6);
  String? holiday;
  for (final range in const <(int,int,String)>[
    (101,103,'元旦'),(215,223,'春节'),(404,406,'清明'),(501,505,'劳动'),
    (619,621,'端午'),(925,927,'中秋'),(1001,1007,'国庆'),
  ]) { if (key>=range.$1 && key<=range.$2) holiday=range.$3; }
  const terms = <int,String>{105:'小寒',120:'大寒',204:'立春',218:'雨水',305:'惊蛰',320:'春分',
    405:'清明',420:'谷雨',505:'立夏',521:'小满',605:'芒种',621:'夏至',707:'小暑',723:'大暑',
    807:'立秋',823:'处暑',907:'白露',923:'秋分',1008:'寒露',1023:'霜降',1107:'立冬',1122:'小雪',1207:'大雪',1222:'冬至'};
  return DateContext(known:true,weekend:date.weekday>=6,holiday:holiday,term:terms[key],
    makeup:const {104,214,228,509,920,1010}.contains(key));
}

DateContext dateContext(DateTime date, {CalendarUpdates? updates}) {
  final source = updates ?? CalendarUpdates.instance;
  final base = _builtInContext(date);
  final year = source.holidays[date.year];
  final day = year?[date.month * 100 + date.day];
  return DateContext(known: year != null || base.known,
    termsKnown: source.terms.containsKey(date.year) || base.termsKnown,
    weekend: base.weekend,
    holiday: year == null ? base.holiday : day != null && day.off ? day.name : null,
    makeup: year == null ? base.makeup : day != null && !day.off,
    term: source.terms.containsKey(date.year) ? source.terms[date.year]![date.month * 100 + date.day] : base.term);
}

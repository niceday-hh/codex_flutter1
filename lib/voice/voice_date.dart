// Calendar-only Mandarin dates. No model, network, or additional dependency.
class VoiceDateResult {
  const VoiceDateResult(this.date, this.body, this.warnings);
  final DateTime date;
  final String body;
  final List<String> warnings;
}

class _DateCandidate {
  const _DateCandidate(this.start, this.end, this.date, this.rank,
      {this.weekday, this.corrected = false});
  final int start, end, rank;
  final DateTime? date;
  final int? weekday;
  final bool corrected;
}

const _integer = r'[0-9零〇一二两三四五六七八九十]+';
int _dateNumber(String source) {
  const digits = {'零': '0', '〇': '0', '一': '1', '二': '2', '两': '2',
    '三': '3', '四': '4', '五': '5', '六': '6', '七': '7', '八': '8', '九': '9'};
  final value = source.replaceAllMapped(RegExp('[零〇一二两三四五六七八九]'),
      (m) => digits[m[0]]!);
  if (!value.contains('十')) return int.tryParse(value) ?? -1;
  final parts = value.split('十');
  if (parts.length != 2) return -1;
  return (parts.first.isEmpty ? 1 : int.tryParse(parts.first) ?? -100) * 10 +
      (parts.last.isEmpty ? 0 : int.tryParse(parts.last) ?? -100);
}

VoiceDateResult parseVoiceDate(String text, DateTime now) {
  final candidates = <_DateCandidate>[];
  final occupied = <(int, int)>[];
  final warnings = <String>[];
  final today = DateTime(now.year, now.month, now.day);
  DateTime at(int year, int month, int day) =>
      DateTime(year, month, day, now.hour, now.minute);
  DateTime? checked(int year, int month, int day) {
    if (year < 1 || year > 9999 || month < 1 || month > 12 || day < 1 || day > 31) return null;
    final value = at(year, month, day);
    return value.year == year && value.month == month && value.day == day ? value : null;
  }
  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  bool overlaps(RegExpMatch m) => occupied.any((r) => m.start < r.$2 && m.end > r.$1);
  void collect(RegExp pattern, DateTime? Function(RegExpMatch) resolve, int rank,
      {int Function(RegExpMatch)? weekday}) {
    for (final m in pattern.allMatches(text)) {
      if (overlaps(m)) continue;
      occupied.add((m.start, m.end));
      final before = text.substring(0, m.start);
      final after = text.substring(m.end);
      // An object's date is not necessarily the payment date:
      // “今天买了明天的电影票”, “交了上个月的电费”. Keep it in the note.
      if (RegExp(r'^\s*的').hasMatch(after) &&
          RegExp(r'买|订|预订|预定|交|缴|付|支付|补交|报销').hasMatch(before)) continue;
      // Explicitly rejected date: “不是昨天，是前天”.
      if (RegExp(r'(?:不是|并非|不要记|不记在)\s*$').hasMatch(before)) continue;
      candidates.add(_DateCandidate(m.start, m.end, resolve(m), rank,
        weekday: weekday?.call(m),
        corrected: RegExp(r'(?:不对[,，]?\s*(?:是)?|改成|改为|应该是|更正为)\s*$').hasMatch(before)));
    }
  }

  collect(RegExp('(?:(今年|去年|前年|明年)|($_integer)\\s*年)?\\s*'
      '($_integer)\\s*月\\s*($_integer)\\s*(?:[日号]|(?![0-9零〇一二两三四五六七八九十元块角毛分]))'), (m) {
    final offset = const {'今年': 0, '去年': -1, '前年': -2, '明年': 1}[m[1]] ?? 0;
    final year = m[2] == null ? now.year + offset : _dateNumber(m[2]!);
    return checked(year, _dateNumber(m[3]!), _dateNumber(m[4]!));
  }, 3);
  collect(RegExp(r'(?<![0-9])(\d{4})\s*[-/]\s*(\d{1,2})\s*[-/]\s*(\d{1,2})(?![0-9])'),
      (m) => checked(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)), 3);
  collect(RegExp('(上上个月|上个月|上月|这个月|本月|下个月|下月)\\s*($_integer)\\s*[日号]'), (m) {
    final offset = const {'上上个月': -2, '上个月': -1, '上月': -1,
      '这个月': 0, '本月': 0, '下个月': 1, '下月': 1}[m[1]]!;
    final month = DateTime(now.year, now.month + offset, 1);
    return checked(month.year, month.month, _dateNumber(m[2]!));
  }, 3);
  collect(RegExp('($_integer)\\s*天(?:以)?前'), (m) {
    final days = _dateNumber(m[1]!);
    return days < 0 || days > 3660 ? null : at(now.year, now.month, now.day - days);
  }, 2);
  collect(RegExp(r'大前天|前天|昨天|昨晚|今天|今日|明天|后天'), (m) {
    final offset = const {'大前天': -3, '前天': -2, '昨天': -1, '昨晚': -1,
      '今天': 0, '今日': 0, '明天': 1, '后天': 2}[m[0]]!;
    return at(now.year, now.month, now.day + offset);
  }, 2);
  int dayOfWeek(RegExpMatch m) => '一二三四五六日'.indexOf(m[2]!.replaceAll('天', '日')) + 1;
  collect(RegExp(r'(上上|上|这|本|下)?(?:周(?:星期|礼拜)?|星期|礼拜)([一二三四五六日天])'), (m) {
    var offset = dayOfWeek(m) - now.weekday;
    final week = m[1];
    if (week == null && offset > 0) offset -= 7;
    offset += (const {'上上': -2, '上': -1, '这': 0, '本': 0, '下': 1}[week] ?? 0) * 7;
    return at(now.year, now.month, now.day + offset);
  }, 1, weekday: dayOfWeek);

  // Detect but do not invent a specific date for vague/unsupported expressions.
  collect(RegExp('(上上个月|上个月|上月|本月|这个月|下个月|下月|去年|前年|上周末|前几天|最近几天|'
      '农历[^,，;； ]{0,8}|春节|中秋节|国庆节|端午节|($_integer)\\s*[日号])'), (_) => null, 0);
  final corrected = candidates.where((c) => c.corrected).toList();
  final effective = corrected.isEmpty ? candidates : candidates.where((c) => c.start >= corrected.last.start).toList();
  final valid = effective.where((c) => c.date != null).toList()
    ..sort((a, b) => a.rank != b.rank ? b.rank.compareTo(a.rank) : a.start.compareTo(b.start));
  var date = now;
  if (valid.isNotEmpty) {
    final selected = valid.first;
    date = selected.date!;
    for (final other in valid.skip(1)) {
      final matches = selected.rank == 3 && other.weekday != null
          ? date.weekday == other.weekday : sameDay(date, other.date!);
      if (!matches) {
        warnings.add('日期表述存在冲突，请核对记账日期');
        break;
      }
    }
    if (DateTime(date.year, date.month, date.day).isAfter(today)) {
      warnings.add('日期在未来，请核对日期和年份');
    }
  }
  if (effective.any((c) => c.date == null)) warnings.add('日期不明确，请核对');
  // Remove only transaction date spans, preserving object/billing dates in notes.
  var body = text;
  for (final c in candidates.toList()..sort((a, b) => b.start.compareTo(a.start))) {
    body = body.replaceRange(c.start, c.end, ' ' * (c.end - c.start));
  }
  return VoiceDateResult(date, body, List.unmodifiable(warnings));
}

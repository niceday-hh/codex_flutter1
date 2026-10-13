// Local, deterministic Mandarin bookkeeping rules. No network or language model.
class VoiceDraft {
  const VoiceDraft({required this.rawText, required this.amount, required this.isIncome,
    required this.category, required this.note, required this.date, this.warnings = const []});
  final String rawText, category, note;
  final double? amount;
  final bool isIncome;
  final DateTime date;
  final List<String> warnings;
  VoiceDraft copyWith({double? amount, bool? isIncome, String? category, String? note, DateTime? date}) =>
    VoiceDraft(rawText: rawText, amount: amount ?? this.amount, isIncome: isIncome ?? this.isIncome,
      category: category ?? this.category, note: note ?? this.note, date: date ?? this.date, warnings: warnings);
}

class _Money {
  const _Money(this.start, this.end, this.value, this.priority);
  final int start, end, priority;
  final double value;
}

const _number = r'[0-9零〇一二两三四五六七八九十百千万亿]+(?:[.点][0-9零〇一二两三四五六七八九]+)?';

VoiceDraft parseVoiceEntry(String raw, {DateTime? now}) {
  final today = now ?? DateTime.now();
  var text = raw.replaceAllMapped(RegExp(r'[０-９]'), (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0xfee0))
      .replaceAll('．', '.').replaceAll('，', ',').replaceAll('。', ' ').replaceAll(RegExp(r'(?<=\d),(?=\d{3}(?:\D|$))'), '');
  final warnings = <String>[];
  final noteMarker = RegExp(r'(?:备注(?:为|是|叫|写)?|记作|标注(?:为|是)?)\s*[:：]?\s*').firstMatch(text);
  final explicitNote = noteMarker == null ? null : text.substring(noteMarker.end).trim();
  var body = noteMarker == null ? text : text.substring(0, noteMarker.start);
  var date = today;
  final absoluteDate = RegExp(r'(?:([0-9]{4})年)?([0-9]{1,2})月([0-9]{1,2})[日号]').firstMatch(body);
  if (absoluteDate != null) {
    final year = int.parse(absoluteDate[1] ?? '${today.year}');
    final month = int.parse(absoluteDate[2]!); final day = int.parse(absoluteDate[3]!);
    final parsed = DateTime(year, month, day, today.hour, today.minute);
    if (parsed.year == year && parsed.month == month && parsed.day == day) { date = parsed; }
    else { warnings.add('日期不明确，请核对'); }
    body = body.replaceRange(absoluteDate.start, absoluteDate.end, ' ');
  } else if (body.contains('大前天')) { date = today.subtract(const Duration(days: 3)); }
  else if (body.contains('前天')) { date = today.subtract(const Duration(days: 2)); }
  else if (body.contains('昨天') || body.contains('昨晚')) { date = today.subtract(const Duration(days: 1)); }
  final weekday = RegExp(r'(上周|这周|本周)?(?:周|星期|礼拜)([一二三四五六日天])').firstMatch(body);
  if (weekday != null) {
    final target = '一二三四五六日'.indexOf(weekday[2]!.replaceAll('天', '日')) + 1;
    var offset = today.weekday - target;
    if (weekday[1] == '上周') { offset += 7; }
    else if (weekday[1] == null && offset < 0) { offset += 7; }
    date = today.subtract(Duration(days: offset));
    body = body.replaceRange(weekday.start, weekday.end, ' ');
  }
  body = body.replaceAll(RegExp(r'(?:今天|昨天|前天|大前天|昨晚|刚才|刚刚|早上|中午|晚上|上午|下午)'), ' ')
    .replaceAll(RegExp(r'(?:\d{1,2}|[一二三四五六七八九十]+)[点时](?:半|(?:\d{1,2}|[一二三四五六七八九十]+)分)?(?=\s|[,，]|花|买|吃|喝|付|收到|打车|$)'), ' ');
  // Negated income phrases must not turn purchases into income.
  final typeBody = body.replaceAll(RegExp(r'(?:没有|还没|没|未|不是|不算)(?:有)?(?:收到|收入|到账|报销|退款|发工资|工资)'), ' ');
  final income = RegExp(r'收入|进账|到账|收到|收到了|收款|赚了|挣了|发工资|工资发了|领工资|报销|退款|退回|退了').hasMatch(typeBody)
    && !RegExp(r'(?:转给|给别人|还给|付给|借给)').hasMatch(typeBody);
  final candidates = <_Money>[];
  void add(RegExp pattern, double Function(RegExpMatch) value) {
    for (final m in pattern.allMatches(body)) {
      if (candidates.any((c) => m.start < c.end && m.end > c.start)) continue;
      final prefix = body.substring(m.start > 12 ? m.start - 12 : 0, m.start);
      final priority = RegExp(r'不对|改成|应该是|实际|实付|最后|最终').hasMatch(prefix) ? 3 :
        RegExp(r'一共|总共|合计|总计').hasMatch(prefix) ? 2 : 0;
      candidates.add(_Money(m.start, m.end, value(m), priority));
    }
  }
  add(RegExp('($_number)(?:元|块)(?:钱)?(?:($_number)(?:毛|角)(?:($_number)分?)?|($_number)分|($_number))?'), (m) {
    var n = mandarinNumber(m[1]!);
    if (m[2] != null) { n += mandarinNumber(m[2]!) / 10; }
    if (m[3] != null) { n += mandarinNumber(m[3]!) / 100; }
    if (m[4] != null) { n += mandarinNumber(m[4]!) / 100; }
    if (m[5] != null) {
      final digits = m[5]!.replaceAllMapped(RegExp('[零〇一二两三四五六七八九]'), (x) => '${_digits[x[0]]}');
      n += mandarinNumber(m[5]!) / (digits.length == 1 ? 10 : 100);
    }
    return n;
  });
  add(RegExp('($_number)(?:毛|角)(?:($_number)分?)?'), (m) => mandarinNumber(m[1]!) / 10 + (m[2] == null ? 0 : mandarinNumber(m[2]!) / 100));
  add(RegExp('($_number)分'), (m) => mandarinNumber(m[1]!) / 100);
  add(RegExp('(?:人民币|¥|￥)\\s*($_number)'), (m) => mandarinNumber(m[1]!));
  add(RegExp('(?:花了?|付了?|支付了?|支出|收入|收到|到账|金额|价格|付款|收款|赚了?|一共|总共|合计|实付|改成|应该是)\\s*($_number)'), (m) => mandarinNumber(m[1]!));
  if (candidates.isEmpty) {
    // Bare amounts are accepted only when not followed by a quantity/date unit.
    for (final m in RegExp(_number).allMatches(body)) {
      final suffix = body.substring(m.end);
      if (RegExp(r'^\s*(?:个|杯|件|瓶|份|斤|公斤|千克|包|张|次|年|月|日|号|点|时|分钟|公里|人|折)').hasMatch(suffix)) continue;
      candidates.add(_Money(m.start, m.end, mandarinNumber(m[0]!), 0));
    }
    if (candidates.isNotEmpty) warnings.add('未说金额单位，请核对金额');
  }
  _Money? selected;
  if (candidates.length == 1) { selected = candidates.single; }
  else if (candidates.length > 1) {
    final prioritized = candidates.where((c) => c.priority > 0).toList()..sort((a,b) => a.priority != b.priority ? a.priority.compareTo(b.priority) : a.start.compareTo(b.start));
    if (prioritized.isNotEmpty) { selected = prioritized.last; warnings.add('包含多个金额，已采用总额或更正后的金额，请核对'); }
    else { warnings.add('识别到多个金额，请填写本次总额；暂不自动合并多笔账'); }
  }
  final amount = selected == null ? null : (selected.value * 100).round() / 100;
  if (amount == null && candidates.isEmpty) warnings.add('未识别到金额，请补充');
  if (amount != null && (amount <= 0 || amount > 999999999)) warnings.add('金额需大于零且不超过九位数字');
  final category = _category(body, income);
  if (category == '其他') warnings.add('用途不明确，请选择分类');
  var note = explicitNote;
  if (note == null || note.isEmpty) {
    note = body;
    for (final c in candidates.toList()..sort((a,b) => b.start.compareTo(a.start))) {
      note = note!.replaceRange(c.start, c.end, ' ');
    }
    note = note!.replaceAll(RegExp(r'分类(?:为|是)?\s*[\u4e00-\u9fa5]+'), ' ')
      .replaceAll(RegExp(r'记一笔|帮我记|记一下|记个账|收入|支出|花了|花费|支付了|付款|付了|一共|总共|合计|买了|购买了|买的|买|收到|到账|吃的|喝的'), ' ')
      .replaceAll(RegExp(r'[\s,，。:：;；]+'), ' ').trim();
  }
  if (note.isEmpty) note = category;
  return VoiceDraft(rawText: raw.trim(), amount: amount, isIncome: income, category: category,
    note: note, date: date, warnings: List.unmodifiable(warnings));
}

const _digits = {'零':0,'〇':0,'一':1,'二':2,'两':2,'三':3,'四':4,'五':5,'六':6,'七':7,'八':8,'九':9};
double mandarinNumber(String source) {
  final normalized = source.replaceAll('点', '.').replaceAllMapped(RegExp('[零〇一二两三四五六七八九]'), (m) => '${_digits[m[0]]}');
  if (!RegExp('[十百千万亿]').hasMatch(source)) return double.tryParse(normalized) ?? 0;
  final parts = source.split(RegExp('[.点]'));
  var total = 0.0, section = 0.0, digit = 0.0, lastUnit = 1.0;
  for (final rune in parts.first.runes) {
    final c = String.fromCharCode(rune);
    final d = _digits[c] ?? int.tryParse(c);
    if (d != null) { digit = digit * 10 + d; continue; }
    final unit = const {'十':10.0,'百':100.0,'千':1000.0,'万':10000.0,'亿':100000000.0}[c];
    if (unit == null) continue;
    if (unit < 10000) { section += (digit == 0 ? 1 : digit) * unit; }
    else { total += (section + digit) * unit; section = 0; }
    digit = 0; lastUnit = unit;
  }
  // Common spoken shorthand: 一百二=120, 一千五=1500; 零 explicitly disables it.
  final shorthand = RegExp(r'[百千万][一二两三四五六七八九]$').hasMatch(parts.first);
  var value = total + section + (shorthand ? digit * lastUnit / 10 : digit);
  if (parts.length > 1) {
    final fraction = parts.last.replaceAllMapped(RegExp('[零〇一二两三四五六七八九]'), (m) => '${_digits[m[0]]}');
    value += double.tryParse('0.$fraction') ?? 0;
  }
  return value;
}

String _category(String text, bool income) {
  final names = income ? const ['工资','兼职','理财','礼金','奖金','报销','退款','其他'] : const [
    '餐饮','购物','日用','交通','蔬菜','水果','零食','运动','娱乐','通讯','服饰','美容','住房','居家','孩子','长辈','社交','旅行','烟酒','数码','汽车','医疗','书籍','学习','宠物','礼金','礼物','办公','维修','捐赠','彩票','亲友','快递','其他'];
  final explicit = RegExp('分类(?:为|是)?\\s*(${names.join('|')})').firstMatch(text);
  if (explicit != null) return explicit[1]!;
  final rules = income ? _incomeRules : _expenseRules;
  for (final rule in rules.entries) {
    if (rule.value.any(text.contains)) return rule.key;
  }
  return income ? '其他' : (RegExp(r'吃|喝').hasMatch(text) ? '餐饮' : RegExp(r'买|购买|购物').hasMatch(text) ? '购物' : '其他');
}
const _incomeRules = {
  '退款':['退款','退回','退了','退货'], '报销':['报销'], '奖金':['奖金','年终奖','奖励'],
  '工资':['工资','薪水','薪资','发薪'], '兼职':['兼职','副业','外快','稿费','接单'],
  '理财':['利息','理财','分红','收益'], '礼金':['红包','礼金','份子钱'],
};
// Specific purposes precede broad buying/eating/home-use words.
const _expenseRules = {
  '住房':['房租','租房','房贷','物业','水电','电费','水费','燃气','暖气'],
  '医疗':['看病','挂号','医院','药品','买药','体检','牙医'],
  '宠物':['猫粮','狗粮','宠物','猫砂','兽医'], '汽车':['加油','汽油','停车','车险','洗车','保养'],
  '数码':['手机','电脑','耳机','键盘','鼠标','平板','充电器','相机'],
  '通讯':['话费','网费','宽带','流量','通讯'], '学习':['学费','培训','课程','网课','辅导','考试'],
  '书籍':['买书','书本','图书','小说','杂志'], '服饰':['衣服','衣裤','裤子','鞋','外套','裙','服装','袜子'],
  '美容':['护肤','化妆','美容','理发','美甲','洗面奶'], '居家':['家电','家具','装修','家装','床','沙发','冰箱','空调','厨具'],
  '交通':['地铁','公交','打车','出租车','滴滴','车票','高铁','火车','机票','出行'],
  '旅行':['旅游','旅行','酒店','住宿','民宿','景点','门票'], '烟酒':['香烟','买烟','烟酒','啤酒','白酒','红酒'],
  '水果':['苹果','香蕉','水果','橙子','葡萄','西瓜','草莓','榴莲'],
  '蔬菜':['蔬菜','买菜','青菜','白菜','土豆','番茄','西红柿','黄瓜'],
  '零食':['零食','薯片','饼干','巧克力','糖果','坚果'],
  '餐饮':['奶茶','咖啡','饮料','矿泉水','早餐','早饭','午饭','午餐','晚饭','晚餐','夜宵','外卖','餐厅','饭店','牛肉面','面条','火锅','烧烤','吃饭','聚餐'],
  '日用':['纸巾','卫生纸','洗衣液','洗洁精','牙膏','牙刷','洗发水','沐浴露','日用品','生活用品','家用','家里用','家庭用品'],
  '运动':['健身','运动','游泳','跑步','瑜伽','球场'], '娱乐':['电影','游戏','唱歌','KTV','会员','演唱会'],
  '孩子':['孩子','宝宝','奶粉','尿不湿','玩具'], '长辈':['父母','爸妈','长辈','孝敬'],
  '礼物':['礼物','送礼','生日礼物'], '礼金':['礼金','份子钱','随礼','红包'], '办公':['办公','文具','打印'],
  '维修':['修理','维修'], '捐赠':['捐赠','捐款'], '彩票':['彩票'], '快递':['快递','运费','邮费'],
  '亲友':['借给','还给','转给'], '社交':['请客','社交'],
};

import '../notes/note_catalog.dart';
import 'voice_category.dart';
import 'voice_date.dart';

// Local, deterministic Mandarin bookkeeping rules with personal note history.
class VoiceDraft {
  const VoiceDraft({required this.rawText, required this.amount, required this.isIncome,
    required this.category, required this.note, required this.date, this.warnings = const [],
    this.categoryReason = '', this.categorySuggestions = const []});
  final String rawText, category, note;
  final double? amount;
  final bool isIncome;
  final DateTime date;
  final List<String> warnings;
  final String categoryReason;
  final List<VoiceCategorySuggestion> categorySuggestions;
  VoiceDraft copyWith({double? amount, bool? isIncome, String? category, String? note, DateTime? date}) {
    final updatedWarnings = warnings.where((w) =>
      !(amount != null && (w.contains('金额') || w.contains('总额'))) &&
      !(category != null && (w.contains('分类') || w.contains('用途'))) &&
      !(date != null && w.contains('日期'))).toList();
    if (amount != null && (amount <= 0 || amount > 999999999)) updatedWarnings.add('金额需大于零且不超过九位数字');
    if (category == '其他') updatedWarnings.add('用途不明确，请选择分类');
    return VoiceDraft(rawText: rawText, amount: amount ?? this.amount, isIncome: isIncome ?? this.isIncome,
      category: category ?? this.category, note: note ?? this.note, date: date ?? this.date,
      warnings: List.unmodifiable(updatedWarnings),
      categoryReason: category == null ? categoryReason : '',
      categorySuggestions: category == null ? categorySuggestions : const []);
  }
}

class _Money {
  const _Money(this.start, this.end, this.value, this.priority);
  final int start, end, priority;
  final double value;
}

const _number = r'[0-9零〇一二两三四五六七八九十百千万亿]+(?:[.点][0-9零〇一二两三四五六七八九]+)?';

// Restrict negation removal to explicit rejected phrases. Do not strip arbitrary
// prose after a bare “不”; keep the affirmative replacement and original raw text.
String _withoutRejectedPhrases(String text) {
  return text.replaceAll(RegExp(
      r'(?:不是|并非|不算)(?:(?![,，;；]|而是|是).)+?(?:[,，;；]\s*(?:而)?是|而是|是)'), ' ')
    .replaceAll(RegExp(
      '(?:没有|还没|没|未)(?:有)?(?:收到|收入|到账|报销|退款|发工资)'
      '(?:工资|薪水|奖金|钱|款)?(?:\\s*$_number(?:元|块)(?:钱)?)?'), ' ');
}

String _maskNonMoney(String text) {
  var masked = text;
  void mask(RegExp pattern) {
    masked = masked.replaceAllMapped(pattern, (m) => ' ' * m[0]!.length);
  }
  // Clock times must not mask decimal prices such as “二十八点五元”.
  mask(RegExp(r'(?:[0-9]{1,2}|[一二两三四五六七八九十]+)[点时](?:半|(?:[0-9]{1,2}|[一二三四五六七八九十]+)分)?(?=\s|[,，]|花|买|吃|喝|付|收到|打车|$)'));
  mask(RegExp(r'\d{1,2}:\d{2}(?::\d{2})?'));
  mask(RegExp('$_number\\s*(?:分钟|小时|秒钟|秒|公里|千米|公斤|千克|毫升|升|厘米|平方米|个月|天|年|月|日|号|个|杯|件|瓶|份|斤|包|张|次|人|折|笔|期|积分|分贝|码|成)(?![元块])'));
  return masked;
}

VoiceDraft parseVoiceEntry(String raw, {DateTime? now, NoteCatalog? catalog,
    bool? incomeOverride, String? noteOverride}) {
  final today = now ?? DateTime.now();
  var text = raw.replaceAllMapped(RegExp(r'[０-９]'), (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0xfee0))
      .replaceAll('．', '.').replaceAll('，', ',').replaceAll('。', ' ').replaceAll(RegExp(r'(?<=\d),(?=\d{3}(?:\D|$))'), '');
  final warnings = <String>[];
  final noteMarker = RegExp(r'(?:备注(?:为|是|叫|写)?|记作|标注(?:为|是)?)\s*[:：]?\s*').firstMatch(text);
  final noteTail = noteMarker == null ? null : text.substring(noteMarker.end).trim();
  // Allow “备注牛肉面，花了28元”, while keeping quantities inside a
  // remark (“备注买了2杯咖啡”) out of amount extraction.
  final trailingTransaction = noteTail == null ? null : RegExp(
    '[,;；]\\s*(?=(?:(?:花了?|支付了?|付了?|支出|收入|金额|价格|一共|总共|实付)\\s*$_number|$_number(?:元|块)))').firstMatch(noteTail);
  final explicitNote = noteOverride ?? (trailingTransaction == null ? noteTail : noteTail!.substring(0, trailingTransaction.start).trim());
  var body = noteMarker == null ? text : text.substring(0, noteMarker.start);
  if (trailingTransaction != null) body += ' ${noteTail!.substring(trailingTransaction.end)}';
  body = _withoutRejectedPhrases(body);
  final parsedDate = parseVoiceDate(body, today);
  final date = parsedDate.date;
  warnings.addAll(parsedDate.warnings);
  body = parsedDate.body;
  // Keep quantity/duration spans in the note, but mask them for all money rules.
  // Equal-length masking preserves offsets used by note extraction.
  final moneyBody = _maskNonMoney(body);
  final typeBody = body.replaceAll(RegExp(
      r'(?:没有|还没|没|未|不是|不算)(?:有)?(?:收到(?:工资|薪水|奖金)?|收入|到账|报销|退款|发工资|工资)'), ' ');
  final cashReceipt = RegExp('收到\\s*(?:$_number|钱|款|工资|薪水|奖金|红包|转账|退款|报销|货款)').hasMatch(_maskNonMoney(typeBody));
  final explicitIncome = RegExp(r'收入|进账|到账|收款|赚了|挣了|发工资|工资发了|领工资|报销|退款|退回|退了').hasMatch(typeBody) || cashReceipt;
  final implicitIncome = RegExp(r'薪水|工资|奖金|利息|分红').hasMatch(typeBody)
    && !RegExp(r'买|购买|花|支付|付给|转给|还没|没发|没有').hasMatch(body);
  final outgoing = RegExp(r'支出|转给|给别人|还给|付给|借给').hasMatch(typeBody);
  final income = incomeOverride ?? (!outgoing && (explicitIncome || implicitIncome));
  if (incomeOverride == null && explicitIncome &&
      RegExp('(?:花了?|支付了?|付了?)\\s*$_number').hasMatch(typeBody)) {
    warnings.add('同时提到收款和付款，请核对收支类型与金额');
  }
  final candidates = <_Money>[];
  void add(RegExp pattern, double Function(RegExpMatch) value) {
    for (final m in pattern.allMatches(moneyBody)) {
      if (candidates.any((c) => m.start < c.end && m.end > c.start)) continue;
      final prefix = moneyBody.substring(m.start > 12 ? m.start - 12 : 0, m.start);
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
    for (final m in RegExp(_number).allMatches(moneyBody)) {
      final suffix = moneyBody.substring(m.end);
      if (RegExp(r'^\s*(?:个|杯|件|瓶|份|斤|公斤|千克|包|张|次|年|月|日|号|点|时|分钟|公里|人|折|笔)').hasMatch(suffix)) continue;
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
  final categoryText = '$body ${explicitNote ?? ''}';
  final history = matchVoiceNotes(categoryText, income, catalog, today);
  final explicitCategory = _explicitCategory(body, income);
  final specific = _specificCategory(history.removeFrom(categoryText), income);
  final String category;
  var categoryReason = '';
  if (explicitCategory != null) {
    category = explicitCategory;
    categoryReason = '采用你明确指定的分类';
  } else if (specific != null) {
    category = specific;
    categoryReason = '根据本次用途推荐';
  } else if (history.suggestions.isNotEmpty && history.certain) {
    category = history.suggestions.first.category;
    categoryReason = '根据历史备注「${history.suggestions.first.note}」推荐';
  } else if (history.suggestions.isNotEmpty) {
    category = '其他';
    categoryReason = '历史备注有多个分类，请选择';
    warnings.add('历史备注分类存在歧义，请核对分类');
  } else {
    category = _category(categoryText, income);
  }
  if (category == '其他') warnings.add('用途不明确，请选择分类');
  var note = explicitNote;
  if (noteOverride == null && (note == null || note.isEmpty)) {
    note = body;
    for (final c in candidates.toList()..sort((a,b) => b.start.compareTo(a.start))) {
      note = note!.replaceRange(c.start, c.end, ' ');
    }
    note = note!.replaceAll(RegExp(r'刚才|刚刚|早上|中午|晚上|上午|下午'), ' ')
      .replaceAll(RegExp(r'分类(?:为|是)?\s*[\u4e00-\u9fa5]+'), ' ')
      .replaceAll(RegExp(r'记一笔|帮我记|记一下|记个账|收入|支出|花了|花费|支付了|付款|付了|一共|总共|合计|买了|购买了|买的|买|收到|到账|吃的|喝的'), ' ')
      .replaceAll(RegExp(r'[\s,，。:：;；]+'), ' ').trim();
  }
  if (noteOverride == null && (note == null || note.isEmpty)) note = category;
  return VoiceDraft(rawText: raw.trim(), amount: amount, isIncome: income, category: category,
    note: note ?? '', date: date, warnings: List.unmodifiable(warnings), categoryReason: categoryReason,
    categorySuggestions: history.suggestions);
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
  return _explicitCategory(text, income) ?? _specificCategory(text, income) ??
    (income ? '其他' : (RegExp(r'吃|喝').hasMatch(text) ? '餐饮' : RegExp(r'买|购买|购物').hasMatch(text) ? '购物' : '其他'));
}

String? _explicitCategory(String text, bool income) {
  final names = income ? const ['工资','兼职','理财','礼金','奖金','报销','退款','其他'] : const [
    '餐饮','购物','日用','交通','蔬菜','水果','零食','运动','娱乐','通讯','服饰','美容','住房','居家','孩子','长辈','社交','旅行','烟酒','数码','汽车','医疗','书籍','学习','宠物','礼金','礼物','办公','维修','捐赠','彩票','亲友','快递','其他'];
  final explicit = RegExp('分类(?:为|是)?\\s*(${names.join('|')})').firstMatch(text);
  return explicit?[1];
}

String? _specificCategory(String text, bool income) {
  final rules = income ? _incomeRules : _expenseRules;
  for (final rule in rules.entries) {
    if (rule.value.any(text.contains)) return rule.key;
  }
  return null;
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


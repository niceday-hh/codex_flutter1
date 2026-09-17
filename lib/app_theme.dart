import 'package:flutter/material.dart';

class AppPalette {
  static const background = Color(0xFFF5F4F0);
  static const backgroundDark = Color(0xFF111315);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF1B1E20);
  static const primary = Color(0xFFF2A722);
  static const primaryDeep = Color(0xFFB66A00);
  static const primarySoft = Color(0xFFFFF0D2);
  static const mint = Color(0xFF43AE9C);
  static const mintSoft = Color(0xFFE2F5F0);
  static const coral = Color(0xFFF36E75);
  static const cyan = Color(0xFF59B7C7);
  static const violet = Color(0xFF9181D8);
  static const ink = Color(0xFF1D2C38);
  static const inkDark = Color(0xFFF5F2EA);
  static const secondary = Color(0xFF736C61);
  static const secondaryDark = Color(0xFFA9A298);
  static const line = Color(0xFFE7E1D8);
  static const lineDark = Color(0xFF303437);
  static const danger = Color(0xFFC83737);
}

ThemeData buildTheme({bool dark = false}) {
  final brightness = dark ? Brightness.dark : Brightness.light;
  final background = dark ? AppPalette.backgroundDark : AppPalette.background;
  final surface = dark ? AppPalette.surfaceDark : AppPalette.surface;
  final ink = dark ? AppPalette.inkDark : AppPalette.ink;
  final secondary = dark ? AppPalette.secondaryDark : AppPalette.secondary;
  final line = dark ? AppPalette.lineDark : AppPalette.line;

  return ThemeData(
    useMaterial3: true,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    brightness: brightness,
    scaffoldBackgroundColor: background,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppPalette.primary,
      brightness: brightness,
      surface: surface,
    ).copyWith(
      primary: AppPalette.primary,
      secondary: AppPalette.mint,
      surface: surface,
      outlineVariant: line,
    ),
    fontFamilyFallback: const [
      'HarmonyOS Sans SC',
      'PingFang SC',
      'Noto Sans CJK SC',
      'sans-serif',
    ],
    textTheme: TextTheme(
      displaySmall: TextStyle(
        color: ink,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.6,
      ),
      headlineSmall: TextStyle(
        color: ink,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      titleLarge: TextStyle(color: ink, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: ink, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: ink),
      bodyMedium: TextStyle(color: ink),
      bodySmall: TextStyle(color: secondary),
    ),
    dividerColor: line,
    inputDecorationTheme: const InputDecorationTheme(border: InputBorder.none),
  );
}

const expenseCategories = <String>[
  '餐饮', '购物', '日用', '交通', '蔬菜',
  '水果', '零食', '运动', '娱乐', '通讯',
  '服饰', '美容', '住房', '居家', '孩子',
  '长辈', '社交', '旅行', '烟酒', '数码',
  '汽车', '医疗', '书籍', '学习', '宠物',
  '礼金', '礼物', '办公', '维修', '捐赠',
  '彩票', '亲友', '快递', '其他',
];

const incomeCategories = <String>[
  '工资', '兼职', '理财', '礼金', '奖金', '报销', '退款', '其他', '设置',
];

String emojiForCategory(String category) {
  switch (category) {
    case '餐饮': return '🍽️';
    case '购物': return '🛍️';
    case '日用': return '🧻';
    case '交通': return '🚌';
    case '蔬菜': return '🥕';
    case '水果': return '🍒';
    case '零食': return '🧁';
    case '运动': return '⚽';
    case '娱乐': return '🎤';
    case '通讯': return '☎️';
    case '服饰': return '👕';
    case '美容': return '💄';
    case '住房': return '🏠';
    case '居家': return '🛋️';
    case '孩子': return '👶';
    case '长辈': return '🧓';
    case '社交': return '💬';
    case '旅行': return '✈️';
    case '烟酒': return '🍷';
    case '数码': return '🔌';
    case '汽车': return '🚗';
    case '医疗': return '🩺';
    case '书籍': return '📚';
    case '学习': return '🎓';
    case '宠物': return '🐶';
    case '礼金': return '🧧';
    case '礼物': return '🎁';
    case '办公': return '💼';
    case '维修': return '🔨';
    case '捐赠': return '💝';
    case '彩票': return '🎟️';
    case '亲友': return '👪';
    case '快递': return '📦';
    case '工资': return '💴';
    case '兼职': return '🕘';
    case '理财': return '📈';
    case '奖金': return '💰';
    case '报销': return '🧾';
    case '退款': return '↩️';
    case '设置': return '⚙️';
    default: return '⬡';
  }
}

Color colorForCategory(String category) {
  switch (category) {
    case '餐饮': return AppPalette.primary;
    case '交通': return AppPalette.cyan;
    case '购物': return AppPalette.coral;
    case '通讯': return const Color(0xFFE76169);
    case '日用': return AppPalette.mint;
    case '居家': return const Color(0xFF68B59D);
    case '娱乐': return AppPalette.violet;
    case '医疗': return const Color(0xFF58B9B0);
    case '学习': return const Color(0xFF5B91D9);
    case '工资': return AppPalette.mint;
    case '兼职': return AppPalette.cyan;
    case '理财': return const Color(0xFFEB746E);
    case '礼金': return const Color(0xFFE96A54);
    case '奖金': return AppPalette.primary;
    default: return const Color(0xFF9AA59F);
  }
}


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_store.dart';
import '../calendar/calendar_settings.dart';
import '../app_theme.dart';
import '../widgets/common.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final now = DateTime.now();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 126),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('我的', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 34))),
              Text('${now.year}年 ${now.month}月', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 22),
          WarmCard(
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFFFFC85F), AppPalette.primary]),
                  ),
                  child: const Text('光', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppPalette.ink)),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('我的拾光账本', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text('${store.entries.length} 笔记录 · 数据仅保存在本机', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12.5)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionTitle(title: '偏好设置'),
          const SizedBox(height: 12),
          WarmCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ToggleRow(
                  icon: Icons.visibility_off_outlined,
                  title: '隐藏金额',
                  value: store.hideAmounts,
                  onChanged: store.setHideAmounts,
                ),
                _divider(context),
                _ToggleRow(
                  icon: Icons.notifications_none_rounded,
                  title: '每日记账提醒',
                  subtitle: '每天 ${store.reminderHour.toString().padLeft(2, '0')}:${store.reminderMinute.toString().padLeft(2, '0')} 提醒',
                  value: store.dailyReminder,
                  onChanged: store.setDailyReminder,
                ),
                _divider(context),
                _ToggleRow(
                  icon: Icons.dark_mode_outlined,
                  title: '深色模式',
                  value: store.darkMode,
                  onChanged: store.setDarkMode,
                ),
                _divider(context),
                _ArrowRow(
                  icon: Icons.calendar_month_outlined,
                  title: '日期资料更新',
                  subtitle: '假期、补班、节气 · 手动或自动检查',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CalendarSettings())),
                ),
                _divider(context),
                _ArrowRow(
                  icon: Icons.notes_rounded,
                  title: '常用备注数量',
                  subtitle: '${store.noteLimit} 个（最多 24 个）',
                  onTap: () => _chooseNoteLimit(context, store),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionTitle(title: '数据管理'),
          const SizedBox(height: 12),
          WarmCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ArrowRow(
                  icon: Icons.ios_share_rounded,
                  title: '导出 CSV',
                  subtitle: '日期、类型、分类、金额、备注',
                  onTap: () => _exportCsv(context, store),
                ),
                _divider(context),
                _ArrowRow(
                  icon: Icons.file_download_outlined,
                  title: '导入 CSV',
                  subtitle: '支持追加导入或替换现有账单',
                  onTap: () => _importCsv(context, store),
                ),
                _divider(context),
                _ArrowRow(
                  icon: Icons.delete_sweep_outlined,
                  title: '清空账本',
                  titleColor: AppPalette.danger,
                  iconColor: AppPalette.danger,
                  onTap: () => _clearAll(context, store),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Text(
              '拾光账本 2.0 · Flutter 优化版',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5, letterSpacing: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _divider(BuildContext context) => Divider(height: 1, indent: 60, color: Theme.of(context).dividerColor);

  static Future<void> _chooseNoteLimit(BuildContext context, AppStore store) async {
    final value = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('常用备注数量', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('记一笔时会展示最近使用过的备注，点击即可快速填入。', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [4, 6, 8, 12, 16, 20, 24].map((count) {
                final selected = count == store.noteLimit;
                return ChoiceChip(
                  selected: selected,
                  label: Text('$count 个'),
                  selectedColor: AppPalette.primarySoft,
                  side: BorderSide(color: selected ? AppPalette.primary : Theme.of(context).dividerColor),
                  onSelected: (_) => Navigator.pop(context, count),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
    if (value != null) store.setNoteLimit(value);
  }

  static Future<void> _exportCsv(BuildContext context, AppStore store) async {
    HapticFeedback.selectionClick();
    final ok = await store.exportCsvToFile();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(ok ? 'CSV 已导出' : '未保存 CSV'),
      ),
    );
  }

  static Future<void> _importCsv(BuildContext context, AppStore store) async {
    HapticFeedback.selectionClick();
    final content = await store.pickCsvFromFile();
    if (!context.mounted || content == null || content.trim().isEmpty) return;
    final mode = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('导入方式', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('CSV 表头应为：日期、类型、分类、金额、备注。也兼容制表符分隔的数据。', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.add_rounded)),
              title: const Text('追加导入', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('保留现有账单，把 CSV 记录追加进来'),
              onTap: () => Navigator.pop(context, false),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.swap_horiz_rounded)),
              title: const Text('替换现有账单', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('清空当前账单后，再导入 CSV'),
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (mode == null || !context.mounted) return;
    try {
      final count = store.importCsv(content, replace: mode);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text('已导入 $count 笔记录')),
      );
    } on FormatException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(e.message.toString())),
      );
    }
  }

  static Future<void> _clearAll(BuildContext context, AppStore store) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空账本？'),
        content: const Text('此操作会删除本机全部记账记录。建议先导出 CSV 备份。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空', style: TextStyle(color: AppPalette.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) store.clearEntries();
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Theme.of(context).textTheme.bodySmall?.color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppPalette.primaryDeep,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _ArrowRow extends StatelessWidget {
  const _ArrowRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.titleColor,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? titleColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: [
            Icon(icon, size: 24, color: iconColor ?? Theme.of(context).textTheme.bodySmall?.color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: titleColor)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}


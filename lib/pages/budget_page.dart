import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_store.dart';
import '../app_theme.dart';
import '../widgets/common.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final used = store.expenseForMonth(_month);
    final remaining = store.monthlyBudget - used;
    final progress = store.monthlyBudget <= 0 ? 0.0 : (used / store.monthlyBudget).clamp(0.0, 1.0);
    final categorySummary = store.categorySummaryForMonth(_month);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 126),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('本月预算', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 34)),
          const SizedBox(height: 4),
          Text('${_month.year}年 ${_month.month}月', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 15)),
          const SizedBox(height: 22),
          WarmCard(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppPalette.primary.withValues(alpha: 0.18),
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('剩余可用', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppPalette.primarySoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text('${(progress * 100).round()}%', style: const TextStyle(color: AppPalette.primaryDeep, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  store.displayMoney(remaining),
                  style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: -1.4),
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 9,
                    backgroundColor: AppPalette.primary.withValues(alpha: 0.10),
                    valueColor: const AlwaysStoppedAnimation(AppPalette.primary),
                  ),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(child: Text('已用 ${store.displayMoney(used)}', style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text('预算 ${store.displayMoney(store.monthlyBudget)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WarmCard(
            onTap: () => _editBudget(context, store),
            child: const Row(
              children: [
                _SettingsIcon(icon: Icons.tune_rounded),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('设置月度预算', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      SizedBox(height: 2),
                      Text('按你的消费计划灵活调整', style: TextStyle(color: AppPalette.secondary, fontSize: 12.5)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionTitle(title: '分类预算'),
          const SizedBox(height: 12),
          WarmCard(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Column(
              children: store.categoryBudgets.entries.map((budgetEntry) {
                final category = budgetEntry.key;
                final budget = budgetEntry.value;
                final usedByCategory = categorySummary
                    .where((e) => e.name == category)
                    .fold<double>(0, (sum, e) => sum + e.amount);
                final ratio = budget <= 0 ? 0.0 : (usedByCategory / budget).clamp(0.0, 1.0);
                return InkWell(
                  onTap: () => _editCategoryBudget(context, store, category, budget),
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        CategoryAvatar(category: category, size: 44),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(category, style: const TextStyle(fontWeight: FontWeight.w800))),
                                  Text('${store.displayMoney(usedByCategory)} / ${store.displayMoney(budget)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
                                ],
                              ),
                              const SizedBox(height: 7),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 6,
                                  backgroundColor: colorForCategory(category).withValues(alpha: 0.10),
                                  valueColor: AlwaysStoppedAnimation(colorForCategory(category)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.chevron_right_rounded, size: 18),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editBudget(BuildContext context, AppStore store) async {
    HapticFeedback.selectionClick();
    final controller = TextEditingController(text: store.monthlyBudget.toStringAsFixed(0));
    final value = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(22, 0, 22, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('设置月度预算', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '¥ ',
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, double.tryParse(controller.text.trim())),
                style: FilledButton.styleFrom(backgroundColor: AppPalette.primary, foregroundColor: AppPalette.ink),
                child: const Text('保存预算', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value != null && value > 0) store.setBudget(value);
  }

  Future<void> _editCategoryBudget(BuildContext context, AppStore store, String category, double current) async {
    final controller = TextEditingController(text: current.toStringAsFixed(0));
    final value = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(22, 0, 22, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryAvatar(category: category, size: 44),
                const SizedBox(width: 12),
                Text('$category预算', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '¥ ',
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, double.tryParse(controller.text.trim())),
                style: FilledButton.styleFrom(backgroundColor: AppPalette.primary, foregroundColor: AppPalette.ink),
                child: const Text('保存', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value != null && value >= 0) store.setCategoryBudget(category, value);
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppPalette.primarySoft, borderRadius: BorderRadius.circular(15)),
      child: Icon(icon, color: AppPalette.primaryDeep),
    );
  }
}

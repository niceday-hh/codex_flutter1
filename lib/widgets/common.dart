import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models.dart';

class WarmCard extends StatelessWidget {
  const WarmCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.radius = 20,
    this.onTap,
    this.gradient,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final double radius;
  final VoidCallback? onTap;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = RepaintBoundary(
      child: Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: gradient == null
              ? Theme.of(context).colorScheme.surface
              : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.white.withValues(alpha: 0.92),
          ),
          boxShadow: [
            BoxShadow(
              color: dark
                  ? Colors.black.withValues(alpha: 0.16)
                  : const Color(0xFF8A6B38).withValues(alpha: 0.065),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: child,
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: card,
    );
  }
}

class FrostedBar extends StatelessWidget {
  const FrostedBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: DecoratedBox(
          decoration: const BoxDecoration(),
          child: Container(
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF181B1E) : Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: dark ? 0.08 : 0.88),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    super.key,
    required this.category,
    this.size = 44,
    this.selected = false,
  });

  final String category;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = colorForCategory(category);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? color : color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.20),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Text(
        emojiForCategory(category),
        style: TextStyle(fontSize: size * 0.48),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    this.compact = false,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .titleLarge
        ?.copyWith(fontSize: compact ? 19 : 23);
    return Row(
      children: [
        _RoundIcon(
          icon: Icons.chevron_left_rounded,
          onTap: onPrevious,
          compact: compact,
        ),
        Expanded(
          child: Text(
            '${month.year}年 ${month.month}月',
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
        _RoundIcon(
          icon: Icons.chevron_right_rounded,
          onTap: onNext,
          compact: compact,
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.onTap,
    required this.compact,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final extent = compact ? 46.0 : 50.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: extent,
        height: extent,
        child: Center(
          child: Container(
            width: compact ? 40 : 44,
            height: compact ? 40 : 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.74),
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.7),
              ),
            ),
            child: Icon(icon, size: compact ? 24 : 28),
          ),
        ),
      ),
    );
  }
}

class PillTabs extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.activeColor = AppPalette.primary,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == index;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 46),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 170),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? activeColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: activeColor.withValues(alpha: 0.16),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? Colors.white
                          : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class EntryRow extends StatelessWidget {
  const EntryRow({
    super.key,
    required this.entry,
    required this.amountText,
    this.onTap,
    this.onCategoryTap,
    this.onContentTap,
    this.onAmountTap,
    this.onAmountTapAt,
    this.onLongPress,
  });

  final LedgerEntry entry;
  final String amountText;
  final VoidCallback? onTap;
  final VoidCallback? onCategoryTap;
  final VoidCallback? onContentTap;
  final VoidCallback? onAmountTap;
  final ValueChanged<Offset>? onAmountTapAt;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final categoryTap = onCategoryTap ?? onTap;
    final contentTap = onContentTap ?? onTap;
    final amountTap = onAmountTap ?? onTap;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      child: SizedBox(
        height: 68,
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: categoryTap,
              child: SizedBox(
                width: 60,
                height: 68,
                child: Center(
                  child: CategoryAvatar(category: entry.category, size: 46),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: contentTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(2, 9, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        entry.note.isEmpty ? entry.title : entry.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${entry.category} · ${entry.date.hour.toString().padLeft(2, '0')}:${entry.date.minute.toString().padLeft(2, '0')}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAmountTapAt == null ? amountTap : null,
              onTapUp: onAmountTapAt == null
                  ? null
                  : (details) => onAmountTapAt!(details.globalPosition),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 86, minHeight: 68),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, right: 2),
                    child: Text(
                      amountText,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: entry.isIncome
                            ? AppPalette.mint
                            : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


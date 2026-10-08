import 'app_store.dart';
import 'widgets/active_store_scope.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'pages/add_page.dart';
import 'pages/budget_page.dart';
import 'pages/home_page.dart';
import 'pages/profile_page.dart';
import 'pages/stats_page_v23.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final Set<int> _visited = {0};
  bool _adding = false;

  static const _pages = <Widget>[
    RepaintBoundary(child: HomePage()),
    RepaintBoundary(child: StatsPage()),
    RepaintBoundary(child: BudgetPage()),
    RepaintBoundary(child: ProfilePage()),
  ];

  void _goTo(int value) {
    if (value == _index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _visited.add(value);
      _index = value;
    });
  }

  Future<void> _openAdd() async {
    if (_adding) return;
    _adding = true;
    HapticFeedback.lightImpact();
    try {
      await Navigator.of(context).push(
        CupertinoPageRoute<void>(
          fullscreenDialog: true,
          builder: (routeContext) => AddPage(
            onSaved: () => Navigator.of(routeContext).pop(),
          ),
        ),
      );
    } finally {
      _adding = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(child: _WarmBackground()),
          ),
          SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _index,
              sizing: StackFit.expand,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  TickerMode(
                    enabled: i == _index,
                    child: _visited.contains(i) ? ActiveStoreScope(
                      store: AppStoreScope.read(context), active: i == _index, child: _pages[i]) : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: DecoratedBox(
              decoration: const BoxDecoration(),
              child: Container(
                height: 78,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _NavItem(
                      icon: Icons.receipt_long_outlined,
                      label: '明细',
                      selected: _index == 0,
                      onTap: () => _goTo(0),
                    ),
                    _NavItem(
                      icon: Icons.bar_chart_rounded,
                      label: '报表',
                      selected: _index == 1,
                      onTap: () => _goTo(1),
                    ),
                    Expanded(
                      child: Center(
                        child: Transform.translate(
                          offset: const Offset(0, 0),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _openAdd,
                            child: SizedBox(
                              width: 70,
                              height: 70,
                              child: Center(
                                child: Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFFFFC457), AppPalette.primary],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.82),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppPalette.primary.withValues(alpha: 0.28),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.add_rounded,
                                    size: 34,
                                    color: AppPalette.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _NavItem(
                      icon: Icons.account_balance_wallet_outlined,
                      label: '预算',
                      selected: _index == 2,
                      onTap: () => _goTo(2),
                    ),
                    _NavItem(
                      icon: Icons.person_outline_rounded,
                      label: '我的',
                      selected: _index == 3,
                      onTap: () => _goTo(3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppPalette.primaryDeep
        : Theme.of(context).textTheme.bodySmall?.color;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.06 : 1,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 160),
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarmBackground extends StatelessWidget {
  const _WarmBackground();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          gradient: RadialGradient(
            center: const Alignment(-0.88, -0.92),
            radius: 1.15,
            colors: [
              AppPalette.primary.withValues(alpha: dark ? 0.055 : 0.10),
              Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0),
            ],
            stops: const [0, 1],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(1.0, -0.25),
              radius: 1.0,
              colors: [
                const Color(0xFFFFD99B).withValues(alpha: dark ? 0.035 : 0.09),
                Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0),
              ],
              stops: const [0, 1],
            ),
          ),
        ),
      ),
    );
  }
}



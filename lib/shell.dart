import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'pages/add_page.dart';
import 'pages/budget_page.dart';
import 'pages/home_page.dart';
import 'pages/profile_page.dart';
import 'pages/stats_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int value) {
    if (value == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = value);
    _controller.animateToPage(
      value,
      duration: const Duration(milliseconds: 330),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openAdd() async {
    HapticFeedback.mediumImpact();
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 390),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, animation, __) => AddPage(
          onSaved: () => Navigator.of(context).pop(),
        ),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final slide = Tween(begin: const Offset(0, 0.08), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic))
              .animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(child: _WarmBackground()),
          SafeArea(
            bottom: false,
            child: PageView(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                HomePage(),
                StatsPage(),
                BudgetPage(),
                ProfilePage(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: Container(
              height: 78,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.receipt_long_rounded,
                    label: '明细',
                    selected: _index == 0,
                    onTap: () => _goTo(0),
                  ),
                  _NavItem(
                    icon: Icons.insights_rounded,
                    label: '报表',
                    selected: _index == 1,
                    onTap: () => _goTo(1),
                  ),
                  Expanded(
                    child: Center(
                      child: Transform.translate(
                        offset: const Offset(0, -14),
                        child: GestureDetector(
                          onTap: _openAdd,
                          child: Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFFC457), AppPalette.primary],
                              ),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.82), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppPalette.primary.withValues(alpha: 0.35),
                                  blurRadius: 22,
                                  offset: const Offset(0, 9),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.add_rounded, size: 34, color: AppPalette.ink),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _NavItem(
                    icon: Icons.savings_rounded,
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
    final color = selected ? AppPalette.primaryDeep : Theme.of(context).textTheme.bodySmall?.color;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1,
              duration: const Duration(milliseconds: 230),
              curve: Curves.easeOutBack,
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 5),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
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
    );
  }
}

class _WarmBackground extends StatelessWidget {
  const _WarmBackground();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor)),
          Positioned(
            left: -90,
            top: -100,
            child: _Glow(size: 280, color: AppPalette.primary.withValues(alpha: dark ? 0.08 : 0.13)),
          ),
          Positioned(
            right: -140,
            top: 120,
            child: _Glow(size: 330, color: const Color(0xFFFFD99B).withValues(alpha: dark ? 0.05 : 0.15)),
          ),
          Positioned(
            left: -120,
            bottom: 90,
            child: _Glow(size: 300, color: AppPalette.mint.withValues(alpha: dark ? 0.04 : 0.07)),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 80, spreadRadius: 15)],
      ),
    );
  }
}

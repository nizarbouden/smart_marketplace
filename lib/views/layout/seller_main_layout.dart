// lib/views/layout/seller_main_layout.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';
import 'package:smart_marketplace/providers/language_provider.dart';
import '../compte/seller_profile_page.dart';
import '../dashboard/seller_dashboard_page.dart';
import '../orders/seller_sub_orders_page.dart';
import '../products/seller/seller_products_page.dart';

class SellerMainLayout extends StatefulWidget {
  const SellerMainLayout({super.key});

  @override
  State<SellerMainLayout> createState() => _SellerMainLayoutState();
}

class _SellerMainLayoutState extends State<SellerMainLayout> {
  int _currentIndex = 0;

  String _t(String key) => AppLocalizations.get(key);

  final List<Widget> _pages = const [
    SellerDashboardPage(),
    SellerProductsPage(),
    SellerSubOrdersPage(),
    SellerProfilePage(),
  ];

  List<_NavItemData> _buildNavItems() => [
    _NavItemData(
      activeIcon: Icons.dashboard_rounded,
      inactiveIcon: Icons.dashboard_outlined,
      label: _t('seller_nav_dashboard'),
    ),
    _NavItemData(
      activeIcon: Icons.inventory_2_rounded,
      inactiveIcon: Icons.inventory_2_outlined,
      label: _t('seller_nav_products'),
    ),
    _NavItemData(
      activeIcon: Icons.receipt_long_rounded,
      inactiveIcon: Icons.receipt_long_outlined,
      label: _t('seller_nav_orders'),
    ),
    _NavItemData(
      activeIcon: Icons.person_rounded,
      inactiveIcon: Icons.person_outline_rounded,
      label: _t('seller_nav_profile'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, langProvider, _) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isWideScreen = screenWidth >= 600;
        final bottomPad = MediaQuery.of(context).padding.bottom;

        return Directionality(
          textDirection: TextDirection.ltr,
          child: isWideScreen
              ? _buildWideLayout()
              : _buildNarrowLayout(bottomPad),
        );
      },
    );
  }

  // ── Narrow layout ─────────────────────────────────────────────

  Widget _buildNarrowLayout(double bottomPad) {
    final items = _buildNavItems();
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Stack(
        children: [
          // ── Pages ──────────────────────────────────────────────
          Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _pages,
                ),
              ),
              SizedBox(height: 64 + bottomPad),
            ],
          ),

          // ── ✅ Animated Indicator NavBar ───────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _AnimatedIndicatorNavBar(
              currentIndex: _currentIndex,
              items: items,
              onTap: (i) => setState(() => _currentIndex = i),
              bottomPad: bottomPad,
            ),
          ),
        ],
      ),
    );
  }

  // ── Wide layout (tablet) ──────────────────────────────────────

  Widget _buildWideLayout() {
    final items = _buildNavItems();

    // Couleurs seller (même ordre que _colors dans la navbar)
    const colors = [
      Color(0xFF16A34A), // dashboard — vert
      Color(0xFF3B82F6), // produits  — bleu
      Color(0xFFF97316), // commandes — orange
      Color(0xFF8B5CF6), // profil    — violet
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: Colors.white,
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            labelType: NavigationRailLabelType.all,
            selectedIconTheme: IconThemeData(color: colors[_currentIndex]),
            unselectedIconTheme: IconThemeData(color: Colors.grey[400]),
            selectedLabelTextStyle: TextStyle(
              color: colors[_currentIndex],
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            unselectedLabelTextStyle:
            TextStyle(color: Colors.grey[400], fontSize: 12),
            indicatorColor: colors[_currentIndex].withOpacity(0.12),
            destinations: items
                .map((e) => NavigationRailDestination(
              icon: Icon(e.inactiveIcon),
              selectedIcon: Icon(e.activeIcon),
              label: Text(e.label),
            ))
                .toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ✅ ANIMATED INDICATOR NAVBAR — Seller edition
//    Même logique que MainLayout, couleurs adaptées au seller
// ═══════════════════════════════════════════════════════════════════

class _NavItemData {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;

  const _NavItemData({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
  });
}

class _AnimatedIndicatorNavBar extends StatefulWidget {
  final int currentIndex;
  final List<_NavItemData> items;
  final ValueChanged<int> onTap;
  final double bottomPad;

  const _AnimatedIndicatorNavBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
    required this.bottomPad,
  });

  @override
  State<_AnimatedIndicatorNavBar> createState() =>
      _AnimatedIndicatorNavBarState();
}

class _AnimatedIndicatorNavBarState extends State<_AnimatedIndicatorNavBar>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _indicatorAnim;
  int _prevIndex = 0;

  // ✅ Couleurs seller par onglet
  static const _colors = [
    Color(0xFF16A34A), // dashboard — vert primaire
    Color(0xFF3B82F6), // produits  — bleu
    Color(0xFFF97316), // commandes — orange
    Color(0xFF8B5CF6), // profil    — violet
  ];

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.currentIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _indicatorAnim =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo);
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(_AnimatedIndicatorNavBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _prevIndex = old.currentIndex;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _colors[widget.currentIndex];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: activeColor.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: LayoutBuilder(builder: (context, constraints) {
            final itemW = constraints.maxWidth / widget.items.length;

            return Stack(clipBehavior: Clip.none, children: [

              // ── Trait animé en haut ────────────────────────────
              AnimatedBuilder(
                animation: _indicatorAnim,
                builder: (_, __) {
                  final fromX = _prevIndex * itemW + itemW / 2;
                  final toX   = widget.currentIndex * itemW + itemW / 2;
                  final x = lerpDouble(fromX, toX, _indicatorAnim.value)!;

                  return Positioned(
                    top: 0,
                    left: x - 20,
                    child: Container(
                      width: 40,
                      height: 3,
                      decoration: BoxDecoration(
                        color: activeColor,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withOpacity(0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // ── Spotlight circulaire derrière l'icône active ───
              AnimatedBuilder(
                animation: _indicatorAnim,
                builder: (_, __) {
                  final fromX = _prevIndex * itemW + itemW / 2;
                  final toX   = widget.currentIndex * itemW + itemW / 2;
                  final x = lerpDouble(fromX, toX, _indicatorAnim.value)!;

                  return Positioned(
                    top: 8,
                    left: x - 24,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: activeColor.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),

              // ── Items ──────────────────────────────────────────
              Row(
                children: List.generate(widget.items.length, (i) {
                  final item     = widget.items[i];
                  final isActive = i == widget.currentIndex;
                  final color    = _colors[i];

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        height: 64,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [

                            // ── Icône avec switch animé ──────────
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, anim) =>
                                  ScaleTransition(scale: anim, child: child),
                              child: Icon(
                                isActive ? item.activeIcon : item.inactiveIcon,
                                key: ValueKey(isActive),
                                size: isActive ? 26 : 23,
                                color: isActive
                                    ? color
                                    : const Color(0xFFB0BEC5),
                              ),
                            ),

                            const SizedBox(height: 4),

                            // ── Label animé ──────────────────────
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: isActive ? 11 : 10,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isActive
                                    ? color
                                    : const Color(0xFFB0BEC5),
                                letterSpacing: isActive ? 0.2 : 0,
                              ),
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.ltr,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),

            ]);
          }),
        ),
      ),
    );
  }
}
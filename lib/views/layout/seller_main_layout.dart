import 'package:flutter/material.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';
import '../compte/seller_profile_page.dart';
import '../dashboard/seller_dashboard_page.dart';
import '../orders/seller_orders_page.dart';
import '../products/seller_products_page.dart';

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
    SellerOrdersPage(),
    SellerProfilePage(),
  ];

  List<_NavItemData> get _navItems => [
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
    final isRtl = AppLocalizations.isRtl;
    final screenWidth = MediaQuery.of(context).size.width;
    // Use side navigation on large screens (tablets/desktops >= 600px)
    final isWideScreen = screenWidth >= 600;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: isWideScreen ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  /// Narrow layout: bottom navigation bar (phones)
  Widget _buildNarrowLayout() {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  /// Wide layout: side rail navigation (tablets / desktops)
  Widget _buildWideLayout() {
    final items = _navItems;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: Colors.white,
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            labelType: NavigationRailLabelType.all,
            selectedIconTheme:
            const IconThemeData(color: Color(0xFF16A34A)),
            unselectedIconTheme:
            IconThemeData(color: Colors.grey[400]),
            selectedLabelTextStyle: const TextStyle(
              color: Color(0xFF16A34A),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            unselectedLabelTextStyle:
            TextStyle(color: Colors.grey[400], fontSize: 12),
            indicatorColor:
            const Color(0xFF16A34A).withOpacity(0.12),
            destinations: items
                .asMap()
                .entries
                .map(
                  (e) => NavigationRailDestination(
                icon: Icon(e.value.inactiveIcon),
                selectedIcon: Icon(e.value.activeIcon),
                label: Text(e.value.label),
              ),
            )
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

  Widget _buildBottomNav() {
    final items = _navItems;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items
                .asMap()
                .entries
                .map((e) => _buildNavItem(e.key, e.value))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, _NavItemData item) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF16A34A).withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? item.activeIcon : item.inactiveIcon,
                color: isActive
                    ? const Color(0xFF16A34A)
                    : Colors.grey[400],
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive
                      ? FontWeight.w700
                      : FontWeight.normal,
                  color: isActive
                      ? const Color(0xFF16A34A)
                      : Colors.grey[400],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
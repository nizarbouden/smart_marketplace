import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../localization/app_localizations.dart';
import '../../providers/language_provider.dart';
import '../../services/auto_logout_service.dart';
import '../cart/cart_page.dart';
import '../compte/profile_page.dart';
import '../home/home_page.dart';
import '../history/history_page.dart';
import '../notifications/notifications_page.dart';
import '../favorites/favorites_page.dart';
import '../../services/selection_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../widgets/auto_logout_warning_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';


class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  int _totalCartItems = 0;
  int _selectedCartItems = 0;
  double _selectedTotal = 0.0;
  bool _showNotifications = false;
  bool _showCartOverlay = false;
  int _unreadNotificationsCount = 0;

  final SelectionService _selectionService = SelectionService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseAuthService _authService = FirebaseAuthService();
  final AutoLogoutService _autoLogoutService = AutoLogoutService();
  bool _dialogShown = false;

  bool _isUserConnected() => _auth.currentUser != null;

  String _t(String key) {
    try {
      return Provider.of<LanguageProvider>(context, listen: false).translate(key);
    } catch (_) {
      return AppLocalizations.get(key);
    }
  }

  void _showAutoLogoutWarning(int remainingSeconds) {
    if (_dialogShown) return;
    _dialogShown = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AutoLogoutWarningDialog(
        remainingSeconds: remainingSeconds,
        onStayLoggedIn: () {
          _dialogShown = false;
          if (mounted && Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
          _autoLogoutService.recordActivity();
        },
        onLogout: () {
          _dialogShown = false;
          if (mounted && Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
          _autoLogoutService.stopAutoLogout();
          _auth.signOut();
          if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        },
      ),
    ).then((_) => _dialogShown = false);
  }

  void _showLoginRequiredMessage() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 20,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA855F7)],
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.all(28),
              child: Container(width: 70, height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15), shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                ),
                child: const Icon(Icons.lock_rounded, color: Colors.white, size: 32),
              ),
            ),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(lang.translate('login_title'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                        color: Color(0xFF8700FF), letterSpacing: 0.5)),
                const SizedBox(height: 12),
                Text(lang.translate('login'),
                    style: const TextStyle(fontSize: 16, color: Color(0xFF64748B), height: 1.4),
                    textAlign: TextAlign.center),
                const SizedBox(height: 28),
                Row(children: [
                  Expanded(child: SizedBox(height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(lang.translate('cancel'),
                          style: const TextStyle(color: Color(0xFF6366F1),
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: SizedBox(height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white, elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: FittedBox(child: Text(lang.translate('login'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                    ),
                  )),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUnreadNotificationsCount();
    _selectionService.addListener(_onSelectionChanged);
    _initializeAutoLogout();
  }

  Future<void> _initializeAutoLogout() async {
    try {
      if (_auth.currentUser != null) {
        await _autoLogoutService.init();
        final settings = await _autoLogoutService.loadAutoLogoutSettings();
        if (settings['enabled'] ?? false) {
          _autoLogoutService.startAutoLogout(settings['duration'] ?? '30 minutes');
        }
        _setupAutoLogoutCallbacks();
      }
    } catch (e) { debugPrint('❌ auto-logout: $e'); }
  }

  void _setupAutoLogoutCallbacks() {
    _autoLogoutService.setOnLogoutCallback(() {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('inactivity_detected')),
        backgroundColor: Colors.red, duration: const Duration(seconds: 5),
      ));
      _autoLogoutService.stopAutoLogout();
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    });
    _autoLogoutService.setOnWarningCallback((s) { if (mounted) _showAutoLogoutWarning(s); });
  }

  @override
  void dispose() {
    _selectionService.removeListener(_onSelectionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && !_showNotifications) {
      _autoLogoutService.recordActivity();
      _refreshNotificationCount();
    }
  }

  Future<void> _loadUnreadNotificationsCount() async {
    try {
      final notifications = await _authService.getUserNotifications();
      final count = notifications.where((n) => !(n['isRead'] ?? true)).length;
      if (mounted) setState(() => _unreadNotificationsCount = count);
    } catch (_) {}
  }

  void _refreshNotificationCount() => _loadUnreadNotificationsCount();
  void _onSelectionChanged() { if (mounted) setState(() {}); }

  void _onItemTapped(int index) {
    if (index == 0) {
      setState(() { _currentIndex = index; _refreshNotificationCount(); });
    } else if (_isUserConnected()) {
      setState(() { _currentIndex = index; _refreshNotificationCount(); });
      if (index == 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          cartPageKey.currentState?.loadCart();
        });
      }
    } else {
      _showLoginRequiredMessage();
    }
  }

  void _toggleNotifications() {
    if (_isUserConnected()) {
      setState(() {
        _showNotifications = !_showNotifications;
        if (_showNotifications) _unreadNotificationsCount = 0;
        else _refreshNotificationCount();
      });
    } else {
      _showLoginRequiredMessage();
    }
  }

  void _navigateToFavorites() {
    if (_isUserConnected()) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesPage()));
    } else {
      _showLoginRequiredMessage();
    }
  }

  void _updateCartItemCount(int totalCount) {
    setState(() {
      _totalCartItems = totalCount;
      if (_totalCartItems == 0) {
        _selectedCartItems = 0; _selectedTotal = 0.0;
        _selectionService.setAllSelected(false); _showCartOverlay = false;
      }
    });
  }

  void _updateCartSelection(int count, double total) {
    setState(() { _selectedCartItems = count; _selectedTotal = total; });
  }

  void _toggleCartOverlay() => setState(() => _showCartOverlay = !_showCartOverlay);

  void _openHomeFilter() {
    homePageKey.currentState?.openFilterDrawer();
    Future.delayed(const Duration(milliseconds: 400), () { if (mounted) setState(() {}); });
  }

  String _getAppBarTitle(LanguageProvider lang) {
    if (_showNotifications) return lang.translate('notifications');
    switch (_currentIndex) {
      case 0: return 'Winzy';
      case 1: return lang.translate('cart');
      case 2: return lang.translate('history');
      case 3: return lang.translate('profile');
      default: return 'Winzy';
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    final navItems = [
      _NavItemData(icon: Icons.home_outlined,        activeIcon: Icons.home_rounded,          label: lang.translate('home')),
      _NavItemData(icon: Icons.shopping_bag_outlined, activeIcon: Icons.shopping_bag_rounded,  label: lang.translate('cart')),
      _NavItemData(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded,  label: lang.translate('history')),
      _NavItemData(icon: Icons.person_outline,        activeIcon: Icons.person_rounded,        label: lang.translate('profile')),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Stack(children: [
        // ── Main content ─────────────────────────────────────────
        Column(children: [
          SafeArea(bottom: false, child: _buildTopBar(lang)),
          Expanded(
            child: _showNotifications
                ? const NotificationsPage()
                : IndexedStack(
              index: _currentIndex,
              children: [
                HomePage(key: homePageKey),
                CartPage(
                  key: cartPageKey,
                  onTotalCartItemsChanged: _updateCartItemCount,
                  onCartSelectionChanged: _updateCartSelection,
                  onGoHome: () => setState(() => _currentIndex = 0),
                ),
                const HistoryPage(),
                const ProfilePage(),
              ],
            ),
          ),
          SizedBox(height: 72 + bottomPad),
        ]),

        // ── Cart overlay ─────────────────────────────────────────
        if (_currentIndex == 1 && _showCartOverlay)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: Stack(children: [
                Positioned.fill(child: GestureDetector(
                  onTap: _toggleCartOverlay,
                  child: Container(color: Colors.transparent),
                )),
                Positioned(
                  bottom: 90 + bottomPad, left: 16, right: 16, top: 80,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2),
                          blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: _buildCartOverlayContent(lang),
                  ),
                ),
              ]),
            ),
          ),

        // ── ✅ Animated Indicator NavBar ─────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _AnimatedIndicatorNavBar(
            currentIndex: _currentIndex,
            items: navItems,
            cartCount: _totalCartItems,
            onTap: _onItemTapped,
            bottomPad: bottomPad,
          ),
        ),
      ]),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────
  Widget _buildTopBar(LanguageProvider lang) {
    return Container(
      height: 60,
      color: Colors.white,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: _currentIndex == 0 && !_showNotifications
              ? Row(mainAxisSize: MainAxisSize.min, children: [
            _FilterButton(
              onTap: _openHomeFilter,
              hasActiveFilters: homePageKey.currentState?.hasActiveFilters ?? false,
            ),
            const SizedBox(width: 8),
            Image.asset('assets/images/logoApp.png', height: 32, width: 32, fit: BoxFit.contain),
            const SizedBox(width: 8),
            const Text('Winzy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ])
              : Text(_getAppBarTitle(lang),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (_currentIndex == 1 && !_showNotifications)
              IconButton(
                icon: const Icon(Icons.favorite_rounded, color: Colors.red, size: 24),
                onPressed: _navigateToFavorites,
              ),
            Stack(children: [
              IconButton(
                icon: Icon(_showNotifications ? Icons.close : Icons.notifications_rounded,
                    color: Colors.black87, size: 24),
                onPressed: _toggleNotifications,
              ),
              if (!_showNotifications && _unreadNotificationsCount > 0)
                Positioned(right: 6, top: 6,
                  child: Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(child: Text(
                      _unreadNotificationsCount > 9 ? '9+' : '$_unreadNotificationsCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9,
                          fontWeight: FontWeight.bold),
                    )),
                  ),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCartOverlayContent(LanguageProvider lang) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey, width: 1))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(lang.translate('summary'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          GestureDetector(
            onTap: _toggleCartOverlay,
            child: Container(width: 32, height: 32,
                decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 18)),
          ),
        ]),
      ),
      Expanded(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lang.translate('items_selected'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (_selectedCartItems > 0)
              Expanded(child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedCartItems,
                itemBuilder: (_, i) => _selectedItemCard(i),
              ))
            else
              Expanded(child: Center(child: Text(lang.translate('empty_cart'),
                  style: const TextStyle(fontSize: 14, color: Colors.grey)))),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                _summaryRow(lang.translate('subtotal'), '${_selectedTotal.toStringAsFixed(2)} €'),
                _summaryRow(lang.translate('shipping'), '5.99 €'),
                _summaryRow(lang.translate('total'),
                    '${(_selectedTotal + 5.99).toStringAsFixed(2)} €',
                    isBold: true, isLarge: true),
              ]),
            ),
          ],
        ))]),
      )),
    ]);
  }

  Widget _selectedItemCard(int index) {
    final items = [
      {'quantity': 2}, {'quantity': 1},
    ];
    if (index >= items.length) return const SizedBox.shrink();
    return Container(
      width: 80, height: 80,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Column(children: [
        Expanded(flex: 3, child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Container(width: double.infinity, color: Colors.grey[200],
              child: Icon(Icons.image, color: Colors.grey[400], size: 24)),
        )),
        Expanded(flex: 1, child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: const BoxDecoration(color: Colors.deepPurple,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12))),
          child: Center(child: Text('x${items[index]['quantity']}',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
        )),
      ]),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, bool isLarge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isLarge ? 18 : 14)),
        Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isLarge ? 18 : 14,
            color: isLarge ? Colors.deepPurple : Colors.black)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ✅ ANIMATED INDICATOR NAVBAR
// ═══════════════════════════════════════════════════════════════════

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItemData({required this.icon, required this.activeIcon, required this.label});
}

class _AnimatedIndicatorNavBar extends StatefulWidget {
  final int currentIndex;
  final List<_NavItemData> items;
  final int cartCount;
  final ValueChanged<int> onTap;
  final double bottomPad;

  const _AnimatedIndicatorNavBar({
    required this.currentIndex,
    required this.items,
    required this.cartCount,
    required this.onTap,
    required this.bottomPad,
  });

  @override
  State<_AnimatedIndicatorNavBar> createState() => _AnimatedIndicatorNavBarState();
}

class _AnimatedIndicatorNavBarState extends State<_AnimatedIndicatorNavBar>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _indicatorAnim;
  int _prevIndex = 0;

  // Couleurs par onglet
  static const _colors = [
    Color(0xFF6C63FF), // home — violet
    Color(0xFFFF6584), // cart — rose
    Color(0xFF43C6AC), // history — teal
    Color(0xFFFFAA00), // profile — amber
  ];

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.currentIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _indicatorAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo);
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

              // ── ✅ Indicator trait animé en haut ─────────────────
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

              // ── ✅ Spotlight circulaire derrière l'icône active ──
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

              // ── Items ────────────────────────────────────────────
              Row(
                children: List.generate(widget.items.length, (i) {
                  final item    = widget.items[i];
                  final isActive = i == widget.currentIndex;
                  final color   = _colors[i];

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        height: 64,
                        child: Stack(alignment: Alignment.center, children: [

                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // ── Icône avec bounce ───────────────
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 1.0, end: isActive ? 1.0 : 1.0),
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutBack,
                                builder: (_, scale, child) =>
                                    Transform.scale(scale: scale, child: child),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (child, anim) => ScaleTransition(
                                    scale: anim, child: child,
                                  ),
                                  child: Icon(
                                    isActive ? item.activeIcon : item.icon,
                                    key: ValueKey(isActive),
                                    size: isActive ? 26 : 23,
                                    color: isActive ? color : const Color(0xFFB0BEC5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),

                              // ── Label animé ─────────────────────
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: isActive ? 11 : 10,
                                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                                  color: isActive ? color : const Color(0xFFB0BEC5),
                                  letterSpacing: isActive ? 0.2 : 0,
                                ),
                                child: Text(item.label),
                              ),
                            ],
                          ),

                          // ── Badge panier ─────────────────────────
                          if (i == 1 && widget.cartCount > 0)
                            Positioned(
                              top: 8,
                              right: itemW / 2 - 28,
                              child: _CartBadge(count: widget.cartCount),
                            ),
                        ]),
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

// ── Cart badge ────────────────────────────────────────────────────
class _CartBadge extends StatelessWidget {
  final int count;
  const _CartBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6584), Color(0xFFFF4757)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: const Color(0xFFFF4757).withOpacity(0.4),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ── Filter button ─────────────────────────────────────────────────
class _FilterButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool hasActiveFilters;
  const _FilterButton({required this.onTap, required this.hasActiveFilters});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: hasActiveFilters
                ? Colors.deepPurple.withOpacity(0.1)
                : Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.tune_rounded,
              color: hasActiveFilters ? Colors.deepPurple : Colors.black87, size: 20),
        ),
        if (hasActiveFilters)
          Positioned(right: 0, top: 0,
            child: Container(width: 9, height: 9,
              decoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5)),
            ),
          ),
      ]),
    );
  }
}
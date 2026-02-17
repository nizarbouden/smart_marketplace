import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../services/auto_logout_service.dart';
import '../cart/cart_page.dart';
import '../compte/profile_page.dart';
import '../home/home_page.dart';
import '../history/history_page.dart';
import '../notifications/notifications_page.dart';
import '../../services/selection_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../widgets/auto_logout_warning_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';


class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  int _totalCartItems = 5;
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

  void _showAutoLogoutWarning(int remainingSeconds) {
    if (_dialogShown) return;
    _dialogShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AutoLogoutWarningDialog(
        remainingSeconds: remainingSeconds,
        onStayLoggedIn: () {
          _dialogShown = false;
          if (mounted && Navigator.of(dialogContext).canPop()) Navigator.of(dialogContext).pop();
          _autoLogoutService.recordActivity();
        },
        onLogout: () {
          _dialogShown = false;
          if (mounted && Navigator.of(dialogContext).canPop()) Navigator.of(dialogContext).pop();
          _autoLogoutService.stopAutoLogout();
          _auth.signOut();
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
          }
        },
      ),
    ).then((_) => _dialogShown = false);
  }

  void _showLoginRequiredMessage() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 20,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA855F7)],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                    ),
                    child: const Icon(Icons.lock_rounded, color: Colors.white, size: 32),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.get('login_title'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8700FF),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.get('login'),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Text(
                                  AppLocalizations.get('cancel'),
                                  style: const TextStyle(
                                      color: Color(0xFF6366F1),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  Navigator.pushReplacementNamed(context, '/login');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1),
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                child: FittedBox(
                                  child: Text(
                                    AppLocalizations.get('login'),
                                    style: const TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _loadUnreadNotificationsCount();
    _selectionService.addListener(_onSelectionChanged);
    _initializeAutoLogout();
  }

  Future<void> _initializeAutoLogout() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _autoLogoutService.init();
        final settings = await _autoLogoutService.loadAutoLogoutSettings();
        final isEnabled = settings['enabled'] ?? false;
        final duration = settings['duration'] ?? '30 minutes';
        if (isEnabled) _autoLogoutService.startAutoLogout(duration);
        _setupAutoLogoutCallbacks();
      }
    } catch (e) {
      print('❌ Erreur auto-logout: $e');
    }
  }

  void _setupAutoLogoutCallbacks() {
    _autoLogoutService.setOnLogoutCallback(() {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.get('inactivity_detected')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
        _autoLogoutService.stopAutoLogout();
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    });

    _autoLogoutService.setOnWarningCallback((remainingSeconds) {
      if (mounted) _showAutoLogoutWarning(remainingSeconds);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
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
      List<Map<String, dynamic>> notifications = await _authService.getUserNotifications();
      int unreadCount = notifications.where((n) => !(n['isRead'] ?? true)).length;
      if (mounted) setState(() => _unreadNotificationsCount = unreadCount);
    } catch (e) {
      print('❌ Erreur notifications: $e');
    }
  }

  void _refreshNotificationCount() => _loadUnreadNotificationsCount();

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  Map<String, dynamic> _calculateRealTotals() {
    if (_selectedCartItems > 0) return {'count': _selectedCartItems, 'total': _selectedTotal};
    return {'count': 0, 'total': 0.0};
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      setState(() {
        _currentIndex = index;
        _refreshNotificationCount();
      });
    } else {
      if (_isUserConnected()) {
        setState(() {
          _currentIndex = index;
          _refreshNotificationCount();
        });
      } else {
        _showLoginRequiredMessage();
      }
    }
  }

  void _toggleNotifications() {
    if (_isUserConnected()) {
      setState(() {
        _showNotifications = !_showNotifications;
        if (_showNotifications) {
          _unreadNotificationsCount = 0;
        } else {
          _refreshNotificationCount();
        }
      });
    } else {
      _showLoginRequiredMessage();
    }
  }

  void _updateCartItemCount(int totalCount) {
    setState(() {
      _totalCartItems = totalCount;
      if (_totalCartItems == 0) {
        _selectedCartItems = 0;
        _selectedTotal = 0.0;
        _selectionService.setAllSelected(false);
        _showCartOverlay = false;
      }
    });
  }

  void _updateCartSelection(int selectedCount, double selectedTotal) {
    setState(() {
      _selectedCartItems = selectedCount;
      _selectedTotal = selectedTotal;
    });
  }

  void _toggleCartOverlay() => setState(() => _showCartOverlay = !_showCartOverlay);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              SafeArea(
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          _getAppBarTitle(),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Stack(
                          children: [
                            IconButton(
                              icon: Icon(
                                _showNotifications ? Icons.close : Icons.notifications,
                                color: Colors.black,
                                size: 28,
                              ),
                              onPressed: _toggleNotifications,
                            ),
                            if (!_showNotifications && _unreadNotificationsCount > 0)
                              Positioned(
                                right: 2,
                                top: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                  child: Text(
                                    _unreadNotificationsCount > 99
                                        ? '99+'
                                        : _unreadNotificationsCount.toString(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _showNotifications
                    ? const NotificationsPage()
                    : IndexedStack(
                  index: _currentIndex,
                  children: [
                    const HomePage(),
                    _totalCartItems == 0
                        ? _buildEmptyCart()
                        : CartPage(
                      onTotalCartItemsChanged: _updateCartItemCount,
                      onCartSelectionChanged: _updateCartSelection,
                    ),
                    const HistoryPage(),
                    const ProfilePage(),
                  ],
                ),
              ),
            ],
          ),

          if (_currentIndex == 1 && _showCartOverlay)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _toggleCartOverlay,
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                    Positioned(
                      bottom: 161,
                      left: 16,
                      right: 16,
                      top: 80,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10))
                          ],
                        ),
                        child: _buildCartOverlayContent(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar:
      _currentIndex == 1 ? _buildCartNavigationBar() : _buildDefaultNavigationBar(),
    );
  }

  Widget _buildCartOverlayContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey, width: 1))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.get('summary'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: _toggleCartOverlay,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 18),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.get('items_selected'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      if (_selectedCartItems > 0)
                        Expanded(
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedCartItems,
                            itemBuilder: (context, index) => _selectedItemCard(index),
                          ),
                        )
                      else
                        Expanded(
                          child: Center(
                            child: Text(AppLocalizations.get('empty_cart'),
                                style: const TextStyle(fontSize: 14, color: Colors.grey)),
                          ),
                        ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            _summaryRow(AppLocalizations.get('subtotal'),
                                '${_selectedTotal.toStringAsFixed(2)} €'),
                            _summaryRow(AppLocalizations.get('shipping'), '5.99 €'),
                            _summaryRow(
                              AppLocalizations.get('total'),
                              '${(_selectedTotal + 5.99).toStringAsFixed(2)} €',
                              isBold: true,
                              isLarge: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _selectedItemCard(int index) {
    final testItems = [
      {'id': '1', 'name': 'Produit A', 'price': 49.99, 'quantity': 2},
      {'id': '2', 'name': 'Produit B', 'price': 29.99, 'quantity': 1},
    ];

    if (index < testItems.length) {
      final item = testItems[index];
      return Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Container(
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: Icon(Icons.image, color: Colors.grey[400], size: 24),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 2),
                decoration: const BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(12))),
                child: Center(
                  child: Text('x${item['quantity']}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildEmptyCart() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.shopping_cart_outlined, color: Colors.deepPurple, size: 60),
            ),
            const SizedBox(height: 24),
            Text(AppLocalizations.get('empty_cart'),
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            Text(AppLocalizations.get('no_data'),
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => setState(() => _currentIndex = 0),
              icon: const Icon(Icons.shopping_bag),
              label: Text(AppLocalizations.get('home')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, bool isLarge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: isLarge ? 18 : 14)),
          Text(value,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: isLarge ? 18 : 14,
                  color: isLarge ? Colors.deepPurple : Colors.black)),
        ],
      ),
    );
  }

  Widget _buildDefaultNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(icon: Icons.home_outlined, activeIcon: Icons.home,
                  label: AppLocalizations.get('home'), index: 0),
              _buildNavItem(icon: Icons.shopping_cart_outlined, activeIcon: Icons.shopping_cart,
                  label: AppLocalizations.get('cart'), index: 1),
              _buildNavItem(icon: Icons.history_outlined, activeIcon: Icons.history,
                  label: AppLocalizations.get('history'), index: 2),
              _buildNavItem(icon: Icons.person_outline, activeIcon: Icons.person,
                  label: AppLocalizations.get('profile'), index: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartNavigationBar() {
    return Container(
      height: 161,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, -2))
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 90,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(bottom: BorderSide(color: Colors.grey[300]!))),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    _selectionService.toggleAllSelection();
                    final totals = _calculateRealTotals();
                    _updateCartSelection(totals['count'] as int, totals['total'] as double);
                  },
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[400]!, width: 2),
                      color: _selectionService.isAllSelected ? Colors.deepPurple : null,
                    ),
                    child: _selectionService.isAllSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 12)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(AppLocalizations.get('select_all'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_selectedCartItems ${AppLocalizations.get('articles')}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                if (_selectedCartItems > 0)
                  GestureDetector(
                    onTap: () {
                      if (_isUserConnected()) {
                        _toggleCartOverlay();
                      } else {
                        _showLoginRequiredMessage();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${_selectedTotal.toStringAsFixed(2)} €',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple)),
                          const SizedBox(width: 4),
                          Icon(
                            _showCartOverlay
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up,
                            color: Colors.deepPurple,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Text('0.00 €',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _selectedCartItems > 0
                      ? () => Navigator.pushNamed(context, '/paiement')
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedCartItems > 0 ? Colors.deepPurple : Colors.grey[300],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(0, 40),
                  ),
                  child: Text(
                    '${AppLocalizations.get('payment')} ($_selectedCartItems)',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width < 360 ? 12 : 16,
                    vertical: MediaQuery.of(context).size.width < 360 ? 1 : 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(icon: Icons.home_outlined, activeIcon: Icons.home,
                        label: AppLocalizations.get('home'), index: 0),
                    _buildNavItem(icon: Icons.shopping_cart_outlined, activeIcon: Icons.shopping_cart,
                        label: AppLocalizations.get('cart'), index: 1),
                    _buildNavItem(icon: Icons.history_outlined, activeIcon: Icons.history,
                        label: AppLocalizations.get('history'), index: 2),
                    _buildNavItem(icon: Icons.person_outline, activeIcon: Icons.person,
                        label: AppLocalizations.get('profile'), index: 3),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isActive ? activeIcon : icon,
              key: ValueKey(isActive),
              color: isActive ? Colors.deepPurple : Colors.grey[600],
              size: MediaQuery.of(context).size.width < 360 ? 16 : 20,
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.width < 360 ? 0.5 : 1),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width < 360 ? 8 : 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? Colors.deepPurple : Colors.grey[600],
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    if (_showNotifications) return AppLocalizations.get('history');
    switch (_currentIndex) {
      case 0: return 'Smart Market';
      case 1: return '${AppLocalizations.get('cart')} ($_totalCartItems)';
      case 2: return AppLocalizations.get('history');
      case 3: return AppLocalizations.get('profile');
      default: return 'Smart Market';
    }
  }
}
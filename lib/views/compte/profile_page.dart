import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/language_provider.dart';
import '../../providers/currency_provider.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/auto_logout_service.dart';
import '../../widgets/auto_logout_warning_dialog.dart';
import 'profile/edit_profile_page.dart';
import 'adress/address_page.dart';
import 'notifications/notification_settings_page.dart';
import 'security/security_settings_page.dart';
import 'help/help_page.dart';
import 'payment/payment_methods_page.dart';
import 'terms&conditions/terms_conditions_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuthService _authService       = FirebaseAuthService();
  final AutoLogoutService   _autoLogoutService = AutoLogoutService();
  final FirebaseFirestore   _firestore         = FirebaseFirestore.instance;

  int    _points         = 0;
  int    _ordersCount    = 0;
  int    _favoritesCount = 0;
  bool   _dialogShown    = false;
  String? _photoBase64;
  bool    _loadingPhoto  = true;

  StreamSubscription? _pointsSubscription;

  @override
  void initState() {
    super.initState();
    _syncEmailIfNeeded();
    _setupListeners();
    _loadUserStats();
    _loadPhotoBase64();
    _listenToPoints();
  }

  void _listenToPoints() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _pointsSubscription = _firestore
        .collection('users').doc(uid).snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        setState(() =>
        _points = (doc.data()?['points'] as num?)?.toInt() ?? 0);
      }
    });
  }

  Future<void> _loadPhotoBase64() async {
    setState(() => _loadingPhoto = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() => _photoBase64 = doc.data()?['photoBase64'] as String?);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingPhoto = false);
  }

  Widget _buildAvatar({
    required double radius,
    required app_auth.AuthProvider authProvider,
  }) {
    if (_loadingPhoto) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.deepPurple[100],
        child: SizedBox(width: radius, height: radius,
            child: const CircularProgressIndicator(
                strokeWidth: 2, color: Colors.deepPurple)),
      );
    }
    if (_photoBase64 != null && _photoBase64!.isNotEmpty) {
      return CircleAvatar(
        radius: radius, backgroundColor: Colors.deepPurple[100],
        child: ClipOval(child: Image.memory(
          base64Decode(_photoBase64!),
          width: radius * 2, height: radius * 2, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackIcon(radius),
        )),
      );
    }
    if (authProvider.user?.photoUrl != null) {
      return CircleAvatar(
        radius: radius, backgroundColor: Colors.deepPurple[100],
        backgroundImage: NetworkImage(authProvider.user!.photoUrl!),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: radius, backgroundColor: Colors.deepPurple[100],
      child: _fallbackIcon(radius),
    );
  }

  Widget _fallbackIcon(double radius) =>
      Icon(Icons.person, size: radius, color: Colors.deepPurple);

  Future<void> _loadUserStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      int orders = 0, favorites = 0;
      try {
        orders = (await _firestore.collection('users')
            .doc(user.uid).collection('orders').get()).docs.length;
      } catch (_) {}
      try {
        favorites = (await _firestore.collection('users')
            .doc(user.uid).collection('favorites').get()).docs.length;
      } catch (_) {}
      if (mounted) setState(() {
        _ordersCount    = orders;
        _favoritesCount = favorites;
      });
    } catch (_) {}
  }

  void _setupListeners() {
    _autoLogoutService.addWarningListener((event) {
      if (mounted) _showAutoLogoutWarning(event.remainingSeconds);
    });
    _autoLogoutService.addLogoutListener((event) {
      if (mounted) {
        _pointsSubscription?.cancel();
        final lp = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lp.translate('session_expired')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
        _autoLogoutService.stopAutoLogout();
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    });
  }

  void _showAutoLogoutWarning(int remainingSeconds) {
    if (_dialogShown) return;
    _dialogShown = true;
    showDialog(
      context: context, barrierDismissible: false,
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
          FirebaseAuth.instance.signOut();
          if (mounted) Navigator.of(context)
              .pushNamedAndRemoveUntil('/login', (_) => false);
        },
      ),
    ).then((_) => _dialogShown = false);
  }

  Future<void> _syncEmailIfNeeded() async {
    try {
      final authEmail    = _authService.getCurrentEmail();
      final authProvider = Provider.of<app_auth.AuthProvider>(
          context, listen: false);
      if (authEmail != null && authEmail != authProvider.user?.email)
        await _authService.syncEmailFromAuth();
    } catch (_) {}
  }

  String _getCorrectEmail() {
    final authEmail    = _authService.getCurrentEmail();
    final authProvider = Provider.of<app_auth.AuthProvider>(context);
    return authEmail ?? authProvider.user?.email ?? 'email@example.com';
  }

  @override
  void dispose() {
    _pointsSubscription?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sw        = MediaQuery.of(context).size.width;
    final isMobile  = sw < 600;
    final isTablet  = sw >= 600 && sw < 1200;
    final isDesktop = sw >= 1200;

    final authProvider = Provider.of<app_auth.AuthProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    final isRtl        = langProvider.currentLanguageCode == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: RefreshIndicator(
          color: Colors.deepPurple,
          onRefresh: () async {
            await _loadPhotoBase64();
            await _loadUserStats();
            await Provider.of<CurrencyProvider>(context, listen: false)
                .fetchRates();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isDesktop ? 32 : isTablet ? 24 : 16),
            child: Column(children: [
              SizedBox(height: isDesktop ? 40 : isTablet ? 30 : 20),

              // ── Profil ────────────────────────────────────────
              Container(
                padding: EdgeInsets.all(isDesktop ? 32 : isTablet ? 24 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isDesktop ? 20 : 12),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Column(children: [
                  _buildAvatar(
                      radius: isDesktop ? 80 : isTablet ? 60 : 50,
                      authProvider: authProvider),
                  SizedBox(height: isDesktop ? 24 : isTablet ? 20 : 16),
                  Text(authProvider.fullName ?? 'User',
                      style: TextStyle(
                          fontSize: isDesktop ? 28 : isTablet ? 24 : 20,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: isDesktop ? 8 : isTablet ? 6 : 4),
                  Text(_getCorrectEmail(),
                      style: TextStyle(
                          fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                          color: Colors.grey[600])),
                  SizedBox(height: isDesktop ? 32 : isTablet ? 24 : 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statItem(langProvider.translate('orders'),
                          '$_ordersCount', isDesktop, isTablet),
                      _statItem(langProvider.translate('favorites'),
                          '$_favoritesCount', isDesktop, isTablet),
                      _statItem(langProvider.translate('points'),
                          '$_points', isDesktop, isTablet),
                    ],
                  ),
                ]),
              ),

              SizedBox(height: isDesktop ? 32 : isTablet ? 24 : 20),

              // ── Menu ──────────────────────────────────────────
              Container(
                padding: EdgeInsets.all(isDesktop ? 24 : isTablet ? 20 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isDesktop ? 20 : 12),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Column(children: [
                  _menuTile('personal_info',         Icons.person,
                      isDesktop, isTablet, langProvider, context),
                  _menuTile('addresses',             Icons.location_on,
                      isDesktop, isTablet, langProvider, context),
                  _menuTile('payment_methods',       Icons.credit_card,
                      isDesktop, isTablet, langProvider, context),
                  _menuTile('notification_settings', Icons.notifications,
                      isDesktop, isTablet, langProvider, context),
                  _menuTile('security',              Icons.security,
                      isDesktop, isTablet, langProvider, context),
                  _languageTile(isDesktop, isTablet, langProvider, context),
                  // ✅ Section devise entre langue et aide
                  _currencyTile(isDesktop, isTablet, langProvider, context),
                  _menuTile('help',             Icons.help,
                      isDesktop, isTablet, langProvider, context),
                  _menuTile('terms_conditions', Icons.description,
                      isDesktop, isTablet, langProvider, context),
                  _menuTile('logout',           Icons.logout,
                      isDesktop, isTablet, langProvider, context,
                      isLast: true),
                ]),
              ),

              SizedBox(height: isTablet ? 30 : 20),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, bool isDesktop, bool isTablet) {
    return Column(children: [
      Text(value, style: TextStyle(
          fontSize: isDesktop ? 32 : isTablet ? 28 : 24,
          fontWeight: FontWeight.bold, color: Colors.deepPurple)),
      SizedBox(height: isDesktop ? 8 : isTablet ? 6 : 4),
      Text(label, style: TextStyle(
          fontSize: isDesktop ? 16 : isTablet ? 14 : 12,
          color: Colors.grey[600])),
    ]);
  }

  // ─────────────────────────────────────────────────────────────
  //  LANGUAGE TILE
  // ─────────────────────────────────────────────────────────────

  Widget _languageTile(bool isDesktop, bool isTablet,
      LanguageProvider langProvider, BuildContext context) {
    return Column(children: [
      ListTile(
        leading: Icon(Icons.language, color: Colors.deepPurple,
            size: isDesktop ? 28 : isTablet ? 24 : 20),
        title: Text(langProvider.translate('language'),
            style: TextStyle(
                fontSize:   isDesktop ? 18 : isTablet ? 16 : 14,
                fontWeight: FontWeight.w500, color: Colors.black)),
        trailing: PopupMenuButton<String>(
          onSelected: (code) async {
            await langProvider.setLanguage(code);
            setState(() {});
          },
          itemBuilder: (_) => langProvider.supportedLanguages.entries.map((e) {
            final sel = e.key == langProvider.currentLanguageCode;
            return PopupMenuItem<String>(
              value: e.key,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(e.value, style: TextStyle(
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    color: sel ? Colors.deepPurple : Colors.black)),
                if (sel) const Padding(padding: EdgeInsets.only(left: 12),
                    child: Icon(Icons.check_circle,
                        color: Colors.deepPurple, size: 20)),
              ]),
            );
          }).toList(),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 12 : 8,
                vertical:   isDesktop ? 6  : 4),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(langProvider.currentLanguageFlag,
                  style: TextStyle(fontSize: isDesktop ? 18 : 16)),
              SizedBox(width: isDesktop ? 8 : 4),
              Text(langProvider.currentLanguageCode.toUpperCase(),
                  style: TextStyle(fontSize: isDesktop ? 14 : 12,
                      fontWeight: FontWeight.w600, color: Colors.deepPurple)),
              SizedBox(width: isDesktop ? 8 : 4),
              Icon(Icons.arrow_drop_down, color: Colors.deepPurple,
                  size: isDesktop ? 20 : 16),
            ]),
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 8 : isTablet ? 4 : 0,
            vertical:   isDesktop ? 4 : isTablet ? 2 : 0),
      ),
      Divider(height: 1, thickness: 0.5, color: Colors.grey[300],
          indent: isDesktop ? 68 : isTablet ? 64 : 60,
          endIndent: isDesktop ? 20 : isTablet ? 16 : 12),
    ]);
  }

  // ─────────────────────────────────────────────────────────────
  //  CURRENCY TILE
  // ─────────────────────────────────────────────────────────────

  Widget _currencyTile(bool isDesktop, bool isTablet,
      LanguageProvider langProvider, BuildContext context) {
    return Consumer<CurrencyProvider>(
      builder: (ctx, cp, _) => Column(children: [
        ListTile(
          leading: Icon(Icons.currency_exchange_rounded,
              color: Colors.deepPurple,
              size: isDesktop ? 28 : isTablet ? 24 : 20),
          title: Text(langProvider.translate('currency'),
              style: TextStyle(
                  fontSize:   isDesktop ? 18 : isTablet ? 16 : 14,
                  fontWeight: FontWeight.w500, color: Colors.black)),
          subtitle: Text(
            '${langProvider.translate('currency_updated')} '
                '${cp.lastUpdatedFormatted}',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
          ),
          trailing: GestureDetector(
            onTap: () => _showCurrencySheet(
                context, cp, langProvider, isDesktop, isTablet),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 12 : 8,
                  vertical:   isDesktop ? 6  : 4),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(cp.selectedFlag,
                    style: TextStyle(fontSize: isDesktop ? 18 : 16)),
                SizedBox(width: isDesktop ? 8 : 4),
                Text(cp.selectedCode,
                    style: TextStyle(fontSize: isDesktop ? 14 : 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple)),
                SizedBox(width: isDesktop ? 8 : 4),
                cp.isLoading
                    ? SizedBox(width: 14, height: 14,
                    child: const CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.deepPurple))
                    : Icon(Icons.arrow_drop_down,
                    color: Colors.deepPurple,
                    size: isDesktop ? 20 : 16),
              ]),
            ),
          ),
          contentPadding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 8 : isTablet ? 4 : 0,
              vertical:   isDesktop ? 4 : isTablet ? 2 : 0),
        ),
        Divider(height: 1, thickness: 0.5, color: Colors.grey[300],
            indent: isDesktop ? 68 : isTablet ? 64 : 60,
            endIndent: isDesktop ? 20 : isTablet ? 16 : 12),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  ✅ BOTTOM SHEET DEVISE — avec barre de recherche
  // ─────────────────────────────────────────────────────────────

  void _showCurrencySheet(
      BuildContext context,
      CurrencyProvider cp,
      LanguageProvider langProvider,
      bool isDesktop,
      bool isTablet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CurrencySheet(
        currencyProvider: cp,
        langProvider:     langProvider,
        onSelected: (code) async {
          await cp.setCurrency(code);
          setState(() {});
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  MENU TILE
  // ─────────────────────────────────────────────────────────────

  Widget _menuTile(
      String titleKey, IconData icon,
      bool isDesktop, bool isTablet,
      LanguageProvider langProvider, BuildContext context, {
        bool isLast = false,
      }) {
    return Column(children: [
      ListTile(
        leading: Icon(icon,
            color: isLast ? Colors.red : Colors.deepPurple,
            size: isDesktop ? 28 : isTablet ? 24 : 20),
        title: Text(langProvider.translate(titleKey),
            style: TextStyle(
                fontSize:   isDesktop ? 18 : isTablet ? 16 : 14,
                fontWeight: FontWeight.w500,
                color: isLast ? Colors.red : Colors.black)),
        trailing: Icon(Icons.arrow_forward_ios,
            color: Colors.grey[400],
            size: isDesktop ? 20 : isTablet ? 16 : 12),
        contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 8 : isTablet ? 4 : 0,
            vertical:   isDesktop ? 4 : isTablet ? 2 : 0),
        onTap: () async {
          if (titleKey == 'logout') {
            _showLogoutDialog(langProvider);
          } else if (titleKey == 'personal_info') {
            final ap = Provider.of<app_auth.AuthProvider>(
                context, listen: false);
            await Navigator.push(context, MaterialPageRoute(
                builder: (_) => EditProfilePage(user: ap.user)));
            await _loadPhotoBase64();
          } else if (titleKey == 'addresses') {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => const AddressPage()));
            await _loadUserStats();
          } else if (titleKey == 'notification_settings') {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => const NotificationSettingsPage()));
          } else if (titleKey == 'security') {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => const SecuritySettingsPage()));
          } else if (titleKey == 'terms_conditions') {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => const TermsConditionsPage()));
          } else if (titleKey == 'help') {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => const HelpPage()));
          } else if (titleKey == 'payment_methods') {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => const PaymentMethodsPage()));
            await _loadUserStats();
          }
        },
      ),
      if (!isLast)
        Divider(height: 1, thickness: 0.5, color: Colors.grey[300],
            indent:    isDesktop ? 68 : isTablet ? 64 : 60,
            endIndent: isDesktop ? 20 : isTablet ? 16 : 12),
    ]);
  }

  // ─────────────────────────────────────────────────────────────
  //  LOGOUT DIALOG
  // ─────────────────────────────────────────────────────────────

  void _showLogoutDialog(LanguageProvider langProvider) {
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
            Padding(
              padding: const EdgeInsets.all(28),
              child: Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15), shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3), width: 2),
                ),
                child: const Icon(Icons.logout_rounded,
                    color: Colors.white, size: 32),
              ),
            ),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(langProvider.translate('logout'),
                    style: const TextStyle(fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8700FF), letterSpacing: 0.5)),
                const SizedBox(height: 12),
                Text(langProvider.translate('confirm_logout'),
                    style: const TextStyle(fontSize: 16,
                        color: Color(0xFF64748B), height: 1.4),
                    textAlign: TextAlign.center),
                const SizedBox(height: 28),
                Row(children: [
                  Expanded(child: SizedBox(height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFF6366F1), width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(langProvider.translate('cancel'),
                            style: const TextStyle(color: Color(0xFF6366F1),
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      ))),
                  const SizedBox(width: 12),
                  Expanded(child: SizedBox(height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            _autoLogoutService.stopAutoLogout();
                            _pointsSubscription?.cancel();
                            await FirebaseAuth.instance.signOut();
                            Navigator.of(ctx).pop();
                            Navigator.pushReplacementNamed(context, '/login');
                          } catch (_) {
                            Navigator.of(ctx).pop();
                            Navigator.pushReplacementNamed(context, '/login');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white, elevation: 4,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: FittedBox(child: Text(
                            langProvider.translate('logout'),
                            style: const TextStyle(fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3))),
                      ))),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  ✅ _CurrencySheet — StatefulWidget avec barre de recherche
//     + taux croisé dynamique par rapport à la devise choisie
// ─────────────────────────────────────────────────────────────────

class _CurrencySheet extends StatefulWidget {
  final CurrencyProvider cp;
  final LanguageProvider langProvider;
  final Future<void> Function(String code) onSelected;

  const _CurrencySheet({
    required CurrencyProvider currencyProvider,
    required this.langProvider,
    required this.onSelected,
  }) : cp = currencyProvider;

  @override
  State<_CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends State<_CurrencySheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MapEntry<String, CurrencyMeta>> get _filtered {
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return kSupportedCurrencies.entries.toList();
    return kSupportedCurrencies.entries.where((e) =>
    e.key.toLowerCase().contains(q) ||
        e.value.name.toLowerCase().contains(q) ||
        e.value.symbol.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Consumer : le sheet se rebuild automatiquement quand
    // fetchRates() termine et appelle notifyListeners()
    // → la date de mise à jour et le spinner se mettent à jour
    return Consumer<CurrencyProvider>(
      builder: (context, cp, _) {
        final lang = widget.langProvider;

        return DraggableScrollableSheet(
          initialChildSize: 0.90,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (ctx, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(children: [

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Column(children: [

                    Center(child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)),
                    )),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(lang.translate('currency'),
                                  style: const TextStyle(fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B))),
                              const SizedBox(height: 3),
                              Text(lang.translate('currency_sheet_subtitle'),
                                  style: TextStyle(fontSize: 12,
                                      color: Colors.grey.shade500)),
                            ]),
                        // ✅ Bouton actualiser — appelle fetchRates()
                        // Consumer rebuilde le sheet quand isLoading change
                        // et quand lastUpdatedFormatted est mis à jour
                        GestureDetector(
                          onTap: cp.isLoading ? null : () => cp.fetchRates(),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: cp.isLoading
                                  ? Colors.grey.withOpacity(0.08)
                                  : Colors.deepPurple.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: cp.isLoading
                                      ? Colors.grey.withOpacity(0.2)
                                      : Colors.deepPurple.withOpacity(0.2)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              cp.isLoading
                                  ? const SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.deepPurple))
                                  : const Icon(Icons.refresh_rounded,
                                  size: 16, color: Colors.deepPurple),
                              const SizedBox(width: 6),
                              Text(lang.translate('currency_refresh'),
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: cp.isLoading
                                          ? Colors.grey
                                          : Colors.deepPurple)),
                            ]),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ✅ Bandeau MAJ — mis à jour automatiquement
                    // après fetchRates() via Consumer
                    if (cp.lastUpdated.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.update_rounded,
                              size: 12, color: Color(0xFF16A34A)),
                          const SizedBox(width: 7),
                          Expanded(child: Text(
                            '${lang.translate('currency_updated')} '
                                '${cp.lastUpdatedFormatted}',
                            style: const TextStyle(fontSize: 11,
                                color: Color(0xFF15803D),
                                fontWeight: FontWeight.w500),
                          )),
                        ]),
                      ),

                    if (cp.error.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5F5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFEF4444).withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.warning_rounded,
                              size: 12, color: Color(0xFFEF4444)),
                          const SizedBox(width: 7),
                          Expanded(child: Text(
                            lang.translate('currency_error_offline'),
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFFB91C1C)),
                          )),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: lang.translate('currency_search'),
                          hintStyle: TextStyle(
                              color: Colors.grey.shade400, fontSize: 14),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: Colors.grey.shade400, size: 20),
                          suffixIcon: _query.isNotEmpty
                              ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                            child: Icon(Icons.close_rounded,
                                color: Colors.grey.shade400, size: 18),
                          ) : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_filtered.length} ${lang.translate('currency_results')}',
                        style: TextStyle(fontSize: 11,
                            color: Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ]),
                ),

                Expanded(
                  child: _filtered.isEmpty
                      ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 48, color: Colors.grey.shade200),
                      const SizedBox(height: 10),
                      Text(lang.translate('currency_no_result'),
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 14)),
                    ],
                  ))
                      : ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final code       = _filtered[i].key;
                      final meta       = _filtered[i].value;
                      final isSelected = cp.selectedCode == code;
                      final rateStr    = cp.formatCrossRate(code);

                      return GestureDetector(
                        onTap: () async {
                          await widget.onSelected(code);
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.deepPurple.withOpacity(0.07)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.deepPurple.withOpacity(0.4)
                                  : Colors.grey.shade200,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(children: [
                            Text(meta.flag,
                                style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text(code, style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.deepPurple
                                          : const Color(0xFF1E293B))),
                                  const SizedBox(width: 8),
                                  Text(meta.symbol, style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w600)),
                                ]),
                                const SizedBox(height: 2),
                                Text(meta.name, style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500)),
                              ],
                            )),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                isSelected
                                    ? Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                      color: Colors.deepPurple,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.check_rounded,
                                      size: 11, color: Colors.white),
                                )
                                    : Container(
                                  width: 17, height: 17,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.grey.shade300)),
                                ),
                                const SizedBox(height: 4),
                                Text(rateStr, style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected
                                        ? Colors.deepPurple.withOpacity(0.7)
                                        : Colors.grey.shade400,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400)),
                              ],
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}
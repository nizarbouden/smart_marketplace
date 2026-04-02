import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';
import 'package:smart_marketplace/providers/auth_provider.dart';
import 'package:smart_marketplace/providers/currency_provider.dart'; // ✅
import 'package:smart_marketplace/providers/language_provider.dart';
import 'package:smart_marketplace/views/compte/profile/edit_profile_page.dart';
import 'package:smart_marketplace/views/compte/security/security_settings_page.dart';
import 'package:smart_marketplace/views/compte/terms&conditions/terms_conditions_page.dart';
import '../../models/user_model.dart';
import 'adress/add_address_page.dart';
import 'help/help_page.dart';
import 'notifications/notification_settings_page.dart';

const _green = Color(0xFF16A34A);

class SellerProfilePage extends StatefulWidget {
  const SellerProfilePage({super.key});

  @override
  State<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends State<SellerProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _t(String key) => AppLocalizations.get(key);
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  // ── Profil ─────────────────────────────────────────────────
  Map<String, dynamic>? _userData;
  bool    _isLoading    = true;
  String? _photoBase64;
  bool    _loadingPhoto = true;

  // ── Stats temps réel ───────────────────────────────────────
  int _productsCount  = 0;
  int _ordersCount    = 0;
  int _deliveredCount = 0;

  StreamSubscription<QuerySnapshot>? _productsSub;
  StreamSubscription<QuerySnapshot>? _subOrdersSub;
  StreamSubscription<User?>?         _authSub;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPhotoBase64();
    _listenStats();

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _productsSub?.cancel();
        _subOrdersSub?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _productsSub?.cancel();
    _subOrdersSub?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  //  STREAMS STATS
  // ─────────────────────────────────────────────────────────────

  void _listenStats() {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    _productsSub = _firestore
        .collection('products')
        .where('sellerId', isEqualTo: uid)
        .snapshots()
        .listen(
          (snap) {
        if (mounted) setState(() => _productsCount = snap.docs.length);
      },
      onError: (_) async {
        try {
          final snap = await _firestore
              .collection('products')
              .where('sellerId', isEqualTo: uid)
              .get();
          if (mounted) setState(() => _productsCount = snap.docs.length);
        } catch (_) {}
      },
    );

    _subOrdersSub = _firestore
        .collectionGroup('subOrders')
        .where('sellerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snap) {
        if (!mounted) return;
        int orders    = 0;
        int delivered = 0;
        for (final doc in snap.docs) {
          final status = (doc.data()['status'] as String?) ?? 'paid';
          if (status != 'cancelled') orders++;
          if (status == 'delivered') delivered++;
        }
        setState(() {
          _ordersCount    = orders;
          _deliveredCount = delivered;
        });
      },
      onError: (_) async {
        try {
          final snap = await _firestore
              .collectionGroup('subOrders')
              .where('sellerId', isEqualTo: uid)
              .get();
          if (!mounted) return;
          int orders    = 0;
          int delivered = 0;
          for (final doc in snap.docs) {
            final status = (doc.data()['status'] as String?) ?? 'paid';
            if (status != 'cancelled') orders++;
            if (status == 'delivered') delivered++;
          }
          setState(() {
            _ordersCount    = orders;
            _deliveredCount = delivered;
          });
        } catch (_) {}
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  CHARGEMENT PROFIL
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadUserData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final uid = _currentUser?.uid;
      if (uid == null) return;
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && mounted) setState(() => _userData = doc.data());
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadPhotoBase64() async {
    if (mounted) setState(() => _loadingPhoto = true);
    try {
      final uid = _currentUser?.uid;
      if (uid == null) return;
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() =>
        _photoBase64 = doc.data()?['photoBase64'] as String?);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingPhoto = false);
  }

  // ─────────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────────

  String _getDisplayName() {
    if (_userData != null) {
      return '${_userData!['prenom'] ?? ''} ${_userData!['nom'] ?? ''}'
          .trim();
    }
    return _currentUser?.displayName ?? '';
  }

  String _getEmail() =>
      _currentUser?.email ?? _userData?['email'] as String? ?? '';

  // ─────────────────────────────────────────────────────────────
  //  AVATAR
  // ─────────────────────────────────────────────────────────────

  Widget _buildAvatar({required double radius}) {
    if (_loadingPhoto) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.deepPurple[100],
        child: SizedBox(
          width: radius, height: radius,
          child: const CircularProgressIndicator(
              strokeWidth: 2, color: Colors.deepPurple),
        ),
      );
    }
    if (_photoBase64 != null && _photoBase64!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.deepPurple[100],
        child: ClipOval(
          child: Image.memory(
            base64Decode(_photoBase64!),
            width: radius * 2, height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackIcon(radius),
          ),
        ),
      );
    }
    final photoUrl =
        _userData?['photoUrl'] as String? ?? _currentUser?.photoURL;
    if (photoUrl != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.deepPurple[100],
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.deepPurple[100],
      child: _fallbackIcon(radius),
    );
  }

  Widget _fallbackIcon(double radius) =>
      Icon(Icons.person, size: radius, color: Colors.deepPurple);

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth  = MediaQuery.of(context).size.width;
    final isMobile     = screenWidth < 600;
    final isTablet     = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop    = screenWidth >= 1200;
    final langProvider = Provider.of<LanguageProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isRtl        = AppLocalizations.isRtl;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: RefreshIndicator(
          color: Colors.deepPurple,
          onRefresh: () async {
            await _loadPhotoBase64();
            await _loadUserData();
            // ✅ Rafraîchir les taux de change aussi
            await Provider.of<CurrencyProvider>(context, listen: false)
                .fetchRates();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(
                isDesktop ? 32 : isTablet ? 24 : 16),
            child: Column(children: [
              SizedBox(height: isDesktop ? 40 : isTablet ? 30 : 20),
              _buildProfileCard(
                  isDesktop, isTablet, authProvider, langProvider),
              SizedBox(height: isDesktop ? 32 : isTablet ? 24 : 20),
              _buildMenuCard(isDesktop, isTablet, langProvider),
              SizedBox(height: isTablet ? 30 : 20),
            ]),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  CARTE PROFIL
  // ─────────────────────────────────────────────────────────────

  Widget _buildProfileCard(bool isDesktop, bool isTablet,
      AuthProvider authProvider, LanguageProvider langProvider) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(children: [

        _buildAvatar(radius: isDesktop ? 80 : isTablet ? 60 : 50),
        SizedBox(height: isDesktop ? 24 : isTablet ? 20 : 16),

        Text(
          _getDisplayName().isEmpty
              ? _t('seller_default_name')
              : _getDisplayName(),
          style: TextStyle(
              fontSize: isDesktop ? 28 : isTablet ? 24 : 20,
              fontWeight: FontWeight.bold),
        ),
        SizedBox(height: isDesktop ? 8 : isTablet ? 6 : 4),

        Text(_getEmail(),
            style: TextStyle(
                fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                color: Colors.grey[600])),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.store_rounded, color: Colors.green, size: 14),
            const SizedBox(width: 5),
            Text(_t('seller_role_label'),
                style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        ),

        SizedBox(height: isDesktop ? 32 : isTablet ? 24 : 20),

        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statItem(
                label:     _t('seller_nav_products'),
                value:     '$_productsCount',
                icon:      Icons.inventory_2_rounded,
                color:     const Color(0xFF3B82F6),
                isDesktop: isDesktop,
                isTablet:  isTablet,
              ),
              _statDivider(),
              _statItem(
                label:     _t('seller_nav_orders'),
                value:     '$_ordersCount',
                icon:      Icons.receipt_long_rounded,
                color:     const Color(0xFF8B5CF6),
                isDesktop: isDesktop,
                isTablet:  isTablet,
              ),
              _statDivider(),
              _statItem(
                label:     _t('seller_stat_delivered'),
                value:     '$_deliveredCount',
                icon:      Icons.check_circle_rounded,
                color:     _green,
                isDesktop: isDesktop,
                isTablet:  isTablet,
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _statDivider() => Container(
      width: 1, height: 40, color: Colors.grey.shade200);

  Widget _statItem({
    required String   label,
    required String   value,
    required IconData icon,
    required Color    color,
    required bool     isDesktop,
    required bool     isTablet,
  }) {
    return Expanded(
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color,
              size: isDesktop ? 22 : isTablet ? 20 : 18),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: isDesktop ? 26 : isTablet ? 22 : 20,
                fontWeight: FontWeight.bold,
                color: color)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: isDesktop ? 12 : isTablet ? 11 : 10,
                color: Colors.grey[500]),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  MENU CARD
  // ─────────────────────────────────────────────────────────────

  Widget _buildMenuCard(
      bool isDesktop, bool isTablet, LanguageProvider langProvider) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(children: [
        _menuTile('seller_edit_profile', Icons.person,
            isDesktop, isTablet, langProvider,
            onTap: () async {
              final uid = _currentUser?.uid;
              if (uid == null) return;
              final doc = await FirebaseFirestore.instance
                  .collection('users').doc(uid).get();
              if (!mounted) return;
              final user =
              doc.exists ? UserModel.fromMap(doc.data()!) : null;
              Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => EditProfilePage(user: user)));
            }),
        _menuTile('seller_store_address', Icons.location_on_rounded,
            isDesktop, isTablet, langProvider,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) =>
                    const AddAddressPage(isSellerMode: true)))),
        _menuTile('notifications', Icons.notifications,
            isDesktop, isTablet, langProvider,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const NotificationSettingsPage()))),
        _menuTile('security', Icons.security,
            isDesktop, isTablet, langProvider,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const SecuritySettingsPage()))),
        _languageTile(isDesktop, isTablet, langProvider),

        // ✅ Section devise — entre langue et aide (identique côté acheteur)
        _currencyTile(isDesktop, isTablet, langProvider),

        _menuTile('help', Icons.help,
            isDesktop, isTablet, langProvider,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HelpPage()))),
        _menuTile('terms_conditions', Icons.description,
            isDesktop, isTablet, langProvider,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const TermsConditionsPage()))),
        _menuTile('seller_logout', Icons.logout,
            isDesktop, isTablet, langProvider,
            isLast: true,
            onTap: () => _showLogoutDialog(langProvider)),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  MENU TILE
  // ─────────────────────────────────────────────────────────────

  Widget _menuTile(
      String titleKey, IconData icon,
      bool isDesktop, bool isTablet, LanguageProvider langProvider, {
        required VoidCallback onTap,
        bool isLast = false,
      }) {
    return Column(children: [
      ListTile(
        leading: Icon(icon,
            color: isLast ? Colors.red : _green,
            size: isDesktop ? 28 : isTablet ? 24 : 20),
        title: Text(_t(titleKey),
            style: TextStyle(
                fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                fontWeight: FontWeight.w500,
                color: isLast ? Colors.red : Colors.black)),
        trailing: Icon(Icons.arrow_forward_ios,
            color: Colors.grey[400],
            size: isDesktop ? 20 : isTablet ? 16 : 12),
        contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 8 : isTablet ? 4 : 0,
            vertical: isDesktop ? 4 : isTablet ? 2 : 0),
        onTap: onTap,
      ),
      if (!isLast)
        Divider(
          height: 1, thickness: 0.5,
          color: Colors.grey[300],
          indent: isDesktop ? 68 : isTablet ? 64 : 60,
          endIndent: isDesktop ? 20 : isTablet ? 16 : 12,
        ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────
  //  LANGUAGE TILE
  // ─────────────────────────────────────────────────────────────

  Widget _languageTile(
      bool isDesktop, bool isTablet, LanguageProvider langProvider) {
    return Column(children: [
      ListTile(
        leading: Icon(Icons.language, color: _green,
            size: isDesktop ? 28 : isTablet ? 24 : 20),
        title: Text(_t('seller_language'),
            style: TextStyle(
                fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                fontWeight: FontWeight.w500)),
        trailing: PopupMenuButton<String>(
          onSelected: (code) async {
            await langProvider.setLanguage(code);
            setState(() {});
          },
          itemBuilder: (_) =>
              langProvider.supportedLanguages.entries.map((entry) {
                final sel = entry.key == langProvider.currentLanguageCode;
                return PopupMenuItem<String>(
                  value: entry.key,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(entry.value,
                        style: TextStyle(
                            fontWeight:
                            sel ? FontWeight.bold : FontWeight.normal,
                            color: sel ? Colors.green : Colors.black)),
                    if (sel)
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(Icons.check_circle,
                            color: Colors.green, size: 20),
                      ),
                  ]),
                );
              }).toList(),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 12 : 8,
                vertical: isDesktop ? 6 : 4),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(langProvider.currentLanguageFlag,
                  style: TextStyle(fontSize: isDesktop ? 18 : 16)),
              SizedBox(width: isDesktop ? 8 : 4),
              Text(langProvider.currentLanguageCode.toUpperCase(),
                  style: TextStyle(
                      fontSize: isDesktop ? 14 : 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green)),
              SizedBox(width: isDesktop ? 8 : 4),
              Icon(Icons.arrow_drop_down,
                  color: Colors.green,
                  size: isDesktop ? 20 : 16),
            ]),
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 8 : isTablet ? 4 : 0,
            vertical: isDesktop ? 4 : isTablet ? 2 : 0),
      ),
      Divider(
        height: 1, thickness: 0.5,
        color: Colors.grey[300],
        indent: isDesktop ? 68 : isTablet ? 64 : 60,
        endIndent: isDesktop ? 20 : isTablet ? 16 : 12,
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────
  //  ✅ CURRENCY TILE — identique côté acheteur
  // ─────────────────────────────────────────────────────────────

  Widget _currencyTile(
      bool isDesktop, bool isTablet, LanguageProvider langProvider) {
    return Consumer<CurrencyProvider>(
      builder: (ctx, cp, _) => Column(children: [
        ListTile(
          leading: Icon(Icons.currency_exchange_rounded,
              color: _green,
              size: isDesktop ? 28 : isTablet ? 24 : 20),
          title: Text(_t('currency'),
              style: TextStyle(
                  fontSize:   isDesktop ? 18 : isTablet ? 16 : 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black)),
          subtitle: Text(
            '${_t('currency_updated')} ${cp.lastUpdatedFormatted}',
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
                color: _green.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(cp.selectedFlag,
                    style: TextStyle(fontSize: isDesktop ? 18 : 16)),
                SizedBox(width: isDesktop ? 8 : 4),
                Text(cp.selectedCode,
                    style: TextStyle(
                        fontSize:   isDesktop ? 14 : 12,
                        fontWeight: FontWeight.w600,
                        color: _green)),
                SizedBox(width: isDesktop ? 8 : 4),
                cp.isLoading
                    ? SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _green),
                )
                    : Icon(Icons.arrow_drop_down,
                    color: _green,
                    size: isDesktop ? 20 : 16),
              ]),
            ),
          ),
          contentPadding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 8 : isTablet ? 4 : 0,
              vertical:   isDesktop ? 4 : isTablet ? 2 : 0),
        ),
        Divider(
          height: 1, thickness: 0.5,
          color: Colors.grey[300],
          indent: isDesktop ? 68 : isTablet ? 64 : 60,
          endIndent: isDesktop ? 20 : isTablet ? 16 : 12,
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  ✅ BOTTOM SHEET DEVISE
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
        accentColor:      _green,
        onSelected: (code) async {
          await cp.setCurrency(code);
          setState(() {});
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  LOGOUT DIALOG
  // ─────────────────────────────────────────────────────────────

  void _showLogoutDialog(LanguageProvider langProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        elevation: 20,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6366F1),
                Color(0xFF8B5CF6),
                Color(0xFFA855F7),
              ],
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.all(28),
              child: Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3), width: 2),
                ),
                child: const Icon(Icons.logout_rounded,
                    color: Colors.white, size: 32),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft:  Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_t('seller_logout'),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8700FF),
                        letterSpacing: 0.5)),
                const SizedBox(height: 12),
                Text(langProvider.translate('confirm_logout'),
                    style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF64748B),
                        height: 1.4),
                    textAlign: TextAlign.center),
                const SizedBox(height: 28),
                Row(children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFF6366F1), width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(_t('cancel'),
                            style: const TextStyle(
                                color: Color(0xFF6366F1),
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            _productsSub?.cancel();
                            _subOrdersSub?.cancel();
                            await FirebaseAuth.instance.signOut();
                          } catch (_) {}
                          Navigator.of(context).pop();
                          Navigator.pushReplacementNamed(
                              context, '/login');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: FittedBox(
                          child: Text(_t('seller_logout'),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3)),
                        ),
                      ),
                    ),
                  ),
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
//  ✅ _CurrencySheet — réutilisable côté vendeur
//     Même logique que côté acheteur, couleur accent paramétrable
// ─────────────────────────────────────────────────────────────────

class _CurrencySheet extends StatefulWidget {
  final CurrencyProvider            currencyProvider;
  final LanguageProvider            langProvider;
  final Color                       accentColor;
  final Future<void> Function(String code) onSelected;

  const _CurrencySheet({
    required this.currencyProvider,
    required this.langProvider,
    required this.accentColor,
    required this.onSelected,
  });

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
    // ✅ Consumer : rebuild automatique quand fetchRates() termine
    // → spinner, date MAJ et taux se mettent à jour en temps réel
    return Consumer<CurrencyProvider>(
      builder: (context, cp, _) {
        final lang   = widget.langProvider;
        final accent = widget.accentColor;

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
                        // ✅ Bouton actualiser désactivé pendant le chargement
                        GestureDetector(
                          onTap: cp.isLoading ? null : () => cp.fetchRates(),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: cp.isLoading
                                  ? Colors.grey.withOpacity(0.08)
                                  : accent.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: cp.isLoading
                                      ? Colors.grey.withOpacity(0.2)
                                      : accent.withOpacity(0.2)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              cp.isLoading
                                  ? SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: accent))
                                  : Icon(Icons.refresh_rounded,
                                  size: 16, color: accent),
                              const SizedBox(width: 6),
                              Text(lang.translate('currency_refresh'),
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: cp.isLoading
                                          ? Colors.grey
                                          : accent)),
                            ]),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ✅ Date MAJ — se met à jour automatiquement
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
                                ? accent.withOpacity(0.07)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? accent.withOpacity(0.4)
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
                                          ? accent
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
                                  decoration: BoxDecoration(
                                      color: accent, shape: BoxShape.circle),
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
                                        ? accent.withOpacity(0.7)
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
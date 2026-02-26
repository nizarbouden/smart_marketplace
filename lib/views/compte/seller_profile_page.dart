import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';
import 'package:smart_marketplace/providers/auth_provider.dart';
import 'package:smart_marketplace/providers/language_provider.dart';
import 'package:smart_marketplace/views/compte/profile/edit_profile_page.dart';
import 'package:smart_marketplace/views/compte/security/security_settings_page.dart';
import 'package:smart_marketplace/views/compte/terms&conditions/terms_conditions_page.dart';

import '../../models/user_model.dart';
import 'help/help_page.dart';
import 'notifications/notification_settings_page.dart';

// ── Décommente selon tes imports réels ─────────────────────────
// import 'seller_edit_profile_page.dart';
// import '../help/help_page.dart';
// import '../security/security_settings_page.dart';
// import '../notifications/notification_settings_page.dart';

const _green = Color(0xFF16A34A); // ✅ vert vendeur

class SellerProfilePage extends StatefulWidget {
  const SellerProfilePage({super.key});

  @override
  State<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends State<SellerProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _t(String key) => AppLocalizations.get(key);
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  // ── State ──────────────────────────────────────────────────
  Map<String, dynamic>? _userData;
  bool   _isLoading    = true;
  String? _photoBase64;
  bool   _loadingPhoto = true;

  // Stats vendeur
  int _productsCount = 0;
  int _ordersCount   = 0;
  int _revenueCount  = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ── Chargement ─────────────────────────────────────────────

  Future<void> _loadAll() async {
    await Future.wait([
      _loadUserData(),
      _loadPhotoBase64(),
      _loadSellerStats(),
    ]);
  }

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

  Future<void> _loadSellerStats() async {
    try {
      final uid = _currentUser?.uid;
      if (uid == null) return;

      final products = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: uid)
          .get();

      final orders = await _firestore
          .collection('orders')
          .where('sellerId', isEqualTo: uid)
          .get();

      final delivered = orders.docs
          .where((d) => d.data()['status'] == 'delivered')
          .length;

      if (mounted) {
        setState(() {
          _productsCount = products.docs.length;
          _ordersCount   = orders.docs.length;
          _revenueCount  = delivered;
        });
      }
    } catch (_) {}
  }

  // ── Helpers ─────────────────────────────────────────────────

  String _getDisplayName() {
    if (_userData != null) {
      return '${_userData!['prenom'] ?? ''} ${_userData!['nom'] ?? ''}'
          .trim();
    }
    return _currentUser?.displayName ?? '';
  }

  String _getEmail() {
    return _currentUser?.email ?? _userData?['email'] as String? ?? '';
  }

  // ── Avatar ──────────────────────────────────────────────────

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

  Widget _fallbackIcon(double radius) => Icon(
    Icons.person,
    size: radius,
    color: Colors.deepPurple,
  );

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth  = MediaQuery.of(context).size.width;
    final isMobile     = screenWidth < 600;
    final isTablet     = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop    = screenWidth >= 1200;
    final langProvider = Provider.of<LanguageProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
        color: Colors.deepPurple,
        onRefresh: () async {
          await _loadPhotoBase64();
          await _loadAll();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(
              isDesktop ? 32 : isTablet ? 24 : 16),
          child: Column(
            children: [
              SizedBox(height: isDesktop ? 40 : isTablet ? 30 : 20),

              _buildProfileCard(
                  isDesktop, isTablet, authProvider, langProvider),

              SizedBox(
                  height: isDesktop ? 32 : isTablet ? 24 : 20),

              _buildMenuCard(
                  isDesktop, isTablet, langProvider),

              SizedBox(height: isTablet ? 30 : 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Carte profil ─────────────────────────────────────────────

  Widget _buildProfileCard(bool isDesktop, bool isTablet,
      AuthProvider authProvider, LanguageProvider langProvider) {
    return Container(
      padding: EdgeInsets.all(
          isDesktop ? 32 : isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(isDesktop ? 20 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildAvatar(
              radius: isDesktop ? 80 : isTablet ? 60 : 50),

          SizedBox(height: isDesktop ? 24 : isTablet ? 20 : 16),

          Text(
            _getDisplayName().isEmpty
                ? _t('seller_default_name')
                : _getDisplayName(),
            style: TextStyle(
              fontSize: isDesktop ? 28 : isTablet ? 24 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: isDesktop ? 8 : isTablet ? 6 : 4),

          Text(
            _getEmail(),
            style: TextStyle(
              fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
              color: Colors.grey[600],
            ),
          ),

          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.store_rounded,
                    color: Colors.green, size: 14),
                const SizedBox(width: 5),
                Text(
                  _t('seller_role_label'),
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
              height: isDesktop ? 32 : isTablet ? 24 : 20),

          // ✅ Stats — chiffres en vert uniquement
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statItem(
                _t('seller_nav_products'),
                '$_productsCount',
                isDesktop, isTablet,
              ),
              _statItem(
                _t('seller_nav_orders'),
                '$_ordersCount',
                isDesktop, isTablet,
              ),
              _statItem(
                _t('seller_stat_delivered'),
                '$_revenueCount',
                isDesktop, isTablet,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ Seule modification : color: _green pour les chiffres
  Widget _statItem(
      String label, String value, bool isDesktop, bool isTablet) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: isDesktop ? 32 : isTablet ? 28 : 24,
            fontWeight: FontWeight.bold,
            color: _green, // ✅ vert
          ),
        ),
        SizedBox(height: isDesktop ? 8 : isTablet ? 6 : 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isDesktop ? 16 : isTablet ? 14 : 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── Menu card ─────────────────────────────────────────────────

  Widget _buildMenuCard(
      bool isDesktop, bool isTablet, LanguageProvider langProvider) {
    return Container(
      padding: EdgeInsets.all(
          isDesktop ? 24 : isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(isDesktop ? 20 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _menuTile(
            'seller_edit_profile', Icons.person,
            isDesktop, isTablet, langProvider,
            onTap: () async {
              final uid = _currentUser?.uid;
              if (uid == null) return;

              final doc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .get();

              if (!mounted) return;

              final user = doc.exists
                  ? UserModel.fromMap(doc.data()!)
                  : null;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfilePage(user: user),
                ),
              );
            },
          ),
          _menuTile(
            'notifications', Icons.notifications,
            isDesktop, isTablet, langProvider,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationSettingsPage())),
          ),

          _menuTile(
            'security', Icons.security,
            isDesktop, isTablet, langProvider,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SecuritySettingsPage())),
          ),

          _languageTile(isDesktop, isTablet, langProvider),

          _menuTile('help', Icons.help,
              isDesktop, isTablet, langProvider,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HelpPage()))),

          _menuTile(
            'terms_conditions', Icons.description,
            isDesktop, isTablet, langProvider,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TermsConditionsPage(),
                ),
              );
            },
          ),

          _menuTile(
            'seller_logout', Icons.logout,
            isDesktop, isTablet, langProvider,
            isLast: true,
            onTap: () => _showLogoutDialog(langProvider),
          ),
        ],
      ),
    );
  }

  // ✅ Seule modification : color: _green pour les icônes (rouge pour logout)
  Widget _menuTile(
      String titleKey,
      IconData icon,
      bool isDesktop,
      bool isTablet,
      LanguageProvider langProvider, {
        required VoidCallback onTap,
        bool isLast = false,
      }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(
            icon,
            color: isLast ? Colors.red : _green, // ✅ vert
            size: isDesktop ? 28 : isTablet ? 24 : 20,
          ),
          title: Text(
            _t(titleKey),
            style: TextStyle(
              fontSize:   isDesktop ? 18 : isTablet ? 16 : 14,
              fontWeight: FontWeight.w500,
              color: isLast ? Colors.red : Colors.black,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: Colors.grey[400],
            size: isDesktop ? 20 : isTablet ? 16 : 12,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 8 : isTablet ? 4 : 0,
            vertical:   isDesktop ? 4 : isTablet ? 2 : 0,
          ),
          onTap: onTap,
        ),
        if (!isLast)
          Divider(
            height: 1, thickness: 0.5,
            color: Colors.grey[300],
            indent:    isDesktop ? 68 : isTablet ? 64 : 60,
            endIndent: isDesktop ? 20 : isTablet ? 16 : 12,
          ),
      ],
    );
  }

  // ✅ Seule modification : color: _green pour l'icône langue
  Widget _languageTile(
      bool isDesktop, bool isTablet, LanguageProvider langProvider) {
    return Column(
      children: [
        ListTile(
          leading: Icon(
            Icons.language,
            color: _green, // ✅ vert
            size: isDesktop ? 28 : isTablet ? 24 : 20,
          ),
          title: Text(
            _t('seller_language'),
            style: TextStyle(
              fontSize:   isDesktop ? 18 : isTablet ? 16 : 14,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (code) async {
              await langProvider.setLanguage(code);
              setState(() {});
            },
            itemBuilder: (_) =>
                langProvider.supportedLanguages.entries.map((entry) {
                  final sel =
                      entry.key == langProvider.currentLanguageCode;
                  return PopupMenuItem<String>(
                    value: entry.key,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          entry.value,
                          style: TextStyle(
                            fontWeight: sel
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color:
                            sel ? Colors.green : Colors.black,
                          ),
                        ),
                        if (sel)
                          const Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: Icon(Icons.check_circle,
                                color: Colors.green, size: 20),
                          ),
                      ],
                    ),
                  );
                }).toList(),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 12 : 8,
                vertical:   isDesktop ? 6  : 4,
              ),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(langProvider.currentLanguageFlag,
                      style: TextStyle(
                          fontSize: isDesktop ? 18 : 16)),
                  SizedBox(width: isDesktop ? 8 : 4),
                  Text(
                    langProvider.currentLanguageCode.toUpperCase(),
                    style: TextStyle(
                      fontSize:   isDesktop ? 14 : 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(width: isDesktop ? 8 : 4),
                  Icon(Icons.arrow_drop_down,
                      color: Colors.green,
                      size: isDesktop ? 20 : 16),
                ],
              ),
            ),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 8 : isTablet ? 4 : 0,
            vertical:   isDesktop ? 4 : isTablet ? 2 : 0,
          ),
        ),
        Divider(
          height: 1, thickness: 0.5,
          color: Colors.grey[300],
          indent:    isDesktop ? 68 : isTablet ? 64 : 60,
          endIndent: isDesktop ? 20 : isTablet ? 16 : 12,
        ),
      ],
    );
  }

  // ── Logout dialog — identique à l'original ────────────────────

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                child: Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _t('seller_logout'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8700FF),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      langProvider.translate('confirm_logout'),
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
                              onPressed: () =>
                                  Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: Color(0xFF6366F1),
                                    width: 1.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(16)),
                              ),
                              child: Text(
                                _t('cancel'),
                                style: const TextStyle(
                                  color: Color(0xFF6366F1),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
                                    borderRadius:
                                    BorderRadius.circular(16)),
                              ),
                              child: FittedBox(
                                child: Text(
                                  _t('seller_logout'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
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
      ),
    );
  }
}
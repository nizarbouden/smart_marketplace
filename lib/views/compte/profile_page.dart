import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/language_provider.dart';
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
  final FirebaseAuthService _authService = FirebaseAuthService();
  final AutoLogoutService _autoLogoutService = AutoLogoutService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _dialogShown = false;
  int _ordersCount = 0;
  int _favoritesCount = 0;

  // ── Base64 avatar ──────────────────────────────────────────
  String? _photoBase64;
  bool _loadingPhoto = true;

  @override
  void initState() {
    super.initState();
    _syncEmailIfNeeded();
    _setupListeners();
    _loadUserStats();
    _loadPhotoBase64();
  }

  // ── Charger photo Base64 depuis Firestore ──────────────────

  Future<void> _loadPhotoBase64() async {
    setState(() => _loadingPhoto = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _photoBase64 = doc.data()?['photoBase64'] as String?;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingPhoto = false);
  }

  // ── Avatar widget ──────────────────────────────────────────

  Widget _buildAvatar({
    required double radius,
    required app_auth.AuthProvider authProvider,
  }) {
    if (_loadingPhoto) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.deepPurple[100],
        child: SizedBox(
          width: radius,
          height: radius,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.deepPurple,
          ),
        ),
      );
    }

    // Priorité : Base64 Firestore > photoUrl réseau > icône
    if (_photoBase64 != null && _photoBase64!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.deepPurple[100],
        child: ClipOval(
          child: Image.memory(
            base64Decode(_photoBase64!),
            width:  radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackIcon(radius),
          ),
        ),
      );
    }

    if (authProvider.user?.photoUrl != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.deepPurple[100],
        backgroundImage: NetworkImage(authProvider.user!.photoUrl!),
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

  // ── Stats & listeners (inchangés) ─────────────────────────

  Future<void> _loadUserStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        int orders = 0;
        int favorites = 0;

        try {
          final ordersSnapshot = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('commandes')
              .get();
          orders = ordersSnapshot.docs.length;
        } catch (_) {}

        try {
          final favoritesSnapshot = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('favoris')
              .get();
          favorites = favoritesSnapshot.docs.length;
        } catch (_) {}

        if (mounted) {
          setState(() {
            _ordersCount   = orders;
            _favoritesCount = favorites;
          });
        }
      }
    } catch (_) {}
  }

  void _setupListeners() {
    _autoLogoutService.addWarningListener((event) {
      if (mounted) _showAutoLogoutWarning(event.remainingSeconds);
    });

    _autoLogoutService.addLogoutListener((event) {
      if (mounted) {
        final langProvider =
        Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(langProvider.translate('session_expired')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
        _autoLogoutService.stopAutoLogout();
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    });
  }

  void _showAutoLogoutWarning(int remainingSeconds) {
    if (_dialogShown) return;
    _dialogShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AutoLogoutWarningDialog(
          remainingSeconds: remainingSeconds,
          onStayLoggedIn: () {
            _dialogShown = false;
            if (mounted && Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
            _autoLogoutService.recordActivity();
          },
          onLogout: () {
            _dialogShown = false;
            if (mounted && Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
            _autoLogoutService.stopAutoLogout();
            FirebaseAuth.instance.signOut();
            if (mounted) {
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            }
          },
        );
      },
    ).then((_) => _dialogShown = false);
  }

  Future<void> _syncEmailIfNeeded() async {
    try {
      String? authEmail = _authService.getCurrentEmail();
      final authProvider =
      Provider.of<app_auth.AuthProvider>(context, listen: false);
      if (authEmail != null && authEmail != authProvider.user?.email) {
        await _authService.syncEmailFromAuth();
      }
    } catch (_) {}
  }

  String _getCorrectEmail() {
    String? authEmail = _authService.getCurrentEmail();
    final authProvider =
    Provider.of<app_auth.AuthProvider>(context);
    return authEmail ??
        authProvider.user?.email ??
        'email@example.com';
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile  = screenWidth < 600;
    final isTablet  = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    final authProvider = Provider.of<app_auth.AuthProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
        // Pull-to-refresh pour recharger la photo après retour de l'édition
        color: Colors.deepPurple,
        onRefresh: () async {
          await _loadPhotoBase64();
          await _loadUserStats();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding:
          EdgeInsets.all(isDesktop ? 32 : isTablet ? 24 : 16),
          child: Column(
            children: [
              SizedBox(height: isDesktop ? 40 : isTablet ? 30 : 20),

              // ── Carte profil ─────────────────────────────────
              Container(
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
                    // Avatar avec reload automatique
                    _buildAvatar(
                      radius: isDesktop ? 80 : isTablet ? 60 : 50,
                      authProvider: authProvider,
                    ),

                    SizedBox(
                        height: isDesktop ? 24 : isTablet ? 20 : 16),

                    Text(
                      authProvider.fullName ?? 'User',
                      style: TextStyle(
                        fontSize: isDesktop
                            ? 28
                            : isTablet
                            ? 24
                            : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(
                        height: isDesktop ? 8 : isTablet ? 6 : 4),
                    Text(
                      _getCorrectEmail(),
                      style: TextStyle(
                        fontSize: isDesktop
                            ? 18
                            : isTablet
                            ? 16
                            : 14,
                        color: Colors.grey[600],
                      ),
                    ),

                    SizedBox(
                        height: isDesktop ? 32 : isTablet ? 24 : 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statItem(
                          langProvider.translate('orders'),
                          '$_ordersCount',
                          isDesktop,
                          isTablet,
                        ),
                        _statItem(
                          langProvider.translate('favorites'),
                          '$_favoritesCount',
                          isDesktop,
                          isTablet,
                        ),
                        _statItem(
                          langProvider.translate('points'),
                          '${authProvider.points}',
                          isDesktop,
                          isTablet,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: isDesktop ? 32 : isTablet ? 24 : 20),

              // ── Menu ─────────────────────────────────────────
              Container(
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
                    _menuTile('personal_info', Icons.person,
                        isDesktop, isTablet, langProvider, context),
                    _menuTile('addresses', Icons.location_on,
                        isDesktop, isTablet, langProvider, context),
                    _menuTile('payment_methods', Icons.credit_card,
                        isDesktop, isTablet, langProvider, context),
                    _menuTile('notification_settings',
                        Icons.notifications, isDesktop, isTablet,
                        langProvider, context),
                    _menuTile('security', Icons.security, isDesktop,
                        isTablet, langProvider, context),
                    _languageTile(
                        isDesktop, isTablet, langProvider, context),
                    _menuTile('help', Icons.help, isDesktop, isTablet,
                        langProvider, context),
                    _menuTile('terms_conditions', Icons.description,
                        isDesktop, isTablet, langProvider, context),
                    _menuTile('logout', Icons.logout, isDesktop,
                        isTablet, langProvider, context,
                        isLast: true),
                  ],
                ),
              ),

              SizedBox(height: isTablet ? 30 : 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(
      String label, String value, bool isDesktop, bool isTablet) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize:
            isDesktop ? 32 : isTablet ? 28 : 24,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        SizedBox(height: isDesktop ? 8 : isTablet ? 6 : 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isDesktop ? 16 : isTablet ? 14 : 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _languageTile(bool isDesktop, bool isTablet,
      LanguageProvider langProvider, BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.language,
              color: Colors.deepPurple,
              size: isDesktop ? 28 : isTablet ? 24 : 20),
          title: Text(
            langProvider.translate('language'),
            style: TextStyle(
              fontSize:   isDesktop ? 18 : isTablet ? 16 : 14,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (String languageCode) async {
              await langProvider.setLanguage(languageCode);
              setState(() {});
            },
            itemBuilder: (BuildContext context) {
              return langProvider.supportedLanguages.entries
                  .map((entry) {
                final isSelected =
                    entry.key == langProvider.currentLanguageCode;
                return PopupMenuItem<String>(
                  value: entry.key,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.value,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? Colors.deepPurple
                              : Colors.black,
                        ),
                      ),
                      if (isSelected)
                        const Padding(
                          padding: EdgeInsets.only(left: 12.0),
                          child: Icon(Icons.check_circle,
                              color: Colors.deepPurple, size: 20),
                        ),
                    ],
                  ),
                );
              }).toList();
            },
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
                      style:
                      TextStyle(fontSize: isDesktop ? 18 : 16)),
                  SizedBox(width: isDesktop ? 8 : 4),
                  Text(
                    langProvider.currentLanguageCode.toUpperCase(),
                    style: TextStyle(
                      fontSize:   isDesktop ? 14 : 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.deepPurple,
                    ),
                  ),
                  SizedBox(width: isDesktop ? 8 : 4),
                  Icon(Icons.arrow_drop_down,
                      color: Colors.deepPurple,
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

  Widget _menuTile(
      String titleKey,
      IconData icon,
      bool isDesktop,
      bool isTablet,
      LanguageProvider langProvider,
      BuildContext context, {
        bool isLast = false,
      }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon,
              color: isLast ? Colors.red : Colors.deepPurple,
              size: isDesktop ? 28 : isTablet ? 24 : 20),
          title: Text(
            langProvider.translate(titleKey),
            style: TextStyle(
              fontSize:   isDesktop ? 18 : isTablet ? 16 : 14,
              fontWeight: FontWeight.w500,
              color: isLast ? Colors.red : Colors.black,
            ),
          ),
          trailing: Icon(Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: isDesktop ? 20 : isTablet ? 16 : 12),
          contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 8 : isTablet ? 4 : 0,
            vertical:   isDesktop ? 4 : isTablet ? 2 : 0,
          ),
          onTap: () async {
            if (titleKey == 'logout') {
              _showLogoutDialog(langProvider);
            } else if (titleKey == 'personal_info') {
              final authProvider = Provider.of<app_auth.AuthProvider>(
                  context, listen: false);
              // ✅ Attendre le retour et recharger la photo
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      EditProfilePage(user: authProvider.user),
                ),
              );
              // Recharger la photo Base64 après retour de l'édition
              await _loadPhotoBase64();
            } else if (titleKey == 'addresses') {
              Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const AddressPage()));
            } else if (titleKey == 'notification_settings') {
              Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) =>
                      const NotificationSettingsPage()));
            } else if (titleKey == 'security') {
              Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) =>
                      const SecuritySettingsPage()));
            } else if (titleKey == 'terms_conditions') {
              Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) =>
                      const TermsConditionsPage()));
            } else if (titleKey == 'help') {
              Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const HelpPage()));
            } else if (titleKey == 'payment_methods') {
              Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) =>
                      const PaymentMethodsPage()));
            }
          },
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

  void _showLogoutDialog(LanguageProvider langProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext context) {
        return Dialog(
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
                      color:
                      Colors.white.withOpacity(0.15),
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
                        langProvider.translate('logout'),
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
                                  langProvider.translate('cancel'),
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
                                    _autoLogoutService
                                        .stopAutoLogout();
                                    await FirebaseAuth.instance
                                        .signOut();
                                    Navigator.of(context).pop();
                                    Navigator.pushReplacementNamed(
                                        context, '/login');
                                  } catch (_) {
                                    Navigator.of(context).pop();
                                    Navigator.pushReplacementNamed(
                                        context, '/login');
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                  const Color(0xFF6366F1),
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(16)),
                                ),
                                child: FittedBox(
                                  child: Text(
                                    langProvider.translate('logout'),
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
        );
      },
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../localization/app_localizations.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/auto_logout_service.dart';
import '../../../services/session_management_service.dart';
import '../../../widgets/auto_logout_warning_dialog.dart';
import '../../../widgets/active_sessions_dialog.dart';
import '../../../widgets/delete_account_dialog.dart';
import 'change_password/change_password_page.dart';


class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  bool _twoFactorAuth = false;
  bool _biometricAuth = true;
  bool _loginNotifications = true;
  bool _sessionTimeout = true;
  String _sessionTimeoutValue = '30 minutes'; // Valeur par défaut temporaire

  bool _isServiceReady = false;
  bool _dialogShown = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseAuthService _authService = FirebaseAuthService();
  final AutoLogoutService _autoLogoutService = AutoLogoutService();
  final SessionManagementService _sessionService = SessionManagementService();

  // Fonction pour mapper les valeurs stockées vers les valeurs traduites
  String _mapStoredValueToLocalized(String storedValue) {
    switch (storedValue) {
      case '5 seconds':
      case '5 secondes':
      case '5 ثوانٍ':
        return AppLocalizations.get('session_timeout_5_seconds');
      case '15 minutes':
      case '15 دقيقة':
        return AppLocalizations.get('session_timeout_15_minutes');
      case '30 minutes':
      case '30 دقيقة':
        return AppLocalizations.get('session_timeout_30_minutes');
      case '1 hour':
      case '1 heure':
      case '1 ساعة':
        return AppLocalizations.get('session_timeout_1_hour');
      case '2 hours':
      case '2 heures':
      case 'ساعتان':
        return AppLocalizations.get('session_timeout_2_hours');
      default:
        return AppLocalizations.get('session_timeout_30_minutes');
    }
  }

  // Fonction pour mapper les valeurs traduites vers les valeurs stockées (en anglais pour la cohérence)
  String _mapLocalizedToStoredValue(String localizedValue) {
    final frenchToEnglish = {
      AppLocalizations.get('session_timeout_5_seconds'): '5 seconds',
      AppLocalizations.get('session_timeout_15_minutes'): '15 minutes',
      AppLocalizations.get('session_timeout_30_minutes'): '30 minutes',
      AppLocalizations.get('session_timeout_1_hour'): '1 hour',
      AppLocalizations.get('session_timeout_2_hours'): '2 hours',
    };
    
    return frenchToEnglish[localizedValue] ?? '30 minutes';
  }

  @override
  void initState() {
    super.initState();
    _initializeService();
    _setupAutoLogout();
  }

  Future<void> _initializeService() async {
    try {
      await _autoLogoutService.init();
      await _sessionService.init();
      await _sessionService.createSession();

      final settings = await _autoLogoutService.loadAutoLogoutSettings();

      if (mounted) {
        setState(() {
          _sessionTimeout = settings['enabled'] ?? false;
          // Mapper la valeur stockée vers la valeur localisée
          final storedDuration = settings['duration'] ?? '30 minutes';
          _sessionTimeoutValue = _mapStoredValueToLocalized(storedDuration);
          _isServiceReady = true;
        });
      }

      if (_sessionTimeout) {
        // Utiliser la valeur stockée (en anglais) pour le service
        final storedDuration = _mapLocalizedToStoredValue(_sessionTimeoutValue);
        _autoLogoutService.startAutoLogout(storedDuration);
      }
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation du service: $e');
    }
  }

  void _setupAutoLogout() {
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

  @override
  void dispose() {
    print('🔌 SecuritySettingsPage: dispose()');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    if (!_isServiceReady) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(AppLocalizations.get('security')),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(context, isDesktop, isTablet, isMobile),
      body: _buildBody(context, isDesktop, isTablet, isMobile),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDesktop, bool isTablet, bool isMobile) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(Icons.arrow_back, color: Colors.black87,
            size: isDesktop ? 28 : isTablet ? 24 : 20),
      ),
      title: Text(
        AppLocalizations.get('security'),
        style: TextStyle(
          color: Colors.black87,
          fontSize: isDesktop ? 24 : isTablet ? 22 : 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: IconButton(
            onPressed: _saveSettings,
            icon: Icon(Icons.save, color: Colors.deepPurple,
                size: isDesktop ? 24 : isTablet ? 22 : 20),
            tooltip: AppLocalizations.get('save'),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, bool isDesktop, bool isTablet, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 24 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Authentification
          _buildSectionCard(
            title: AppLocalizations.get('security'),
            icon: Icons.lock,
            children: [
              _buildSwitchTile(
                title: AppLocalizations.get('two_factor_auth'),
                subtitle: 'Ajoute une couche de sécurité supplémentaire',
                value: _twoFactorAuth,
                onChanged: (value) => setState(() => _twoFactorAuth = value),
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
              _buildSwitchTile(
                title: AppLocalizations.get('biometric_auth'),
                subtitle: 'Utilisez votre empreinte ou visage',
                value: _biometricAuth,
                onChanged: (value) => setState(() => _biometricAuth = value),
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
              _buildActionTile(
                title: AppLocalizations.get('change_password'),
                subtitle: AppLocalizations.get('new_password'),
                icon: Icons.password,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const ChangePasswordPage())),
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
            ],
            isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
          ),

          SizedBox(height: isMobile ? 20 : isTablet ? 24 : 28),

          // Session
          _buildSectionCard(
            title: AppLocalizations.get('section_session'),
            icon: Icons.timer,
            children: [
              _buildSwitchTile(
                title: AppLocalizations.get('session_expired'),
                subtitle: AppLocalizations.get('inactivity_detected'),
                value: _sessionTimeout,
                onChanged: (value) async {
                  setState(() => _sessionTimeout = value);
                  if (value) {
                    // Utiliser la valeur stockée (en anglais) pour le service
                    final storedDuration = _mapLocalizedToStoredValue(_sessionTimeoutValue);
                    _autoLogoutService.startAutoLogout(storedDuration);
                    await _autoLogoutService.saveAutoLogoutSettings(
                        enabled: true, duration: storedDuration);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${AppLocalizations.get('success')} $_sessionTimeoutValue'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                      ));
                    }
                  } else {
                    _autoLogoutService.stopAutoLogout();
                    // Utiliser la valeur stockée (en anglais) pour la sauvegarde
                    final storedDuration = _mapLocalizedToStoredValue(_sessionTimeoutValue);
                    await _autoLogoutService.saveAutoLogoutSettings(
                        enabled: false, duration: storedDuration);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(AppLocalizations.get('session_expired')),
                        backgroundColor: Colors.orange,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                      ));
                    }
                  }
                },
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
              if (_sessionTimeout)
                _buildDropdownTile(
                  title: AppLocalizations.get('remaining_time'),
                  subtitle: AppLocalizations.get('inactivity_warning'),
                  value: _sessionTimeoutValue,
                  items: [
                    AppLocalizations.get('session_timeout_5_seconds'),
                    AppLocalizations.get('session_timeout_15_minutes'),
                    AppLocalizations.get('session_timeout_30_minutes'),
                    AppLocalizations.get('session_timeout_1_hour'),
                    AppLocalizations.get('session_timeout_2_hours'),
                  ],
                  onChanged: (value) async {
                    setState(() => _sessionTimeoutValue = value);
                    // Utiliser la valeur stockée (en anglais) pour le service
                    final storedDuration = _mapLocalizedToStoredValue(value);
                    _autoLogoutService.startAutoLogout(storedDuration);
                    await _autoLogoutService.saveAutoLogoutSettings(
                        enabled: true, duration: storedDuration);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${AppLocalizations.get('success')} $value'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ));
                    }
                  },
                  isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
                ),
              _buildActionTile(
                title: AppLocalizations.get('active_sessions'),
                subtitle: AppLocalizations.get('active_sessions'),
                icon: Icons.devices,
                onTap: _showActiveSessions,
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
            ],
            isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
          ),

          SizedBox(height: isMobile ? 20 : isTablet ? 24 : 28),

          // Confidentialité
          _buildSectionCard(
            title: AppLocalizations.get('section_confidentiality'),
            icon: Icons.privacy_tip,
            children: [
              _buildSwitchTile(
                title: AppLocalizations.get('notif_security_title'),
                subtitle: AppLocalizations.get('notif_security_subtitle'),
                value: _loginNotifications,
                onChanged: (value) => setState(() => _loginNotifications = value),
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
              _buildActionTile(
                title: AppLocalizations.get('save'),
                subtitle: AppLocalizations.get('personal_info'),
                icon: Icons.download,
                onTap: _downloadData,
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
              _buildActionTile(
                title: AppLocalizations.get('security_delete_account'),
                subtitle: AppLocalizations.get('confirm'),
                icon: Icons.delete_forever,
                isDanger: true,
                onTap: _showDeleteAccountDialog,
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
            ],
            isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
          ),

          SizedBox(height: isMobile ? 32 : isTablet ? 40 : 48),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 8 : isTablet ? 10 : 12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.deepPurple,
                      size: isDesktop ? 24 : isTablet ? 22 : 20),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Text(title,
                    style: TextStyle(
                        fontSize: isDesktop ? 18 : isTablet ? 17 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : isTablet ? 20 : 24,
            vertical: isMobile ? 12 : isTablet ? 14 : 16,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    SizedBox(height: isMobile ? 2 : 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                            color: Colors.grey[600])),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.deepPurple,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 0.5, color: Colors.grey[200],
            indent: isMobile ? 16 : isTablet ? 20 : 24,
            endIndent: isMobile ? 16 : isTablet ? 20 : 24),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isDanger = false,
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : isTablet ? 20 : 24,
              vertical: isMobile ? 12 : isTablet ? 14 : 16,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 8 : isTablet ? 10 : 12),
                  decoration: BoxDecoration(
                    color: isDanger
                        ? Colors.red.withOpacity(0.1)
                        : Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon,
                      color: isDanger ? Colors.red : Colors.deepPurple,
                      size: isDesktop ? 20 : isTablet ? 18 : 16),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
                              fontWeight: FontWeight.w600,
                              color: isDanger ? Colors.red : Colors.black87)),
                      SizedBox(height: isMobile ? 2 : 4),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                              color: Colors.grey[600])),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.grey[400],
                    size: isDesktop ? 20 : isTablet ? 18 : 16),
              ],
            ),
          ),
        ),
        Divider(height: 1, thickness: 0.5, color: Colors.grey[200],
            indent: isMobile ? 16 : isTablet ? 20 : 24,
            endIndent: isMobile ? 16 : isTablet ? 20 : 24),
      ],
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required Function(String) onChanged,
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : isTablet ? 20 : 24,
            vertical: isMobile ? 12 : isTablet ? 14 : 16,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    SizedBox(height: isMobile ? 2 : 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                            color: Colors.grey[600])),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : isTablet ? 16 : 20,
                  vertical: isMobile ? 8 : isTablet ? 10 : 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: value,
                  onChanged: (String? newValue) {
                    if (newValue != null) onChanged(newValue);
                  },
                  items: items.map<DropdownMenuItem<String>>((String item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(item,
                          style: TextStyle(fontSize: isDesktop ? 14 : isTablet ? 13 : 12)),
                    );
                  }).toList(),
                  underline: const SizedBox(),
                  icon: Icon(Icons.keyboard_arrow_down, color: Colors.deepPurple,
                      size: isDesktop ? 20 : isTablet ? 18 : 16),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 0.5, color: Colors.grey[200],
            indent: isMobile ? 16 : isTablet ? 20 : 24,
            endIndent: isMobile ? 16 : isTablet ? 20 : 24),
      ],
    );
  }

  void _saveSettings() async {
    if (_sessionTimeout) {
      // Utiliser la valeur stockée (en anglais) pour le service
      final storedDuration = _mapLocalizedToStoredValue(_sessionTimeoutValue);
      _autoLogoutService.startAutoLogout(storedDuration);
      await _autoLogoutService.saveAutoLogoutSettings(
          enabled: true, duration: storedDuration);
    } else {
      _autoLogoutService.stopAutoLogout();
      // Utiliser la valeur stockée (en anglais) pour la sauvegarde
      final storedDuration = _mapLocalizedToStoredValue(_sessionTimeoutValue);
      await _autoLogoutService.saveAutoLogoutSettings(
          enabled: false, duration: storedDuration);
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppLocalizations.get('notif_saved_success')),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
    Navigator.of(context).pop();
  }

  void _showActiveSessions() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const ActiveSessionsDialog(),
    );
  }

  void _downloadData() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.get('error')),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.get('personal_info')),
        content: Text(
          '${AppLocalizations.get('confirm')} ?\n\n'
              '• ${AppLocalizations.get('profile')}\n'
              '• ${AppLocalizations.get('addresses')}\n'
              '• ${AppLocalizations.get('settings')}\n'
              '• ${AppLocalizations.get('history')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            child: Text(AppLocalizations.get('save')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppLocalizations.get('loading')),
      backgroundColor: Colors.blue,
      duration: const Duration(seconds: 2),
    ));

    try {
      final userData = await _getUserCompleteData(user.uid);

      final exportData = {
        'export_info': {
          'date': DateTime.now().toIso8601String(),
          'version': '1.0.0',
          'user_id': user.uid,
          'app_name': 'Winzy Marketplace',
        },
        'profile': {
          'email': user.email,
          'display_name': user.displayName,
          'photo_url': user.photoURL,
          'email_verified': user.emailVerified,
          'creation_time': user.metadata.creationTime?.toIso8601String(),
          'last_sign_in': user.metadata.lastSignInTime?.toIso8601String(),
        },
        'addresses': userData['addresses'] ?? [],
        'preferences': userData['preferences'] ?? {},
        'notifications_count': userData['notifications_count'] ?? 0,
      };

      final jsonString = jsonEncode(exportData);
      final readableContent = '========================================\n'
          '     MES DONNÉES PERSONNELLES - WINZY MARKETPLACE\n'
          '========================================\n\n'
          'Date d\'export: ${DateTime.now().toString().split('.')[0]}\n\n'
          '$jsonString\n';

      final bytes = utf8.encode(readableContent);
      Directory directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) await directory.create(recursive: true);
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final fileName = 'winzy_donnees_${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${AppLocalizations.get('success')} : ${file.path}'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: AppLocalizations.get('edit'),
            textColor: Colors.white,
            onPressed: () async {
              await Share.share(readableContent,
                  subject: AppLocalizations.get('personal_info'));
            },
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${AppLocalizations.get('error')}: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  Future<Map<String, dynamic>> _getUserCompleteData(String userId) async {
    try {
      final addresses = await _authService.getUserAddresses();
      final notifications = await _authService.getUserNotifications();
      return {
        'addresses': addresses.map((addr) => {
          'id': addr['id'],
          'street': addr['street'],
          'city': addr['city'],
          'postal_code': addr['postalCode'],
          'country': addr['country'],
          'is_default': addr['isDefault'],
        }).toList(),
        'preferences': {'theme': 'light', 'language': AppLocalizations.getLanguage()},
        'notifications_count': notifications.length,
      };
    } catch (e) {
      return {'addresses': <Map<String, dynamic>>[], 'preferences': {}, 'notifications_count': 0};
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => DeleteAccountDialog(
        onConfirmDelete: () {
          // Le DeleteAccountDialog gère maintenant toute la logique
          // Pas besoin de code supplémentaire ici
        },
        onDeactivated: () async {
          try {
            // Attendre un peu pour s'assurer que tout est bien déconnecté
            await Future.delayed(const Duration(milliseconds: 300));
            
            // Forcer la navigation vers login
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            }
          } catch (e) {
            print('❌ Erreur dans onDeactivated: $e');
            // Dernière tentative de redirection
            try {
              if (mounted) {
                Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              }
            } catch (e2) {
              print('❌ Erreur finale de redirection: $e2');
            }
          }
        },
      ),
    );
  }
}
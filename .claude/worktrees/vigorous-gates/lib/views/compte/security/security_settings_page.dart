import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../localization/app_localizations.dart';
import '../../../services/biometric_auth_service.dart';
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

  // ─────────────────────────────────────────────────────────────────────────────
  //  STATE
  // ─────────────────────────────────────────────────────────────────────────────
  bool   _twoFactorAuth        = false;
  bool   _biometricAuth        = false;
  bool   _sessionTimeout       = true;
  String _sessionTimeoutValue  = '30 minutes';

  bool   _isServiceReady       = false;
  bool   _dialogShown          = false;
  bool   _biometricAvailable   = false;
  bool   _biometricLoading     = false;
  String _biometricType        = '';

  // ─────────────────────────────────────────────────────────────────────────────
  //  SERVICES
  // ─────────────────────────────────────────────────────────────────────────────
  final FirebaseAuth             _auth             = FirebaseAuth.instance;
  final FirebaseAuthService      _authService      = FirebaseAuthService();
  final AutoLogoutService        _autoLogoutService = AutoLogoutService();
  final SessionManagementService _sessionService   = SessionManagementService();
  final BiometricAuthService     _biometricService = BiometricAuthService();

  // ─────────────────────────────────────────────────────────────────────────────
  //  MAPPING DURÉE SESSION
  // ─────────────────────────────────────────────────────────────────────────────
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

  String _mapLocalizedToStoredValue(String localizedValue) {
    final map = {
      AppLocalizations.get('session_timeout_5_seconds'):  '5 seconds',
      AppLocalizations.get('session_timeout_15_minutes'): '15 minutes',
      AppLocalizations.get('session_timeout_30_minutes'): '30 minutes',
      AppLocalizations.get('session_timeout_1_hour'):     '1 hour',
      AppLocalizations.get('session_timeout_2_hours'):    '2 hours',
    };
    return map[localizedValue] ?? '30 minutes';
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initializeService();
    _setupAutoLogout();
    _checkBiometric();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  INITIALISATION
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _initializeService() async {
    try {
      await _autoLogoutService.init();
      await _sessionService.init();
      await _sessionService.createSession();

      final settings = await _autoLogoutService.loadAutoLogoutSettings();
      if (mounted) {
        setState(() {
          _sessionTimeout      = settings['enabled'] ?? false;
          final storedDuration = settings['duration'] ?? '30 minutes';
          _sessionTimeoutValue = _mapStoredValueToLocalized(storedDuration);
          _isServiceReady      = true;
        });
      }
      if (_sessionTimeout) {
        _autoLogoutService.startAutoLogout(
            _mapLocalizedToStoredValue(_sessionTimeoutValue));
      }
    } catch (e) {
      debugPrint('❌ Erreur initialisation service: $e');
    }
  }

  Future<void> _checkBiometric() async {
    try {
      final available = await _biometricService.isAvailable();

      if (!available) {
        // L'appareil ne supporte pas la biométrie
        if (mounted) {
          setState(() {
            _biometricAvailable = false;
            _biometricAuth      = false; // forcer à false
            _biometricType      = '';
          });
        }
        return; // ← AJOUTER ce return pour sortir proprement
      }

      final enabled = await _biometricService.isBiometricEnabled();
      final label   = await _biometricService.getBiometricLabel();

      if (mounted) {
        setState(() {
          _biometricAvailable = true;
          _biometricAuth      = enabled;
          _biometricType      = label;
        });
      }
    } catch (e) {
      // En cas d'erreur → désactiver proprement
      debugPrint('⚠️ Biométrie non disponible: $e');
      if (mounted) {
        setState(() {
          _biometricAvailable = false;
          _biometricAuth      = false;
        });
      }
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
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
      }
    });
    _autoLogoutService.setOnWarningCallback((s) {
      if (mounted) _showAutoLogoutWarning(s);
    });
  }

  void _showAutoLogoutWarning(int remainingSeconds) {
    if (_dialogShown) return;
    _dialogShown = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AutoLogoutWarningDialog(
        remainingSeconds: remainingSeconds,
        onStayLoggedIn: () {
          _dialogShown = false;
          if (mounted && Navigator.of(dialogContext).canPop())
            Navigator.of(dialogContext).pop();
          _autoLogoutService.recordActivity();
        },
        onLogout: () {
          _dialogShown = false;
          if (mounted && Navigator.of(dialogContext).canPop())
            Navigator.of(dialogContext).pop();
          _autoLogoutService.stopAutoLogout();
          _auth.signOut();
          if (mounted)
            Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
        },
      ),
    ).then((_) => _dialogShown = false);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  BIOMÉTRIE — TOGGLE PRINCIPAL
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _handleBiometricToggle(bool value) async {

    // ── DÉSACTIVER ────────────────────────────────────────────────
    if (!value) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.fingerprint, color: Colors.deepPurple, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(
              AppLocalizations.get('biometric_disable_title'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            )),
          ]),
          content: Text(
            '${AppLocalizations.get('biometric_disable_confirm')} $_biometricType ?',
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.get('cancel'),
                  style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(AppLocalizations.get('biometric_disable_btn'),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _biometricService.disableBiometric();
        setState(() => _biometricAuth = false);
        _showSnack(AppLocalizations.get('biometric_disabled_success'), Colors.orange);
      }
      return;
    }

    // ── ACTIVER ───────────────────────────────────────────────────
    // ── ACTIVER ───────────────────────────────────────────────────
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack(AppLocalizations.get('biometric_no_user'), Colors.red);
      return;
    }

// Détecter automatiquement la méthode disponible
    final types = await _biometricService.getAvailableBiometrics();
    String detectedMethod = 'fingerprint'; // défaut
    if (types.contains(BiometricType.face)) {
      detectedMethod = 'face';
    }

// Si email/password → demander le mot de passe
    final provider = user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : 'password';

    String? password;
    if (provider == 'password') {
      password = await _showPasswordDialog();
      if (password == null) return;
    }

    setState(() => _biometricLoading = true);
    final result = await _biometricService.enableBiometric(
      password:        password,
      preferredMethod: detectedMethod,
    );
    setState(() {
      _biometricLoading = false;
      if (result == BiometricSetupResult.success) {
        _biometricType = detectedMethod == 'face'
            ? AppLocalizations.get('biometric_face_id')
            : AppLocalizations.get('biometric_fingerprint');
      }
    });

    switch (result) {
      case BiometricSetupResult.success:
        setState(() => _biometricAuth = true);
        _showSnack(
          '$_biometricType ${AppLocalizations.get('biometric_activated_success')}',
          Colors.green,
        );
        break;
      case BiometricSetupResult.cancelled:
        _showSnack(AppLocalizations.get('biometric_activation_cancelled'), Colors.orange);
        break;
      case BiometricSetupResult.passwordRequired:
        _showSnack(AppLocalizations.get('password_required'), Colors.red);
        break;
      case BiometricSetupResult.notAvailable:
        _showSnack(AppLocalizations.get('biometric_not_available'), Colors.red);
        break;
      case BiometricSetupResult.noUser:
        _showSnack(AppLocalizations.get('biometric_no_user'), Colors.red);
        break;
      case BiometricSetupResult.error:
        _showSnack(AppLocalizations.get('error'), Colors.red);
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  DIALOG — MOT DE PASSE
  // ─────────────────────────────────────────────────────────────────────────────
  Future<String?> _showPasswordDialog() async {
    final controller = TextEditingController();
    bool isVisible   = false;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.lock, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text(AppLocalizations.get('biometric_auth'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.get('biometric_password_needed'),
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller:  controller,
                obscureText: !isVisible,
                decoration: InputDecoration(
                  hintText:   AppLocalizations.get('password'),
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.deepPurple),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isVisible ? Icons.visibility : Icons.visibility_off,
                      color: Colors.deepPurple,
                    ),
                    onPressed: () => setDialogState(() => isVisible = !isVisible),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(AppLocalizations.get('cancel'),
                  style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) Navigator.pop(ctx, controller.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(AppLocalizations.get('confirm'),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  SNACKBAR HELPER
  // ─────────────────────────────────────────────────────────────────────────────
  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior:        SnackBarBehavior.floating,
      shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration:        const Duration(seconds: 3),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile    = screenWidth < 600;
    final isTablet    = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop   = screenWidth >= 1200;
    final isArabic    = AppLocalizations.getLanguage() == 'ar';

    if (!_isServiceReady) {
      return Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: Text(AppLocalizations.get('security')),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _buildAppBar(context, isDesktop, isTablet, isMobile),
        body:   _buildBody(context, isDesktop, isTablet, isMobile),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  APP BAR
  // ─────────────────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(
      BuildContext context, bool isDesktop, bool isTablet, bool isMobile) {
    final isRtl = AppLocalizations.isRtl;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(
          isRtl ? Icons.arrow_forward : Icons.arrow_back,
          color: Colors.black87,
          size: isDesktop ? 28 : isTablet ? 24 : 20,
        ),
      ),
      title: Text(
        AppLocalizations.get('security'),
        style: TextStyle(
          color:      Colors.black87,
          fontSize:   isDesktop ? 24 : isTablet ? 22 : 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: IconButton(
            onPressed: _saveSettings,
            icon: Icon(Icons.save,
                color: Colors.deepPurple,
                size: isDesktop ? 24 : isTablet ? 22 : 20),
            tooltip: AppLocalizations.get('save'),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  BODY
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildBody(
      BuildContext context, bool isDesktop, bool isTablet, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 24 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Section Authentification ──────────────────────────
          _buildSectionCard(
            title: AppLocalizations.get('security'),
            icon:  Icons.lock,
            children: [
              _buildSwitchTile(
                title:    AppLocalizations.get('two_factor_auth'),
                subtitle: 'Ajoute une couche de sécurité supplémentaire',
                value:    _twoFactorAuth,
                onChanged: (v) => setState(() => _twoFactorAuth = v),
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
              _buildBiometricSwitchTile(isDesktop, isTablet, isMobile),
              _buildActionTile(
                title:    AppLocalizations.get('change_password'),
                subtitle: AppLocalizations.get('new_password'),
                icon:     Icons.password,
                onTap:    () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ChangePasswordPage())),
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
            ],
            isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
          ),

          SizedBox(height: isMobile ? 20 : isTablet ? 24 : 28),

          // ── Section Session ───────────────────────────────────
          _buildSectionCard(
            title: AppLocalizations.get('section_session'),
            icon:  Icons.timer,
            children: [
              _buildSwitchTile(
                title:    AppLocalizations.get('session_expired'),
                subtitle: AppLocalizations.get('inactivity_detected'),
                value:    _sessionTimeout,
                onChanged: (value) async {
                  setState(() => _sessionTimeout = value);
                  final stored = _mapLocalizedToStoredValue(_sessionTimeoutValue);
                  if (value) {
                    _autoLogoutService.startAutoLogout(stored);
                    await _autoLogoutService.saveAutoLogoutSettings(
                        enabled: true, duration: stored);
                    _showSnack(
                        '${AppLocalizations.get('success')} $_sessionTimeoutValue',
                        Colors.green);
                  } else {
                    _autoLogoutService.stopAutoLogout();
                    await _autoLogoutService.saveAutoLogoutSettings(
                        enabled: false, duration: stored);
                    _showSnack(AppLocalizations.get('session_expired'), Colors.orange);
                  }
                },
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
              if (_sessionTimeout)
                _buildDropdownTile(
                  title:    AppLocalizations.get('remaining_time'),
                  subtitle: AppLocalizations.get('inactivity_warning'),
                  value:    _sessionTimeoutValue,
                  items: [
                    AppLocalizations.get('session_timeout_5_seconds'),
                    AppLocalizations.get('session_timeout_15_minutes'),
                    AppLocalizations.get('session_timeout_30_minutes'),
                    AppLocalizations.get('session_timeout_1_hour'),
                    AppLocalizations.get('session_timeout_2_hours'),
                  ],
                  onChanged: (value) async {
                    setState(() => _sessionTimeoutValue = value);
                    final stored = _mapLocalizedToStoredValue(value);
                    _autoLogoutService.startAutoLogout(stored);
                    await _autoLogoutService.saveAutoLogoutSettings(
                        enabled: true, duration: stored);
                    _showSnack(
                        '${AppLocalizations.get('success')} $value', Colors.green);
                  },
                  isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
                ),
              _buildActionTile(
                title:    AppLocalizations.get('active_sessions'),
                subtitle: AppLocalizations.get('active_sessions'),
                icon:     Icons.devices,
                onTap:    _showActiveSessions,
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
            ],
            isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
          ),

          SizedBox(height: isMobile ? 20 : isTablet ? 24 : 28),

          // ── Section Confidentialité ───────────────────────────
          _buildSectionCard(
            title: AppLocalizations.get('section_confidentiality'),
            icon:  Icons.privacy_tip,
            children: [
              _buildActionTile(
                title:    AppLocalizations.get('save'),
                subtitle: AppLocalizations.get('personal_info'),
                icon:     Icons.download,
                onTap:    _downloadData,
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
              _buildActionTile(
                title:    AppLocalizations.get('security_delete_account'),
                subtitle: AppLocalizations.get('confirm'),
                icon:     Icons.delete_forever,
                isDanger: true,
                onTap:    _showDeleteAccountDialog,
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

  // ─────────────────────────────────────────────────────────────────────────────
  //  WIDGET — SWITCH BIOMÉTRIQUE ENRICHI
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildBiometricSwitchTile(bool isDesktop, bool isTablet, bool isMobile) {
    final Color    statusColor = !_biometricAvailable
        ? Colors.grey
        : _biometricAuth ? Colors.green : Colors.orange;

    final IconData statusIcon = !_biometricAvailable
        ? Icons.block
        : _biometricAuth ? Icons.check_circle : Icons.fingerprint;

    final String subtitle = !_biometricAvailable
        ? AppLocalizations.get('biometric_not_available')
        : _biometricAuth
        ? '$_biometricType — ${AppLocalizations.get('biometric_enabled_suffix')}'
        : '${AppLocalizations.get('biometric_activate_desc')} $_biometricType';

    return Column(children: [
      Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : isTablet ? 20 : 24,
          vertical:   isMobile ? 12 : isTablet ? 14 : 16,
        ),
        child: Row(children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color:        statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon,
                color: statusColor,
                size: isDesktop ? 22 : isTablet ? 20 : 18),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.get('biometric_auth'),
                  style: TextStyle(
                    fontSize:   isDesktop ? 16 : isTablet ? 15 : 14,
                    fontWeight: FontWeight.w600,
                    color:      _biometricAvailable ? Colors.black87 : Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize:   isDesktop ? 13 : isTablet ? 12 : 11,
                    color:      statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Loader pendant l'activation ou Switch
          if (_biometricLoading)
            const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor:  AlwaysStoppedAnimation<Color>(Colors.deepPurple),
              ),
            )
          else
            Switch(
              value:              _biometricAuth,
              onChanged:          _biometricAvailable ? _handleBiometricToggle : null,
              activeColor:        Colors.deepPurple,
              inactiveThumbColor: Colors.grey[400],
              inactiveTrackColor: Colors.grey[300],
            ),
        ]),
      ),
      Divider(
        height: 1, thickness: 0.5, color: Colors.grey[200],
        indent:    isMobile ? 16 : isTablet ? 20 : 24,
        endIndent: isMobile ? 16 : isTablet ? 20 : 24,
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  WIDGETS GÉNÉRIQUES
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildSectionCard({
    required String       title,
    required IconData     icon,
    required List<Widget> children,
    required bool isDesktop, required bool isTablet, required bool isMobile,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset:     const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
            child: Row(children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 8 : isTablet ? 10 : 12),
                decoration: BoxDecoration(
                  color:        Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    color: Colors.deepPurple,
                    size: isDesktop ? 24 : isTablet ? 22 : 20),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              Text(title,
                  style: TextStyle(
                      fontSize:   isDesktop ? 18 : isTablet ? 17 : 16,
                      fontWeight: FontWeight.bold,
                      color:      Colors.black87)),
            ]),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String       title,
    required String       subtitle,
    required bool         value,
    required Function(bool) onChanged,
    required bool isDesktop, required bool isTablet, required bool isMobile,
  }) {
    return Column(children: [
      Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : isTablet ? 20 : 24,
          vertical:   isMobile ? 12 : isTablet ? 14 : 16,
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize:   isDesktop ? 16 : isTablet ? 15 : 14,
                        fontWeight: FontWeight.w600,
                        color:      Colors.black87)),
                SizedBox(height: isMobile ? 2 : 4),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                        color:    Colors.grey[600])),
              ],
            ),
          ),
          Switch(
            value:              value,
            onChanged:          onChanged,
            activeColor:        Colors.deepPurple,
            inactiveThumbColor: Colors.grey[400],
            inactiveTrackColor: Colors.grey[300],
          ),
        ]),
      ),
      Divider(
        height: 1, thickness: 0.5, color: Colors.grey[200],
        indent:    isMobile ? 16 : isTablet ? 20 : 24,
        endIndent: isMobile ? 16 : isTablet ? 20 : 24,
      ),
    ]);
  }

  Widget _buildActionTile({
    required String    title,
    required String    subtitle,
    required IconData  icon,
    required VoidCallback onTap,
    bool isDanger = false,
    required bool isDesktop, required bool isTablet, required bool isMobile,
  }) {
    return Column(children: [
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : isTablet ? 20 : 24,
            vertical:   isMobile ? 12 : isTablet ? 14 : 16,
          ),
          child: Row(children: [
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
                          fontSize:   isDesktop ? 16 : isTablet ? 15 : 14,
                          fontWeight: FontWeight.w600,
                          color:      isDanger ? Colors.red : Colors.black87)),
                  SizedBox(height: isMobile ? 2 : 4),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                          color:    Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: isDesktop ? 20 : isTablet ? 18 : 16),
          ]),
        ),
      ),
      Divider(
        height: 1, thickness: 0.5, color: Colors.grey[200],
        indent:    isMobile ? 16 : isTablet ? 20 : 24,
        endIndent: isMobile ? 16 : isTablet ? 20 : 24,
      ),
    ]);
  }

  Widget _buildDropdownTile({
    required String         title,
    required String         subtitle,
    required String         value,
    required List<String>   items,
    required Function(String) onChanged,
    required bool isDesktop, required bool isTablet, required bool isMobile,
  }) {
    return Column(children: [
      Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : isTablet ? 20 : 24,
          vertical:   isMobile ? 12 : isTablet ? 14 : 16,
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize:   isDesktop ? 16 : isTablet ? 15 : 14,
                        fontWeight: FontWeight.w600,
                        color:      Colors.black87)),
                SizedBox(height: isMobile ? 2 : 4),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                        color:    Colors.grey[600])),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : isTablet ? 16 : 20,
              vertical:   isMobile ? 8  : isTablet ? 10 : 12,
            ),
            decoration: BoxDecoration(
              border:       Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value:    value,
              onChanged: (v) { if (v != null) onChanged(v); },
              items: items.map((item) => DropdownMenuItem(
                value: item,
                child: Text(item,
                    style: TextStyle(
                        fontSize: isDesktop ? 14 : isTablet ? 13 : 12)),
              )).toList(),
              underline: const SizedBox(),
              icon: Icon(Icons.keyboard_arrow_down,
                  color: Colors.deepPurple,
                  size: isDesktop ? 20 : isTablet ? 18 : 16),
            ),
          ),
        ]),
      ),
      Divider(
        height: 1, thickness: 0.5, color: Colors.grey[200],
        indent:    isMobile ? 16 : isTablet ? 20 : 24,
        endIndent: isMobile ? 16 : isTablet ? 20 : 24,
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  ACTIONS
  // ─────────────────────────────────────────────────────────────────────────────
  void _saveSettings() async {
    final stored = _mapLocalizedToStoredValue(_sessionTimeoutValue);
    if (_sessionTimeout) {
      _autoLogoutService.startAutoLogout(stored);
      await _autoLogoutService.saveAutoLogoutSettings(
          enabled: true, duration: stored);
    } else {
      _autoLogoutService.stopAutoLogout();
      await _autoLogoutService.saveAutoLogoutSettings(
          enabled: false, duration: stored);
    }
    _showSnack(AppLocalizations.get('notif_saved_success'), Colors.green);
    Navigator.of(context).pop();
  }

  void _showActiveSessions() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ActiveSessionsDialog(),
    );
  }

  void _downloadData() async {
    final user = _auth.currentUser;
    if (user == null) {
      _showSnack(AppLocalizations.get('error'), Colors.red);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:   Text(AppLocalizations.get('personal_info')),
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
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white),
            child: Text(AppLocalizations.get('save')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    _showSnack(AppLocalizations.get('loading'), Colors.blue);

    try {
      final userData   = await _getUserCompleteData(user.uid);
      final exportData = {
        'export_info': {
          'date':     DateTime.now().toIso8601String(),
          'version':  '1.0.0',
          'user_id':  user.uid,
          'app_name': 'Winzy Marketplace',
        },
        'profile': {
          'email':          user.email,
          'display_name':   user.displayName,
          'photo_url':      user.photoURL,
          'email_verified': user.emailVerified,
          'creation_time':  user.metadata.creationTime?.toIso8601String(),
          'last_sign_in':   user.metadata.lastSignInTime?.toIso8601String(),
        },
        'addresses':           userData['addresses'] ?? [],
        'preferences':         userData['preferences'] ?? {},
        'notifications_count': userData['notifications_count'] ?? 0,
      };

      final jsonString      = jsonEncode(exportData);
      final readableContent =
          '========================================\n'
          '     MES DONNÉES PERSONNELLES - WINZY\n'
          '========================================\n\n'
          'Date: ${DateTime.now().toString().split('.')[0]}\n\n'
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
      final file     = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('${AppLocalizations.get('success')} : ${file.path}'),
          backgroundColor: Colors.green,
          behavior:        SnackBarBehavior.floating,
          duration:        const Duration(seconds: 10),
          action: SnackBarAction(
            label:     AppLocalizations.get('edit'),
            textColor: Colors.white,
            onPressed: () async => await Share.share(readableContent,
                subject: AppLocalizations.get('personal_info')),
          ),
        ));
      }
    } catch (e) {
      _showSnack('${AppLocalizations.get('error')}: $e', Colors.red);
    }
  }

  Future<Map<String, dynamic>> _getUserCompleteData(String userId) async {
    try {
      final addresses     = await _authService.getUserAddresses();
      final notifications = await _authService.getUserNotifications();
      return {
        'addresses': addresses.map((addr) => {
          'id':          addr['id'],
          'street':      addr['street'],
          'city':        addr['city'],
          'postal_code': addr['postalCode'],
          'country':     addr['country'],
          'is_default':  addr['isDefault'],
        }).toList(),
        'preferences': {
          'theme':    'light',
          'language': AppLocalizations.getLanguage(),
        },
        'notifications_count': notifications.length,
      };
    } catch (_) {
      return {
        'addresses':           <Map<String, dynamic>>[],
        'preferences':         {},
        'notifications_count': 0,
      };
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (_) => DeleteAccountDialog(
        onConfirmDelete: () {},
        onDeactivated: () async {
          try {
            await Future.delayed(const Duration(milliseconds: 300));
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
            }
          } catch (e) {
            if (mounted) {
              Navigator.of(context, rootNavigator: true)
                  .pushNamedAndRemoveUntil('/login', (_) => false);
            }
          }
        },
      ),
    );
  }
}
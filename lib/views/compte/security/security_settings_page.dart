import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_filex/open_filex.dart';
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
        if (mounted) {
          setState(() {
            _biometricAvailable = false;
            _biometricAuth      = false;
            _biometricType      = '';
          });
        }
        return;
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
      builder: (dialogContext) => Directionality(
        textDirection: AppLocalizations.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: AutoLogoutWarningDialog(
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
      ),
    ).then((_) => _dialogShown = false);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  BIOMÉTRIE — TOGGLE PRINCIPAL
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _handleBiometricToggle(bool value) async {
    final isRtl = AppLocalizations.isRtl;

    if (!value) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
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
        ),
      );

      if (confirm == true) {
        await _biometricService.disableBiometric();
        setState(() => _biometricAuth = false);
        _showSnack(AppLocalizations.get('biometric_disabled_success'), Colors.orange);
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack(AppLocalizations.get('biometric_no_user'), Colors.red);
      return;
    }

    final types = await _biometricService.getAvailableBiometrics();
    String detectedMethod = 'fingerprint';
    if (types.contains(BiometricType.face)) {
      detectedMethod = 'face';
    }

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
  //  DIALOG — MOT DE PASSE (RTL)
  // ─────────────────────────────────────────────────────────────────────────────
  Future<String?> _showPasswordDialog() async {
    final controller = TextEditingController();
    bool isVisible   = false;
    final isRtl = AppLocalizations.isRtl;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: StatefulBuilder(
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
    final isRtl       = AppLocalizations.isRtl;

    if (!_isServiceReady) {
      return Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
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
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _buildAppBar(context, isDesktop, isTablet, isMobile, isRtl),
        body:   _buildBody(context, isDesktop, isTablet, isMobile),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  APP BAR (flèche inversée si RTL)
  // ─────────────────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(
      BuildContext context, bool isDesktop, bool isTablet, bool isMobile, bool isRtl) {
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
    final isRtl = AppLocalizations.isRtl;
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
            Icon(
              isRtl ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: isDesktop ? 20 : isTablet ? 18 : 16,
            ),
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
      builder: (_) => Directionality(
        textDirection: AppLocalizations.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: const ActiveSessionsDialog(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  DOWNLOAD DATA — ENTRY POINT
  // ─────────────────────────────────────────────────────────────────────────────
  void _downloadData() {
    final user = _auth.currentUser;
    if (user == null) {
      _showSnack(AppLocalizations.get('error'), Colors.red);
      return;
    }
    _showFormatPickerSheet(user);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  FORMAT PICKER BOTTOM SHEET (RTL)
  // ─────────────────────────────────────────────────────────────────────────────
  void _showFormatPickerSheet(User user) {
    final isRtl = AppLocalizations.isRtl;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.download_rounded,
                          color: Colors.deepPurple, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.get('personal_info'),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold,
                                  color: Colors.black87)),
                          const SizedBox(height: 2),
                          Text(AppLocalizations.get('confirm'),
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Data preview
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      _exportInfoRow(Icons.person_outline,
                          AppLocalizations.get('profile')),
                      _exportInfoRow(Icons.location_on_outlined,
                          AppLocalizations.get('addresses')),
                      _exportInfoRow(Icons.settings_outlined,
                          AppLocalizations.get('settings')),
                      _exportInfoRow(Icons.history,
                          AppLocalizations.get('history')),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // PDF card
                _buildFormatCard(
                  icon: Icons.picture_as_pdf_rounded,
                  iconColor: const Color(0xFFE53935),
                  bgColor: const Color(0xFFFBE9E7),
                  title: AppLocalizations.get('export_format_pdf_title'),
                  description: AppLocalizations.get('export_format_pdf_desc'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportAs('pdf', user);
                  },
                ),
                const SizedBox(height: 12),
                _buildFormatCard(
                  icon: Icons.data_object_rounded,
                  iconColor: const Color(0xFF1565C0),
                  bgColor: const Color(0xFFE3F2FD),
                  title: AppLocalizations.get('export_format_txt_title'),
                  description: AppLocalizations.get('export_format_txt_desc'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportAs('txt', user);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _exportInfoRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.deepPurple),
          const SizedBox(width: 10),
          Flexible(
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey[700],
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatCard({
    required IconData    icon,
    required Color       iconColor,
    required Color       bgColor,
    required String      title,
    required String      description,
    required VoidCallback onTap,
  }) {
    final isRtl = AppLocalizations.isRtl;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: Colors.black87)),
                    const SizedBox(height: 3),
                    Text(description,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500],
                            height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isRtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                  color: Colors.grey[600], size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  EXPORT — ORCHESTRATION
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _exportAs(String format, User user) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 44, height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
              ),
              const SizedBox(height: 16),
              Text(AppLocalizations.get('loading'),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: Colors.black87, decoration: TextDecoration.none)),
            ],
          ),
        ),
      ),
    );

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

      String filePath;
      if (format == 'pdf') {
        filePath = await _generatePdf(exportData, user);
      } else {
        filePath = await _exportAsTxt(exportData);
      }

      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading
        _showExportSuccessSheet(filePath, format);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading
        _showSnack('${AppLocalizations.get('error')}: $e', Colors.red);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  EXPORT — TXT
  // ─────────────────────────────────────────────────────────────────────────────
  Future<String> _exportAsTxt(Map<String, dynamic> exportData) async {
    final jsonString      = jsonEncode(exportData);
    final readableContent =
        '========================================\n'
        '     MES DONNÉES PERSONNELLES - WINZY\n'
        '========================================\n\n'
        'Date: ${DateTime.now().toString().split('.')[0]}\n\n'
        '$jsonString\n';

    final bytes     = utf8.encode(readableContent);
    final directory = await _getExportDirectory();
    final fileName  = 'winzy_donnees_${DateTime.now().millisecondsSinceEpoch}.txt';
    final file      = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  EXPORT — PDF
  // ─────────────────────────────────────────────────────────────────────────────
  Future<String> _generatePdf(Map<String, dynamic> exportData, User user) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base:       pw.Font.helvetica(),
        bold:       pw.Font.helveticaBold(),
        italic:     pw.Font.helveticaOblique(),
        boldItalic: pw.Font.helveticaBoldOblique(),
      ),
    );

    final purple  = PdfColor.fromHex('#673AB7');
    final now     = DateTime.now();
    final dateStr = _fmtDate(now);

    final addresses = exportData['addresses'] as List? ?? [];
    final prefs     = exportData['preferences'] as Map<String, dynamic>? ?? {};

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),

        header: (pw.Context ctx) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('WINZY MARKETPLACE',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: purple,
                    )),
                pw.Text(dateStr,
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(color: purple, thickness: 1.5),
            pw.SizedBox(height: 6),
            pw.Text('Export des données personnelles',
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey700,
                  fontStyle: pw.FontStyle.italic,
                )),
            pw.SizedBox(height: 16),
          ],
        ),

        footer: (pw.Context ctx) => pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
          ),
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Winzy Marketplace — Confidentiel',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey500,
                    fontStyle: pw.FontStyle.italic,
                  )),
              pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey500)),
            ],
          ),
        ),

        build: (pw.Context ctx) => [
          // Profile
          _pdfSection('Profil', purple, [
            _pdfRow('Email',               user.email ?? '—'),
            _pdfRow('Nom',                 user.displayName ?? '—'),
            _pdfRow('Email vérifié',       user.emailVerified ? 'Oui' : 'Non'),
            _pdfRow('Compte créé',         _fmtDate(user.metadata.creationTime)),
            _pdfRow('Dernière connexion',  _fmtDate(user.metadata.lastSignInTime)),
          ]),
          pw.SizedBox(height: 20),

          // Addresses
          _pdfSection('Adresses', purple, addresses.isEmpty
              ? [_pdfRow('', 'Aucune adresse enregistrée')]
              : addresses.asMap().entries.map((e) {
            final a   = e.value as Map<String, dynamic>;
            final idx = e.key + 1;
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Adresse $idx${a['is_default'] == true ? '  (par défaut)' : ''}',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  if (a['street'] != null)
                    pw.Text('${a['street']}',
                        style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(
                    [a['city'], a['postal_code']]
                        .where((v) => v != null && v.toString().isNotEmpty)
                        .join(', '),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  if (a['country'] != null)
                    pw.Text('${a['country']}',
                        style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            );
          }).toList(),
          ),
          pw.SizedBox(height: 20),

          // Preferences
          _pdfSection('Préférences', purple, [
            _pdfRow('Thème',          prefs['theme']    ?? '—'),
            _pdfRow('Langue',         prefs['language']  ?? '—'),
            _pdfRow('Notifications',  '${exportData['notifications_count'] ?? 0}'),
          ]),
        ],
      ),
    );

    final bytes     = await pdf.save();
    final directory = await _getExportDirectory();
    final fileName  = 'winzy_donnees_${now.millisecondsSinceEpoch}.pdf';
    final file      = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  // PDF helpers
  pw.Widget _pdfSection(String title, PdfColor accent, List<pw.Widget> children) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: accent, width: 3)),
      ),
      padding: const pw.EdgeInsets.only(left: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: accent,
                letterSpacing: 1.5,
              )),
          pw.SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _pdfRow(String label, String value) {
    if (label.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Text(value,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic)),
      );
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<Directory> _getExportDirectory() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    return await getApplicationDocumentsDirectory();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  SUCCESS BOTTOM SHEET (RTL)
  // ─────────────────────────────────────────────────────────────────────────────
  void _showExportSuccessSheet(String filePath, String format) {
    final fileName = filePath.split(Platform.pathSeparator).last;
    final isRtl = AppLocalizations.isRtl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Success icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: Colors.green, size: 48),
                ),
                const SizedBox(height: 16),
                Text(AppLocalizations.get('success'),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 8),
                // File info chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        format == 'pdf'
                            ? Icons.picture_as_pdf_rounded
                            : Icons.description_rounded,
                        size: 16,
                        color: format == 'pdf' ? Colors.red : Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(fileName,
                            style: TextStyle(fontSize: 12, color: Colors.grey[700],
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Action buttons
                Row(
                  children: [
                    // Open
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            await OpenFilex.open(filePath);
                          } catch (e) {
                            _showSnack(
                                '${AppLocalizations.get('error')}: $e', Colors.red);
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: Text(AppLocalizations.get('open_file')),  // ✅ modifié
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepPurple,
                          side: const BorderSide(color: Colors.deepPurple),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Share
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await Share.shareXFiles(
                            [XFile(filePath)],
                            subject: 'Winzy — ${AppLocalizations.get('personal_info')}',
                          );
                        },
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: Text(AppLocalizations.get('share')),  // ✅ modifié
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Close
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalizations.get('cancel'),
                      style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  USER DATA
  // ─────────────────────────────────────────────────────────────────────────────
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
    final isRtl = AppLocalizations.isRtl;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (_) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: DeleteAccountDialog(
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
      ),
    );
  }
}
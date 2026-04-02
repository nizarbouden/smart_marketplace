import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../localization/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/biometric_auth_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../models/user_model.dart';
import 'role_selection_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Enum
// ─────────────────────────────────────────────────────────────────────────────
enum _ErrorType { none, emailNotVerified }

// ─────────────────────────────────────────────────────────────────────────────
//  LoginScreen
// ─────────────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ── Constants ───────────────────────────────────────────────────────────────
  static const _purple       = Color(0xFF8700FF);
  static const _purpleLight  = Color(0xFF6366F1);
  static const _purpleMid    = Color(0xFF8B5CF6);
  static const _purpleDeep   = Color(0xFFA855F7);

  // ── State ────────────────────────────────────────────────────────────────────
  final _formKey               = GlobalKey<FormState>();
  final _biometricService      = BiometricAuthService();

  bool   _rememberMe           = false;
  bool   _isPasswordVisible    = false;
  bool   _isLoading            = false;
  bool   _isResending          = false;
  bool   _showBiometricButton  = false;
  String _email                = '';
  String _password             = '';
  String _biometricLabel       = '';
  _ErrorType _errorType        = _ErrorType.none;

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkBiometricAvailability();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  INITIALISATION HELPERS
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _checkBiometricAvailability() async {
    final enabled = await _biometricService.isBiometricEnabled();
    final label   = await _biometricService.getBiometricLabel();
    if (mounted) {
      setState(() {
        _showBiometricButton = enabled;
        _biometricLabel      = label;
      });
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs    = await SharedPreferences.getInstance();
      final remember = prefs.getBool('rememberMe') ?? false;
      final email    = prefs.getString('lastEmail');
      if (remember && email != null) {
        setState(() { _rememberMe = true; _email = email; });
      }
    } catch (e) {
      debugPrint('❌ Erreur préférences: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  FIREBASE HELPERS
  // ─────────────────────────────────────────────────────────────────────────────
  Future<String?> _getUserRole(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      if (doc.exists) {
        final role = (doc.data() as Map<String, dynamic>)['role'] as String?;
        if (role != null && role.isNotEmpty && role != 'null') return role;
      }
    } catch (e) { debugPrint('❌ Erreur rôle: $e'); }
    return null;
  }

  Future<void> _checkAndReactivateIfNeeded(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      if (!doc.exists) return;

      final status = (doc.data() as Map<String, dynamic>)['status'] as String? ?? 'active';
      if (status != 'deactivated') return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'status':              'active',
        'reactivatedAt':       Timestamp.now(),
        'deletionRequestedAt': FieldValue.delete(),
        'scheduledDeletionAt': FieldValue.delete(),
      });
      debugPrint('✅ Compte réactivé: ${user.email}');

      if (mounted) _showSnackBar('🎉 Votre compte a été réactivé avec succès !', Colors.green.shade600);
    } catch (e) { debugPrint('❌ Erreur réactivation: $e'); }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  NAVIGATION
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _navigateByRole(User user) async {
    final role = await _getUserRole(user);
    if (!mounted) return;
    if (role == null) {
      await _navigateToRoleSelection(user);
    } else if (role == 'seller') {
      Navigator.pushReplacementNamed(context, '/seller-home');
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _navigateToRoleSelection(User user) async {
    try {
      final parts     = (user.displayName ?? '').split(' ');
      final firstName = parts.isNotEmpty ? parts.first : '';
      final lastName  = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      final userModel = await Navigator.of(context).push<UserModel>(
        MaterialPageRoute(
          builder: (_) => RoleSelectionPage(
            firstName:       firstName,
            lastName:        lastName,
            email:           user.email ?? '',
            phoneNumber:     user.phoneNumber ?? '',
            countryCode:     null,
            genre:           null,
            photoUrl:        user.photoURL,
            isGoogleUser:    user.providerData.any((p) => p.providerId == 'google.com'),
            isEmailVerified: user.emailVerified,
          ),
        ),
      );

      if (!mounted || userModel == null) return;
      await _saveUserRole(userModel);
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        userModel.role == UserRole.seller ? '/seller-home' : '/home',
      );
    } catch (e) {
      debugPrint('❌ Erreur sélection rôle: $e');
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _saveUserRole(UserModel userModel) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users').doc(user.uid)
            .set(userModel.toMap(), SetOptions(merge: true));
      }
    } catch (e) { debugPrint('❌ Erreur sauvegarde rôle: $e'); }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  AUTH ACTIONS
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() { _isLoading = true; _errorType = _ErrorType.none; });

    try {
      final success = await authProvider.signIn(
        email:      _email.trim(),
        password:   _password,
        rememberMe: _rememberMe,
      );

      setState(() => _isLoading = false);

      if (success) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _checkAndReactivateIfNeeded(user);
          if (mounted) await _navigateByRole(user);
        }
        return;
      }

      final errMsg = authProvider.errorMessage ?? '';
      if (_isEmailNotVerifiedError(errMsg)) {
        authProvider.clearError();
        setState(() => _errorType = _ErrorType.emailNotVerified);
      }
    } on EmailNotVerifiedException {
      setState(() { _isLoading = false; _errorType = _ErrorType.emailNotVerified; });
      Provider.of<AuthProvider>(context, listen: false).clearError();
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('❌ Erreur login: $e');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isLoading = true);
    final success = await authProvider.signInWithGoogle(rememberMe: _rememberMe);
    setState(() => _isLoading = false);
    if (success) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _checkAndReactivateIfNeeded(user);
        if (mounted) await _navigateByRole(user);
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    setState(() => _isLoading = true);
    final result = await _biometricService.loginWithBiometric();
    setState(() => _isLoading = false);
    if (!mounted) return;

    if (result.success && result.user != null) {
      await _checkAndReactivateIfNeeded(result.user!);
      if (mounted) await _navigateByRole(result.user!);

    } else if (result.error == 'session_expired') {
      if (result.email != null) setState(() => _email = result.email!);
      final t = Provider.of<LanguageProvider>(context, listen: false).translate;
      _showSnackBar(t('biometric_session_expired'), Colors.orange);

    } else if (result.error != null &&
        result.error != AppLocalizations.get('biometric_cancelled')) {
      _showSnackBar(result.error!, Colors.red);
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_isResending) return;
    if (_password.isEmpty) { _showPasswordNeededDialog(); return; }

    final t = Provider.of<LanguageProvider>(context, listen: false).translate;
    setState(() => _isResending = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.trim(), password: _password,
      );
      final user = credential.user ?? (throw Exception('User null'));

      if (user.emailVerified) {
        await FirebaseAuth.instance.signOut();
        setState(() { _isResending = false; _errorType = _ErrorType.none; });
        if (mounted) _showSnackBar(t('email_already_verified'), Colors.green);
        return;
      }

      await user.sendEmailVerification();
      await FirebaseAuth.instance.signOut();
      setState(() => _isResending = false);
      if (mounted) _showSnackBar(t('verification_email_resent'), Colors.green);

    } on FirebaseAuthException catch (e) {
      setState(() => _isResending = false);
      await FirebaseAuth.instance.signOut().catchError((_) {});
      final t2 = Provider.of<LanguageProvider>(context, listen: false).translate;
      final msg = (e.code == 'wrong-password' || e.code == 'invalid-credential')
          ? t2('wrong_password_for_resend')
          : e.code == 'too-many-requests'
          ? t2('too_many_requests')
          : t2('resend_email_error');
      if (mounted) _showSnackBar(msg, Colors.red);
    } catch (e) {
      setState(() => _isResending = false);
      await FirebaseAuth.instance.signOut().catchError((_) {});
      if (mounted) {
        _showSnackBar(
          Provider.of<LanguageProvider>(context, listen: false)
              .translate('resend_email_error'),
          Colors.red,
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  UTILS
  // ─────────────────────────────────────────────────────────────────────────────
  bool _isEmailNotVerifiedError(String msg) {
    final m = msg.toLowerCase();
    return m.contains('email-not-verified')  ||
        m.contains('email not verified')     ||
        m.contains('email non vérifié')      ||
        m.contains('vérifier votre email')   ||
        m.contains('verify your email')      ||
        m.contains('emailnotverified')       ||
        m.contains('not verified')           ||
        m.contains('boîte de réception');
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:          Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor:  color,
      behavior:         SnackBarBehavior.floating,
      duration:         const Duration(seconds: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showPasswordNeededDialog() {
    final t = Provider.of<LanguageProvider>(context, listen: false).translate;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Icon(Icons.lock_outline, color: _purple, size: 40),
        content: Text(t('enter_password_to_resend'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t('understand'),
                style: const TextStyle(color: _purple)),
          ),
        ],
      ),
    );
  }

  bool get _isBusy =>
      Provider.of<AuthProvider>(context, listen: false).isLoading || _isLoading;

  // ─────────────────────────────────────────────────────────────────────────────
  //  WIDGETS HELPERS
  // ─────────────────────────────────────────────────────────────────────────────

  /// Champ texte commun (email ou mot de passe)
  Widget _buildTextField({
    required String hint,
    required IconData icon,
    required ValueChanged<String> onChanged,
    required FormFieldValidator<String> validator,
    bool obscure      = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? initialValue,
  }) {
    return TextFormField(
      obscureText:  obscure,
      keyboardType: keyboardType,
      initialValue: initialValue,
      style: const TextStyle(color: Colors.black),
      onChanged:    onChanged,
      validator:    validator,
      decoration: InputDecoration(
        filled:     true,
        fillColor:  Colors.grey[50],
        hintText:   hint,
        prefixIcon: Icon(icon, color: _purple),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _purple, width: 2)),
      ),
    );
  }

  /// Bannière email non vérifié
  Widget _buildEmailNotVerifiedBanner(LanguageProvider lang) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:  const Color(0xFFFFF8E1),
        border: Border.all(color: const Color(0xFFFFB300)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.mark_email_unread_rounded,
              color: Color(0xFFFF8F00), size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(
            lang.translate('email_not_verified_message'),
            style: const TextStyle(
                color: Color(0xFF5D4037),
                fontSize: 13, fontWeight: FontWeight.w500),
          )),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              side:    const BorderSide(color: Color(0xFFFFB300)),
              shape:   RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _isResending ? null : _resendVerificationEmail,
            icon: _isResending
                ? const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Color(0xFFFF8F00))))
                : const Icon(Icons.send, size: 16, color: Color(0xFFFF8F00)),
            label: Text(
              _isResending
                  ? lang.translate('sending')
                  : lang.translate('resend_verification_email'),
              style: const TextStyle(color: Color(0xFFFF8F00), fontSize: 13),
            ),
          ),
        ),
      ]),
    );
  }

  /// Bannière erreur provider
  Widget _buildErrorBanner(String message) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:  Colors.red[50],
        border: Border.all(color: Colors.red[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.error, color: Colors.red[600], size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(message,
            style: TextStyle(color: Colors.red[600], fontSize: 14))),
      ]),
    );
  }

  /// Bouton principal
  Widget _buildLoginButton(LanguageProvider lang) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _purple,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        onPressed: _isBusy ? null : _handleLogin,
        child: _isBusy
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white))),
          const SizedBox(width: 12),
          Text(lang.translate('logging_in'),
              style: const TextStyle(color: Colors.white)),
        ])
            : Text(lang.translate('login'),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  /// Bouton Google
  Widget _buildGoogleButton(LanguageProvider lang) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side:    const BorderSide(color: Colors.grey),
        ),
        onPressed: _isBusy ? null : _handleGoogleSignIn,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Image.asset('assets/icons/google-icon.png',
              height: 22, width: 22,
              errorBuilder: (_, __, ___) =>
              const Icon(Icons.account_circle, size: 22)),
          const SizedBox(width: 10),
          Text(lang.translate('continue_google'),
              style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  /// Bouton biométrique (icône uniquement + label court)
  Widget _buildBiometricButton(LanguageProvider lang) {
    if (!_showBiometricButton) return const SizedBox.shrink();

    return Column(children: [
      // Séparateur
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          const Expanded(child: Divider(thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(lang.translate('or'),
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          const Expanded(child: Divider(thickness: 0.5)),
        ]),
      ),

      // Bouton biométrique compact
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side:  const BorderSide(color: _purple, width: 1.5),
            backgroundColor: _purple.withOpacity(0.04),
          ),
          onPressed: _isBusy ? null : _handleBiometricLogin,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fingerprint, size: 26, color: _purple),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  // Label court : "Face ID", "Touch ID", "Biométrique"
                  _biometricLabel.isNotEmpty
                      ? _biometricLabel
                      : lang.translate('biometric_login_btn'),
                  style: const TextStyle(
                      fontSize: 15,
                      color: _purple,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final lang         = Provider.of<LanguageProvider>(context);
    final size         = MediaQuery.of(context).size;

    final providerErrMsg = authProvider.errorMessage;
    final showProviderError = providerErrMsg != null &&
        !_isEmailNotVerifiedError(providerErrMsg);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width:  size.width,
        height: size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: [_purpleLight, _purpleMid, _purpleDeep],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Card(
                margin: EdgeInsets.symmetric(horizontal: size.width * 0.06),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                color: Colors.white.withOpacity(0.96),
                elevation: 12,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        // ── Logo ───────────────────────────────────
                        SizedBox(
                          width:  size.width * 0.28,
                          height: size.height * 0.1,
                          child:  Image.asset('assets/images/logoApp.png'),
                        ),
                        const SizedBox(height: 16),

                        // ── Titre ──────────────────────────────────
                        Text(lang.translate('login_title'),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: _purple)),
                        const SizedBox(height: 28),

                        // ── Email ──────────────────────────────────
                        _buildTextField(
                          hint:         lang.translate('email'),
                          icon:         Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          initialValue: _email,
                          onChanged:    (v) => _email = v,
                          validator:    (v) {
                            if (v == null || v.isEmpty)
                              return lang.translate('email_required');
                            if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(v))
                              return lang.translate('invalid_email');
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // ── Mot de passe ───────────────────────────
                        _buildTextField(
                          hint:   lang.translate('password'),
                          icon:   Icons.lock_outline,
                          obscure: !_isPasswordVisible,
                          onChanged: (v) => setState(() => _password = v),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: _purple,
                            ),
                            onPressed: () => setState(
                                    () => _isPasswordVisible = !_isPasswordVisible),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty)
                              return lang.translate('password_required');
                            if (v.length < 8) return '';
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),

                        // ── Remember me + Forgot password ─────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              SizedBox(
                                height: 24, width: 24,
                                child: Checkbox(
                                  value:       _rememberMe,
                                  onChanged:   (v) =>
                                      setState(() => _rememberMe = v!),
                                  activeColor: _purple,
                                  materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(lang.translate('remember_me'),
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 13)),
                            ]),
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                  context, '/forgot-password'),
                              child: Text(lang.translate('forgot_password'),
                                  style: const TextStyle(
                                      color: _purple,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── Bannière email non vérifié ─────────────
                        if (_errorType == _ErrorType.emailNotVerified)
                          _buildEmailNotVerifiedBanner(lang),

                        // ── Erreur provider ────────────────────────
                        if (showProviderError)
                          _buildErrorBanner(providerErrMsg),

                        // ── Bouton Connexion ───────────────────────
                        _buildLoginButton(lang),
                        const SizedBox(height: 12),

                        // ── Bouton Google ──────────────────────────
                        _buildGoogleButton(lang),

                        // ── Bouton biométrique ─────────────────────
                        _buildBiometricButton(lang),

                        const SizedBox(height: 16),

                        // ── Visiteur ───────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () async {
                              try {
                                await FirebaseAuth.instance.signOut();
                              } catch (_) {}
                              if (mounted)
                                Navigator.pushReplacementNamed(context, '/home');
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(lang.translate('continue_guest'),
                                style: const TextStyle(
                                    fontSize: 15,
                                    color: _purple,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ),

                        // ── Pas de compte ──────────────────────────
                        Row(mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${lang.translate('no_account')} ',
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.grey)),
                              GestureDetector(
                                onTap: () => Navigator.pushReplacementNamed(
                                    context, '/signup'),
                                child: Text(lang.translate('signup_title'),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _purple)),
                              ),
                            ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
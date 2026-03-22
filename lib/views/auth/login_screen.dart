import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/firebase_auth_service.dart';
import '../../models/user_model.dart';
import 'role_selection_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _rememberMe = false;
  bool _isPasswordVisible = false;
  String _email = '';
  String _password = '';
  bool _isLoading = false;
  bool _isResending = false;

  _ErrorType _errorType = _ErrorType.none;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs      = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('rememberMe') ?? false;
      final lastEmail  = prefs.getString('lastEmail');
      if (rememberMe && lastEmail != null) {
        setState(() {
          _rememberMe = true;
          _email      = lastEmail;
        });
      }
    } catch (e) {
      print('❌ LoginScreen: Erreur chargement préférences: $e');
    }
  }

  Future<String?> _getUserRole(User currentUser) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final role = data['role'] as String?;
        if (role != null && role.isNotEmpty && role != 'null') return role;
      }
      return null;
    } catch (e) {
      print('❌ LoginScreen: Erreur récupération rôle: $e');
      return null;
    }
  }

  Future<void> _navigateByRole(User currentUser) async {
    final role = await _getUserRole(currentUser);
    if (!mounted) return;
    if (role == null) {
      await _navigateToRoleSelection(currentUser);
    } else if (role == 'seller') {
      Navigator.pushReplacementNamed(context, '/seller-home');
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _navigateToRoleSelection(User currentUser) async {
    try {
      final displayName = currentUser.displayName ?? '';
      final nameParts   = displayName.split(' ');
      final firstName   = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName    = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      final userModel = await Navigator.of(context).push<UserModel>(
        MaterialPageRoute(
          builder: (context) => RoleSelectionPage(
            firstName:       firstName,
            lastName:        lastName,
            email:           currentUser.email ?? '',
            phoneNumber:     currentUser.phoneNumber ?? '',
            countryCode:     null,
            genre:           null,
            photoUrl:        currentUser.photoURL,
            isGoogleUser:    currentUser.providerData.any((p) => p.providerId == 'google.com'),
            isEmailVerified: currentUser.emailVerified,
          ),
        ),
      );

      if (!mounted) return;
      if (userModel != null) {
        await _saveUserRole(userModel);
        if (!mounted) return;
        if (userModel.role == UserRole.seller) {
          Navigator.pushReplacementNamed(context, '/seller-home');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      print('❌ LoginScreen: Erreur sélection rôle: $e');
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _saveUserRole(UserModel userModel) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set(userModel.toMap(), SetOptions(merge: true));
      }
    } catch (e) {
      print('❌ Erreur sauvegarde rôle: $e');
    }
  }

  bool _isEmailNotVerifiedError(String msg) {
    final m = msg.toLowerCase();
    return m.contains('email-not-verified') ||
        m.contains('email not verified') ||
        m.contains('email non vérifié') ||
        m.contains('vérifier votre email') ||
        m.contains('verify your email') ||
        m.contains('emailnotverified') ||
        m.contains('not verified') ||
        m.contains('boîte de réception');
  }

  // ── Handle Login ─────────────────────────────────────────────
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    setState(() {
      _isLoading = true;
      _errorType = _ErrorType.none;
    });

    try {
      final success = await authProvider.signIn(
        email:      _email.trim(),
        password:   _password,
        rememberMe: _rememberMe,
      );

      setState(() => _isLoading = false);

      if (success) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) await _navigateByRole(currentUser);
        return;
      }

      // ── Email non vérifié → bannière jaune ────────────────────
      final errMsg = authProvider.errorMessage ?? '';
      if (_isEmailNotVerifiedError(errMsg)) {
        authProvider.clearError();
        setState(() => _errorType = _ErrorType.emailNotVerified);
      }

    } on EmailNotVerifiedException {
      setState(() {
        _isLoading = false;
        _errorType = _ErrorType.emailNotVerified;
      });
      Provider.of<AuthProvider>(context, listen: false).clearError();

    } catch (e) {
      setState(() => _isLoading = false);
      print('❌ LoginScreen: Erreur inattendue: $e');
    }
  }

  // ── Renvoyer l'email de vérification ─────────────────────────
  // ✅ FIX : se connecte silencieusement, envoie l'email, se déconnecte
  //   (l'user est déconnecté par le service après l'inscription)
  Future<void> _resendVerificationEmail() async {
    if (_isResending) return;
    if (_password.isEmpty) {
      // Demander le mot de passe si le champ est vide
      _showPasswordNeededDialog();
      return;
    }

    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    setState(() => _isResending = true);

    try {
      // 1️⃣ Se connecter silencieusement avec email + mot de passe
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email:    _email.trim(),
        password: _password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Utilisateur introuvable');
      }

      if (user.emailVerified) {
        // Email déjà vérifié → cacher la bannière et laisser l'user se connecter
        await FirebaseAuth.instance.signOut();
        setState(() {
          _isResending = false;
          _errorType   = _ErrorType.none;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:         Text(langProvider.translate('email_already_verified')),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      // 2️⃣ Envoyer l'email de vérification
      await user.sendEmailVerification();
      print('📧 Email de vérification renvoyé à: ${user.email}');

      // 3️⃣ Déconnecter immédiatement (doit vérifier avant de se connecter)
      await FirebaseAuth.instance.signOut();

      setState(() => _isResending = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:         Text(langProvider.translate('verification_email_resent')),
            backgroundColor: Colors.green,
            duration:        const Duration(seconds: 4),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isResending = false);
      await FirebaseAuth.instance.signOut().catchError((_) {});

      String msg;
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = langProvider.translate('wrong_password_for_resend');
      } else if (e.code == 'too-many-requests') {
        msg = langProvider.translate('too_many_requests');
      } else {
        msg = langProvider.translate('resend_email_error');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => _isResending = false);
      await FirebaseAuth.instance.signOut().catchError((_) {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:         Text(langProvider.translate('resend_email_error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Dialog si mot de passe vide ──────────────────────────────
  void _showPasswordNeededDialog() {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Icon(Icons.lock_outline, color: Color(0xFF8700FF), size: 40),
        content: Text(
          langProvider.translate('enter_password_to_resend'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(langProvider.translate('understand'),
                style: const TextStyle(color: Color(0xFF8700FF))),
          ),
        ],
      ),
    );
  }

  // ── Handle Google Sign In ────────────────────────────────────
  Future<void> _handleGoogleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isLoading = true);
    final success = await authProvider.signInWithGoogle(rememberMe: _rememberMe);
    setState(() => _isLoading = false);
    if (success) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) await _navigateByRole(currentUser);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth  = MediaQuery.of(context).size.width;

    final providerErrMsg    = authProvider.errorMessage;
    final showProviderError = providerErrMsg != null &&
        !_isEmailNotVerifiedError(providerErrMsg);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: [
              Color(0xFF6366F1),
              Color(0xFF8B5CF6),
              Color(0xFFA855F7),
            ],
          ),
        ),
        child: SizedBox(
          height: screenHeight,
          width:  screenWidth,
          child: Center(
            child: SingleChildScrollView(
              child: Card(
                margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25)),
                color:     Colors.white.withOpacity(0.95),
                elevation: 15,
                child: Padding(
                  padding: EdgeInsets.all(screenWidth * 0.08),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width:  screenWidth * 0.3,
                          height: screenHeight * 0.12,
                          child: Image.asset('assets/images/logoApp.png'),
                        ),
                        const SizedBox(height: 20),

                        Text(
                          langProvider.translate('login_title'),
                          style: const TextStyle(
                            fontSize:   24,
                            fontWeight: FontWeight.bold,
                            color:      Color(0xFF8700FF),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // ── Email ──
                        TextFormField(
                          keyboardType: TextInputType.emailAddress,
                          initialValue: _email,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            filled:    true,
                            fillColor: Colors.grey[50],
                            hintText:  langProvider.translate('email'),
                            prefixIcon: const Icon(Icons.email, color: Color(0xFF8700FF)),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF8700FF), width: 2)),
                          ),
                          onChanged:  (value) => _email = value,
                          validator:  (value) {
                            if (value == null || value.isEmpty)
                              return langProvider.translate('email_required');
                            if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value))
                              return langProvider.translate('invalid_email');
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // ── Mot de passe ──
                        TextFormField(
                          obscureText: !_isPasswordVisible,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            filled:    true,
                            fillColor: Colors.grey[50],
                            hintText:  langProvider.translate('password'),
                            prefixIcon: const Icon(Icons.lock, color: Color(0xFF8700FF)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                color: const Color(0xFF8700FF),
                              ),
                              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF8700FF), width: 2)),
                          ),
                          onChanged:  (value) => setState(() => _password = value),
                          validator:  (value) {
                            if (value == null || value.isEmpty)
                              return langProvider.translate('password_required');
                            if (value.length < 8) return '';
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),

                        // ── Remember me ──
                        Row(children: [
                          Checkbox(
                            value:     _rememberMe,
                            onChanged: (value) => setState(() => _rememberMe = value!),
                            activeColor: const Color(0xFF8700FF),
                          ),
                          Text(
                            langProvider.translate('remember_me'),
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ]),
                        const SizedBox(height: 10),

                        // ── Mot de passe oublié ──
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/forgot-password'),
                            child: Text(
                              langProvider.translate('forgot_password'),
                              style: const TextStyle(
                                color:      Color(0xFF8700FF),
                                fontSize:   14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),

                        // ── Bannière email non vérifié ────────────────────────
                        if (_errorType == _ErrorType.emailNotVerified) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color:  const Color(0xFFFFF8E1),
                              border: Border.all(color: const Color(0xFFFFB300)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                // ── Message ──
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.mark_email_unread_rounded,
                                        color: Color(0xFFFF8F00), size: 22),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        langProvider.translate('email_not_verified_message'),
                                        style: const TextStyle(
                                          color:      Color(0xFF5D4037),
                                          fontSize:   13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // ── Bouton renvoyer ──
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      side:  const BorderSide(color: Color(0xFFFFB300)),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: _isResending ? null : _resendVerificationEmail,
                                    icon: _isResending
                                        ? const SizedBox(
                                      width: 14, height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Color(0xFFFF8F00)),
                                      ),
                                    )
                                        : const Icon(Icons.send,
                                        size: 16, color: Color(0xFFFF8F00)),
                                    label: Text(
                                      _isResending
                                          ? langProvider.translate('sending')
                                          : langProvider.translate('resend_verification_email'),
                                      style: const TextStyle(
                                          color: Color(0xFFFF8F00), fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // ── Erreur provider (mauvais mdp, compte inexistant…) ─
                        if (showProviderError)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:  Colors.red[50],
                              border: Border.all(color: Colors.red[200]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(children: [
                              Icon(Icons.error, color: Colors.red[600], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  providerErrMsg!,
                                  style: TextStyle(color: Colors.red[600], fontSize: 14),
                                ),
                              ),
                            ]),
                          ),

                        // ── Bouton connexion ──
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8700FF),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                            onPressed: (authProvider.isLoading || _isLoading)
                                ? null : _handleLogin,
                            child: (authProvider.isLoading || _isLoading)
                                ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(langProvider.translate('logging_in'),
                                    style: const TextStyle(color: Colors.white)),
                              ],
                            )
                                : Text(
                              langProvider.translate('login'),
                              style: const TextStyle(
                                color:      Colors.white,
                                fontSize:   16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Bouton Google ──
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: Colors.grey),
                            ),
                            onPressed: (authProvider.isLoading || _isLoading)
                                ? null : _handleGoogleSignIn,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/icons/google-icon.png',
                                  height: 24, width: 24,
                                  errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.account_circle, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  langProvider.translate('continue_google'),
                                  style: const TextStyle(
                                    fontSize:   16,
                                    color:      Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Continuer comme visiteur ──
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () async {
                              try { await FirebaseAuth.instance.signOut(); } catch (_) {}
                              if (mounted) Navigator.pushReplacementNamed(context, '/home');
                            },
                            child: Text(
                              langProvider.translate('continue_guest'),
                              style: const TextStyle(
                                fontSize:   16,
                                color:      Color(0xFF8700FF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                        // ── Pas de compte ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${langProvider.translate('no_account')} ',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pushReplacementNamed(context, '/signup'),
                              child: Text(
                                langProvider.translate('signup_title'),
                                style: const TextStyle(
                                  fontSize:   14,
                                  fontWeight: FontWeight.w600,
                                  color:      Color(0xFF8700FF),
                                ),
                              ),
                            ),
                          ],
                        ),
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

enum _ErrorType { none, emailNotVerified }
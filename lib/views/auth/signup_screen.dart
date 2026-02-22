import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/terms_and_conditions_dialog.dart';
import 'role_selection_page.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  bool _isLoading = false;
  bool _agreeToTerms = false;
  List<String> _passwordErrors = [];

  bool _hasMinLength(String p) => p.length >= 8;
  bool _hasUpperCase(String p) => p.contains(RegExp(r'[A-Z]'));
  bool _hasLowerCase(String p) => p.contains(RegExp(r'[a-z]'));
  bool _isPasswordValid(String p) =>
      _hasMinLength(p) && _hasUpperCase(p) && _hasLowerCase(p);

  List<String> _getPasswordErrors(
      String password, LanguageProvider langProvider) {
    final errors = <String>[];
    if (password.length < 8)
      errors.add(langProvider.translate('password_min_length'));
    if (!password.contains(RegExp(r'[A-Z]')))
      errors.add(langProvider.translate('password_uppercase'));
    if (!password.contains(RegExp(r'[a-z]')))
      errors.add(langProvider.translate('password_lowercase'));
    return errors;
  }

  // ── Récupérer le rôle depuis Firestore ───────────────────────
  Future<String?> _getUserRole(User currentUser) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final role = data['role'] as String?;
        if (role != null && role.isNotEmpty && role != 'null') {
          return role;
        }
      }
      return null;
    } catch (e) {
      print('❌ SignUpScreen: Erreur récupération rôle: $e');
      return null;
    }
  }

  // ── Navigation selon le rôle ─────────────────────────────────
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

  // ── Navigation vers la sélection de rôle ────────────────────
  Future<void> _navigateToRoleSelection(User currentUser) async {
    try {
      final displayName = currentUser.displayName ?? '';
      final nameParts = displayName.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName =
      nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      final userModel = await Navigator.of(context).push<UserModel>(
        MaterialPageRoute(
          builder: (context) => RoleSelectionPage(
            firstName: firstName,
            lastName: lastName,
            email: currentUser.email ?? '',
            phoneNumber: currentUser.phoneNumber ?? '',
            photoUrl: currentUser.photoURL,
            isGoogleUser: currentUser.providerData
                .any((p) => p.providerId == 'google.com'),
            isEmailVerified: currentUser.emailVerified,
          ),
        ),
      );

      if (!mounted) return;

      if (userModel != null) {
        await _saveUserRole(userModel);

        if (!mounted) return;

        // ✅ Rediriger selon le rôle choisi
        if (userModel.role == UserRole.seller) {
          Navigator.pushReplacementNamed(context, '/seller-home');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      print('❌ SignUpScreen: Erreur sélection rôle: $e');
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    }
  }

  // ── Sauvegarder le rôle dans Firestore ──────────────────────
  Future<void> _saveUserRole(UserModel userModel) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set(userModel.toMap(), SetOptions(merge: true));
        print('✅ Rôle sauvegardé: ${userModel.role}');
      }
    } catch (e) {
      print('❌ Erreur sauvegarde rôle: $e');
    }
  }

  // ── Handle SignUp ────────────────────────────────────────────
  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    final langProvider =
    Provider.of<LanguageProvider>(context, listen: false);

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(langProvider.translate('accept_terms_required')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isLoading = true);

    try {
      final success = await authProvider.signUp(
        email: _email.trim(),
        password: _password,
      );

      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(langProvider.translate('signup_success')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (e.toString().contains('Inscription réussie')) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.email, color: Colors.blue, size: 24),
                  const SizedBox(width: 10),
                  Text(langProvider.translate('signup_success')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(langProvider.translate('verification_email_sent')),
                  const SizedBox(height: 8),
                  Text(
                    _email.trim(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  const SizedBox(height: 12),
                  Text(langProvider.translate('verify_before_login')),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: Text(langProvider.translate('understand')),
                ),
              ],
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            ),
          ),
        );
      }
    }
  }

  // ── Handle Google Sign In ────────────────────────────────────
  Future<void> _handleGoogleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isLoading = true);

    final success = await authProvider.signInWithGoogle();
    setState(() => _isLoading = false);

    if (success) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _navigateByRole(currentUser); // ✅ navigation selon rôle
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6366F1),
              Color(0xFF8B5CF6),
              Color(0xFFA855F7),
            ],
          ),
        ),
        child: SizedBox(
          height: screenHeight,
          width: screenWidth,
          child: Center(
            child: SingleChildScrollView(
              child: Card(
                margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                color: Colors.white.withOpacity(0.95),
                elevation: 15,
                child: Padding(
                  padding: EdgeInsets.all(screenWidth * 0.08),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: screenWidth * 0.3,
                          height: screenHeight * 0.12,
                          child: Image.asset('assets/images/logoApp.png'),
                        ),
                        const SizedBox(height: 20),

                        Text(
                          langProvider.translate('create_account'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8700FF),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Email ──
                        TextFormField(
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[50],
                            hintText: langProvider.translate('email'),
                            prefixIcon: const Icon(Icons.email,
                                color: Color(0xFF8700FF)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                              BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xFF8700FF), width: 2),
                            ),
                          ),
                          onChanged: (value) => _email = value,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return langProvider.translate('email_required');
                            }
                            final emailRegex =
                            RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegex.hasMatch(value)) {
                              return langProvider.translate('invalid_email');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // ── Mot de passe ──
                        TextFormField(
                          obscureText: !_isPasswordVisible,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[50],
                            hintText: langProvider.translate('password'),
                            prefixIcon: const Icon(Icons.lock,
                                color: Color(0xFF8700FF)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: const Color(0xFF8700FF),
                              ),
                              onPressed: () => setState(() =>
                              _isPasswordVisible = !_isPasswordVisible),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                              BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xFF8700FF), width: 2),
                            ),
                          ),
                          onChanged: (value) {
                            _password = value;
                            setState(() => _passwordErrors =
                                _getPasswordErrors(value, langProvider));
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return langProvider
                                  .translate('password_required');
                            }
                            if (!_isPasswordValid(value)) {
                              return langProvider
                                  .translate('password_requirements');
                            }
                            return null;
                          },
                        ),

                        // ── Erreurs mot de passe ──
                        if (_passwordErrors.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  langProvider
                                      .translate('password_must_contain'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ..._passwordErrors.map((error) => Padding(
                                  padding:
                                  const EdgeInsets.only(top: 2),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline,
                                          size: 14,
                                          color: Colors.red[600]),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          error,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.red[600]),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),

                        // ── Confirmer mot de passe ──
                        TextFormField(
                          obscureText: !_isConfirmPasswordVisible,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[50],
                            hintText:
                            langProvider.translate('confirm_password'),
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: Color(0xFF8700FF)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isConfirmPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: const Color(0xFF8700FF),
                              ),
                              onPressed: () => setState(() =>
                              _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                              BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xFF8700FF), width: 2),
                            ),
                          ),
                          onChanged: (value) => _confirmPassword = value,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return langProvider
                                  .translate('confirm_password_required');
                            }
                            if (value != _password) {
                              return langProvider
                                  .translate('passwords_not_match');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // ── Conditions générales ──
                        Row(
                          children: [
                            Checkbox(
                              value: _agreeToTerms,
                              onChanged: (value) => setState(
                                      () => _agreeToTerms = value ?? false),
                              activeColor: const Color(0xFF8700FF),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final result = await showDialog<bool>(
                                    context: context,
                                    builder: (_) =>
                                    const TermsAndConditionsDialog(),
                                  );
                                  if (result == true) {
                                    setState(() => _agreeToTerms = true);
                                  }
                                },
                                child: Text(
                                  langProvider.translate('agree_terms'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF8700FF),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ── Message d'erreur ──
                        if (authProvider.errorMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              border: Border.all(color: Colors.red[200]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error,
                                    color: Colors.red[600], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    authProvider.errorMessage!,
                                    style: TextStyle(
                                        color: Colors.red[600],
                                        fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // ── Bouton inscription ──
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8700FF),
                              padding:
                              const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                            onPressed: (authProvider.isLoading || _isLoading)
                                ? null
                                : _handleSignUp,
                            child: (authProvider.isLoading || _isLoading)
                                ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                    langProvider.translate('signing_up'),
                                    style: const TextStyle(
                                        color: Colors.white)),
                              ],
                            )
                                : Text(
                              langProvider.translate('signup_title'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
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
                              padding:
                              const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: Colors.grey),
                            ),
                            onPressed: (authProvider.isLoading || _isLoading)
                                ? null
                                : _handleGoogleSignIn,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/icons/google-icon.png',
                                  height: 24,
                                  width: 24,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.account_circle,
                                      size: 24),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  langProvider.translate('continue_google'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Déjà un compte ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${langProvider.translate('already_account')} ',
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.grey),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pushReplacementNamed(
                                  context, '/login'),
                              child: Text(
                                langProvider.translate('login'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8700FF),
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
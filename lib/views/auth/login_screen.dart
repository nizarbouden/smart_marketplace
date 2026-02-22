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

  @override
  void initState() {
    super.initState();
    _checkAndForceSignOut();
    _loadPreferences();
  }

  // Vérifier et forcer la déconnexion si "Se souvenir de moi" n'est pas coché
  Future<void> _checkAndForceSignOut() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.checkConnectionState();
  }

  // Charger les préférences au démarrage
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool rememberMe = prefs.getBool('rememberMe') ?? false;
      String? lastEmail = prefs.getString('lastEmail');

      if (rememberMe && lastEmail != null) {
        setState(() {
          _rememberMe = true;
          _email = lastEmail;
        });
        print('✅ LoginScreen: Préférences chargées - email: $lastEmail, rememberMe: $rememberMe');
      }
    } catch (e) {
      print('❌ LoginScreen: Erreur lors du chargement des préférences: $e');
    }
  }

  // Méthodes de validation
  bool _hasMinLength(String password) => password.length >= 8;
  bool _hasLowerCase(String password) => password.contains(RegExp(r'[a-z]'));
  bool _hasUpperCase(String password) => password.contains(RegExp(r'[A-Z]'));

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
              const Color(0xFF6366F1),
              const Color(0xFF8B5CF6),
              const Color(0xFFA855F7),
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

                        // ✅ TRADUIT
                        Text(
                          langProvider.translate('login_title'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8700FF),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Email Field
                        TextFormField(
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[50],
                            // ✅ TRADUIT
                            hintText: langProvider.translate('email'),
                            prefixIcon: const Icon(Icons.email, color: Color(0xFF8700FF)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF8700FF), width: 2),
                            ),
                          ),
                          onChanged: (value) => _email = value,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return langProvider.translate('email_required');
                            }
                            final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegex.hasMatch(value)) {
                              return langProvider.translate('invalid_email');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Password Field
                        TextFormField(
                          obscureText: !_isPasswordVisible,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[50],
                            // ✅ TRADUIT
                            hintText: langProvider.translate('password'),
                            prefixIcon: const Icon(Icons.lock, color: Color(0xFF8700FF)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                color: const Color(0xFF8700FF),
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF8700FF), width: 2),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _password = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return langProvider.translate('password_required');
                            }

                            // Validation simple sans indicateurs visuels
                            if (value.length < 8) {
                              return '';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 15),

                        // Remember me
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value!;
                                });
                              },
                              activeColor: const Color(0xFF8700FF),
                            ),
                            // ✅ TRADUIT
                            Text(
                              langProvider.translate('remember_me'),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Forgot password
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, '/forgot-password');
                              },
                              child: Text(
                                langProvider.translate('forgot_password'),
                                style: const TextStyle(
                                  color: Color(0xFF8700FF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),

                        // Message d'erreur
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
                                Icon(Icons.error, color: Colors.red[600], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    authProvider.errorMessage!,
                                    style: TextStyle(color: Colors.red[600], fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8700FF),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            onPressed: (authProvider.isLoading || _isLoading) ? null : _handleLogin,
                            child: (authProvider.isLoading || _isLoading)
                                ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // ✅ TRADUIT
                                Text(langProvider.translate('logging_in')),
                              ],
                            )
                                : Text(
                              langProvider.translate('login'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Bouton Google
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(color: Colors.grey),
                            ),
                            onPressed: (authProvider.isLoading || _isLoading) ? null : _handleGoogleSignIn,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/icons/google-icon.png',
                                  height: 24,
                                  width: 24,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.account_circle, size: 24);
                                  },
                                ),
                                const SizedBox(width: 12),
                                // ✅ TRADUIT
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

                        // Bouton Continuer comme visiteur
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () async {
                              try {
                                await FirebaseAuth.instance.signOut();
                                print('✅ LoginScreen: Déconnexion forcée réussie');
                              } catch (e) {
                                print('⚠️ LoginScreen: Erreur lors de la déconnexion: $e');
                              }

                              Navigator.pushReplacementNamed(context, '/home');
                            },
                            child: Text(
                              langProvider.translate('continue_guest'),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF8700FF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // ✅ TRADUIT
                            Text(
                              '${langProvider.translate('no_account')} ',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacementNamed(context, '/signup');
                              },
                              child: Text(
                                langProvider.translate('signup_title'),
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

  /**
   * Méthode pour gérer la connexion
   */
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    setState(() {
      _isLoading = true;
    });

    print('🔄 LoginScreen: Appel de authProvider.signIn');
    try {
      bool success = await authProvider.signIn(
        email: _email.trim(),
        password: _password,
        rememberMe: _rememberMe,
      );
      print('🔄 LoginScreen: Résultat de signIn: $success (rememberMe: $_rememberMe)');

      setState(() {
        _isLoading = false;
      });

      if (success) {
        print('✅ LoginScreen: Connexion réussie');
        
        // Vérifier si l'utilisateur a déjà un rôle
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          bool hasRole = await _checkUserRole(currentUser);
          
          if (hasRole) {
            // L'utilisateur a déjà un rôle, aller directement au main layout
            print('✅ LoginScreen: Utilisateur avec rôle existant, navigation vers /home');
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            // L'utilisateur n'a pas de rôle, aller à la sélection de rôle
            print('🔄 LoginScreen: Utilisateur sans rôle, navigation vers la sélection');
            await _navigateToRoleSelection(currentUser);
          }
        }
      } else {
        print('❌ LoginScreen: Connexion échouée');
      }
    } on EmailNotVerifiedException catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 15),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      print('❌ LoginScreen: Erreur inattendue: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Une erreur est survenue: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    setState(() => _isLoading = true);

    bool success = await authProvider.signInWithGoogle();

    setState(() => _isLoading = false);

    if (success) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        bool hasRole = await _checkUserRole(currentUser);
        if (hasRole) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          await _navigateToRoleSelection(currentUser);
        }
      }
    }
  }

  // Méthode pour naviguer vers la sélection de rôle
  Future<void> _navigateToRoleSelection(User currentUser) async {
    try {
      // Extraire les informations de l'utilisateur
      final displayName = currentUser.displayName ?? '';
      final nameParts = displayName.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      
      final userModel = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RoleSelectionPage(
            firstName: firstName,
            lastName: lastName,
            email: currentUser.email ?? '',
            phoneNumber: currentUser.phoneNumber ?? '',
            countryCode: null, // À extraire si nécessaire
            genre: null, // À extraire si nécessaire
            photoUrl: currentUser.photoURL,
            isGoogleUser: true,
            isEmailVerified: currentUser.emailVerified ?? false,
          ),
        ),
      );

      if (userModel != null && userModel is UserModel) {
        // Sauvegarder le rôle dans Firestore
        await _saveUserRole(userModel);
        
        // Naviguer vers la page d'accueil
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      print(' LoginScreen: Erreur lors de la sélection de rôle: $e');
      // En cas d'erreur, naviguer directement vers l'accueil
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  // Méthode pour vérifier si l'utilisateur a déjà un rôle
  Future<bool> _checkUserRole(User currentUser) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String? role = userData['role'];
        
        print(' Vérification rôle pour ${currentUser.email}: role = $role');
        
        // Vérifier si le rôle existe et n'est pas null ou vide
        return role != null && role.isNotEmpty && role != 'null';
      } else {
        print(' Document utilisateur non trouvé pour ${currentUser.uid}');
        return false; // Nouvel utilisateur, pas de document = pas de rôle
      }
    } catch (e) {
      print(' Erreur lors de la vérification du rôle: $e');
      return false; // En cas d'erreur, considérer qu'il n'a pas de rôle
    }
  }

  // Méthode pour sauvegarder le rôle de l'utilisateur dans Firestore
  Future<void> _saveUserRole(UserModel userModel) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set(userModel.toMap(), SetOptions(merge: true));
        
        print('✅ Rôle utilisateur sauvegardé: ${userModel.role}');
      }
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde du rôle: $e');
    }
  }
}
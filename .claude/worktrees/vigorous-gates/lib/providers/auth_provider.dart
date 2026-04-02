import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/firebase_auth_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirebaseAuth        _auth        = FirebaseAuth.instance;

  UserModel? _user;
  bool      _isLoading    = false;
  String?   _errorMessage;

  UserModel? get user          => _user;
  bool       get isLoading     => _isLoading;
  String?    get errorMessage  => _errorMessage;
  bool       get isAuthenticated => _user != null;
  bool       get isGuest       => _user == null;

  String? get nom        => _user?.nom;
  String? get prenom     => _user?.prenom;
  String? get genre      => _user?.genre;
  String? get countryCode => _user?.countryCode;
  String? get fullName   => _user != null ? '${_user!.prenom} ${_user!.nom}' : null;
  int     get points     => _user?.points ?? 0;

  AuthProvider() { _initAsync(); }

  Future<void> _initAsync() async {
    _authService.authStateChanges.listen((User? firebaseUser) {
      if (firebaseUser != null) {
        _loadUserData();
      } else {
        _user = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUserData() async {
    try {
      _setLoading(true);
      _user = await _authService.getUserProfile();
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshUserProfile() async {
    print('🔄 AuthProvider: Rafraîchissement des données utilisateur...');
    await _loadUserData();
    print('✅ AuthProvider: Données rafraîchies');
  }

  Future<void> refreshUserData() async => _loadUserData();

  // ─────────────────────────────────────────────────────────────
  //  INSCRIPTION
  // ─────────────────────────────────────────────────────────────
  Future<bool> signUp({
    required String email,
    required String password,
    String nom = '',
    String prenom = '',
    String? genre,
    String? countryCode,
    String? phoneNumber,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      await _authService.signUpWithEmailAndPassword(
        email, password, nom,
        prenom:      prenom,
        genre:       genre,
        countryCode: countryCode,
        phoneNumber: phoneNumber,
      );

      notifyListeners();
      return true;

    } on SignUpSuccessException {
      _clearError();
      notifyListeners();
      return true;

    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'Erreur lors de l\'inscription');
      notifyListeners();
      return false;

    } catch (e) {
      _setError(e.toString());
      notifyListeners();
      return false;

    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  CONNEXION EMAIL / MOT DE PASSE
  //
  //  ✅ FIX : vérification du statut APRÈS signIn (pas avant)
  //           Si compte désactivé → réactiver automatiquement
  //           (ne plus bloquer la connexion)
  // ─────────────────────────────────────────────────────────────
  Future<bool> signIn({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      print('🔄 AuthProvider: Connexion pour $email');
      _setLoading(true);
      _clearError();

      // 1. Connexion Firebase
      _user = await _authService.signInWithEmailAndPassword(email, password);

      // 2. ✅ Vérifier le statut APRÈS connexion (pas avant)
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();

        if (userDoc.exists) {
          final status = userDoc.data()?['status'] as String? ?? 'active';

          if (status == 'deactivated') {
            // ✅ Réactiver automatiquement au lieu de bloquer
            print('🔄 Compte désactivé détecté — réactivation automatique...');
            await FirebaseFirestore.instance
                .collection('users')
                .doc(firebaseUser.uid)
                .update({
              'status':              'active',
              'reactivatedAt':       Timestamp.now(),
              'deletionRequestedAt': FieldValue.delete(),
              'scheduledDeletionAt': FieldValue.delete(),
            });
            print('✅ Compte réactivé pour ${firebaseUser.email}');
            // Continuer normalement — ne pas bloquer
          }
        }
      }

      // 3. Sauvegarder rememberMe
      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setBool('rememberMe', true);
        await prefs.setString('lastEmail', email);
        print('✅ AuthProvider: rememberMe=true sauvegardé');
      } else {
        await prefs.remove('rememberMe');
        await prefs.remove('lastEmail');
        print('✅ AuthProvider: rememberMe=false');
      }

      notifyListeners();
      print('✅ AuthProvider: Connexion réussie');
      return true;

    } on EmailNotVerifiedException catch (e) {
      _setError(e.toString());
      notifyListeners();
      return false;

    } catch (e) {
      print('❌ AuthProvider: Erreur connexion: $e');
      _setError(e.toString());
      notifyListeners();
      return false;

    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  CONNEXION GOOGLE
  //  ✅ FIX : réactiver au lieu de bloquer si compte désactivé
  // ─────────────────────────────────────────────────────────────
  Future<bool> signInWithGoogle({bool rememberMe = false}) async {
    try {
      _setLoading(true);
      _clearError();

      _user = await _authService.signInWithGoogle();

      if (_user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .get();

        if (userDoc.exists) {
          final status = userDoc.data()?['status'] as String? ?? 'active';

          if (status == 'deactivated') {
            // ✅ Réactiver automatiquement
            print('🔄 Compte Google désactivé — réactivation automatique...');
            await FirebaseFirestore.instance
                .collection('users')
                .doc(_user!.uid)
                .update({
              'status':              'active',
              'reactivatedAt':       Timestamp.now(),
              'deletionRequestedAt': FieldValue.delete(),
              'scheduledDeletionAt': FieldValue.delete(),
            });
            print('✅ Compte Google réactivé pour ${_user!.email}');
          }
        }

        final prefs = await SharedPreferences.getInstance();
        if (rememberMe) {
          await prefs.setBool('rememberMe', true);
          await prefs.setString('lastEmail', _user!.email );
        } else {
          await prefs.remove('rememberMe');
          await prefs.remove('lastEmail');
        }
      }

      notifyListeners();
      return _user != null;

    } catch (e) {
      _setError(e.toString());
      notifyListeners();
      return false;

    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  MOT DE PASSE OUBLIÉ
  // ─────────────────────────────────────────────────────────────
  Future<bool> resetPassword(String email) async {
    try {
      _setLoading(true);
      _clearError();
      await _authService.resetPassword(email);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  DÉCONNEXION
  // ─────────────────────────────────────────────────────────────
  Future<void> signOut({bool forceSignOut = false}) async {
    try {
      _setLoading(true);
      _clearError();

      final prefs      = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('rememberMe') ?? false;

      await _authService.signOut();

      if (!rememberMe || forceSignOut) {
        await prefs.remove('rememberMe');
        await prefs.remove('lastEmail');
        print('✅ AuthProvider: Déconnexion forcée + préférences effacées');
      } else {
        print('✅ AuthProvider: Déconnexion normale (rememberMe actif)');
      }

      _user = null;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  MISE À JOUR PROFIL
  // ─────────────────────────────────────────────────────────────
  Future<bool> updateProfile({
    String? nom,
    String? prenom,
    String? genre,
    String? phoneNumber,
    String? countryCode,
    String? photoUrl,
  }) async {
    try {
      _setLoading(true);
      _clearError();
      await _authService.updateProfile(
        nom: nom, prenom: prenom, genre: genre,
        phoneNumber: phoneNumber, countryCode: countryCode,
        photoUrl: photoUrl,
      );
      await _loadUserData();
      return true;
    } catch (e) {
      _setError(e.toString());
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  SUPPRESSION COMPTE
  // ─────────────────────────────────────────────────────────────
  Future<bool> deleteAccount() async {
    try {
      _setLoading(true);
      _clearError();
      await _authService.deleteAccount();
      _user = null;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  HELPERS PRIVÉS
  // ─────────────────────────────────────────────────────────────
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
    final isEmailVerificationError =
        error.toLowerCase().contains('vérifier') ||
            error.toLowerCase().contains('verify')   ||
            error.toLowerCase().contains('verified');
    if (!isEmailVerificationError) {
      Future.delayed(const Duration(seconds: 5), _clearError);
    }
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() => _clearError();

  // ─────────────────────────────────────────────────────────────
  //  VALIDATION
  // ─────────────────────────────────────────────────────────────
  bool isValidEmail(String email) =>
      RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

  String? validatePassword(String password) {
    if (password.length < 6) {
      return 'Le mot de passe doit contenir au moins 6 caractères';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Le mot de passe doit contenir au moins une majuscule';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Le mot de passe doit contenir au moins un chiffre';
    }
    return null;
  }

  bool isValidPhoneNumber(String phone) =>
      RegExp(r'^[+]?[0-9]{10,15}$').hasMatch(phone.replaceAll(' ', ''));
}
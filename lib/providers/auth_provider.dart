import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../localization/app_localizations.dart';
import '../models/user_model.dart';
import '../services/firebase_auth_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isGuest => _user == null;

  String? get nom => _user?.nom;
  String? get prenom => _user?.prenom;
  String? get genre => _user?.genre;
  String? get countryCode => _user?.countryCode;
  String? get fullName => _user != null ? '${_user!.prenom} ${_user!.nom}' : null;
  int get points => _user?.points ?? 0;

  AuthProvider() {
    _initAsync();
  }

  Future<void> _initAsync() async {
    // 1️⃣ D'abord : vérifier et forcer la déconnexion si nécessaire
    await _checkAndForceSignOut();

    // 2️⃣ Ensuite seulement : ouvrir le listener
    //    À ce stade, si l'utilisateur a été déconnecté, firebaseUser = null
    //    et SplashScreen verra un état propre dès le début.
    _authService.authStateChanges.listen((User? firebaseUser) {
      if (firebaseUser != null) {
        _loadUserData();
      } else {
        _user = null;
        notifyListeners();
      }
    });
  }

  // ─────────────────────────────────────────────────────────────
  //  Déconnexion forcée au démarrage si "Se souvenir de moi" OFF
  // ─────────────────────────────────────────────────────────────
  Future<void> _checkAndForceSignOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('rememberMe') ?? false;

      if (!rememberMe && _auth.currentUser != null) {
        print('🔄 AuthProvider: "Se souvenir de moi" non coché, déconnexion forcée au démarrage');
        await _auth.signOut();
        await prefs.remove('rememberMe');
        await prefs.remove('lastEmail');
        // ✅ Mettre _user à null immédiatement — avant que le listener soit ouvert
        _user = null;
      }
    } catch (e) {
      print('❌ AuthProvider: Erreur lors de la vérification au démarrage: $e');
    }
  }

  // Vérifier l'état de connexion (appelé depuis SplashScreen si besoin)
  Future<void> checkConnectionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('rememberMe') ?? false;

      if (!rememberMe && _auth.currentUser != null) {
        print('🔄 AuthProvider: Déconnexion automatique - "Se souvenir de moi" non coché');
        await _auth.signOut();
        await prefs.remove('rememberMe');
        await prefs.remove('lastEmail');
        _user = null;
        notifyListeners();
      }
    } catch (e) {
      print('❌ AuthProvider: Erreur checkConnectionState: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Charger les données utilisateur depuis Firestore
  // ─────────────────────────────────────────────────────────────
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
  //  Inscription
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

      _user = await _authService.signUpWithEmailAndPassword(
        email, password, nom,
        prenom: prenom,
        genre: genre,
        countryCode: countryCode,
        phoneNumber: phoneNumber,
      );

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
  //  Connexion email / mot de passe
  // ─────────────────────────────────────────────────────────────
  Future<bool> signIn({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      print('🔄 AuthProvider: Connexion pour $email (rememberMe: $rememberMe)');
      _setLoading(true);
      _clearError();

      // Vérifier statut avant connexion
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();
        if (userDoc.exists) {
          final status = userDoc.data()?['status'] as String? ?? 'active';
          if (status == 'deactivated') {
            await _auth.signOut();
            _setError('Ce compte a été désactivé et sera supprimé dans 30 jours.');
            notifyListeners();
            return false;
          }
        }
      }

      _user = await _authService.signInWithEmailAndPassword(email, password);

      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setBool('rememberMe', true);
        await prefs.setString('lastEmail', email);
      } else {
        await prefs.remove('rememberMe');
        await prefs.remove('lastEmail');
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
  //  Connexion Google
  // ─────────────────────────────────────────────────────────────
  Future<bool> signInWithGoogle() async {
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
            print('❌ Compte Google désactivé pour ${_user!.email}');
            await _auth.signOut();
            _user = null;
            _setError(AppLocalizations.get('account_deactivated_error'));
            notifyListeners();
            return false;
          }
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
  //  Mot de passe oublié
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
  //  Déconnexion
  // ─────────────────────────────────────────────────────────────
  Future<void> signOut({bool forceSignOut = false}) async {
    try {
      _setLoading(true);
      _clearError();

      final prefs = await SharedPreferences.getInstance();
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
  //  Mise à jour profil
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
        phoneNumber: phoneNumber, countryCode: countryCode, photoUrl: photoUrl,
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
  //  Suppression compte
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
  //  Helpers privés
  // ─────────────────────────────────────────────────────────────
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
    final isEmailVerificationError = error.contains('vérifier votre email');
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
  //  Validation
  // ─────────────────────────────────────────────────────────────
  bool isValidEmail(String email) =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

  String? validatePassword(String password) {
    if (password.length < 6) return 'Le mot de passe doit contenir au moins 6 caractères';
    if (!password.contains(RegExp(r'[A-Z]'))) return 'Le mot de passe doit contenir au moins une majuscule';
    if (!password.contains(RegExp(r'[0-9]'))) return 'Le mot de passe doit contenir au moins un chiffre';
    return null;
  }

  bool isValidPhoneNumber(String phone) =>
      RegExp(r'^[+]?[0-9]{10,15}$').hasMatch(phone.replaceAll(' ', ''));
}
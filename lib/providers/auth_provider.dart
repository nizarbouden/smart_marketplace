import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firebase_auth_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();
  
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isGuest => _user == null;
  
  // Getters pour les informations utilisateur
  String? get nom => _user?.nom;
  String? get prenom => _user?.prenom;
  String? get genre => _user?.genre;
  String? get countryCode => _user?.countryCode;
  String? get fullName => _user != null ? '${_user!.prenom} ${_user!.nom}' : null;
  int get points => _user?.points ?? 0;
  List<String> get favorites => _user?.favoris ?? [];
  List<String> get orders => _user?.commandes ?? [];

  // Constructeur - écouter les changements d'état
  AuthProvider() {
    _authService.authStateChanges.listen((User? firebaseUser) {
      if (firebaseUser != null) {
        _loadUserData();
      } else {
        _user = null;
        notifyListeners();
      }
    });
  }

  // Charger les données utilisateur
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

  // Inscription avec email/mot de passe
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
        email,
        password,
        nom,
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

  // Connexion avec email/mot de passe
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('🔄 AuthProvider: Début de la connexion pour $email');
      _setLoading(true);
      _clearError();
      
      print('🔄 AuthProvider: Appel de signInWithEmailAndPassword');
      _user = await _authService.signInWithEmailAndPassword(email, password);
      print('🔄 AuthProvider: UserModel reçu: ${_user?.email}');
      
      notifyListeners();
      print('✅ AuthProvider: Connexion réussie, retour true');
      return true;
    } catch (e) {
      print('❌ AuthProvider: Erreur lors de la connexion: $e');
      _setError(e.toString());
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Connexion avec Google
  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);
      _clearError();
      
      _user = await _authService.signInWithGoogle();
      
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

  // Mot de passe oublié
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

  // Rafraîchir les données utilisateur
  Future<void> refreshUserProfile() async {
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

  // Déconnexion
  Future<void> signOut() async {
    try {
      _setLoading(true);
      _clearError();
      
      await _authService.signOut();
      _user = null;
      
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // Mettre à jour le profil
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
        nom: nom,
        prenom: prenom,
        genre: genre,
        phoneNumber: phoneNumber,
        countryCode: countryCode,
        photoUrl: photoUrl,
      );
      
      // Recharger les données utilisateur
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

  // Supprimer le compte
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

  // Rafraîchir les données utilisateur
  Future<void> refreshUserData() async {
    await _loadUserData();
  }

  // Ajouter un produit favori
  Future<bool> addFavorite(String productId) async {
    try {
      _setLoading(true);
      _clearError();
      
      await _authService.addFavorite(productId);
      
      // Recharger les données utilisateur pour mettre à jour les favoris
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

  // Supprimer un produit favori
  Future<bool> removeFavorite(String productId) async {
    try {
      _setLoading(true);
      _clearError();
      
      await _authService.removeFavorite(productId);
      
      // Recharger les données utilisateur pour mettre à jour les favoris
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

  // Ajouter une commande
  Future<bool> addOrder(String orderId) async {
    try {
      _setLoading(true);
      _clearError();
      
      await _authService.addOrder(orderId);
      
      // Recharger les données utilisateur pour mettre à jour les commandes
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

  // Méthodes privées pour gérer l'état
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
    
    // Effacer automatiquement l'erreur après 5 secondes
    Future.delayed(const Duration(seconds: 5), () {
      _clearError();
    });
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Vérifier si l'email est valide
  bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Vérifier si le mot de passe est valide
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

  // Vérifier si le numéro de téléphone est valide
  bool isValidPhoneNumber(String phone) {
    return RegExp(r'^[+]?[0-9]{10,15}$').hasMatch(phone.replaceAll(' ', ''));
  }
}

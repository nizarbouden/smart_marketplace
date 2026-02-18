import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    _checkAndForceSignOut();
    _authService.authStateChanges.listen((User? firebaseUser) {
      if (firebaseUser != null) {
        _loadUserData();
      } else {
        _user = null;
        notifyListeners();
      }
    });
  }

  // Vérifier et forcer la déconnexion au démarrage si nécessaire
  Future<void> _checkAndForceSignOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool rememberMe = prefs.getBool('rememberMe') ?? false;
      
      // Si "se souvenir de moi" n'est pas coché et qu'il y a un utilisateur Firebase connecté
      if (!rememberMe && _auth.currentUser != null) {
        print('🔄 AuthProvider: "Se souvenir de moi" non coché, déconnexion forcée au démarrage');
        await _auth.signOut();
        await prefs.remove('rememberMe');
        await prefs.remove('lastEmail');
      }
    } catch (e) {
      print('❌ AuthProvider: Erreur lors de la vérification au démarrage: $e');
    }
  }

  // Vérifier l'état de connexion au démarrage
  Future<void> checkConnectionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool rememberMe = prefs.getBool('rememberMe') ?? false;
      
      // Si "se souvenir de moi" n'est pas coché et qu'il y a un utilisateur Firebase connecté
      if (!rememberMe && _auth.currentUser != null) {
        print('🔄 AuthProvider: Déconnexion automatique - "Se souvenir de moi" non coché');
        await _auth.signOut();
        await prefs.remove('rememberMe');
        await prefs.remove('lastEmail');
        _user = null;
        notifyListeners();
      }
    } catch (e) {
      print('❌ AuthProvider: Erreur lors de la vérification de l\'état de connexion: $e');
    }
  }

  // Charger les préférences au démarrage
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool rememberMe = prefs.getBool('rememberMe') ?? false;
      String? lastEmail = prefs.getString('lastEmail');
      
      print('🔄 AuthProvider: Préférences chargées - rememberMe: $rememberMe, lastEmail: $lastEmail');
      
      // Si "se souvenir de moi" est activé et qu'il y a un email sauvegardé
      if (rememberMe && lastEmail != null) {
        // Ne pas se reconnecter automatiquement, juste pré-remplir le formulaire
        print('✅ AuthProvider: Préférences "se souvenir de moi" trouvées pour $lastEmail');
      }
    } catch (e) {
      print('❌ AuthProvider: Erreur lors du chargement des préférences: $e');
    }
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

  // Rafraîchir explicitement les données utilisateur
  Future<void> refreshUserProfile() async {
    print('🔄 AuthProvider: Rafraîchissement des données utilisateur...');
    await _loadUserData();
    print('✅ AuthProvider: Données rafraîchies');
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
    bool rememberMe = false,
  }) async {
    try {
      print('🔄 AuthProvider: Début de la connexion pour $email (rememberMe: $rememberMe)');
      _setLoading(true);
      _clearError();
      
      // Vérifier si le compte est désactivé avant de permettre la connexion
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase().trim())
          .limit(1)
          .get();
      
      if (userDoc.docs.isNotEmpty) {
        final userData = userDoc.docs.first.data() as Map<String, dynamic>;
        final status = userData['status'] as String? ?? 'active';
        
        if (status == 'deactivated') {
          print('❌ AuthProvider: Compte désactivé, connexion refusée pour $email');
          _setError('Ce compte a été désactivé et sera supprimé dans 30 jours.');
          notifyListeners();
          return false;
        }
      }
      
      print('🔄 AuthProvider: Appel de signInWithEmailAndPassword');
      _user = await _authService.signInWithEmailAndPassword(email, password);
      print('🔄 AuthProvider: UserModel reçu: ${_user?.email}');
      
      // Sauvegarder la préférence "se souvenir de moi"
      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setBool('rememberMe', true);
        await prefs.setString('lastEmail', email);
        print('✅ AuthProvider: Préférence rememberMe sauvegardée');
      } else {
        await prefs.remove('rememberMe');
        await prefs.remove('lastEmail');
        print('✅ AuthProvider: Préférence rememberMe supprimée');
      }
      
      notifyListeners();
      print('✅ AuthProvider: Connexion réussie, retour true');
      return true;
    } on EmailNotVerifiedException catch (e) {
      print('🔄 AuthProvider: EmailNotVerifiedException capturée: ${e.toString()}');
      _setError(e.toString());
      notifyListeners();
      return false;
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
      
      // Vérifier si le compte est désactivé après connexion Google
      if (_user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: _user!.email.toLowerCase().trim())
            .limit(1)
            .get();
        
        if (userDoc.docs.isNotEmpty) {
          final userData = userDoc.docs.first.data() as Map<String, dynamic>;
          final status = userData['status'] as String? ?? 'active';
          
          if (status == 'deactivated') {
            print('❌ AuthProvider: Compte Google désactivé, déconnexion forcée pour ${_user!.email}');
            await _auth.signOut();
            _user = null;
            _setError('Ce compte a été désactivé et sera supprimé dans 30 jours.');
            notifyListeners();
            return false;
          }
        }
      }
      
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

  // Déconnexion
  Future<void> signOut({bool forceSignOut = false}) async {
    try {
      _setLoading(true);
      _clearError();
      
      // Vérifier si "se souvenir de moi" était activé
      final prefs = await SharedPreferences.getInstance();
      bool rememberMe = prefs.getBool('rememberMe') ?? false;
      
      if (!rememberMe || forceSignOut) {
        // Si "se souvenir de moi" n'était pas coché, forcer la déconnexion Firebase
        await _authService.signOut();
        await prefs.remove('rememberMe');
        await prefs.remove('lastEmail');
        print('✅ AuthProvider: Déconnexion forcée et préférences effacées');
      } else {
        await _authService.signOut();
        print('✅ AuthProvider: Déconnexion normale (rememberMe activé)');
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
    
    // Ne pas effacer automatiquement les erreurs de vérification email
    bool isEmailVerificationError = error.contains('vérifier votre email');
    if (!isEmailVerificationError) {
      // Effacer automatiquement l'erreur après 5 secondes seulement pour les autres erreurs
      Future.delayed(const Duration(seconds: 5), () {
        _clearError();
      });
    }
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Méthode publique pour effacer l'erreur
  void clearError() {
    _clearError();
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

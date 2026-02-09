import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream pour écouter les changements d'état de l'utilisateur
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Utilisateur courant
  User? get currentUser => _auth.currentUser;

  // Vérifier si l'utilisateur est connecté
  bool get isSignedIn => _auth.currentUser != null;

  // INSCRIPTION EMAIL/MOT DE PASSE
  Future<UserModel?> signUpWithEmailAndPassword(
    String email,
    String password,
    String fullName,
    String phoneNumber,
  ) async {
    try {
      // Créer l'utilisateur dans Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;

      if (user != null) {
        // Créer le profil utilisateur dans Firestore
        UserModel userModel = UserModel(
          uid: user.uid,
          email: email,
          fullName: fullName,
          phoneNumber: phoneNumber,
          createdAt: DateTime.now(),
          isActive: true,
        );

        await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
        
        return userModel;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _getErrorMessage(e);
    } catch (e) {
      throw 'Une erreur est survenue lors de l\'inscription';
    }
  }

  // CONNEXION EMAIL/MOT DE PASSE
  Future<UserModel?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;

      if (user != null) {
        // Récupérer les données utilisateur depuis Firestore
        DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
        
        if (doc.exists) {
          return UserModel.fromMap(doc.data() as Map<String, dynamic>);
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _getErrorMessage(e);
    } catch (e) {
      throw 'Une erreur est survenue lors de la connexion';
    }
  }

  // CONNEXION GOOGLE
  Future<UserModel?> signInWithGoogle() async {
    try {
      // Déconnexion de Google au cas où
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw 'Connexion Google annulée';
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        // Vérifier si l'utilisateur existe déjà dans Firestore
        DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
        
        if (doc.exists) {
          // Mettre à jour la dernière connexion
          await _firestore.collection('users').doc(user.uid).update({
            'lastLoginAt': DateTime.now(),
          });
          return UserModel.fromMap(doc.data() as Map<String, dynamic>);
        } else {
          // Créer un nouveau profil utilisateur
          UserModel userModel = UserModel(
            uid: user.uid,
            email: user.email ?? '',
            fullName: user.displayName ?? 'Utilisateur Google',
            phoneNumber: user.phoneNumber ?? '',
            photoUrl: user.photoURL,
            createdAt: DateTime.now(),
            isActive: true,
            isGoogleUser: true,
          );

          await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
          return userModel;
        }
      }
      return null;
    } catch (e) {
      throw 'Erreur lors de la connexion Google: $e';
    }
  }

  // MOT DE PASSE OUBLIÉ
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _getErrorMessage(e);
    } catch (e) {
      throw 'Une erreur est survenue lors de l\'envoi de l\'email de réinitialisation';
    }
  }

  // DÉCONNEXION
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw 'Erreur lors de la déconnexion';
    }
  }

  // METTRE À JOUR LE PROFIL
  Future<void> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? photoUrl,
  }) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        Map<String, dynamic> updateData = {};
        
        if (fullName != null) updateData['fullName'] = fullName;
        if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
        if (photoUrl != null) updateData['photoUrl'] = photoUrl;
        
        updateData['updatedAt'] = DateTime.now();

        await _firestore.collection('users').doc(user.uid).update(updateData);
      }
    } catch (e) {
      throw 'Erreur lors de la mise à jour du profil';
    }
  }

  // RÉCUPÉRER LE PROFIL UTILISATEUR
  Future<UserModel?> getUserProfile() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
        
        if (doc.exists) {
          return UserModel.fromMap(doc.data() as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      throw 'Erreur lors de la récupération du profil';
    }
  }

  // SUPPRIMER LE COMPTE
  Future<void> deleteAccount() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Supprimer les données de Firestore
        await _firestore.collection('users').doc(user.uid).delete();
        
        // Supprimer le compte Firebase Auth
        await user.delete();
      }
    } catch (e) {
      throw 'Erreur lors de la suppression du compte';
    }
  }

  // GESTION DES ERREURS
  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Le mot de passe est trop faible (minimum 6 caractères)';
      case 'email-already-in-use':
        return 'Cette adresse email est déjà utilisée';
      case 'user-not-found':
        return 'Aucun utilisateur trouvé avec cette adresse email';
      case 'wrong-password':
        return 'Mot de passe incorrect';
      case 'invalid-email':
        return 'Adresse email invalide';
      case 'user-disabled':
        return 'Ce compte a été désactivé';
      case 'too-many-requests':
        return 'Trop de tentatives de connexion. Veuillez réessayer plus tard';
      case 'operation-not-allowed':
        return 'Cette méthode de connexion n\'est pas autorisée';
      default:
        return 'Une erreur est survenue: ${e.message}';
    }
  }
}

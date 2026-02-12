import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    String nom, {
    String prenom = '',
    String? genre,
    String? countryCode,
    String? phoneNumber,
  }) async {
    try {
      print('🔐 Tentative d\'inscription pour: $email');
      
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      print('✅ Utilisateur Firebase créé: ${user?.uid}');

      if (user != null) {
        UserModel userModel = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          nom: nom,
          prenom: prenom,
          genre: genre,
          phoneNumber: phoneNumber ?? '',
          countryCode: countryCode,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          isActive: true,
        );

        print('💾 Écriture du profil dans Firestore...');
        await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
        print('✅ Profil créé avec succès dans Firestore');
        
        return userModel;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      print('❌ Erreur Firebase Auth: ${e.code} - ${e.message}');
      throw _getErrorMessage(e);
    } catch (e) {
      print('❌ Erreur générale lors de l\'inscription: $e');
      throw 'Une erreur est survenue lors de l\'inscription';
    }
  }

  // CONNEXION EMAIL/MOT DE PASSE
  Future<UserModel?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    User? user; // Déclarer user ici pour l'accessibilité
    
    try {
      print('🔐 Tentative de connexion pour: $email');
      
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      user = result.user; // Assigner ici
      print('✅ Utilisateur Firebase authentifié: ${user?.uid}');

      if (user != null) {
        try {
          // Récupérer les données utilisateur depuis Firestore
          print('🔍 Vérification de l\'utilisateur dans Firestore...');
          DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
          
          if (doc.exists) {
            print('✅ Utilisateur trouvé dans Firestore');
            // Mettre à jour la dernière connexion
            await _firestore.collection('users').doc(user.uid).update({
              'lastLoginAt': Timestamp.fromDate(DateTime.now()),
            });
            
            // Utiliser UserModel.fromMap avec gestion d'erreur
            try {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              return UserModel.fromMap(data);
            } catch (mapError) {
              print('⚠️ Erreur UserModel.fromMap, création manuelle: $mapError');
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              return UserModel(
                uid: user.uid,
                email: data['email'] ?? user.email ?? '',
                nom: data['nom'] ?? 'Utilisateur',
                prenom: data['prenom'] ?? '',
                genre: data['genre'],
                phoneNumber: data['phoneNumber'] ?? '',
                countryCode: data['countryCode'],
                createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                lastLoginAt: DateTime.now(),
                isActive: data['isActive'] ?? true,
              );
            }
          } else {
            print('🆕 Utilisateur non trouvé dans Firestore, création du profil...');
            // Créer un profil utilisateur par défaut s'il n'existe pas
            UserModel userModel = UserModel(
              uid: user.uid,
              email: user.email ?? '',
              nom: 'Utilisateur',
              prenom: '',
              genre: null,
              phoneNumber: '',
              countryCode: null,
              createdAt: DateTime.now(),
              lastLoginAt: DateTime.now(),
              isActive: true,
            );

            print('💾 Écriture du profil dans Firestore...');
            await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
            print('✅ Profil créé avec succès dans Firestore');
            
            return userModel;
          }
        } catch (firestoreError) {
          print('⚠️ Erreur Firestore, mais utilisateur Firebase connecté: $firestoreError');
          // Retourner un UserModel basique même si Firestore échoue
          return UserModel(
            uid: user.uid,
            email: user.email ?? '',
            nom: 'Utilisateur',
            prenom: '',
            genre: null,
            phoneNumber: '',
            countryCode: null,
            createdAt: DateTime.now(),
            lastLoginAt: DateTime.now(),
            isActive: true,
          );
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      print('❌ Erreur Firebase Auth: ${e.code} - ${e.message}');
      throw _getErrorMessage(e);
    } catch (e) {
      print('❌ Erreur générale lors de la connexion: $e');
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
        try {
          // Vérifier si l'utilisateur existe déjà dans Firestore
          DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
          
          if (doc.exists) {
            // Mettre à jour la dernière connexion
            await _firestore.collection('users').doc(user.uid).update({
              'lastLoginAt': Timestamp.fromDate(DateTime.now()),
            });
            
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            return UserModel(
              uid: user.uid,
              email: data['email'] ?? user.email ?? '',
              nom: data['nom'] ?? user.displayName?.split(' ').last ?? 'Utilisateur',
              prenom: data['prenom'] ?? user.displayName?.split(' ').first ?? '',
              genre: data['genre'],
              phoneNumber: data['phoneNumber'] ?? '',
              countryCode: data['countryCode'],
              createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              lastLoginAt: DateTime.now(),
              isActive: data['isActive'] ?? true,
            );
          } else {
            // Créer un nouveau profil utilisateur
            String displayName = user.displayName ?? 'Utilisateur Google';
            List<String> nameParts = displayName.split(' ');
            String firstName = nameParts.isNotEmpty ? nameParts.first : '';
            String lastName = nameParts.length > 1 ? nameParts.last : nameParts.first;
            
            UserModel userModel = UserModel(
              uid: user.uid,
              email: user.email ?? '',
              nom: lastName,
              prenom: firstName,
              genre: null,
              phoneNumber: user.phoneNumber ?? '',
              countryCode: null,
              photoUrl: user.photoURL,
              createdAt: DateTime.now(),
              lastLoginAt: DateTime.now(),
              isActive: true,
              isGoogleUser: true,
            );

            await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
            return userModel;
          }
        } catch (firestoreError) {
          print('⚠️ Erreur Firestore Google, mais utilisateur Firebase connecté: $firestoreError');
          // Fallback basique même si Firestore échoue
          String displayName = user.displayName ?? 'Utilisateur Google';
          List<String> nameParts = displayName.split(' ');
          String firstName = nameParts.isNotEmpty ? nameParts.first : '';
          String lastName = nameParts.length > 1 ? nameParts.last : nameParts.first;
          
          return UserModel(
            uid: user.uid,
            email: user.email ?? '',
            nom: lastName,
            prenom: firstName,
            genre: null,
            phoneNumber: user.phoneNumber ?? '',
            countryCode: null,
            photoUrl: user.photoURL,
            createdAt: DateTime.now(),
            lastLoginAt: DateTime.now(),
            isActive: true,
            isGoogleUser: true,
          );
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      print('❌ Erreur Firebase Auth Google: ${e.code} - ${e.message}');
      throw _getErrorMessage(e);
    } catch (e) {
      print('❌ Erreur générale Google Sign-In: $e');
      throw 'Erreur lors de la connexion Google';
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
    String? nom,
    String? prenom,
    String? genre,
    String? phoneNumber,
    String? countryCode,
    String? photoUrl,
  }) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        Map<String, dynamic> updateData = {};
        
        if (nom != null) updateData['nom'] = nom;
        if (prenom != null) updateData['prenom'] = prenom;
        if (genre != null) updateData['genre'] = genre;
        if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
        if (countryCode != null) updateData['countryCode'] = countryCode;
        if (photoUrl != null) updateData['photoUrl'] = photoUrl;
        
        updateData['updatedAt'] = Timestamp.fromDate(DateTime.now());

        await _firestore.collection('users').doc(user.uid).update(updateData);
      }
    } catch (e) {
      throw 'Erreur lors de la mise à jour du profil';
    }
  }

  // Nettoyer le cache Firestore pour résoudre le crash SQLiteBlobTooBigException
  Future<void> clearFirestoreCache() async {
    try {
      await _firestore.clearPersistence();
      print('✅ Cache Firestore nettoyé avec succès');
    } catch (e) {
      print('⚠️ Erreur lors du nettoyage du cache Firestore: $e');
    }
  }

  // RÉCUPÉRER LE PROFIL UTILISATEUR
  Future<UserModel?> getUserProfile() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
        
        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return UserModel(
            uid: user.uid,
            email: data['email'] ?? user.email ?? '',
            nom: data['nom'] ?? 'Utilisateur',
            prenom: data['prenom'] ?? '',
            genre: data['genre'],
            phoneNumber: data['phoneNumber'] ?? '',
            countryCode: data['countryCode'],
            photoUrl: data['photoUrl'],
            createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            isActive: data['isActive'] ?? true,
            favoris: List<String>.from(data['favoris'] ?? []),
            commandes: List<String>.from(data['commandes'] ?? []),
            preferences: Map<String, dynamic>.from(data['preferences'] ?? {}),
            points: data['points'] ?? 0,
          );
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

  // AJOUTER UN PRODUIT FAVORI
  Future<void> addFavorite(String productId) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'favoris': FieldValue.arrayUnion([productId])
        });
      }
    } catch (e) {
      throw 'Erreur lors de l\'ajout aux favoris';
    }
  }

  // SUPPRIMER UN PRODUIT FAVORI
  Future<void> removeFavorite(String productId) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'favoris': FieldValue.arrayRemove([productId])
        });
      }
    } catch (e) {
      throw 'Erreur lors de la suppression des favoris';
    }
  }

  // AJOUTER UNE COMMANDE
  Future<void> addOrder(String orderId) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'commandes': FieldValue.arrayUnion([orderId])
        });
      }
    } catch (e) {
      throw 'Erreur lors de l\'ajout de la commande';
    }
  }

  // RÉCUPÉRER LES FAVORIS
  Future<List<String>> getFavorites() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return List<String>.from(data['favoris'] ?? []);
        }
      }
      return [];
    } catch (e) {
      throw 'Erreur lors de la récupération des favoris';
    }
  }

  // RÉCUPÉRER LES COMMANDES
  Future<List<String>> getOrders() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return List<String>.from(data['commandes'] ?? []);
        }
      }
      return [];
    } catch (e) {
      throw 'Erreur lors de la récupération des commandes';
    }
  }

  // GESTION DES ERREURS
  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Le mot de passe est trop faible (minimum 8 caractères)';
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

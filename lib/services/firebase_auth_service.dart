import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

// Exception personnalisée pour la vérification email
class EmailNotVerifiedException implements Exception {
  final String message;
  EmailNotVerifiedException(this.message);
  
  @override
  String toString() => message;
}

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
        // Envoyer l'email de vérification AVANT de créer le profil
        await user.sendEmailVerification();
        print('📧 Email de vérification envoyé à: $email');
        
        // Créer le profil mais marqué comme non vérifié
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
          isActive: false, // Inactif tant que non vérifié
        );

        print('💾 Écriture du profil dans Firestore (non vérifié)...');
        await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
        print('✅ Profil créé avec succès dans Firestore (en attente de vérification)');
        
        // Lancer une exception personnalisée pour rediriger vers la connexion
        throw 'Inscription réussie ! Veuillez vérifier votre email avant de vous connecter. Un email de vérification a été envoyé à $email.';
      }
      return null;
    } on FirebaseAuthException catch (e) {
      print('❌ Erreur Firebase Auth: ${e.code} - ${e.message}');
      throw _getErrorMessage(e);
    } catch (e) {
      // Si c'est notre message personnalisé, le relancer directement
      if (e.toString().contains('Inscription réussie')) {
        rethrow;
      }
      print('❌ Erreur générale lors de l\'inscription: $e');
      throw 'Une erreur est survenue lors de l\'inscription';
    }
  }

  // VÉRIFIER SI L'EMAIL A ÉTÉ VÉRIFIÉ ET ACTIVER LE COMPTE
  Future<UserModel?> checkEmailVerificationAndActivate() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        print('🔍 Vérification du statut de l\'email pour: ${user.email}');
        
        // Recharger l'utilisateur pour obtenir le statut de vérification actualisé
        await user.reload();
        user = _auth.currentUser;
        
        if (user != null && user.emailVerified) {
          print('✅ Email vérifié ! Activation du compte...');
          
          // Mettre à jour le profil dans Firestore pour activer le compte
          await _firestore.collection('users').doc(user.uid).update({
            'isActive': true,
            'emailVerified': true,
            'verifiedAt': Timestamp.fromDate(DateTime.now()),
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
          
          print('✅ Compte activé avec succès');
          
          // Récupérer le profil mis à jour
          DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
          if (doc.exists) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            return UserModel(
              uid: user.uid,
              email: user.email ?? data['email'] ?? '',
              nom: data['nom'] ?? 'Utilisateur',
              prenom: data['prenom'] ?? '',
              genre: data['genre'],
              phoneNumber: data['phoneNumber'] ?? '',
              countryCode: data['countryCode'],
              photoUrl: data['photoUrl'],
              createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              lastLoginAt: DateTime.now(),
              isActive: true,
              isEmailVerified: true,
            );
          }
        } else {
          print('⏳ Email non encore vérifié');
          return null;
        }
      }
      return null;
    } catch (e) {
      print('❌ Erreur lors de la vérification de l\'email: $e');
      throw 'Erreur lors de la vérification de l\'email';
    }
  }

  // RENVOYER L'EMAIL DE VÉRIFICATION
  Future<void> resendEmailVerification() async {
    try {
      User? user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        print('📧 Email de vérification renvoyé à: ${user.email}');
      } else {
        throw 'Aucun utilisateur connecté ou email déjà vérifié';
      }
    } catch (e) {
      print('❌ Erreur lors de l\'envoi de l\'email de vérification: $e');
      throw 'Erreur lors de l\'envoi de l\'email de vérification';
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
        // Vérifier si l'email est vérifié
        if (!user.emailVerified) {
          print('❌ Email non vérifié pour: ${user.email}');
          await _auth.signOut(); // Déconnecter l'utilisateur
          
          // Créer une exception personnalisée pour le message de vérification email
          throw EmailNotVerifiedException(
            'Veuillez vérifier votre email avant de vous connecter. Consultez votre boîte de réception et cliquez sur le lien de vérification.'
          );
        }

        try {
          // Récupérer les données utilisateur depuis Firestore
          print('🔍 Vérification de l\'utilisateur dans Firestore...');
          DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
          
          if (doc.exists) {
            print('✅ Utilisateur trouvé dans Firestore');
            // Mettre à jour la dernière connexion
            await _firestore.collection('users').doc(user.uid).update({
              'lastLoginAt': Timestamp.fromDate(DateTime.now()),
              'email': user.email, // Synchroniser l'email depuis Firebase Auth
            });
            
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            return UserModel(
              uid: user.uid,
              email: user.email ?? data['email'] ?? '', // Priorité à Firebase Auth
              nom: data['nom'] ?? 'Utilisateur',
              prenom: data['prenom'] ?? '',
              genre: data['genre'],
              phoneNumber: data['phoneNumber'] ?? '',
              countryCode: data['countryCode'],
              createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              lastLoginAt: DateTime.now(),
              isActive: data['isActive'] ?? true,
              isEmailVerified: true, // L'email est vérifié à ce stade
            );
          } else {
            print('🆕 Utilisateur non trouvé dans Firestore, création du profil...');
            // Créer un profil utilisateur par défaut s'il n'existe pas
            UserModel userModel = UserModel(
              uid: user.uid,
              email: user.email ?? '', // Email depuis Firebase Auth
              nom: 'Utilisateur',
              prenom: '',
              genre: null,
              phoneNumber: '',
              countryCode: null,
              createdAt: DateTime.now(),
              lastLoginAt: DateTime.now(),
              isActive: true,
              isEmailVerified: true,
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
            isEmailVerified: true,
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

  // SYNCHRONISER L'EMAIL DEPUIS FIREBASE AUTH
  Future<void> syncEmailFromAuth() async {
    try {
      User? user = _auth.currentUser;
      if (user != null && user.email != null) {
        print('🔄 Synchronisation de l\'email depuis Firebase Auth: ${user.email}');
        
        // Mettre à jour l'email dans Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'email': user.email,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
        
        print('✅ Email synchronisé avec succès');
      }
    } catch (e) {
      print('❌ Erreur lors de la synchronisation de l\'email: $e');
    }
  }

  // RÉCUPÉRER L'EMAIL ACTUEL DEPUIS FIREBASE AUTH
  String? getCurrentEmail() {
    return _auth.currentUser?.email;
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
        print('🔧 Mise à jour du profil pour: ${user.uid}');
        
        Map<String, dynamic> updateData = {};
        
        if (nom != null) updateData['nom'] = nom;
        if (prenom != null) updateData['prenom'] = prenom;
        if (genre != null) updateData['genre'] = genre;
        if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
        if (countryCode != null) updateData['countryCode'] = countryCode;
        if (photoUrl != null) updateData['photoUrl'] = photoUrl;
        
        // NE PAS synchroniser l'email - il ne doit pas être modifiable ici
        // L'email est géré uniquement par Firebase Auth
        
        updateData['updatedAt'] = Timestamp.fromDate(DateTime.now());

        print('📝 Données à mettre à jour: $updateData');
        
        // Vérifier si le document existe
        DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
        
        if (doc.exists) {
          // Mettre à jour le document existant
          await _firestore.collection('users').doc(user.uid).update(updateData);
          print('✅ Profil mis à jour avec succès');
        } else {
          // Créer le document s'il n'existe pas
          print('📄 Document non trouvé, création du profil utilisateur...');
          
          Map<String, dynamic> newUserData = {
            'uid': user.uid,
            'email': user.email, // Email depuis Firebase Auth uniquement
            'nom': nom ?? 'Utilisateur',
            'prenom': prenom ?? '',
            'genre': genre,
            'phoneNumber': phoneNumber ?? '',
            'countryCode': countryCode ?? '+216',
            'photoUrl': photoUrl,
            'createdAt': Timestamp.fromDate(DateTime.now()),
            'updatedAt': Timestamp.fromDate(DateTime.now()),
            'isActive': true,
            'isGoogleUser': false,
            'points': 0,
          };
          
          await _firestore.collection('users').doc(user.uid).set(newUserData);
          print('✅ Profil utilisateur créé avec succès');
        }
      } else {
        throw 'Aucun utilisateur connecté';
      }
    } catch (e) {
      print('❌ Erreur détaillée lors de la mise à jour du profil: $e');
      throw 'Erreur lors de la mise à jour du profil: $e';
    }
  }

  // AJOUTER UNE ADRESSE
  Future<String> addAddress({
    required String contactName,
    required String phone,
    required String countryCode,
    required String countryName,
    required String countryFlag,
    required String street,
    required String complement,
    required String province,
    required String city,
    required String postalCode,
    required bool isDefault,
  }) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Créer un ID unique pour l'adresse
        String addressId = _firestore.collection('users').doc(user.uid).collection('addresses').doc().id;
        
        Map<String, dynamic> addressData = {
          'id': addressId,
          'contactName': contactName,
          'phone': phone,
          'countryCode': countryCode,
          'countryName': countryName,
          'countryFlag': countryFlag,
          'street': street,
          'complement': complement,
          'province': province,
          'city': city,
          'postalCode': postalCode,
          'isDefault': isDefault,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        };

        await _firestore.collection('users').doc(user.uid).collection('addresses').doc(addressId).set(addressData);
        
        // Si c'est l'adresse par défaut, mettre à jour les autres adresses
        if (isDefault) {
          await _updateOtherAddressesAsNonDefault(user.uid, addressId);
        }
        
        return addressId;
      }
      throw 'Utilisateur non connecté';
    } catch (e) {
      print('❌ Erreur lors de l\'ajout de l\'adresse: $e');
      throw 'Erreur lors de l\'ajout de l\'adresse';
    }
  }

  // Mettre à jour les autres adresses comme non par défaut
  Future<void> _updateOtherAddressesAsNonDefault(String userId, String defaultAddressId) async {
    try {
      QuerySnapshot addresses = await _firestore.collection('users').doc(userId).collection('addresses').get();
      
      for (DocumentSnapshot doc in addresses.docs) {
        if (doc.id != defaultAddressId) {
          await _firestore.collection('users').doc(userId).collection('addresses').doc(doc.id).update({
            'isDefault': false,
          });
        }
      }
    } catch (e) {
      print('⚠️ Erreur lors de la mise à jour des adresses par défaut: $e');
    }
  }

  // RÉCUPÉRER TOUTES LES ADRESSES
  Future<List<Map<String, dynamic>>> getUserAddresses() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        QuerySnapshot addresses = await _firestore.collection('users').doc(user.uid).collection('addresses').get();
        
        List<Map<String, dynamic>> addressList = [];
        for (DocumentSnapshot doc in addresses.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          addressList.add(data);
        }
        
        // Trier les adresses : par défaut en premier, puis par date de création
        addressList.sort((a, b) {
          // Si une adresse est par défaut et l'autre non, la par défaut vient en premier
          if (a['isDefault'] == true && b['isDefault'] != true) return -1;
          if (a['isDefault'] != true && b['isDefault'] == true) return 1;
          
          // Sinon, trier par date de création (plus récent en premier)
          Timestamp aTime = a['createdAt'] as Timestamp;
          Timestamp bTime = b['createdAt'] as Timestamp;
          return bTime.compareTo(aTime);
        });
        
        return addressList;
      }
      return [];
    } catch (e) {
      print('❌ Erreur lors de la récupération des adresses: $e');
      return [];
    }
  }

  // DÉFINIR UNE ADRESSE PAR DÉFAUT
  Future<void> setDefaultAddress(String userId, String addressId) async {
    try {
      // Récupérer toutes les adresses de l'utilisateur
      QuerySnapshot addresses = await _firestore.collection('users').doc(userId).collection('addresses').get();
      
      // Mettre toutes les adresses à non par défaut
      for (DocumentSnapshot doc in addresses.docs) {
        await _firestore.collection('users').doc(userId).collection('addresses').doc(doc.id).update({
          'isDefault': false,
        });
      }
      
      // Mettre l'adresse sélectionnée à par défaut
      await _firestore.collection('users').doc(userId).collection('addresses').doc(addressId).update({
        'isDefault': true,
      });
      
    } catch (e) {
      print('❌ Erreur lors de la définition de l\'adresse par défaut: $e');
      throw 'Erreur lors de la définition de l\'adresse par défaut';
    }
  }

  // MODIFIER UNE ADRESSE
  Future<void> updateAddress({
    required String userId,
    required String addressId,
    required String contactName,
    required String phone,
    required String countryCode,
    required String countryName,
    required String countryFlag,
    required String street,
    required String complement,
    required String province,
    required String city,
    required String postalCode,
    required bool isDefault,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'contactName': contactName,
        'phone': phone,
        'countryCode': countryCode,
        'countryName': countryName,
        'countryFlag': countryFlag,
        'street': street,
        'complement': complement,
        'province': province,
        'city': city,
        'postalCode': postalCode,
        'isDefault': isDefault,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      await _firestore.collection('users').doc(userId).collection('addresses').doc(addressId).update(updateData);
      
      // Si c'est l'adresse par défaut, mettre à jour les autres adresses
      if (isDefault) {
        await _updateOtherAddressesAsNonDefault(userId, addressId);
      }
      
    } catch (e) {
      print('❌ Erreur lors de la modification de l\'adresse: $e');
      throw 'Erreur lors de la modification de l\'adresse';
    }
  }

  // SUPPRIMER UNE ADRESSE
  Future<void> deleteAddress(String userId, String addressId) async {
    try {
      await _firestore.collection('users').doc(userId).collection('addresses').doc(addressId).delete();
    } catch (e) {
      print('❌ Erreur lors de la suppression de l\'adresse: $e');
      throw 'Erreur lors de la suppression de l\'adresse';
    }
  }

  // CRÉER UNE NOTIFICATION
  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      String notificationId = _firestore.collection('users').doc(userId).collection('notifications').doc().id;
      
      Map<String, dynamic> notificationData = {
        'id': notificationId,
        'title': title,
        'body': body,
        'type': type,
        'isRead': false,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'data': data ?? {},
      };

      await _firestore.collection('users').doc(userId).collection('notifications').doc(notificationId).set(notificationData);
    } catch (e) {
      print('❌ Erreur lors de la création de la notification: $e');
    }
  }

  // RÉCUPÉRER TOUTES LES NOTIFICATIONS
  Future<List<Map<String, dynamic>>> getUserNotifications() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        QuerySnapshot notifications = await _firestore.collection('users').doc(user.uid).collection('notifications').get();
        
        List<Map<String, dynamic>> notificationList = [];
        for (DocumentSnapshot doc in notifications.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          notificationList.add(data);
        }
        
        // Trier par date de création (plus récent en premier)
        notificationList.sort((a, b) {
          Timestamp aTime = a['createdAt'] as Timestamp;
          Timestamp bTime = b['createdAt'] as Timestamp;
          return bTime.compareTo(aTime);
        });
        
        return notificationList;
      }
      return [];
    } catch (e) {
      print('❌ Erreur lors de la récupération des notifications: $e');
      return [];
    }
  }

  // MARQUER UNE NOTIFICATION COMME LUE
  Future<void> markNotificationAsRead(String userId, String notificationId) async {
    try {
      await _firestore.collection('users').doc(userId).collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      print('❌ Erreur lors du marquage de la notification comme lue: $e');
    }
  }

  // SUPPRIMER TOUTES LES NOTIFICATIONS
  Future<void> deleteAllNotifications(String userId) async {
    try {
      QuerySnapshot notifications = await _firestore.collection('users').doc(userId).collection('notifications').get();
      
      for (DocumentSnapshot doc in notifications.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('❌ Erreur lors de la suppression de toutes les notifications: $e');
      throw 'Erreur lors de la suppression de toutes les notifications';
    }
  }

  // SUPPRIMER UNE NOTIFICATION SPÉCIFIQUE
  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _firestore.collection('users').doc(userId).collection('notifications').doc(notificationId).delete();
    } catch (e) {
      print('❌ Erreur lors de la suppression de la notification: $e');
      throw 'Erreur lors de la suppression de la notification';
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
            email: user.email ?? data['email'] ?? '', // Priorité à Firebase Auth
            nom: data['nom'] ?? 'Utilisateur',
            prenom: data['prenom'] ?? '',
            genre: data['genre'],
            phoneNumber: data['phoneNumber'] ?? '',
            countryCode: data['countryCode'],
            photoUrl: data['photoUrl'],
            createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            isActive: data['isActive'] ?? true,
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

  Future<String> uploadProfilePhoto(File imageFile) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) throw 'Aucun utilisateur connecté';

      print('📸 Upload de la photo de profil pour: ${user.uid}');

      // 1. Créer une référence unique avec timestamp pour éviter les conflits
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user.uid}_$timestamp.jpg');

      print('📁 Référence Storage: ${storageRef.fullPath}');

      // 2. Compresser légèrement l'image avant upload
      final bytes = await imageFile.readAsBytes();
      print('📊 Taille de l\'image: ${bytes.length} bytes');

      // 3. Upload avec métadonnées
      final uploadTask = storageRef.putData(
        bytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': user.uid,
            'uploadedAt': timestamp.toString(),
          },
        ),
      );

      print('⬆️ Début de l\'upload...');

      // 4. Attendre la fin de l'upload avec gestion des erreurs
      final snapshot = await uploadTask;
      print('✅ Photo uploadée : ${snapshot.bytesTransferred} bytes');

      // 5. Récupérer l'URL publique
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('🔗 URL de la photo: $downloadUrl');

      // 6. Mettre à jour Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'photoUrl': downloadUrl,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // 7. Mettre à jour Firebase Auth displayName/photoURL (optionnel)
      await user.updatePhotoURL(downloadUrl);

      print('✅ Photo de profil mise à jour avec succès');
      return downloadUrl;
    } on FirebaseException catch (e) {
      print('❌ Erreur Firebase Storage: ${e.code} - ${e.message}');
      throw 'Erreur lors de l\'upload de la photo: ${e.message}';
    } catch (e) {
      print('❌ Erreur lors de l\'upload de la photo: $e');
      throw 'Erreur lors de l\'upload de la photo de profil';
    }
  }

  Future<String> getUserRole() async {
    try {
      final uid = currentUser?.uid; // currentUser est déjà dans FirebaseAuthService
      if (uid == null) return 'buyer';

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      return (doc.data()?['role'] as String?) == 'seller' ? 'seller' : 'buyer';
    } catch (e) {
      return 'buyer';
    }
  }

  // ── SUPPRIMER L'ANCIENNE PHOTO ────────────────────────────────
  Future<void> deleteProfilePhoto() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      // Supprimer depuis Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user.uid}.jpg');

      await storageRef.delete();

      // Mettre à jour Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'photoUrl': FieldValue.delete(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Mettre à jour Firebase Auth
      await user.updatePhotoURL(null);

      print('✅ Photo de profil supprimée');
    } catch (e) {
      print('⚠️ Erreur suppression photo (peut-être inexistante): $e');
    }
  }

  // GESTION DES ERREURS
  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Le mot de passe est trop faible (minimum 6 caractères)';
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé par un autre compte';
      case 'invalid-email':
        return 'L\'adresse email n\'est pas valide';
      case 'user-not-found':
        return 'Aucun utilisateur trouvé avec cet email';
      case 'wrong-password':
        return 'Mot de passe incorrect';
      case 'user-disabled':
        return 'Ce compte a été désactivé';
      case 'too-many-requests':
        return 'Trop de tentatives de connexion. Veuillez réessayer plus tard';
      case 'operation-not-allowed':
        return 'Cette opération n\'est pas autorisée';
      case 'network-request-failed':
        return 'Erreur réseau. Vérifiez votre connexion internet';
      case 'email-not-verified':
        return 'Veuillez vérifier votre email avant de vous connecter. Consultez votre boîte de réception et cliquez sur le lien de vérification.';
      default:
        return 'Une erreur est survenue: ${e.message}';
    }
  }

}

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

// ✅ Exception dédiée au succès de l'inscription
// Permet à l'AuthProvider de distinguer "succès" de "vraie erreur"
class SignUpSuccessException implements Exception {
  final String email;
  SignUpSuccessException(this.email);

  @override
  String toString() => 'signup_success:$email';
}

class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  // ── INSCRIPTION EMAIL/MOT DE PASSE ───────────────────────────
  // ✅ FIX : lève SignUpSuccessException au lieu d'un throw String
  //    → AuthProvider peut détecter le succès proprement
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
        // Envoyer l'email de vérification
        await user.sendEmailVerification();
        print('📧 Email de vérification envoyé à: $email');

        // Créer le profil Firestore (inactif tant que non vérifié)
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
          isActive: false,
        );

        print('💾 Écriture du profil dans Firestore (non vérifié)...');
        await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
        print('✅ Profil créé avec succès dans Firestore');

        // ✅ Déconnecter l'utilisateur (il doit vérifier son email d'abord)
        await _auth.signOut();

        // ✅ Lever SignUpSuccessException → interceptée par AuthProvider
        //    pour retourner true sans polluer errorMessage
        throw SignUpSuccessException(email);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      print('❌ Erreur Firebase Auth: ${e.code} - ${e.message}');
      throw _getErrorMessage(e);
    } on SignUpSuccessException {
      // ✅ Relancer telle quelle — ne pas avaler
      rethrow;
    } catch (e) {
      print('❌ Erreur générale lors de l\'inscription: $e');
      throw 'Une erreur est survenue lors de l\'inscription';
    }
  }

  // ── VÉRIFIER EMAIL ET ACTIVER ────────────────────────────────
  Future<UserModel?> checkEmailVerificationAndActivate() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        print('🔍 Vérification du statut de l\'email pour: ${user.email}');
        await user.reload();
        user = _auth.currentUser;

        if (user != null && user.emailVerified) {
          print('✅ Email vérifié ! Activation du compte...');
          await _firestore.collection('users').doc(user.uid).update({
            'isActive': true,
            'emailVerified': true,
            'verifiedAt': Timestamp.fromDate(DateTime.now()),
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
          print('✅ Compte activé avec succès');

          DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();
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
              createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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

  // ── RENVOYER L'EMAIL DE VÉRIFICATION ────────────────────────
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

  // ── CONNEXION EMAIL/MOT DE PASSE ─────────────────────────────
  Future<UserModel?> signInWithEmailAndPassword(
      String email,
      String password,
      ) async {
    User? user;

    try {
      print('🔐 Tentative de connexion pour: $email');

      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      user = result.user;
      print('✅ Utilisateur Firebase authentifié: ${user?.uid}');

      if (user != null) {
        // ✅ Email non vérifié → EmailNotVerifiedException
        if (!user.emailVerified) {
          print('❌ Email non vérifié pour: ${user.email}');
          await _auth.signOut();
          throw EmailNotVerifiedException(
            'Veuillez vérifier votre email avant de vous connecter. '
                'Consultez votre boîte de réception et cliquez sur le lien de vérification.',
          );
        }

        try {
          print('🔍 Vérification de l\'utilisateur dans Firestore...');
          DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();

          if (doc.exists) {
            print('✅ Utilisateur trouvé dans Firestore');
            await _firestore.collection('users').doc(user.uid).update({
              'lastLoginAt': Timestamp.fromDate(DateTime.now()),
              'email': user.email,
            });

            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            return UserModel(
              uid: user.uid,
              email: user.email ?? data['email'] ?? '',
              nom: data['nom'] ?? 'Utilisateur',
              prenom: data['prenom'] ?? '',
              genre: data['genre'],
              phoneNumber: data['phoneNumber'] ?? '',
              countryCode: data['countryCode'],
              createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              lastLoginAt: DateTime.now(),
              isActive: data['isActive'] ?? true,
              isEmailVerified: true,
            );
          } else {
            print('🆕 Profil Firestore introuvable, création...');
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
              isEmailVerified: true,
            );
            await _firestore
                .collection('users')
                .doc(user.uid)
                .set(userModel.toMap());
            print('✅ Profil créé avec succès dans Firestore');
            return userModel;
          }
        } catch (firestoreError) {
          // ✅ Si c'est une EmailNotVerifiedException remontée, la relancer
          if (firestoreError is EmailNotVerifiedException) rethrow;
          print(
              '⚠️ Erreur Firestore, utilisateur Firebase connecté quand même: $firestoreError');
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
    } on EmailNotVerifiedException {
      rethrow; // ✅ Relancer proprement
    } on FirebaseAuthException catch (e) {
      print('❌ Erreur Firebase Auth: ${e.code} - ${e.message}');
      throw _getErrorMessage(e);
    } catch (e) {
      print('❌ Erreur générale lors de la connexion: $e');
      throw 'Une erreur est survenue lors de la connexion';
    }
  }

  // ── CONNEXION GOOGLE ─────────────────────────────────────────
  Future<UserModel?> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw 'Connexion Google annulée';

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        try {
          DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();

          if (doc.exists) {
            await _firestore.collection('users').doc(user.uid).update({
              'lastLoginAt': Timestamp.fromDate(DateTime.now()),
            });
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            return UserModel(
              uid: user.uid,
              email: data['email'] ?? user.email ?? '',
              nom: data['nom'] ??
                  user.displayName?.split(' ').last ??
                  'Utilisateur',
              prenom: data['prenom'] ??
                  user.displayName?.split(' ').first ??
                  '',
              genre: data['genre'],
              phoneNumber: data['phoneNumber'] ?? '',
              countryCode: data['countryCode'],
              createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              lastLoginAt: DateTime.now(),
              isActive: data['isActive'] ?? true,
            );
          } else {
            String displayName = user.displayName ?? 'Utilisateur Google';
            List<String> nameParts = displayName.split(' ');
            String firstName = nameParts.isNotEmpty ? nameParts.first : '';
            String lastName =
            nameParts.length > 1 ? nameParts.last : nameParts.first;

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
            await _firestore
                .collection('users')
                .doc(user.uid)
                .set(userModel.toMap());
            return userModel;
          }
        } catch (firestoreError) {
          print(
              '⚠️ Erreur Firestore Google, fallback basique: $firestoreError');
          String displayName = user.displayName ?? 'Utilisateur Google';
          List<String> nameParts = displayName.split(' ');
          return UserModel(
            uid: user.uid,
            email: user.email ?? '',
            nom: nameParts.length > 1 ? nameParts.last : nameParts.first,
            prenom: nameParts.isNotEmpty ? nameParts.first : '',
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

  // ── MOT DE PASSE OUBLIÉ ──────────────────────────────────────
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _getErrorMessage(e);
    } catch (e) {
      throw 'Une erreur est survenue lors de l\'envoi de l\'email de réinitialisation';
    }
  }

  // ── SYNCHRONISER L'EMAIL ─────────────────────────────────────
  Future<void> syncEmailFromAuth() async {
    try {
      User? user = _auth.currentUser;
      if (user != null && user.email != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'email': user.email,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    } catch (e) {
      print('❌ Erreur lors de la synchronisation de l\'email: $e');
    }
  }

  String? getCurrentEmail() => _auth.currentUser?.email;

  // ── DÉCONNEXION ──────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw 'Erreur lors de la déconnexion';
    }
  }

  // ── METTRE À JOUR LE PROFIL ──────────────────────────────────
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

        DocumentSnapshot doc =
        await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .update(updateData);
        } else {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email,
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
          });
        }
      } else {
        throw 'Aucun utilisateur connecté';
      }
    } catch (e) {
      print('❌ Erreur mise à jour du profil: $e');
      throw 'Erreur lors de la mise à jour du profil: $e';
    }
  }

  // ── ADRESSES ─────────────────────────────────────────────────
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
        String addressId = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('addresses')
            .doc()
            .id;
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
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('addresses')
            .doc(addressId)
            .set(addressData);
        if (isDefault) await _updateOtherAddressesAsNonDefault(user.uid, addressId);
        return addressId;
      }
      throw 'Utilisateur non connecté';
    } catch (e) {
      print('❌ Erreur ajout adresse: $e');
      throw 'Erreur lors de l\'ajout de l\'adresse';
    }
  }

  Future<void> _updateOtherAddressesAsNonDefault(
      String userId, String defaultAddressId) async {
    try {
      QuerySnapshot addresses = await _firestore
          .collection('users')
          .doc(userId)
          .collection('addresses')
          .get();
      for (DocumentSnapshot doc in addresses.docs) {
        if (doc.id != defaultAddressId) {
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('addresses')
              .doc(doc.id)
              .update({'isDefault': false});
        }
      }
    } catch (e) {
      print('⚠️ Erreur mise à jour adresses par défaut: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserAddresses() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        QuerySnapshot addresses = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('addresses')
            .get();
        List<Map<String, dynamic>> addressList = addresses.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        addressList.sort((a, b) {
          if (a['isDefault'] == true && b['isDefault'] != true) return -1;
          if (a['isDefault'] != true && b['isDefault'] == true) return 1;
          Timestamp aTime = a['createdAt'] as Timestamp;
          Timestamp bTime = b['createdAt'] as Timestamp;
          return bTime.compareTo(aTime);
        });
        return addressList;
      }
      return [];
    } catch (e) {
      print('❌ Erreur récupération adresses: $e');
      return [];
    }
  }

  Future<void> setDefaultAddress(String userId, String addressId) async {
    try {
      QuerySnapshot addresses = await _firestore
          .collection('users')
          .doc(userId)
          .collection('addresses')
          .get();
      for (DocumentSnapshot doc in addresses.docs) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('addresses')
            .doc(doc.id)
            .update({'isDefault': doc.id == addressId});
      }
    } catch (e) {
      print('❌ Erreur définition adresse par défaut: $e');
      throw 'Erreur lors de la définition de l\'adresse par défaut';
    }
  }

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
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('addresses')
          .doc(addressId)
          .update({
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
      });
      if (isDefault) await _updateOtherAddressesAsNonDefault(userId, addressId);
    } catch (e) {
      print('❌ Erreur modification adresse: $e');
      throw 'Erreur lors de la modification de l\'adresse';
    }
  }

  Future<void> deleteAddress(String userId, String addressId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('addresses')
          .doc(addressId)
          .delete();
    } catch (e) {
      print('❌ Erreur suppression adresse: $e');
      throw 'Erreur lors de la suppression de l\'adresse';
    }
  }

  // ── NOTIFICATIONS ─────────────────────────────────────────────
  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      String notificationId = _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc()
          .id;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .set({
        'id': notificationId,
        'title': title,
        'body': body,
        'type': type,
        'isRead': false,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'data': data ?? {},
      });
    } catch (e) {
      print('❌ Erreur création notification: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserNotifications() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        QuerySnapshot notifications = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .get();
        List<Map<String, dynamic>> list = notifications.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        list.sort((a, b) {
          Timestamp aTime = a['createdAt'] as Timestamp;
          Timestamp bTime = b['createdAt'] as Timestamp;
          return bTime.compareTo(aTime);
        });
        return list;
      }
      return [];
    } catch (e) {
      print('❌ Erreur récupération notifications: $e');
      return [];
    }
  }

  Future<void> markNotificationAsRead(
      String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('❌ Erreur marquage notification: $e');
    }
  }

  Future<void> deleteAllNotifications(String userId) async {
    try {
      QuerySnapshot notifications = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();
      for (DocumentSnapshot doc in notifications.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('❌ Erreur suppression notifications: $e');
      throw 'Erreur lors de la suppression de toutes les notifications';
    }
  }

  Future<void> deleteNotification(
      String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('❌ Erreur suppression notification: $e');
      throw 'Erreur lors de la suppression de la notification';
    }
  }

  // ── CACHE FIRESTORE ──────────────────────────────────────────
  Future<void> clearFirestoreCache() async {
    try {
      await _firestore.clearPersistence();
      print('✅ Cache Firestore nettoyé avec succès');
    } catch (e) {
      print('⚠️ Erreur nettoyage cache Firestore: $e');
    }
  }

  // ── RÉCUPÉRER LE PROFIL ──────────────────────────────────────
  Future<UserModel?> getUserProfile() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot doc =
        await _firestore.collection('users').doc(user.uid).get();
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
            createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            lastLoginAt:
            (data['lastLoginAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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

  // ── SUPPRIMER LE COMPTE ──────────────────────────────────────
  Future<void> deleteAccount() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).delete();
        await user.delete();
      }
    } catch (e) {
      throw 'Erreur lors de la suppression du compte';
    }
  }

  // ── UPLOAD PHOTO ─────────────────────────────────────────────
  Future<String> uploadProfilePhoto(File imageFile) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) throw 'Aucun utilisateur connecté';

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user.uid}_$timestamp.jpg');

      final bytes = await imageFile.readAsBytes();
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

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await _firestore.collection('users').doc(user.uid).update({
        'photoUrl': downloadUrl,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      await user.updatePhotoURL(downloadUrl);

      return downloadUrl;
    } on FirebaseException catch (e) {
      throw 'Erreur lors de l\'upload de la photo: ${e.message}';
    } catch (e) {
      throw 'Erreur lors de l\'upload de la photo de profil';
    }
  }

  Future<String> getUserRole() async {
    try {
      final uid = currentUser?.uid;
      if (uid == null) return 'buyer';
      final doc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return (doc.data()?['role'] as String?) == 'seller' ? 'seller' : 'buyer';
    } catch (e) {
      return 'buyer';
    }
  }

  Future<void> deleteProfilePhoto() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user.uid}.jpg');
      await storageRef.delete();
      await _firestore.collection('users').doc(user.uid).update({
        'photoUrl': FieldValue.delete(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      await user.updatePhotoURL(null);
    } catch (e) {
      print('⚠️ Erreur suppression photo: $e');
    }
  }

  // ── GESTION DES ERREURS ──────────────────────────────────────
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
        return 'Veuillez vérifier votre email avant de vous connecter.';
      default:
        return 'Une erreur est survenue: ${e.message}';
    }
  }
}
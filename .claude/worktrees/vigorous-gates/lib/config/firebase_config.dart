import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseConfig {
  // ── Initialisation ────────────────────────────────────────────
  static Future<void> initializeFirebase() async {
    try {
      if (kIsWeb) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey:            "AIzaSyDiAjduuv5Wgm67F2ybQ-oMR2rZLLoAMfo",
            authDomain:        "smartmarketplace-ac712.firebaseapp.com",
            projectId:         "smartmarketplace-ac712",
            storageBucket:     "smartmarketplace-ac712.firebasestorage.app",
            messagingSenderId: "728599724051",
            appId:             "1:728599724051:web:8603bfb789f4b8ec903fe6",
          ),
        );
        await FirebaseStorage.instanceFor(
          bucket: 'smartmarketplace-ac712.firebasestorage.app',
        );
      } else {
        await Firebase.initializeApp();
      }

      if (kDebugMode) {
        FirebaseAuth.instance.setSettings(
          appVerificationDisabledForTesting: true,
        );
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      }

      print('✅ Firebase initialisé avec succès');
    } catch (e) {
      print('❌ Erreur Firebase: $e');
      rethrow;
    }
  }

  // ── Collections ───────────────────────────────────────────────
  static const String usersCollection      = 'users';
  static const String productsCollection   = 'products';
  static const String ordersCollection     = 'orders';
  static const String cartsCollection      = 'carts';
  static const String categoriesCollection = 'categories';

  // ── Règles Firestore (à copier dans la console Firebase) ──────
  static const String firestoreRules = '''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;

      match /payment_methods/{cardId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      match /addresses/{addressId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      match /notifications/{notifId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }

    match /deletion_requests/{docId} {
      allow create: if request.auth != null;
      allow read, update, delete: if false;
    }

    match /products/{productId} {
      allow read: if request.auth != null;
    }

    match /orders/{orderId} {
      allow read, write: if request.auth != null;
    }

    match /carts/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Collection FAQ (publique pour les utilisateurs authentifiés)
    match /faq/{faqId} {
      allow read: if request.auth != null;
    }
  }
}
''';

  // ── Règles Storage (à copier dans la console Firebase) ────────
  static const String storageRules = '''
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /profile_photos/{userId}.jpg {
      allow read: if request.auth != null;
      allow write, delete: if request.auth != null 
                           && request.auth.uid == userId
                           && request.resource.size < 5 * 1024 * 1024;
    }
    match /products/{productId}/{imageId} {
      allow read: if request.auth != null;
    }
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
''';
}
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseConfig {
  // Initialiser Firebase
  static Future<void> initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      
      // Configuration pour le mode développement
      if (kDebugMode) {
        // Activer les logs détaillés en mode debug
        FirebaseAuth.instance.setSettings(
          appVerificationDisabledForTesting: true,
        );
        
        // Configurer Firestore pour le mode développement
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      }
      
      print('✅ Firebase initialisé avec succès');
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation de Firebase: $e');
      rethrow;
    }
  }

  // Configuration des règles de sécurité Firestore (à copier dans la console Firebase)
  static const String firestoreRules = '''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Les utilisateurs peuvent lire et écrire leur propre profil
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Les utilisateurs authentifiés peuvent lire les données publiques
    match /products/{productId} {
      allow read: if request.auth != null;
    }
    
    // Les utilisateurs peuvent lire et écrire leurs propres commandes
    match /orders/{orderId} {
      allow read, write: if request.auth != null && 
        request.auth.uid in resource.data()['userId'];
    }
    
    // Les utilisateurs peuvent lire et écrire leur panier
    match /carts/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Les utilisateurs peuvent lire les adresses publiques
    match /addresses/{addressId} {
      allow read: if request.auth != null;
    }
    
    // Refuser tout autre accès
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
''';

  // Configuration des règles de stockage Firebase Storage
  static const String storageRules = '''
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Les utilisateurs peuvent téléverser et lire leurs propres images de profil
    match /users/{userId}/profile/{imageId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Les utilisateurs peuvent lire les images de produits
    match /products/{productId}/{imageId} {
      allow read: if request.auth != null;
    }
    
    // Refuser tout autre accès
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
''';

  // Collections Firestore
  static const String usersCollection = 'users';
  static const String productsCollection = 'products';
  static const String ordersCollection = 'orders';
  static const String cartsCollection = 'carts';
  static const String addressesCollection = 'addresses';
  static const String categoriesCollection = 'categories';

  // Configuration des indexes Firestore (à créer dans la console Firebase)
  static const List<Map<String, dynamic>> requiredIndexes = [
    {
      'collection': 'products',
      'queryScope': 'Collection',
      'fields': [
        {'fieldPath': 'categoryId', 'order': 'Ascending'},
        {'fieldPath': 'price', 'order': 'Ascending'},
      ],
    },
    {
      'collection': 'orders',
      'queryScope': 'Collection',
      'fields': [
        {'fieldPath': 'userId', 'order': 'Ascending'},
        {'fieldPath': 'createdAt', 'order': 'Descending'},
      ],
    },
    {
      'collection': 'users',
      'queryScope': 'Collection',
      'fields': [
        {'fieldPath': 'email', 'order': 'Ascending'},
        {'fieldPath': 'isActive', 'order': 'Ascending'},
      ],
    },
  ];

  // Messages d'aide pour la configuration
  static const String setupInstructions = '''
🔥 ÉTAPES DE CONFIGURATION FIREBASE:

1. Créez un projet Firebase sur https://console.firebase.google.com
2. Activez Authentication:
   - Email/Mot de passe
   - Google Sign-in
   - Facebook Login (optionnel)

3. Configurez Firestore Database:
   - Créez une base de données en mode test
   - Copiez-collez les règles de sécurité depuis firestoreRules

4. Configurez Firebase Storage:
   - Activez le stockage
   - Copiez-collez les règles de sécurité depuis storageRules

5. Configurez les applications:
   - Android: Ajoutez le fichier google-services.json
   - iOS: Ajoutez le fichier GoogleService-Info.plist

6. Créez les indexes requis dans Firestore:
   - Allez dans Firestore > Indexes > Composite
   - Créez les indexes listés dans requiredIndexes

7. Configurez OAuth pour Google Sign-in:
   - Ajoutez l'ID client OAuth de votre application
   - Configurez l'écran de consentement

📋 RÈGLES DE SÉCURITÉ:
Les règles de sécurité sont définies pour protéger les données utilisateur.
Seul l'utilisateur propriétaire peut accéder et modifier ses propres données.

🔍 INDEXES REQUIS:
Les indexes sont nécessaires pour les requêtes complexes dans Firestore.
''';
}

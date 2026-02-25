import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FAQService {
  static final FAQService _instance = FAQService._internal();
  factory FAQService() => _instance;
  FAQService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────
  // Structure Firestore attendue pour chaque document dans 'faq':
  // {
  //   title    : String,
  //   content  : String,
  //   category : String,
  //   icon     : String,
  //   color    : String,
  //   isActive : bool,
  //   role     : 'buyer' | 'seller',   ← champ discriminant
  //   createdAt: Timestamp,
  // }
  // ─────────────────────────────────────────────────────────────

  /// Récupère le rôle de l'utilisateur connecté depuis Firestore.
  /// Retourne 'buyer' par défaut si non trouvé.
  Future<String> getUserRole() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return 'buyer';
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return 'buyer';
      return doc.data()?['role'] as String? ?? 'buyer';
    } catch (e) {
      print('❌ Erreur récupération rôle: $e');
      return 'buyer';
    }
  }

  // ── FAQs filtrées par rôle ───────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllFAQs() async {
    try {
      final role = await getUserRole();
      print('🔥 Récupération FAQs actives pour rôle: $role');

      QuerySnapshot snapshot = await _firestore
          .collection('faq')
          .where('isActive', isEqualTo: true)
          .where('role', isEqualTo: role)
          .get();

      List<Map<String, dynamic>> faqList = snapshot.docs
          .map((doc) => {
        ...doc.data() as Map<String, dynamic>,
        'id': doc.id,
      })
          .toList();

      print('📋 FAQs actives ($role): ${faqList.length}');

      // Fallback : ignorer isActive si vide
      if (faqList.isEmpty) {
        print('⚠️ Fallback sans filtre isActive...');
        final fallback = await _firestore
            .collection('faq')
            .where('role', isEqualTo: role)
            .get();

        faqList = fallback.docs
            .map((doc) => {
          ...doc.data() as Map<String, dynamic>,
          'id': doc.id,
        })
            .toList();

        print('📋 FAQs fallback ($role): ${faqList.length}');
      }

      return faqList;
    } catch (e) {
      print('❌ Erreur FAQs: $e');
      return [];
    }
  }

  // ── Catégories filtrées par rôle ─────────────────────────────

  Future<List<String>> getCategories() async {
    try {
      final role = await getUserRole();

      QuerySnapshot snapshot = await _firestore
          .collection('faq')
          .where('isActive', isEqualTo: true)
          .where('role', isEqualTo: role)
          .get();

      Set<String> categories = {};
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['category'] != null) categories.add(data['category'] as String);
      }

      // Fallback
      if (categories.isEmpty) {
        final fallback = await _firestore
            .collection('faq')
            .where('role', isEqualTo: role)
            .get();
        for (final doc in fallback.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['category'] != null) categories.add(data['category'] as String);
        }
      }

      return categories.toList()..sort();
    } catch (e) {
      print('❌ Erreur catégories: $e');
      return [];
    }
  }

  // ── CRUD admin ───────────────────────────────────────────────

  Future<void> addFAQ({
    required String title,
    required String content,
    required String category,
    required String role, // 'buyer' ou 'seller'
    String icon = 'help_outline',
    String color = 'blue',
    bool isActive = true,
  }) async {
    await _firestore.collection('faq').add({
      'title':     title.trim(),
      'content':   content.trim(),
      'category':  category.trim(),
      'role':      role,
      'icon':      icon,
      'color':     color,
      'isActive':  isActive,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> updateFAQ(String docId, Map<String, dynamic> data) async {
    await _firestore.collection('faq').doc(docId).update({
      ...data,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> deleteFAQ(String docId) async {
    await _firestore.collection('faq').doc(docId).delete();
  }

  /// Toutes les FAQs sans filtre rôle (pour la page admin)
  Future<List<Map<String, dynamic>>> getAllFAQsAdmin() async {
    try {
      final snapshot = await _firestore
          .collection('faq')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      print('❌ Erreur admin FAQs: $e');
      return [];
    }
  }
}
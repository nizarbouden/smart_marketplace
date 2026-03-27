import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../localization/app_localizations.dart';

/// Structure Firestore :
///   faq/{lang}/items/{docId}
///
///   faq/fr/items/{docId} → FAQs en français
///   faq/ar/items/{docId} → FAQs en arabe
///   faq/en/items/{docId} → FAQs en anglais
///
/// Chaque document contient :
///   title, content, category, role, icon, color, isActive, createdAt

class FAQService {
  static final FAQService _instance = FAQService._internal();
  factory FAQService() => _instance;
  FAQService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Langue courante → chemin Firestore
  String get _lang => AppLocalizations.getLanguage(); // 'fr' | 'ar' | 'en'

  /// Collection items pour une langue donnée
  /// faq/{lang}/items
  CollectionReference _itemsRef(String lang) =>
      _firestore.collection('faq').doc(lang).collection('items');

  // ─────────────────────────────────────────────────────────────
  //  Rôle utilisateur
  // ─────────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────
  //  FAQs — filtrées par langue + rôle
  // ─────────────────────────────────────────────────────────────

  /// [lang] optionnel — si non fourni, utilise la langue courante de l'app.
  /// Le passer explicitement force le rechargement quand la langue change.
  Future<List<Map<String, dynamic>>> getAllFAQs({String? lang}) async {
    final targetLang = lang ?? _lang;
    try {
      final role = await getUserRole();
      print('🔥 FAQs — langue: $targetLang, rôle: $role');

      // 1. Avec filtre isActive
      QuerySnapshot snapshot = await _itemsRef(targetLang)
          .where('isActive', isEqualTo: true)
          .where('role',     isEqualTo: role)
          .get();

      List<Map<String, dynamic>> faqList = _mapDocs(snapshot.docs);

      // 2. Fallback sans isActive
      if (faqList.isEmpty) {
        print('⚠️ Fallback sans filtre isActive ($targetLang)...');
        final fallback = await _itemsRef(targetLang)
            .where('role', isEqualTo: role)
            .get();
        faqList = _mapDocs(fallback.docs);
      }

      // 3. Fallback langue → français si toujours vide
      if (faqList.isEmpty && targetLang != 'fr') {
        print('⚠️ Fallback vers FR...');
        final frSnap = await _itemsRef('fr')
            .where('isActive', isEqualTo: true)
            .where('role',     isEqualTo: role)
            .get();
        faqList = _mapDocs(frSnap.docs);
      }

      print('📋 FAQs ($targetLang / $role): ${faqList.length}');
      return faqList;
    } catch (e) {
      print('❌ Erreur FAQs: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Catégories — filtrées par langue + rôle
  // ─────────────────────────────────────────────────────────────

  Future<List<String>> getCategories({String? lang}) async {
    final targetLang = lang ?? _lang;
    try {
      final role = await getUserRole();

      QuerySnapshot snapshot = await _itemsRef(targetLang)
          .where('isActive', isEqualTo: true)
          .where('role',     isEqualTo: role)
          .get();

      Set<String> categories = {};
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final cat  = data['category'] as String?;
        if (cat != null && cat.isNotEmpty) categories.add(cat);
      }

      // Fallback sans isActive
      if (categories.isEmpty) {
        final fallback = await _itemsRef(targetLang)
            .where('role', isEqualTo: role)
            .get();
        for (final doc in fallback.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final cat  = data['category'] as String?;
          if (cat != null && cat.isNotEmpty) categories.add(cat);
        }
      }

      // Fallback FR
      if (categories.isEmpty && targetLang != 'fr') {
        final frSnap = await _itemsRef('fr')
            .where('isActive', isEqualTo: true)
            .where('role',     isEqualTo: role)
            .get();
        for (final doc in frSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final cat  = data['category'] as String?;
          if (cat != null && cat.isNotEmpty) categories.add(cat);
        }
      }

      return categories.toList()..sort();
    } catch (e) {
      print('❌ Erreur catégories: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  CRUD — créer une FAQ dans toutes les langues à la fois
  // ─────────────────────────────────────────────────────────────

  /// Crée la même FAQ dans les 3 langues simultanément.
  /// Le même docId est utilisé dans fr/items, ar/items, en/items.
  Future<void> addFAQ({
    // Français
    required String titleFr,
    required String contentFr,
    required String categoryFr,
    // Arabe
    required String titleAr,
    required String contentAr,
    required String categoryAr,
    // Anglais
    required String titleEn,
    required String contentEn,
    required String categoryEn,
    // Commun
    required String role,
    String icon     = 'help_outline',
    String color    = 'blue',
    bool   isActive = true,
  }) async {
    final commonData = {
      'role':      role,
      'icon':      icon,
      'color':     color,
      'isActive':  isActive,
      'createdAt': Timestamp.now(),
    };

    // Créer le doc dans FR pour obtenir un ID
    final docRef = await _itemsRef('fr').add({
      ...commonData,
      'title':    titleFr.trim(),
      'content':  contentFr.trim(),
      'category': categoryFr.trim(),
    });

    // Utiliser le même ID pour AR et EN
    final docId = docRef.id;

    await Future.wait([
      _itemsRef('ar').doc(docId).set({
        ...commonData,
        'title':    titleAr.trim(),
        'content':  contentAr.trim(),
        'category': categoryAr.trim(),
      }),
      _itemsRef('en').doc(docId).set({
        ...commonData,
        'title':    titleEn.trim(),
        'content':  contentEn.trim(),
        'category': categoryEn.trim(),
      }),
    ]);

    print('✅ FAQ créée (id: $docId) dans fr/ar/en');
  }

  /// Met à jour une FAQ dans une langue spécifique
  Future<void> updateFAQ(String docId, String lang,
      Map<String, dynamic> data) async {
    await _itemsRef(lang).doc(docId).update({
      ...data,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Supprime une FAQ dans toutes les langues
  Future<void> deleteFAQ(String docId) async {
    await Future.wait([
      _itemsRef('fr').doc(docId).delete(),
      _itemsRef('ar').doc(docId).delete(),
      _itemsRef('en').doc(docId).delete(),
    ]);
    print('🗑️ FAQ supprimée (id: $docId) dans fr/ar/en');
  }

  /// Toutes les FAQs d'une langue (pour la page admin)
  Future<List<Map<String, dynamic>>> getAllFAQsAdmin({
    String lang = 'fr',
  }) async {
    try {
      final snapshot = await _itemsRef(lang)
          .orderBy('createdAt', descending: true)
          .get();
      return _mapDocs(snapshot.docs);
    } catch (e) {
      print('❌ Erreur admin FAQs: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Helper
  // ─────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _mapDocs(List<QueryDocumentSnapshot> docs) {
    return docs.map((doc) => {
      ...doc.data() as Map<String, dynamic>,
      'id': doc.id,
    }).toList();
  }
}
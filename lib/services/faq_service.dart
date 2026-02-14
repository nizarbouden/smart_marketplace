import 'package:cloud_firestore/cloud_firestore.dart';

class FAQService {
  static final FAQService _instance = FAQService._internal();
  factory FAQService() => _instance;
  FAQService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Récupérer toutes les FAQs actives
  Future<List<Map<String, dynamic>>> getAllFAQs() async {
    try {
      print('🔥 Récupération des FAQs actives...');
      QuerySnapshot snapshot = await _firestore
          .collection('faq')
          .where('isActive', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> faqList = [];
      for (DocumentSnapshot doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        faqList.add(data);
      }

      print('📋 FAQs actives trouvées: ${faqList.length}');
      
      // Si aucune FAQ active n'est trouvée, essayer de récupérer toutes les FAQs
      if (faqList.isEmpty) {
        print('⚠️ Aucune FAQ active trouvée, récupération de toutes les FAQs...');
        QuerySnapshot allSnapshot = await _firestore
            .collection('faq')
            .get();

        for (DocumentSnapshot doc in allSnapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          print('📄 FAQ trouvée: ${data['title']} - isActive: ${data['isActive']}');
          faqList.add(data);
        }
        
        print('📋 Toutes les FAQs récupérées: ${faqList.length}');
      }

      return faqList;
    } catch (e) {
      print('❌ Erreur lors de la récupération des FAQs: $e');
      return [];
    }
  }

  // Récupérer les catégories uniques
  Future<List<String>> getCategories() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('faq')
          .where('isActive', isEqualTo: true)
          .get();

      Set<String> categories = {};
      for (DocumentSnapshot doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['category'] != null) {
          categories.add(data['category'] as String);
        }
      }

      // Si aucune catégorie active n'est trouvée, récupérer toutes les catégories
      if (categories.isEmpty) {
        QuerySnapshot allSnapshot = await _firestore
            .collection('faq')
            .get();

        for (DocumentSnapshot doc in allSnapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          if (data['category'] != null) {
            categories.add(data['category'] as String);
          }
        }
      }

      List<String> categoryList = categories.toList();
      categoryList.sort(); // Trier alphabétiquement
      return categoryList;
    } catch (e) {
      print('❌ Erreur lors de la récupération des catégories: $e');
      return [];
    }
  }
}

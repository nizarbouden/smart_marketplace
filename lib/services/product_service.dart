import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class ProductService {
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;
  ProductService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // IDs already being processed to avoid duplicate Firestore writes
  final Set<String> _deactivationPending = {};

  Stream<List<Product>> getApprovedProducts() {
    return _firestore
        .collection('products')
        .where('status', isEqualTo: 'approved')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final List<Product> visible = [];

      for (final doc in snapshot.docs) {
        final product = Product.fromFirestore(doc);

        final isExpired = product.hiddenAfterAt != null &&
            now.isAfter(product.hiddenAfterAt!);

        if (!isExpired) {
          // Not expired -> show to client, clear cache entry if present
          _deactivationPending.remove(doc.id);
          visible.add(product);
          continue;
        }

        // Expired -> set isActive=false AND delete hiddenAfterAt (once only)
        // Deleting hiddenAfterAt ensures that if the seller re-activates the
        // product manually, it will show normally without being blocked again.
        if (!_deactivationPending.contains(doc.id)) {
          _deactivationPending.add(doc.id);
          _deactivateAndClearTimer(doc.id);
        }
        // Do not show this product to the client
      }

      return visible;
    });
  }

  // Sets isActive=false and DELETES hiddenAfterAt from Firestore
  Future<void> _deactivateAndClearTimer(String docId) async {
    try {
      await _firestore.collection('products').doc(docId).update({
        'isActive': false,
        'hiddenAfterAt': FieldValue.delete(),
        'updatedAt': Timestamp.now(),
      });
      // Remove from cache after successful write so the doc
      // is no longer tracked (hiddenAfterAt is gone anyway)
      _deactivationPending.remove(docId);
    } catch (_) {
      // Network error -> remove from cache to retry on next stream emission
      _deactivationPending.remove(docId);
    }
  }
}
// lib/services/product_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

/// Number of products fetched per Firestore page request.
const int kProductPageSize = 10;

/// One page of Firestore results plus a cursor for the next page.
class ProductPage {
  final List<Product>     products;   // after hiddenAfterAt check
  final DocumentSnapshot? lastDoc;    // null → no further pages exist
  final int               totalCount; // from AggregateQuery.count()

  const ProductPage({
    required this.products,
    required this.totalCount,
    this.lastDoc,
  });
}

class ProductService {
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;
  ProductService._internal();

  final FirebaseFirestore _firestore          = FirebaseFirestore.instance;
  final Set<String>       _deactivationPending = {};

  // ── Build base query (no limit / cursor) ─────────────────────────────────
  //
  // Server-side: status, isActive, category, sort order.
  // Client-side (applied after fetching): price range, inStockOnly, zoneOnly,
  //   searchQuery — keeping server-side simple avoids composite-index
  //   requirements for every filter combination.
  //
  // Required Firestore indexes (create in Firebase Console if auto-creation fails):
  //   products: status▲ isActive▲ createdAt▼
  //   products: status▲ isActive▲ category▲  createdAt▼
  //   products: status▲ isActive▲ price▲      createdAt▼
  //   products: status▲ isActive▲ price▼      createdAt▼
  //   products: status▲ isActive▲ category▲   price▲  createdAt▼
  //   products: status▲ isActive▲ category▲   price▼  createdAt▼
  Query<Map<String, dynamic>> _baseQuery({
    String? category,
    String  sortOrder = 'none',
  }) {
    Query<Map<String, dynamic>> q = _firestore
        .collection('products')
        .where('status',   isEqualTo: 'approved')
        .where('isActive', isEqualTo: true);

    if (category != null) {
      q = q.where('category', isEqualTo: category);
    }

    switch (sortOrder) {
      case 'asc':
        q = q.orderBy('price').orderBy('createdAt', descending: true);
        break;
      case 'desc':
        q = q.orderBy('price', descending: true)
             .orderBy('createdAt', descending: true);
        break;
      default:
        q = q.orderBy('createdAt', descending: true);
    }

    return q;
  }

  // ── Count without fetching document data ─────────────────────────────────
  Future<int> countProducts({
    String? category,
    String  sortOrder = 'none',
  }) async {
    try {
      final agg = await _baseQuery(
        category:  category,
        sortOrder: sortOrder,
      ).count().get();
      return agg.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ── Fetch one page ────────────────────────────────────────────────────────
  //
  // • knownCount > 0  → skip the count() round-trip (use cached value).
  // • knownCount == 0 → run a fresh count() before fetching the page.
  Future<ProductPage> fetchPage({
    String?           category,
    String            sortOrder  = 'none',
    int               pageSize   = kProductPageSize,
    DocumentSnapshot? startAfter,
    int               knownCount = 0,
  }) async {
    final int total = knownCount > 0
        ? knownCount
        : await countProducts(category: category, sortOrder: sortOrder);

    Query<Map<String, dynamic>> q =
        _baseQuery(category: category, sortOrder: sortOrder).limit(pageSize);

    if (startAfter != null) q = q.startAfterDocument(startAfter);

    final snap = await q.get();
    final now  = DateTime.now();
    final List<Product> products = [];

    for (final doc in snap.docs) {
      final p = Product.fromFirestore(doc);
      if (p.hiddenAfterAt != null && now.isAfter(p.hiddenAfterAt!)) {
        // Expired → deactivate once, skip display
        if (!_deactivationPending.contains(doc.id)) {
          _deactivationPending.add(doc.id);
          _deactivateAndClearTimer(doc.id);
        }
        continue;
      }
      _deactivationPending.remove(doc.id);
      products.add(p);
    }

    return ProductPage(
      products:   products,
      totalCount: total,
      lastDoc:    snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  // ── Filter metadata (categories + max price) ───────────────────────────────
  //
  // One-time fetch used by the filter drawer. Reads all approved+active docs
  // once to extract distinct categories and the highest price.
  Future<({List<String> categories, double maxPrice})> fetchFilterMetadata() async {
    try {
      final snap = await _firestore
          .collection('products')
          .where('status',   isEqualTo: 'approved')
          .where('isActive', isEqualTo: true)
          .get();

      if (snap.docs.isEmpty) {
        return (categories: <String>[], maxPrice: 10000.0);
      }

      double maxPrice = 0;
      final catSet = <String>{};
      for (final doc in snap.docs) {
        final d = doc.data();
        final p = (d['price'] as num?)?.toDouble() ?? 0;
        if (p > maxPrice) maxPrice = p;
        final c = d['category'] as String? ?? '';
        if (c.isNotEmpty) catSet.add(c);
      }

      return (
        categories: catSet.toList()..sort(),
        maxPrice:   maxPrice > 0 ? maxPrice : 10000.0,
      );
    } catch (_) {
      return (categories: <String>[], maxPrice: 10000.0);
    }
  }

  // Sets isActive=false and deletes hiddenAfterAt (run at most once per docId)
  Future<void> _deactivateAndClearTimer(String docId) async {
    try {
      await _firestore.collection('products').doc(docId).update({
        'isActive':      false,
        'hiddenAfterAt': FieldValue.delete(),
        'updatedAt':     Timestamp.now(),
      });
      _deactivationPending.remove(docId);
    } catch (_) {
      _deactivationPending.remove(docId);
    }
  }
}

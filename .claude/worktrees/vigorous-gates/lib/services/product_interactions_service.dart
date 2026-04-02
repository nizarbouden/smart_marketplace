// lib/services/product_interactions_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

// Notifier pour les suppressions de favoris (gardé pour compatibilité)
final favoriteRemovedNotifier = ValueNotifier<String?>('');

// ✅ NOUVEAU : Notifier pour tous les changements de favoris (ajout et suppression)
final favoriteChangedNotifier = ValueNotifier<FavoriteChange?>(null);

class FavoriteChange {
  final String productId;
  final bool isAdded; // true = ajouté, false = supprimé

  FavoriteChange({required this.productId, required this.isAdded});
}

class ProductInteractionsService {
  static final _db   = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  // ─────────────────────────────────────────────────────────────
  //  RATING — moyenne calculée en temps réel
  // ─────────────────────────────────────────────────────────────

  /// Retourne {avg: double, count: int}
  static Future<Map<String, dynamic>> fetchRating(String productId) async {
    try {
      final snap = await _db
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .where('status', isEqualTo: 'approved')
          .get();

      if (snap.docs.isEmpty) return {'avg': 0.0, 'count': 0};

      final total = snap.docs.fold<int>(
          0, (sum, d) => sum + ((d.data()['rating'] as num?)?.toInt() ?? 0));
      final avg   = total / snap.docs.length;
      return {'avg': avg, 'count': snap.docs.length};
    } catch (_) {
      return {'avg': 0.0, 'count': 0};
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  LIKES — users/{uid}/likes/{productId}
  // ─────────────────────────────────────────────────────────────

  static Future<int> fetchLikeCount(String productId) async {
    try {
      final doc = await _db.collection('products').doc(productId).get();
      return (doc.data()?['likesCount'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> isLiked(String productId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final doc = await _db
          .collection('users').doc(uid)
          .collection('likes').doc(productId)
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  static Future<void> toggleLike(String productId, bool currentlyLiked) async {
    final uid = _uid;
    if (uid == null) return;

    final userLikeRef = _db
        .collection('users').doc(uid)
        .collection('likes').doc(productId);
    final productRef  = _db.collection('products').doc(productId);

    try {
      if (currentlyLiked) {
        await userLikeRef.delete();
        await productRef.update({
          'likesCount': FieldValue.increment(-1),
        });
      } else {
        await userLikeRef.set({
          'productId': productId,
          'likedAt':   FieldValue.serverTimestamp(),
        });
        await productRef.update({
          'likesCount': FieldValue.increment(1),
        });
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────
  //  FAVORITES — users/{uid}/favorites/{productId}
  // ─────────────────────────────────────────────────────────────

  static Future<bool> isFavorite(String productId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final doc = await _db
          .collection('users').doc(uid)
          .collection('favorites').doc(productId)
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  // ✅ MODIFIÉ : toggleFavorite avec notification des changements
  static Future<void> toggleFavorite(String productId, bool currentlyFavorite) async {
    final uid = _uid;
    if (uid == null) return;

    final ref = _db
        .collection('users').doc(uid)
        .collection('favorites').doc(productId);
    try {
      if (currentlyFavorite) {
        // Supprimer le favori
        await ref.delete();
        // Notifier la suppression
        favoriteRemovedNotifier.value = productId;
        favoriteChangedNotifier.value = FavoriteChange(
          productId: productId,
          isAdded: false,
        );
      } else {
        // Ajouter le favori
        await ref.set({
          'productId': productId,
          'addedAt':   FieldValue.serverTimestamp(),
        });
        // Notifier l'ajout
        favoriteChangedNotifier.value = FavoriteChange(
          productId: productId,
          isAdded: true,
        );
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────
  //  CHARGEMENT GROUPÉ — rating + like + favori en une fois
  // ─────────────────────────────────────────────────────────────

  static Future<ProductInteractions> fetchAll(String productId) async {
    final results = await Future.wait([
      fetchRating(productId),
      isLiked(productId),
      isFavorite(productId),
      fetchLikeCount(productId),
    ]);

    final rating = results[0] as Map<String, dynamic>;
    return ProductInteractions(
      avgRating:   (rating['avg'] as double),
      reviewCount: (rating['count'] as int),
      isLiked:     results[1] as bool,
      isFavorite:  results[2] as bool,
      likeCount:   results[3] as int,
    );
  }
}

class ProductInteractions {
  final double avgRating;
  final int    reviewCount;
  final bool   isLiked;
  final bool   isFavorite;
  final int    likeCount;

  const ProductInteractions({
    this.avgRating   = 0.0,
    this.reviewCount = 0,
    this.isLiked     = false,
    this.isFavorite  = false,
    this.likeCount   = 0,
  });

  ProductInteractions copyWith({
    double? avgRating,
    int?    reviewCount,
    bool?   isLiked,
    bool?   isFavorite,
    int?    likeCount,
  }) => ProductInteractions(
    avgRating:   avgRating   ?? this.avgRating,
    reviewCount: reviewCount ?? this.reviewCount,
    isLiked:     isLiked     ?? this.isLiked,
    isFavorite:  isFavorite  ?? this.isFavorite,
    likeCount:   likeCount   ?? this.likeCount,
  );
}
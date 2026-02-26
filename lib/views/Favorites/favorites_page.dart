import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';

import '../../models/product_model.dart';
import '../products/buyer/Product_detail_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = true;

  String _t(String key) => AppLocalizations.get(key);
  User? get _currentUser => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  // ── Charger les favoris depuis Firestore ──────────────────────
  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final uid = _currentUser?.uid;
      if (uid == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Récupérer les IDs des favoris depuis users/{uid}/favorites
      final favSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .orderBy('addedAt', descending: true)
          .get();

      if (favSnap.docs.isEmpty) {
        setState(() {
          _favorites = [];
          _isLoading = false;
        });
        return;
      }

      // Récupérer les détails de chaque produit
      final List<Map<String, dynamic>> products = [];
      for (final doc in favSnap.docs) {
        final productId = doc.data()['productId'] as String? ?? doc.id;
        try {
          final productDoc = await _firestore
              .collection('products')
              .doc(productId)
              .get();
          if (productDoc.exists) {
            final data = productDoc.data()!;
            data['productId'] = productDoc.id;
            data['favoriteDocId'] = doc.id;
            products.add(data);
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _favorites = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Supprimer un favori ───────────────────────────────────────
  Future<void> _removeFavorite(String favoriteDocId, int index) async {
    try {
      final uid = _currentUser?.uid;
      if (uid == null) return;

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .doc(favoriteDocId)
          .delete();

      setState(() => _favorites.removeAt(index));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('favorites_removed')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('error')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile  = screenWidth < 600;
    final isTablet  = screenWidth >= 600 && screenWidth < 1200;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            _buildHeader(isMobile, isTablet),

            // ── Contenu ─────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _favorites.isEmpty
                  ? _buildEmptyState(isMobile, isTablet)
                  : _buildFavoritesList(isMobile, isTablet),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header style MainLayout ───────────────────────────────────
  Widget _buildHeader(bool isMobile, bool isTablet) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Bouton retour
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppLocalizations.isRtl
                      ? Icons.arrow_forward_ios_rounded
                      : Icons.arrow_back_ios_rounded,
                  size: 18,
                  color: Colors.black87,
                ),
              ),
            ),

            // Titre
            Text(
              _t('favorites_title'),
              style: TextStyle(
                fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),

            // Badge nombre de favoris
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite_rounded,
                      color: Colors.red, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${_favorites.length}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Loading ───────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            _t('loading'),
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────
  Widget _buildEmptyState(bool isMobile, bool isTablet) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isMobile ? 100 : (isTablet ? 120 : 140),
              height: isMobile ? 100 : (isTablet ? 120 : 140),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border_rounded,
                size: isMobile ? 50 : (isTablet ? 60 : 70),
                color: Colors.red.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              _t('favorites_empty_title'),
              style: TextStyle(
                fontSize: isMobile ? 18 : (isTablet ? 20 : 22),
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _t('favorites_empty_desc'),
              style: TextStyle(
                fontSize: isMobile ? 14 : 15,
                color: Colors.grey[500],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/home');
              },
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(_t('favorites_browse_btn')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Liste des favoris ─────────────────────────────────────────
  Widget _buildFavoritesList(bool isMobile, bool isTablet) {
    return RefreshIndicator(
      color: Colors.deepPurple,
      onRefresh: _loadFavorites,
      child: GridView.builder(
        padding: EdgeInsets.all(isMobile ? 12 : (isTablet ? 16 : 20)),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isMobile ? 2 : (isTablet ? 3 : 4),
          crossAxisSpacing: isMobile ? 10 : 14,
          mainAxisSpacing: isMobile ? 10 : 14,
          childAspectRatio: 0.72,
        ),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          return _buildProductCard(_favorites[index], index, isMobile, isTablet);
        },
      ),
    );
  }

  // ── Carte produit ─────────────────────────────────────────────
  // ── Carte produit ─────────────────────────────────────────────
  Widget _buildProductCard(
      Map<String, dynamic> product,
      int index,
      bool isMobile,
      bool isTablet) {
    final name          = product['name']        as String? ?? '';
    final price         = product['price']       as num?    ?? 0;
    final description   = product['description'] as String? ?? '';
    final images        = product['images']      as List<dynamic>?;
    final favoriteDocId = product['favoriteDocId'] as String? ?? '';
    final productId     = product['productId']   as String? ?? '';

    return Dismissible(
      key: Key(productId.isNotEmpty ? productId : index.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_rounded, color: Colors.white, size: 26),
            const SizedBox(height: 4),
            Text(_t('delete'),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      onDismissed: (_) => _removeFavorite(favoriteDocId, index),
      child: GestureDetector(
        onTap: () {
          final p = Product(
            id: productId,
            name: product['name'] as String? ?? '',
            price: (product['price'] as num? ?? 0).toDouble(),
            category: product['category'] as String? ?? '',
            description: product['description'] as String? ?? '',
            images: List<String>.from(product['images'] ?? []),
            isActive: product['isActive'] as bool? ?? false,
            status: product['status'] as String? ?? '',
            stock: (product['stock'] as num? ?? 0).toInt(),
            sellerId: product['sellerId'] as String? ?? '',
            reward: product['reward'] != null
                ? Reward.fromMap(product['reward'] as Map<String, dynamic>)
                : null,
            createdAt: (product['createdAt'] as Timestamp?)?.toDate(),
            updatedAt: (product['updatedAt'] as Timestamp?)?.toDate(),
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProductDetailPage(product: p)),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image ────────────────────────────────────────
              Expanded(
                flex: 6,
                child: Stack(
                  children: [
                    // Image principale
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: images != null && images.isNotEmpty
                            ? Image.memory(
                          base64Decode(images.first.toString()),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imagePlaceholder(),
                        )
                            : _imagePlaceholder(),
                      ),
                    ),

                    // Gradient overlay bas de l'image
                    Positioned(
                      bottom: 0, left: 0, right: 0, height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withOpacity(0.28), Colors.transparent],
                          ),
                        ),
                      ),
                    ),

                    // Badge favori (cœur) en haut à droite
                    Positioned(
                      top: 10, right: 10,
                      child: GestureDetector(
                        onTap: () => _showRemoveConfirmDialog(favoriteDocId, index),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.favorite_rounded, color: Colors.red, size: 15),
                        ),
                      ),
                    ),

                    // Prix en badge sur l'image (bas gauche)
                    Positioned(
                      bottom: 8, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '${price.toStringAsFixed(2)} €',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 13 : 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Infos texte ───────────────────────────────────
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Nom du produit
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Description courte
                      if (description.isNotEmpty)
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color: Colors.grey[500],
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                      // Bas de carte : flèche "voir détail"
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 11,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Icon(Icons.image_outlined,
            color: Colors.grey[400], size: 40),
      ),
    );
  }

  // ── Dialog confirmation suppression ──────────────────────────
  void _showRemoveConfirmDialog(String favoriteDocId, int index) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEF4444), Color(0xFFF87171)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite_border_rounded,
                      color: Colors.white, size: 30),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _t('favorites_remove_title'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _t('favorites_remove_desc'),
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Color(0xFFEF4444), width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(_t('cancel'),
                                style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _removeFavorite(favoriteDocId, index);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(_t('delete'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
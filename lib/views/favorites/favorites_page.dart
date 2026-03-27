import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';

import '../../models/product_model.dart';
import '../../providers/currency_provider.dart';
import '../products/buyer/Product_detail_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth      _auth      = FirebaseAuth.instance;

  List<Map<String, dynamic>> _favorites = [];
  bool   _isLoading = true;

  // Pour l'animation d'entrée des cartes
  late AnimationController _animController;

  String _t(String key) => AppLocalizations.get(key);
  User? get _currentUser => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _loadFavorites();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  //  REMISE
  // ─────────────────────────────────────────────────────────────

  static _DiscountInfo _computeDiscount(Map<String, dynamic> product) {
    final originalPrice   = (product['price'] as num? ?? 0).toDouble();
    final discountPercent = (product['discountPercent'] as num?)?.toDouble();
    final discountEndsAt  = (product['discountEndsAt'] as Timestamp?)?.toDate();
    final bool isActive   = discountPercent != null &&
        discountPercent > 0 &&
        (discountEndsAt == null || discountEndsAt.isAfter(DateTime.now()));
    final effectivePrice  = isActive
        ? originalPrice * (1 - discountPercent! / 100)
        : originalPrice;
    return _DiscountInfo(
      originalPrice:   originalPrice,
      effectivePrice:  effectivePrice,
      isActive:        isActive,
      discountPercent: isActive ? discountPercent : null,
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  CHARGEMENT
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final uid = _currentUser?.uid;
      if (uid == null) { setState(() => _isLoading = false); return; }

      final favSnap = await _firestore
          .collection('users').doc(uid).collection('favorites')
          .orderBy('addedAt', descending: true).get();

      if (favSnap.docs.isEmpty) {
        setState(() { _favorites = []; _isLoading = false; });
        return;
      }

      final List<Map<String, dynamic>> products = [];
      for (final doc in favSnap.docs) {
        final productId = doc.data()['productId'] as String? ?? doc.id;
        try {
          final productDoc = await _firestore
              .collection('products').doc(productId).get();
          if (productDoc.exists) {
            final data = productDoc.data()!;
            data['productId']     = productDoc.id;
            data['favoriteDocId'] = doc.id;
            products.add(data);
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() { _favorites = products; _isLoading = false; });
        _animController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  SUPPRESSION
  // ─────────────────────────────────────────────────────────────

  Future<void> _removeFavorite(String favoriteDocId, int index) async {
    try {
      final uid = _currentUser?.uid;
      if (uid == null) return;
      await _firestore
          .collection('users').doc(uid)
          .collection('favorites').doc(favoriteDocId).delete();
      setState(() => _favorites.removeAt(index));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.favorite_border_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(_t('favorites_removed'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
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

  // ─────────────────────────────────────────────────────────────
  //  DIALOG CONFIRMATION SUPPRESSION — appelé au swipe ET au cœur
  // ─────────────────────────────────────────────────────────────

  Future<bool> _showRemoveDialog(
      String favoriteDocId, int index, String productName) async {
    HapticFeedback.mediumImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.18),
                  blurRadius: 40, offset: const Offset(0, 16)),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // ── Top coloré ────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFEF4444)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(children: [
                // Icône animée
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.heart_broken_rounded,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                Text(_t('favorites_remove_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2)),
              ]),
            ),

            // ── Corps ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(children: [
                Text(_t('favorites_remove_desc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14,
                        color: Colors.grey.shade500, height: 1.6)),
                const SizedBox(height: 12),
                // Nom produit
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.shopping_bag_rounded,
                        size: 15, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(productName,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B)))),
                  ]),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(_t('cancel'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFEF4444)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                            color: const Color(0xFFEF4444).withOpacity(0.4),
                            blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(ctx, true),
                        icon: const Icon(Icons.delete_rounded,
                            size: 16, color: Colors.white),
                        label: Text(_t('delete'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );

    if (confirmed == true) {
      await _removeFavorite(favoriteDocId, index);
      return true;
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile    = screenWidth < 600;
    final isTablet    = screenWidth >= 600 && screenWidth < 1200;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      body: SafeArea(
        child: Column(children: [
          _buildHeader(isMobile, isTablet),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _favorites.isEmpty
                ? _buildEmptyState(isMobile, isTablet)
                : _buildFavoritesList(isMobile, isTablet),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  HEADER — premium avec gradient
  // ─────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isMobile, bool isTablet) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Row(children: [
            // Bouton retour
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  AppLocalizations.isRtl
                      ? Icons.arrow_forward_ios_rounded
                      : Icons.arrow_back_ios_new_rounded,
                  size: 18, color: Colors.white,
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Titre + sous-titre
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('favorites_title'),
                    style: TextStyle(
                        fontSize: isMobile ? 20 : 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(
                  _favorites.isEmpty
                      ? _t('favorites_empty_sub')
                      : '${_favorites.length} ${_t('favorites_items_count')}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500),
                ),
              ],
            )),

            // Badge compteur
            if (_favorites.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3), width: 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.favorite_rounded,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 5),
                  Text('${_favorites.length}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  LOADING
  // ─────────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)]),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
                color: const Color(0xFF7C3AED).withOpacity(0.3),
                blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: const Padding(
            padding: EdgeInsets.all(18),
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        Text(_t('loading'), style: TextStyle(
            color: Colors.grey.shade500, fontSize: 14,
            fontWeight: FontWeight.w500)),
      ],
    ));
  }

  // ─────────────────────────────────────────────────────────────
  //  EMPTY STATE
  // ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState(bool isMobile, bool isTablet) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: isMobile ? 110 : 130,
          height: isMobile ? 110 : 130,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFEE2E2), Color(0xFFFECDD3)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
                color: Colors.red.withOpacity(0.12),
                blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Icon(Icons.favorite_border_rounded,
              size: isMobile ? 52 : 62,
              color: const Color(0xFFEF4444).withOpacity(0.7)),
        ),
        const SizedBox(height: 28),
        Text(_t('favorites_empty_title'),
            style: TextStyle(
                fontSize: isMobile ? 20 : 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B)),
            textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Text(_t('favorites_empty_desc'),
            style: TextStyle(fontSize: isMobile ? 14 : 15,
                color: Colors.grey.shade500, height: 1.6),
            textAlign: TextAlign.center),
        const SizedBox(height: 32),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: const Color(0xFF7C3AED).withOpacity(0.4),
                blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: ElevatedButton.icon(
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/home'),
            icon: const Icon(Icons.shopping_bag_outlined,
                color: Colors.white, size: 18),
            label: Text(_t('favorites_browse_btn'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700,
                    fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ]),
    ));
  }

  // ─────────────────────────────────────────────────────────────
  //  GRILLE FAVORIS
  // ─────────────────────────────────────────────────────────────

  Widget _buildFavoritesList(bool isMobile, bool isTablet) {
    return RefreshIndicator(
      color: const Color(0xFF7C3AED),
      onRefresh: _loadFavorites,
      child: GridView.builder(
        padding: EdgeInsets.fromLTRB(
            isMobile ? 14 : 18,
            20,
            isMobile ? 14 : 18,
            24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:  isMobile ? 2 : (isTablet ? 3 : 4),
          crossAxisSpacing: isMobile ? 12 : 16,
          mainAxisSpacing:  isMobile ? 12 : 16,
          childAspectRatio: 0.68,
        ),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          // Animation d'entrée en cascade
          final anim = Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
              parent: _animController,
              curve: Interval(
                (index / _favorites.length) * 0.5,
                ((index + 1) / _favorites.length) * 0.5 + 0.5,
                curve: Curves.easeOutCubic,
              ),
            ),
          );
          return AnimatedBuilder(
            animation: anim,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, 30 * (1 - anim.value)),
              child: Opacity(
                  opacity: anim.value.clamp(0.0, 1.0), child: child),
            ),
            child: _buildProductCard(
                _favorites[index], index, isMobile, isTablet),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  CARTE PRODUIT — redesign premium
  // ─────────────────────────────────────────────────────────────

  Widget _buildProductCard(Map<String, dynamic> product, int index,
      bool isMobile, bool isTablet) {
    final currency = context.watch<CurrencyProvider>();
    final name          = product['name']          as String? ?? '';
    final images        = product['images']        as List<dynamic>?;
    final favoriteDocId = product['favoriteDocId'] as String? ?? '';
    final productId     = product['productId']     as String? ?? '';
    final category      = product['category']      as String? ?? '';
    final di            = _computeDiscount(product);

    return Dismissible(
      key: Key('fav_${productId}_$index'),
      direction: DismissDirection.endToStart,

      // ── Background swipe — révèle une zone rouge
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(left: 40),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFDC2626)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.only(right: 22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.heart_broken_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(height: 6),
              const Text('Retirer',
                  style: TextStyle(color: Colors.white,
                      fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),

      // ── Swipe déclenche le dialog (pas suppression directe)
      confirmDismiss: (direction) async {
        return await _showRemoveDialog(favoriteDocId, index, name);
      },
      onDismissed: (_) {
        // La suppression est déjà faite dans _showRemoveDialog
      },

      child: GestureDetector(
        onTap: () {
          final p = Product(
            id:              productId,
            name:            product['name']        as String? ?? '',
            price:           (product['price']      as num? ?? 0).toDouble(),
            category:        product['category']    as String? ?? '',
            description:     product['description'] as String? ?? '',
            images:          List<String>.from(product['images'] ?? []),
            isActive:        product['isActive']    as bool?   ?? false,
            status:          product['status']      as String? ?? '',
            stock:           (product['stock']      as num?    ?? 0).toInt(),
            sellerId:        product['sellerId']    as String? ?? '',
            discountPercent: (product['discountPercent'] as num?)?.toDouble(),
            discountEndsAt:  (product['discountEndsAt']  as Timestamp?)?.toDate(),
            initialStock:    (product['initialStock']    as num?)?.toInt(),
            hiddenAfterAt:   (product['hiddenAfterAt']   as Timestamp?)?.toDate(),
            reward: product['reward'] != null
                ? Reward.fromMap(product['reward'] as Map<String, dynamic>)
                : null,
            createdAt: (product['createdAt'] as Timestamp?)?.toDate(),
            updatedAt: (product['updatedAt'] as Timestamp?)?.toDate(),
          );
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => ProductDetailPage(product: p)));
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06),
                  blurRadius: 18, offset: const Offset(0, 6)),
              BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.04),
                  blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Image ────────────────────────────────────────
              Expanded(
                flex: 62,
                child: Stack(children: [
                  // Photo
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22)),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: images != null && images.isNotEmpty
                          ? Image.memory(
                          base64Decode(images.first.toString()),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _imagePlaceholder())
                          : _imagePlaceholder(),
                    ),
                  ),

                  // Gradient bas pour lisibilité prix
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(22)),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          stops: const [0.0, 0.55, 1.0],
                          colors: [
                            Colors.black.withOpacity(0.55),
                            Colors.black.withOpacity(0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Badge remise
                  if (di.isActive && di.discountPercent != null)
                    Positioned(
                      top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFEF4444)],
                          ),
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: [BoxShadow(
                              color: const Color(0xFFEF4444).withOpacity(0.4),
                              blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Text(
                          '-${di.discountPercent!.toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 11, fontWeight: FontWeight.w900,
                              letterSpacing: 0.3),
                        ),
                      ),
                    ),

                  // ── Bouton cœur (suppression)
                  Positioned(
                    top: 10, right: 10,
                    child: GestureDetector(
                      onTap: () => _showRemoveDialog(
                          favoriteDocId, index, name),
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(0.14),
                              blurRadius: 10, offset: const Offset(0, 3))],
                        ),
                        child: const Icon(Icons.favorite_rounded,
                            color: Color(0xFFEF4444), size: 16),
                      ),
                    ),
                  ),

                  // ── Badge catégorie en haut gauche (si pas remise)
                  if (!di.isActive && category.isNotEmpty)
                    Positioned(
                      top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(category,
                            style: const TextStyle(color: Colors.white,
                                fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ),

                  // ── Prix en bas de l'image
                  Positioned(
                    bottom: 10, left: 10, right: 10,
                    child: di.isActive
                        ? Row(children: [
                      // Prix barré
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          currency.formatPrice(di.originalPrice),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 9,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Prix remisé
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF059669), Color(0xFF10B981)]),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(
                              color: const Color(0xFF059669).withOpacity(0.45),
                              blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Text(
                          currency.formatPrice(di.effectivePrice),
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 12 : 13,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ])
                        : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)]),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(
                            color: const Color(0xFF7C3AED).withOpacity(0.45),
                            blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Text(
                        currency.formatPrice(di.effectivePrice),
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 12 : 13,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ]),
              ),

              // ── Infos texte ───────────────────────────────────
              Expanded(
                flex: 38,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [

                      // Nom
                      Text(name,
                          style: TextStyle(
                              fontSize: isMobile ? 13 : 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                              height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),

                      // Bas : swipe hint + flèche
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Hint swipe discret
                          Row(children: [
                            Icon(Icons.swipe_left_rounded,
                                size: 12, color: Colors.grey.shade400),
                            const SizedBox(width: 3),
                            Text(_t('swipe_to_remove'),
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade400,
                                    fontWeight: FontWeight.w500)),
                          ]),
                          // Bouton voir
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)]),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.arrow_back_ios_rounded,
                                size: 10, color: Colors.white),
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

  Widget _imagePlaceholder() => Container(
    color: const Color(0xFFF1F5F9),
    child: Center(
      child: Icon(Icons.image_outlined,
          color: Colors.grey.shade300, size: 42),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
//  _DiscountInfo
// ─────────────────────────────────────────────────────────────────

class _DiscountInfo {
  final double  originalPrice;
  final double  effectivePrice;
  final bool    isActive;
  final double? discountPercent;

  const _DiscountInfo({
    required this.originalPrice,
    required this.effectivePrice,
    required this.isActive,
    this.discountPercent,
  });
}
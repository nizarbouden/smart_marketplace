import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';
import 'add_product_page.dart'; // à créer

class SellerProductsPage extends StatefulWidget {
  const SellerProductsPage({super.key});

  @override
  State<SellerProductsPage> createState() => _SellerProductsPageState();
}

class _SellerProductsPageState extends State<SellerProductsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _t(String key) => AppLocalizations.get(key);
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildAppBar(),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('products')
            .where('sellerId', isEqualTo: _currentUser?.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF16A34A)),
            );
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return _buildEmptyState();

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              if (isWide) {
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 420,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.9,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return _buildProductCard(
                        doc.id, doc.data() as Map<String, dynamic>);
                  },
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  return _buildProductCard(
                      doc.id, doc.data() as Map<String, dynamic>);
                },
              );
            },
          );
        },
      ),
      // ── FAB : simple + icon seulement ────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: _goToAddProduct,
        backgroundColor: const Color(0xFF16A34A),
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF16A34A),
      elevation: 0,
      title: Text(
        _t('seller_products_title'),
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
      ),
      actions: [
        // Notification icon remplace le + de l'appBar
        Stack(
          children: [
            IconButton(
              onPressed: () {
                // TODO: ouvrir les notifications
              },
              icon: const Icon(Icons.notifications_outlined,
                  color: Colors.white, size: 26),
            ),
            // Badge
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFBBF24),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ── Navigation vers AddProductPage ──────────────────────────
  void _goToAddProduct({String? docId, Map<String, dynamic>? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductPage(docId: docId, existing: existing),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF16A34A).withOpacity(0.15),
                    const Color(0xFF22C55E).withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inventory_2_rounded,
                  size: 52, color: Color(0xFF16A34A)),
            ),
            const SizedBox(height: 24),
            Text(
              _t('seller_no_products'),
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _t('seller_no_products_subtitle'),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _goToAddProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(_t('seller_add_first_product'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Product card ──────────────────────────────────────────────
  Widget _buildProductCard(String docId, Map<String, dynamic> data) {
    final name     = data['name']     as String? ?? '';
    final price    = (data['price']   as num? ?? 0).toDouble();
    final stock    = data['stock']    as int?    ?? 0;
    final isActive = data['isActive'] as bool?   ?? true;
    final hasReward = data['reward']  != null;

    // Image : Base64 list ou imageUrl legacy
    final images = (data['images'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();
    final legacyUrl = data['imageUrl'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Image ────────────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft:    Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
            child: _buildCardImage(images, legacyUrl),
          ),

          // ── Info ─────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + status
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1E293B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildStatusBadge(isActive),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Price
                  Text(
                    '${price.toStringAsFixed(2)} TND',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16A34A)),
                  ),

                  const SizedBox(height: 4),

                  // Stock
                  Row(
                    children: [
                      Icon(Icons.layers_rounded,
                          size: 13, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        '${_t('seller_stock')}: $stock',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500]),
                      ),
                      if (hasReward) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.card_giftcard_rounded,
                                  size: 11, color: Color(0xFFF59E0B)),
                              SizedBox(width: 3),
                              Text('Reward',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFFF59E0B),
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Actions
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildActionBtn(
                        icon: Icons.edit_rounded,
                        color: const Color(0xFF3B82F6),
                        onTap: () =>
                            _goToAddProduct(docId: docId, existing: data),
                      ),
                      _buildActionBtn(
                        icon: isActive
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: const Color(0xFFF59E0B),
                        onTap: () => _toggleStatus(docId, !isActive),
                      ),
                      _buildActionBtn(
                        icon: Icons.delete_rounded,
                        color: const Color(0xFFEF4444),
                        onTap: () => _confirmDelete(docId),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardImage(List<String>? images, String? legacyUrl) {
    if (images != null && images.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(images.first),
          width: 105, height: 120,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _imagePlaceholder(),
        );
      } catch (_) {}
    }
    if (legacyUrl != null) {
      return Image.network(
        legacyUrl,
        width: 105, height: 120,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      );
    }
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 105, height: 120,
      color: const Color(0xFFF0FDF4),
      child: const Icon(Icons.image_rounded,
          color: Color(0xFF16A34A), size: 36),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isActive ? _t('seller_product_active') : _t('seller_product_inactive'),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isActive
              ? const Color(0xFF16A34A)
              : const Color(0xFFF59E0B),
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Future<void> _toggleStatus(String docId, bool isActive) async {
    await _firestore
        .collection('products')
        .doc(docId)
        .update({'isActive': isActive});
  }

  void _confirmDelete(String docId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(_t('seller_delete_product_title')),
        content: Text(_t('seller_delete_product_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _firestore.collection('products').doc(docId).delete();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            child: Text(_t('delete'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../localization/app_localizations.dart';
import '../payment/checkout_page.dart';

// ── Model interne ─────────────────────────────────────────────────
class _CartItem {
  final String productId;
  final String cartDocId;
  final String name;
  final double price;
  final int stock;
  final String sellerId;
  final String storeName;
  final List<String> images;
  int quantity;
  bool isSelected;

  _CartItem({
    required this.productId,
    required this.cartDocId,
    required this.name,
    required this.price,
    required this.stock,
    required this.sellerId,
    required this.storeName,
    required this.images,
    required this.quantity,
    this.isSelected = false,
  });
}

// ── Page ──────────────────────────────────────────────────────────
class CartPage extends StatefulWidget {
  final Function(int)? onTotalCartItemsChanged;
  final Function(int, double)? onCartSelectionChanged;

  const CartPage({super.key, this.onTotalCartItemsChanged, this.onCartSelectionChanged});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<_CartItem> _cartItems = [];
  bool _isLoading = true;
  bool _showSummaryOverlay = false;

  User? get _currentUser => _auth.currentUser;
  String _t(String key) => AppLocalizations.get(key);

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  // ── Chargement du panier ──────────────────────────────────────
  Future<void> _loadCart() async {
    setState(() => _isLoading = true);
    try {
      final uid = _currentUser?.uid;
      if (uid == null) { setState(() => _isLoading = false); return; }

      final cartSnap = await _firestore
          .collection('users').doc(uid).collection('cart')
          .orderBy('addedAt', descending: true)
          .get();

      if (cartSnap.docs.isEmpty) {
        setState(() { _cartItems = []; _isLoading = false; });
        return;
      }

      final List<_CartItem> items = [];

      for (final doc in cartSnap.docs) {
        final data = doc.data();
        final productId = data['productId'] as String? ?? doc.id;
        final quantity  = (data['quantity'] as num? ?? 1).toInt();

        try {
          // Récupérer le produit
          final productDoc = await _firestore.collection('products').doc(productId).get();
          if (!productDoc.exists) continue;
          final p = productDoc.data()!;

          final sellerId = p['sellerId'] as String? ?? '';
          String storeName = '';

          // Récupérer le storeName du vendeur
          if (sellerId.isNotEmpty) {
            try {
              final sellerDoc = await _firestore
                  .collection('users')
                  .doc(sellerId)
                  .get();

              if (sellerDoc.exists) {
                final sellerData = sellerDoc.data();
                storeName = (sellerData?['storeName'] as String?)?.trim() ?? '';
                debugPrint('🏪 Seller [$sellerId] storeName: "$storeName"');
              } else {
                debugPrint('❌ Seller doc [$sellerId] introuvable');
              }
            } catch (e) {
              debugPrint('❌ Erreur seller: $e');
            }
          }

          items.add(_CartItem(
            productId: productId,
            cartDocId: doc.id,
            name: p['name'] as String? ?? '',
            price: (p['price'] as num? ?? 0).toDouble(),
            stock: (p['stock'] as num? ?? 0).toInt(),
            sellerId: sellerId,
            storeName: storeName.isNotEmpty ? storeName : _t('unknown_store'),
            images: List<String>.from(p['images'] ?? []),
            quantity: quantity,
          ));
        } catch (_) {}
      }

      if (mounted) {
        setState(() { _cartItems = items; _isLoading = false; });
        _notifyParent();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Mise à jour quantité Firestore ────────────────────────────
  Future<void> _updateQuantityFirestore(String cartDocId, int newQty) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('users').doc(uid).collection('cart').doc(cartDocId)
        .update({'quantity': newQty, 'updatedAt': Timestamp.now()});
  }

  // ── Suppression Firestore ─────────────────────────────────────
  Future<void> _removeItemFirestore(String cartDocId) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('users').doc(uid).collection('cart').doc(cartDocId)
        .delete();
  }

  // ── Actions locales + sync ────────────────────────────────────
  void _updateQuantity(int index, int newQty) {
    if (newQty < 1 || newQty > _cartItems[index].stock) return;
    setState(() => _cartItems[index].quantity = newQty);
    _updateQuantityFirestore(_cartItems[index].cartDocId, newQty);
    _notifyParent();
  }

  void _removeItem(int index) {
    final cartDocId = _cartItems[index].cartDocId;
    setState(() => _cartItems.removeAt(index));
    _removeItemFirestore(cartDocId);
    _notifyParent();
  }

  void _toggleItemSelection(int index) {
    setState(() => _cartItems[index].isSelected = !_cartItems[index].isSelected);
    _notifyParent();
  }

  void _toggleVendorSelection(String storeName) {
    final vendorItems = _cartItems.where((i) => i.storeName == storeName).toList();
    final allSelected = vendorItems.every((i) => i.isSelected);
    setState(() {
      for (final item in vendorItems) item.isSelected = !allSelected;
    });
    _notifyParent();
  }

  void _toggleAllSelection() {
    final allSelected = _cartItems.every((i) => i.isSelected);
    setState(() {
      for (final item in _cartItems) item.isSelected = !allSelected;
    });
    _notifyParent();
  }

  void _notifyParent() {
    widget.onTotalCartItemsChanged?.call(_cartItems.length);
    widget.onCartSelectionChanged?.call(_selectedCount, _selectedTotal);
  }

  // ── Getters ───────────────────────────────────────────────────
  int get _selectedCount => _cartItems.where((i) => i.isSelected).length;
  double get _selectedTotal => _cartItems
      .where((i) => i.isSelected)
      .fold(0.0, (sum, i) => sum + i.price * i.quantity);

  Map<String, List<_CartItem>> get _grouped {
    final map = <String, List<_CartItem>>{};
    for (final item in _cartItems) {
      (map[item.storeName] ??= []).add(item);
    }
    return map;
  }

  // ── BUILD ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isRtl    = AppLocalizations.isRtl;
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: _isLoading
            ? _buildLoading()
            : Stack(
          children: [
            RefreshIndicator(
              color: Colors.deepPurple,
              onRefresh: _loadCart,
              child: _cartItems.isEmpty
                  ? _buildEmptyCart(isTablet)
                  : ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 24 : 16,
                  isTablet ? 30 : 20,
                  isTablet ? 24 : 16,
                  100,
                ),
                itemCount: _grouped.keys.length,
                itemBuilder: (context, i) {
                  final storeName = _grouped.keys.elementAt(i);
                  return _buildVendorSection(storeName, _grouped[storeName]!, isTablet);
                },
              ),
            ),

            // Barre de sélection bas
            if (_cartItems.isNotEmpty)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: _buildBottomBar(isTablet),
              ),

            // Overlay résumé
            if (_showSummaryOverlay) _buildSummaryOverlay(),
          ],
        ),
      ),
    );
  }

  // ── Loading ───────────────────────────────────────────────────
  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Colors.deepPurple),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(_t('loading'), style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ],
      ),
    );
  }

  // ── Empty ─────────────────────────────────────────────────────
  Widget _buildEmptyCart(bool isTablet) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isTablet ? 120 : 100,
                height: isTablet ? 120 : 100,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shopping_cart_outlined,
                    size: isTablet ? 60 : 48, color: Colors.deepPurple.withOpacity(0.4)),
              ),
              const SizedBox(height: 24),
              Text(_t('empty_cart'),
                  style: TextStyle(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  )),
              const SizedBox(height: 8),
              Text(_t('empty_cart_desc'),
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ],
    );
  }

  // ── Section vendeur ───────────────────────────────────────────
  Widget _buildVendorSection(String storeName, List<_CartItem> items, bool isTablet) {
    final allSelected = items.every((i) => i.isSelected);

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header boutique
          GestureDetector(
            onTap: () => _toggleVendorSelection(storeName),
            child: Container(
              padding: EdgeInsets.all(isTablet ? 16 : 14),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.04),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  // Checkbox vendeur
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: allSelected ? Colors.deepPurple : Colors.transparent,
                      border: Border.all(
                        color: allSelected ? Colors.deepPurple : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: allSelected
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.storefront_rounded, size: 18, color: Colors.deepPurple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      storeName,
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${items.length} ${items.length > 1 ? _t('articles') : _t('article')}',
                      style: TextStyle(
                        color: Colors.deepPurple.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // Articles
          ...items.map((item) {
            final index = _cartItems.indexOf(item);
            return _buildCartItemCard(item, index, isTablet);
          }),
        ],
      ),
    );
  }

  // ── Carte article ─────────────────────────────────────────────
  Widget _buildCartItemCard(_CartItem item, int index, bool isTablet) {
    final imageBytes = item.images.isNotEmpty
        ? (() { try { return base64Decode(item.images.first); } catch (_) { return null; } })()
        : null;

    return Padding(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox item
          GestureDetector(
            onTap: () => _toggleItemSelection(index),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22, height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.isSelected ? Colors.deepPurple : Colors.transparent,
                  border: Border.all(
                    color: item.isSelected ? Colors.deepPurple : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: item.isSelected
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: isTablet ? 100 : 82,
              height: isTablet ? 100 : 82,
              color: Colors.grey.shade100,
              child: imageBytes != null
                  ? Image.memory(imageBytes, fit: BoxFit.cover)
                  : Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 32),
            ),
          ),
          const SizedBox(width: 12),

          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom
                Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: isTablet ? 16 : 14,
                    color: const Color(0xFF1E293B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Prix
                Text(
                  '\$${item.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w800,
                    fontSize: isTablet ? 16 : 15,
                  ),
                ),
                const SizedBox(height: 10),

                // Quantité + supprimer
                Row(
                  children: [
                    // Contrôle quantité
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _QtyBtn(
                            icon: Icons.remove_rounded,
                            onTap: item.quantity > 1 ? () => _updateQuantity(index, item.quantity - 1) : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                            ),
                          ),
                          _QtyBtn(
                            icon: Icons.add_rounded,
                            onTap: item.quantity < item.stock ? () => _updateQuantity(index, item.quantity + 1) : null,
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Supprimer
                    GestureDetector(
                      onTap: () => _removeItem(index),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Icon(Icons.delete_outline_rounded,
                            color: Colors.red.shade400, size: isTablet ? 22 : 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Barre de bas ──────────────────────────────────────────────
  Widget _buildBottomBar(bool isTablet) {
    final allSelected = _cartItems.isNotEmpty && _cartItems.every((i) => i.isSelected);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          // Tout sélectionner
          GestureDetector(
            onTap: _toggleAllSelection,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: allSelected ? Colors.deepPurple : Colors.transparent,
                    border: Border.all(
                      color: allSelected ? Colors.deepPurple : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: allSelected
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(_t('select_all'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              ],
            ),
          ),

          const Spacer(),

          // Total + bouton commande
          if (_selectedCount > 0) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '\$${_selectedTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900, color: Colors.deepPurple),
                ),
                Text(
                  '${_selectedCount} ${_selectedCount > 1 ? _t('articles') : _t('article')}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => setState(() => _showSummaryOverlay = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.deepPurple, Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.35),
                      blurRadius: 10, offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _t('order'),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Overlay résumé ────────────────────────────────────────────
  Widget _buildSummaryOverlay() {
    final selectedItems = _cartItems.where((i) => i.isSelected).toList();
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => setState(() => _showSummaryOverlay = false),
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),
        ),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.55,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -5))],
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Text(_t('summary'),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _showSummaryOverlay = false),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100, shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                const Divider(height: 1),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Miniatures
                        SizedBox(
                          height: 90,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: selectedItems.length,
                            itemBuilder: (context, i) {
                              final item = selectedItems[i];
                              final bytes = item.images.isNotEmpty
                                  ? (() { try { return base64Decode(item.images.first); } catch (_) { return null; } })()
                                  : null;
                              return Container(
                                width: 70,
                                height: 70,
                                margin: const EdgeInsets.only(right: 10),
                                child: Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 70,
                                        height: 54, // ✅ taille fixe pour toutes les images
                                        child: Container(
                                          color: Colors.grey.shade100,
                                          child: bytes != null
                                              ? Image.memory(bytes, fit: BoxFit.cover, width: 70, height: 54)
                                              : Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 28),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\$${item.price.toStringAsFixed(0)} x${item.quantity}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Résumé prix
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              _summaryRow(_t('cart_title'), '\$${_selectedTotal.toStringAsFixed(2)}'),
                              _summaryRow(_t('reductions'), '-\$${(_selectedTotal * 0.1).toStringAsFixed(2)}',
                                  valueColor: Colors.green),
                              _summaryRow(_t('subtotal'), '\$${(_selectedTotal * 0.9).toStringAsFixed(2)}'),
                              const Divider(height: 16),
                              _summaryRow(_t('shipping'), '\$5.00'),
                              const SizedBox(height: 4),
                              _summaryRow(
                                _t('estimated_total'),
                                '\$${(_selectedTotal * 0.9 + 5.0).toStringAsFixed(2)}',
                                isBold: true, isLarge: true,
                                valueColor: Colors.deepPurple,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bouton confirmer
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottomPad),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _showSummaryOverlay = false);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CheckoutPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                        shadowColor: Colors.deepPurple.withOpacity(0.4),
                      ),
                      child: Text(_t('go_to_payment'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value,
      {bool isBold = false, bool isLarge = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: isLarge ? 16 : 14,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
                color: const Color(0xFF475569),
              )),
          Text(value,
              style: TextStyle(
                fontSize: isLarge ? 16 : 14,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                color: valueColor ?? const Color(0xFF1E293B),
              )),
        ],
      ),
    );
  }
}

// ── Bouton quantité ───────────────────────────────────────────────
class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: enabled ? Colors.deepPurple.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16,
            color: enabled ? Colors.deepPurple : Colors.grey.shade400),
      ),
    );
  }
}
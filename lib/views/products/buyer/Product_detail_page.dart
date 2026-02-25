import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/product_model.dart';


class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _currentImageIndex = 0;
  late PageController _pageController;

  bool _isFavorite = false;
  bool _isAddingToCart = false;
  bool _loadingFavorite = true;
  int _quantity = 1;

  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;
  late AnimationController _cartCtrl;
  late Animation<double> _cartBounce;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  User? get _currentUser => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _heartCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _heartScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _heartCtrl, curve: Curves.easeOut));

    _cartCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _cartBounce = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _cartCtrl, curve: Curves.easeOut));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    if (_currentUser == null) {
      setState(() => _loadingFavorite = false);
      return;
    }
    try {
      final doc = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('favorites')
          .doc(widget.product.id)
          .get();
      setState(() {
        _isFavorite = doc.exists;
        _loadingFavorite = false;
      });
    } catch (_) {
      setState(() => _loadingFavorite = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_currentUser == null) {
      _showLoginSnack();
      return;
    }
    _heartCtrl.forward(from: 0);
    setState(() => _isFavorite = !_isFavorite);
    final favRef = _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('favorites')
        .doc(widget.product.id);
    try {
      if (_isFavorite) {
        await favRef.set({
          'productId': widget.product.id,
          'addedAt': Timestamp.now(),
        });
      } else {
        await favRef.delete();
      }
    } catch (_) {
      setState(() => _isFavorite = !_isFavorite);
    }
  }

  Future<void> _addToCart() async {
    if (_currentUser == null) {
      _showLoginSnack();
      return;
    }
    if (widget.product.stock <= 0) return;

    setState(() => _isAddingToCart = true);
    _cartCtrl.forward(from: 0);

    try {
      final cartRef = _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('cart')
          .doc(widget.product.id);

      final existing = await cartRef.get();
      if (existing.exists) {
        await cartRef.update({
          'quantity': (existing.data()?['quantity'] ?? 0) + _quantity,
          'updatedAt': Timestamp.now(),
        });
      } else {
        await cartRef.set({
          'productId': widget.product.id,
          'quantity': _quantity,
          'addedAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });
      }

      if (mounted) {
        _showSnack(
          'Produit ajouté au panier 🛒',
          color: const Color(0xFF16A34A),
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (_) {
      _showSnack('Erreur lors de l\'ajout au panier',
          color: Colors.red, icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  void _showSnack(String msg,
      {Color color = Colors.black87, IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
            ],
            Text(msg,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLoginSnack() {
    _showSnack('Connectez-vous pour continuer',
        color: Colors.deepPurple, icon: Icons.lock_rounded);
  }

  Uint8List? _decodeImage(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    try {
      return base64Decode(base64Str);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _heartCtrl.dispose();
    _cartCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── BUILD ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final isOutOfStock = product.stock <= 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // ── Image sliver ──
                SliverToBoxAdapter(child: _buildImageCarousel(product)),

                // ── Content ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        20, 0, 20, 120 + bottomPad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _buildTitleRow(product),
                        const SizedBox(height: 16),
                        _buildPriceAndStock(product),
                        const SizedBox(height: 20),
                        _buildCategoryBadge(product),
                        const SizedBox(height: 24),
                        _buildQuantitySelector(product),
                        const SizedBox(height: 24),
                        _buildDivider('Description'),
                        const SizedBox(height: 12),
                        _buildDescription(product),
                        if (product.reward != null) ...[
                          const SizedBox(height: 28),
                          _buildRewardSection(product),
                        ],
                        const SizedBox(height: 28),
                        _buildInfoRow(product),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Bottom bar ──
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomBar(isOutOfStock, bottomPad),
            ),
          ],
        ),
      ),
    );
  }

  // ── IMAGE CAROUSEL ───────────────────────────────────────────────

  Widget _buildImageCarousel(Product product) {
    final images = product.images;
    final height = MediaQuery.of(context).size.height * 0.48;

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // Images
          images.isEmpty
              ? Container(
            color: Colors.grey.shade100,
            child: const Center(
              child: Icon(Icons.image_outlined,
                  size: 64, color: Colors.grey),
            ),
          )
              : PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (i) =>
                setState(() => _currentImageIndex = i),
            itemBuilder: (context, index) {
              final bytes = _decodeImage(images[index]);
              return bytes != null
                  ? Image.memory(bytes, fit: BoxFit.cover,
                  width: double.infinity)
                  : Container(
                color: Colors.grey.shade100,
                child: const Icon(Icons.broken_image_outlined,
                    size: 48, color: Colors.grey),
              );
            },
          ),

          // Gradient overlay top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Gradient overlay bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 80,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFFF5F6FA),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: _CircleButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ),

          // ❤️ Favorite button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: ScaleTransition(
              scale: _heartScale,
              child: _loadingFavorite
                  ? const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white))),
              )
                  : _CircleButton(
                icon: _isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                iconColor: _isFavorite ? Colors.red : Colors.white,
                onTap: _toggleFavorite,
              ),
            ),
          ),

          // Image dots indicator
          if (images.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentImageIndex == i ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _currentImageIndex == i
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

          // Image count badge
          if (images.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentImageIndex + 1} / ${images.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── TITLE ROW ────────────────────────────────────────────────────

  Widget _buildTitleRow(Product product) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            product.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  // ── PRICE & STOCK ────────────────────────────────────────────────

  Widget _buildPriceAndStock(Product product) {
    final isOutOfStock = product.stock <= 0;
    return Row(
      children: [
        Text(
          '${product.price.toStringAsFixed(2)} DT',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF16A34A),
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isOutOfStock
                ? Colors.red.shade50
                : Colors.green.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOutOfStock
                  ? Colors.red.shade200
                  : Colors.green.shade200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOutOfStock
                    ? Icons.remove_circle_outline
                    : Icons.check_circle_outline,
                size: 14,
                color: isOutOfStock
                    ? Colors.red.shade600
                    : Colors.green.shade700,
              ),
              const SizedBox(width: 5),
              Text(
                isOutOfStock ? 'Épuisé' : '${product.stock} en stock',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isOutOfStock
                      ? Colors.red.shade700
                      : Colors.green.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── CATEGORY BADGE ───────────────────────────────────────────────

  Widget _buildCategoryBadge(Product product) {
    return Row(
      children: [
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.deepPurple.shade100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.category_rounded,
                  size: 14, color: Colors.deepPurple.shade400),
              const SizedBox(width: 6),
              Text(
                product.category,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepPurple.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── QUANTITY SELECTOR ────────────────────────────────────────────

  Widget _buildQuantitySelector(Product product) {
    final isOutOfStock = product.stock <= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'Quantité',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const Spacer(),
          // Minus
          _QuantityButton(
            icon: Icons.remove_rounded,
            onTap: isOutOfStock || _quantity <= 1
                ? null
                : () => setState(() => _quantity--),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '$_quantity',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          // Plus
          _QuantityButton(
            icon: Icons.add_rounded,
            onTap: isOutOfStock || _quantity >= product.stock
                ? null
                : () => setState(() => _quantity++),
          ),
        ],
      ),
    );
  }

  // ── DESCRIPTION ──────────────────────────────────────────────────

  Widget _buildDescription(Product product) {
    if (product.description.isEmpty) {
      return Text(
        'Aucune description disponible.',
        style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade400,
            fontStyle: FontStyle.italic),
      );
    }
    return Text(
      product.description,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF475569),
        height: 1.7,
      ),
    );
  }

  // ── REWARD SECTION ───────────────────────────────────────────────

  Widget _buildRewardSection(Product product) {
    final reward = product.reward!;
    final rewardImageBytes = _decodeImage(reward.image);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFFBBF24).withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF59E0B),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.card_giftcard_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎁 Reward inclus',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Un cadeau vous attend avec ce produit !',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded,
                          color: Colors.white, size: 12),
                      SizedBox(width: 3),
                      Text('Offert',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Reward image
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFFBBF24).withOpacity(0.4),
                        width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: rewardImageBytes != null
                        ? Image.memory(rewardImageBytes, fit: BoxFit.cover)
                        : const Icon(Icons.card_giftcard_rounded,
                        color: Color(0xFFF59E0B), size: 36),
                  ),
                ),
                const SizedBox(width: 16),

                // Reward details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Votre cadeau',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB45309),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reward.name ?? 'Cadeau surprise',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 14, color: Color(0xFFB45309)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Reward offert à l\'achat de ce produit',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFB45309),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── INFO ROW ─────────────────────────────────────────────────────

  Widget _buildInfoRow(Product product) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _InfoTile(
            icon: Icons.verified_rounded,
            iconColor: Colors.green,
            label: 'Statut',
            value: product.status == 'approved' ? 'Approuvé ✓' : product.status,
          ),
          const Divider(height: 20),
          _InfoTile(
            icon: Icons.inventory_2_rounded,
            iconColor: Colors.blue,
            label: 'Stock disponible',
            value: '${product.stock} unités',
          ),
          if (product.updatedAt != null) ...[
            const Divider(height: 20),
            _InfoTile(
              icon: Icons.update_rounded,
              iconColor: Colors.orange,
              label: 'Dernière mise à jour',
              value: _formatDate(product.updatedAt!),
            ),
          ],
        ],
      ),
    );
  }

  // ── BOTTOM BAR ───────────────────────────────────────────────────

  Widget _buildBottomBar(bool isOutOfStock, double bottomPad) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ❤️ Favorite button (standalone)
          ScaleTransition(
            scale: _heartScale,
            child: GestureDetector(
              onTap: _toggleFavorite,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _isFavorite
                      ? Colors.red.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isFavorite
                        ? Colors.red.shade200
                        : Colors.grey.shade200,
                  ),
                ),
                child: Icon(
                  _isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _isFavorite ? Colors.red : Colors.grey.shade500,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 🛒 Add to cart button
          Expanded(
            child: ScaleTransition(
              scale: _cartBounce,
              child: ElevatedButton(
                onPressed: isOutOfStock || _isAddingToCart ? null : _addToCart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOutOfStock
                      ? Colors.grey.shade300
                      : const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: isOutOfStock ? 0 : 4,
                  shadowColor:
                  const Color(0xFF16A34A).withOpacity(0.35),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isAddingToCart
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_cart_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isOutOfStock
                          ? 'Produit épuisé'
                          : 'Ajouter au panier · ${(_quantity * widget.product.price).toStringAsFixed(2)} DT',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────

  Widget _buildDivider(String label) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

// ── SUB-WIDGETS ──────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          shape: BoxShape.circle,
          border:
          Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Icon(icon, color: iconColor ?? Colors.white, size: 20),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QuantityButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFF16A34A).withOpacity(0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled
                ? const Color(0xFF16A34A).withOpacity(0.3)
                : Colors.grey.shade200,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? const Color(0xFF16A34A)
              : Colors.grey.shade400,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500),
            ),
            Text(
              value,
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';
import '../../../models/product_categories.dart';
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

  // Timers
  Timer? _visibilityTimer;
  String _visibilityLabel = '';
  bool _visibilityUrgent = false;

  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;
  late AnimationController _cartCtrl;
  late Animation<double> _cartBounce;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  User? get _currentUser => _auth.currentUser;
  String _t(String key) => AppLocalizations.get(key);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _heartCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _heartScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _heartCtrl, curve: Curves.easeOut));

    _cartCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _cartBounce = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _cartCtrl, curve: Curves.easeOut));

    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.03)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _checkFavorite();
    _startVisibilityTimer();
  }

  // ── Visibility countdown ─────────────────────────────────────────

  void _startVisibilityTimer() {
    final p = widget.product;
    if (p.hiddenAfterAt == null) return;
    _updateVisibilityLabel();
    _visibilityTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateVisibilityLabel();
    });
  }

  void _updateVisibilityLabel() {
    final p = widget.product;
    if (p.hiddenAfterAt == null) return;
    final now = DateTime.now();
    final diff = p.hiddenAfterAt!.difference(now);
    if (diff.isNegative || diff.inSeconds <= 0) {
      _visibilityTimer?.cancel();
      setState(() { _visibilityLabel = ''; });
      return;
    }
    setState(() {
      _visibilityLabel = _formatDuration(diff);
      _visibilityUrgent = diff.inHours < 24;
    });
  }

  String _formatDuration(Duration d) {
    if (d.isNegative || d.inSeconds <= 0) return '0s';
    if (d.inDays > 0) { final h = d.inHours % 24; return h > 0 ? '${d.inDays}j ${h}h' : '${d.inDays}j'; }
    if (d.inHours > 0) { final m = d.inMinutes % 60; return m > 0 ? '${d.inHours}h ${m}min' : '${d.inHours}h'; }
    if (d.inMinutes > 0) { final s = d.inSeconds % 60; return s > 0 ? '${d.inMinutes}min ${s}s' : '${d.inMinutes}min'; }
    return '${d.inSeconds}s';
  }

  // ── Discount countdown ───────────────────────────────────────────

  String _discountCountdownLabel() {
    final p = widget.product;
    if (!p.isDiscountActive || p.discountEndsAt == null) return '';
    final diff = p.discountEndsAt!.difference(DateTime.now());
    if (diff.isNegative || diff.inSeconds <= 0) return '';
    return _formatDuration(diff);
  }

  // ────────────────────────────────────────────────────────────────

  Future<void> _checkFavorite() async {
    if (_currentUser == null) { setState(() => _loadingFavorite = false); return; }
    try {
      final doc = await _firestore
          .collection('users').doc(_currentUser!.uid)
          .collection('favorites').doc(widget.product.id).get();
      setState(() { _isFavorite = doc.exists; _loadingFavorite = false; });
    } catch (_) { setState(() => _loadingFavorite = false); }
  }

  Future<void> _toggleFavorite() async {
    if (_currentUser == null) { _showLoginSnack(); return; }
    _heartCtrl.forward(from: 0);
    setState(() => _isFavorite = !_isFavorite);
    final favRef = _firestore.collection('users').doc(_currentUser!.uid)
        .collection('favorites').doc(widget.product.id);
    try {
      if (_isFavorite) {
        await favRef.set({'productId': widget.product.id, 'addedAt': Timestamp.now()});
      } else { await favRef.delete(); }
    } catch (_) { setState(() => _isFavorite = !_isFavorite); }
  }

  Future<void> _addToCart() async {
    if (_currentUser == null) { _showLoginSnack(); return; }
    if (widget.product.stock <= 0) return;
    setState(() => _isAddingToCart = true);
    _cartCtrl.forward(from: 0);
    try {
      final cartRef = _firestore.collection('users').doc(_currentUser!.uid)
          .collection('cart').doc(widget.product.id);
      final existing = await cartRef.get();
      if (existing.exists) {
        if (mounted) _showSnack(_t('detail_already_in_cart'), color: Colors.orange.shade700, icon: Icons.shopping_cart_outlined);
        return;
      }
      await cartRef.set({
        'productId': widget.product.id, 'quantity': _quantity,
        'addedAt': Timestamp.now(), 'updatedAt': Timestamp.now(),
      });
      if (mounted) _showSnack(_t('detail_added_to_cart'), color: const Color(0xFF16A34A), icon: Icons.check_circle_rounded);
    } catch (_) {
      _showSnack(_t('detail_add_to_cart_error'), color: Colors.red, icon: Icons.error_outline);
    } finally { if (mounted) setState(() => _isAddingToCart = false); }
  }

  void _showSnack(String msg, {Color color = Colors.black87, IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        if (icon != null) ...[Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 8)],
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  void _showLoginSnack() => _showSnack(_t('detail_login_required'), color: Colors.deepPurple, icon: Icons.lock_rounded);

  Uint8List? _decodeImage(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try { return base64Decode(b64); } catch (_) { return null; }
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    _pageController.dispose();
    _heartCtrl.dispose();
    _cartCtrl.dispose();
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final isOutOfStock = product.stock <= 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildImageCarousel(product)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 130 + bottomPad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),

                        // ── Nom ──────────────────────────────────
                        _buildTitleRow(product),
                        const SizedBox(height: 8),

                        // ── Catégorie ────────────────────────────
                        _buildCategoryBadge(product),
                        const SizedBox(height: 20),

                        // ── Prix (avec remise si active) ─────────
                        _buildPriceBlock(product),
                        const SizedBox(height: 20),

                        // ── Stock progress bar ───────────────────
                        _buildStockProgressBar(product),
                        const SizedBox(height: 20),

                        // ── Chrono visibilité ────────────────────
                        if (_visibilityLabel.isNotEmpty) ...[
                          _buildVisibilityBanner(),
                          const SizedBox(height: 20),
                        ],

                        // ── Sélecteur quantité ───────────────────
                        _buildQuantitySelector(product),
                        const SizedBox(height: 28),

                        // ── Description ──────────────────────────
                        _buildSectionTitle(_t('detail_description')),
                        const SizedBox(height: 12),
                        _buildDescription(product),

                        // ── Reward ───────────────────────────────
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
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildBottomBar(isOutOfStock, bottomPad),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // IMAGE CAROUSEL
  // ══════════════════════════════════════════════════════════════════

  Widget _buildImageCarousel(Product product) {
    final images = product.images;
    final topPad = MediaQuery.of(context).padding.top;
    final height = MediaQuery.of(context).size.height * 0.46 + topPad;

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // Images
          Positioned.fill(
            child: images.isEmpty
                ? Container(
              color: const Color(0xFFF1F5F9),
              child: Center(child: Icon(Icons.image_outlined, size: 64, color: Colors.grey.shade300)),
            )
                : PageView.builder(
              controller: _pageController,
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _currentImageIndex = i),
              itemBuilder: (_, index) {
                final bytes = _decodeImage(images[index]);
                return bytes != null
                    ? Image.memory(bytes, fit: BoxFit.cover, width: double.infinity)
                    : Container(color: const Color(0xFFF1F5F9),
                    child: const Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey));
              },
            ),
          ),

          // Gradient top (status bar)
          Positioned(
            top: 0, left: 0, right: 0,
            height: topPad + 90,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
          ),

          // Gradient bottom (page fade)
          Positioned(
            bottom: 0, left: 0, right: 0, height: 100,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Color(0xFFF4F6FB), Colors.transparent],
                ),
              ),
            ),
          ),

          // Bouton retour
          Positioned(
            top: topPad + 10, left: 16,
            child: _CircleButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Navigator.pop(context)),
          ),

          // Favori
          Positioned(
            top: topPad + 10, right: 16,
            child: ScaleTransition(
              scale: _heartScale,
              child: _loadingFavorite
                  ? const SizedBox(width: 44, height: 44,
                  child: Center(child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))
                  : _CircleButton(
                icon: _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                iconColor: _isFavorite ? Colors.red : Colors.white,
                onTap: _toggleFavorite,
              ),
            ),
          ),

          // Dots
          if (images.length > 1)
            Positioned(
              bottom: 20, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentImageIndex == i ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _currentImageIndex == i ? Colors.white : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
            ),

          // Badge compteur images
          if (images.length > 1)
            Positioned(
              top: topPad + 16, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.42),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${_currentImageIndex + 1} / ${images.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ),

          // ✅ Bannière remise sur l'image — coin inférieur gauche
          if (widget.product.isDiscountActive && widget.product.discountPercent != null)
            Positioned(
              bottom: 28, left: 16,
              child: _buildDiscountBadgeOnImage(),
            ),
        ],
      ),
    );
  }

  Widget _buildDiscountBadgeOnImage() {
    final p = widget.product;
    final discountLabel = _discountCountdownLabel();
    final isUrgent = p.discountEndsAt != null &&
        p.discountEndsAt!.difference(DateTime.now()).inHours < 24;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Badge gros %
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Text('-${p.discountPercent!.toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        ),
        if (discountLabel.isNotEmpty) ...[
          const SizedBox(height: 6),
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(scale: isUrgent ? _pulseAnim.value : 1.0, child: child),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isUrgent ? const Color(0xFFFF2D55) : const Color(0xFFFF6B35),
                borderRadius: BorderRadius.circular(9),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUrgent ? Icons.local_fire_department_rounded : Icons.timer_rounded,
                    size: 12, color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(discountLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // TITLE
  // ══════════════════════════════════════════════════════════════════

  Widget _buildTitleRow(Product product) {
    return Text(product.name,
        style: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A), height: 1.25));
  }

  // ══════════════════════════════════════════════════════════════════
  // CATEGORY
  // ══════════════════════════════════════════════════════════════════

  Widget _buildCategoryBadge(Product product) {
    final langCode = AppLocalizations.getLanguage();
    final label = ProductCategories.labelFromId(product.category, langCode);
    final icon  = ProductCategories.iconFromId(product.category);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.deepPurple.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: Colors.deepPurple.shade600)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // ✅ PRIX — avec remise bien visible
  // ══════════════════════════════════════════════════════════════════

  Widget _buildPriceBlock(Product product) {
    final discountActive = product.isDiscountActive;
    final effectivePrice = product.discountedPrice;
    final originalPrice  = product.price;
    final pct            = product.discountPercent;

    if (!discountActive) {
      // Prix normal — grand et coloré
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('detail_price_label'),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('${effectivePrice.toStringAsFixed(2)} TND',
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A), letterSpacing: -0.5)),
              ],
            ),
          ],
        ),
      );
    }

    // ── Prix avec remise ─────────────────────────────────────────
    final savings = originalPrice - effectivePrice;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.2)),
        boxShadow: [BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Prix original barré
                Row(
                  children: [
                    Text('${originalPrice.toStringAsFixed(2)} TND',
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF94A3B8),
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Color(0xFF94A3B8),
                            decorationThickness: 2)),
                    const SizedBox(width: 8),
                    if (pct != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(7)),
                        child: Text('-${pct.toStringAsFixed(0)}%',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white, fontWeight: FontWeight.w900)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // Prix remisé — très grand
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(effectivePrice.toStringAsFixed(2),
                        style: const TextStyle(
                            fontSize: 34, fontWeight: FontWeight.w900,
                            color: Color(0xFF16A34A), letterSpacing: -1.0)),
                    const SizedBox(width: 5),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 5),
                      child: Text('TND',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bloc économie
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                const Icon(Icons.savings_rounded, color: Colors.white, size: 18),
                const SizedBox(height: 4),
                Text(_t('detail_you_save'),
                    style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${savings.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w900)),
                Text('TND',
                    style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // ✅ STOCK PROGRESS BAR — remplace le texte seul
  // ══════════════════════════════════════════════════════════════════

  Widget _buildStockProgressBar(Product product) {
    final stock    = product.stock;
    final stockMax = (product.initialStock != null && product.initialStock! > 0)
        ? product.initialStock!
        : (stock > 0 ? stock : 1);
    final ratio    = (stock / stockMax).clamp(0.0, 1.0);
    final pct      = (ratio * 100).round();
    final isOut    = stock <= 0;

    final Color barColor = isOut
        ? const Color(0xFFEF4444)
        : ratio < 0.25 ? const Color(0xFFEF4444)
        : ratio < 0.5  ? const Color(0xFFF97316)
        : ratio < 0.75 ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 9, height: 9,
                      decoration: BoxDecoration(color: barColor, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(
                    isOut
                        ? _t('detail_out_of_stock')
                        : '$stock ${_t('detail_in_stock')}',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: barColor),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                    color: barColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('$pct%',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: barColor)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 10,
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),

          // Indication supplémentaire si stock bas
          if (!isOut && ratio < 0.25) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: barColor),
                const SizedBox(width: 5),
                Text(_t('detail_low_stock_warning'),
                    style: TextStyle(fontSize: 11, color: barColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // ✅ CHRONO VISIBILITÉ — bandeau coloré
  // ══════════════════════════════════════════════════════════════════

  Widget _buildVisibilityBanner() {
    final bgColor = _visibilityUrgent ? const Color(0xFF7C3AED) : const Color(0xFF0EA5E9);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bgColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _visibilityUrgent ? Icons.timer_off_rounded : Icons.schedule_rounded,
              size: 18, color: bgColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('detail_visible_for'),
                    style: TextStyle(fontSize: 11, color: bgColor.withOpacity(0.7), fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(_visibilityLabel,
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900, color: bgColor)),
              ],
            ),
          ),
          if (_visibilityUrgent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(9)),
              child: Text(_t('detail_urgent'),
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // QUANTITY SELECTOR
  // ══════════════════════════════════════════════════════════════════

  Widget _buildQuantitySelector(Product product) {
    final isOut = product.stock <= 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Text(_t('detail_quantity'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
          const Spacer(),
          _QuantityButton(
            icon: Icons.remove_rounded,
            onTap: isOut || _quantity <= 1 ? null : () => setState(() => _quantity--),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Text('$_quantity',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          ),
          _QuantityButton(
            icon: Icons.add_rounded,
            onTap: isOut || _quantity >= product.stock ? null : () => setState(() => _quantity++),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // DESCRIPTION
  // ══════════════════════════════════════════════════════════════════

  Widget _buildSectionTitle(String label) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1.5, color: const Color(0xFFF1F5F9))),
      ],
    );
  }

  Widget _buildDescription(Product product) {
    if (product.description.isEmpty) {
      return Text(_t('detail_no_description'),
          style: TextStyle(fontSize: 14, color: Colors.grey.shade400, fontStyle: FontStyle.italic));
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Text(product.description,
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.75)),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // ✅ REWARD SECTION — photo complète, non coupée
  // ══════════════════════════════════════════════════════════════════

  Widget _buildRewardSection(Product product) {
    final reward = product.reward!;
    final rewardImageBytes = _decodeImage(reward.image);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.18), blurRadius: 20, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Header ambré ───────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFB45309), Color(0xFFD97706), Color(0xFFEAB308)],
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_t('detail_reward_title'),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                        Text(_t('detail_reward_subtitle'),
                            style: TextStyle(
                                fontSize: 11, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w400)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.4))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 11),
                        const SizedBox(width: 4),
                        Text(_t('detail_reward_badge'),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Corps fond ambre clair ─────────────────────────
            Container(
              color: const Color(0xFFFFFBEB),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // ✅ IMAGE REWARD PLEINE LARGEUR — non coupée
                  // On utilise AspectRatio + BoxFit.contain pour afficher TOUTE l'image
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.5), width: 1.5),
                      color: const Color(0xFFFEF3C7),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.15),
                            blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: rewardImageBytes != null
                      // ✅ AspectRatio + BoxFit.contain = image complète, pas coupée
                          ? AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Image.memory(
                          rewardImageBytes,
                          fit: BoxFit.contain,
                          width: double.infinity,
                        ),
                      )
                          : AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Container(
                          color: const Color(0xFFFEF3C7),
                          child: const Center(
                            child: Icon(Icons.card_giftcard_rounded,
                                color: Color(0xFFF59E0B), size: 64),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Nom du reward
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_t('detail_reward_your_gift'),
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: Color(0xFFB45309), letterSpacing: 0.8)),
                        const SizedBox(height: 4),
                        Text(reward.name ?? _t('detail_reward_surprise'),
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF92400E))),
                      ],
                    ),
                  ),

                  // Explication tirage au sort
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.emoji_events_rounded,
                                    color: Color(0xFFF59E0B), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(_t('detail_reward_draw_title'),
                                    style: const TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.w800,
                                        color: Color(0xFF92400E))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildDrawStep('1', _t('detail_reward_step1'), Icons.shopping_cart_rounded),
                          const SizedBox(height: 10),
                          _buildDrawStep('2', _t('detail_reward_step2'), Icons.how_to_reg_rounded),
                          const SizedBox(height: 10),
                          _buildDrawStep('3', _t('detail_reward_step3'), Icons.celebration_rounded),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    size: 14, color: Color(0xFFB45309)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_t('detail_reward_note'),
                                      style: const TextStyle(
                                          fontSize: 12, color: Color(0xFFB45309), height: 1.5)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildDrawStep(String number, String text, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
              color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(7)),
          child: Center(child: Text(number,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 17, color: const Color(0xFFB45309)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF92400E), height: 1.5)),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // INFO ROW
  // ══════════════════════════════════════════════════════════════════

  Widget _buildInfoRow(Product product) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          _InfoTile(
            icon: Icons.verified_rounded, iconColor: Colors.green,
            label: _t('detail_status'),
            value: product.status == 'approved' ? _t('detail_status_approved') : product.status,
          ),
          Divider(height: 20, color: Colors.grey.shade100),
          _InfoTile(
            icon: Icons.inventory_2_rounded, iconColor: Colors.blue,
            label: _t('detail_stock_available'),
            value: '${product.stock} ${_t('detail_units')}',
          ),
          if (product.updatedAt != null) ...[
            Divider(height: 20, color: Colors.grey.shade100),
            _InfoTile(
              icon: Icons.update_rounded, iconColor: Colors.orange,
              label: _t('detail_last_updated'),
              value: _formatDate(product.updatedAt!),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // BOTTOM BAR
  // ══════════════════════════════════════════════════════════════════

  Widget _buildBottomBar(bool isOutOfStock, double bottomPad) {
    final effectivePrice = widget.product.discountedPrice;
    final totalPrice = _quantity * effectivePrice;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottomPad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 24, offset: const Offset(0, -6))],
      ),
      child: Row(
        children: [
          // Favori
          ScaleTransition(
            scale: _heartScale,
            child: GestureDetector(
              onTap: _toggleFavorite,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 54, height: 54,
                decoration: BoxDecoration(
                  color: _isFavorite ? Colors.red.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _isFavorite ? Colors.red.shade200 : Colors.grey.shade200),
                ),
                child: Icon(
                  _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: _isFavorite ? Colors.red : Colors.grey.shade500, size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Bouton ajouter panier
          Expanded(
            child: ScaleTransition(
              scale: _cartBounce,
              child: ElevatedButton(
                onPressed: isOutOfStock || _isAddingToCart ? null : _addToCart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOutOfStock ? Colors.grey.shade300 : const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: isOutOfStock ? 0 : 6,
                  shadowColor: const Color(0xFF16A34A).withOpacity(0.4),
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isAddingToCart
                    ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_cart_rounded, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isOutOfStock
                            ? _t('detail_out_of_stock')
                            : '${_t('detail_add_to_cart')} · ${totalPrice.toStringAsFixed(2)} TND',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
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

  // ── Helpers ──────────────────────────────────────────────────────

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

// ══════════════════════════════════════════════════════════════════
// SUB-WIDGETS
// ══════════════════════════════════════════════════════════════════

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.25)),
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
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF16A34A).withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
              color: enabled ? const Color(0xFF16A34A).withOpacity(0.35) : Colors.grey.shade200),
        ),
        child: Icon(icon, size: 19,
            color: enabled ? const Color(0xFF16A34A) : Colors.grey.shade400),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.iconColor,
    required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: iconColor, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(
                  fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
              Text(value, style: const TextStyle(
                  fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}
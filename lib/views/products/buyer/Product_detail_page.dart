import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';
import '../../../models/product_categories.dart';
import '../../../models/product_model.dart';
import '../../../models/shipping_zone_model.dart' hide ShippingCompanies;
import '../../../models/shipping_company_model.dart';
import '../../../providers/currency_provider.dart';
import '../../../widgets/shipping_price_display_widget.dart';
import '../../compte/adress/address_page.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;
  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth      _auth      = FirebaseAuth.instance;

  int  _currentImageIndex = 0;
  late PageController _pageController;

  bool _isFavorite       = false;
  bool _isAddingToCart   = false;
  bool _loadingFavorite  = true;
  int  _quantity         = 1;

  // ── Livraison ────────────────────────────────────────────────────
  String?               _buyerCountryCode;
  bool                  _loadingBuyerCountry = true;
  Map<String, dynamic>? _buyerAddress;
  Map<String, dynamic>? _sellerStoreAddress;

  // ── Animations ───────────────────────────────────────────────────
  late AnimationController _heartCtrl;
  late Animation<double>   _heartScale;
  late AnimationController _cartCtrl;
  late Animation<double>   _cartBounce;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  User?  get _currentUser => _auth.currentUser;
  String _t(String key)   => AppLocalizations.get(key);

  bool get _isSeller =>
      _currentUser != null &&
          widget.product.sellerId != null &&
          _currentUser!.uid == widget.product.sellerId;

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
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.90), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.90, end: 1.05), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _cartCtrl, curve: Curves.easeOut));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _checkFavorite();
    _loadBuyerAddress();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _heartCtrl.dispose();
    _cartCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBuyerAddress() async {
    final uid = _currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loadingBuyerCountry = false);
      return;
    }
    try {
      final buyerSnap = await _firestore
          .collection('users').doc(uid).collection('addresses')
          .limit(10).get();

      Map<String, dynamic>? buyerAddr;
      if (buyerSnap.docs.isNotEmpty) {
        final docs = buyerSnap.docs.map((d) => d.data()).toList();
        buyerAddr = docs.firstWhere(
              (d) => d['isDefault'] == true,
          orElse: () => docs.first,
        );
      }

      Map<String, dynamic>? sellerAddr;
      final sellerId = widget.product.sellerId ?? '';
      if (sellerId.isNotEmpty) {
        final sellerSnap = await _firestore
            .collection('users').doc(sellerId).collection('addresses')
            .where('isStoreAddress', isEqualTo: true).limit(1).get();
        if (sellerSnap.docs.isNotEmpty) sellerAddr = sellerSnap.docs.first.data();
      }

      if (!mounted) return;

      String? iso;
      if (buyerAddr != null) {
        final flag = buyerAddr['countryFlag'] as String? ?? '';
        iso = ShippingZoneExt.isoFromFlag(flag);
      }

      setState(() {
        _buyerAddress        = buyerAddr;
        _sellerStoreAddress  = sellerAddr;
        _buyerCountryCode    = iso;
        _loadingBuyerCountry = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingBuyerCountry = false);
    }
  }

  bool _isSameCity() {
    if (_buyerAddress == null || _sellerStoreAddress == null) return false;
    final bCity = (_buyerAddress!['city']           as String? ?? '').toLowerCase().trim();
    final sCity = (_sellerStoreAddress!['city']     as String? ?? '').toLowerCase().trim();
    final bProv = (_buyerAddress!['province']       as String? ?? '').toLowerCase().trim();
    final sProv = (_sellerStoreAddress!['province'] as String? ?? '').toLowerCase().trim();
    return bCity.isNotEmpty && bCity == sCity && bProv.isNotEmpty && bProv == sProv;
  }

  bool _isSameCountry() {
    if (_buyerAddress == null || _sellerStoreAddress == null) return false;
    final bFlag = _buyerAddress!['countryFlag']       as String? ?? '';
    final sFlag = _sellerStoreAddress!['countryFlag'] as String? ?? '';
    return bFlag.isNotEmpty && bFlag == sFlag;
  }

  ShippingZone _effectiveZone() {
    if (_buyerCountryCode == null) return ShippingZone.world;
    if (_isSameCity())    return ShippingZone.local;
    if (_isSameCountry()) return ShippingZone.national;
    return ShippingZoneExt.zoneForCountry(_buyerCountryCode!);
  }

  Future<void> _checkFavorite() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _loadingFavorite = false);
      return;
    }
    try {
      final doc = await _firestore
          .collection('users').doc(_currentUser!.uid)
          .collection('favorites').doc(widget.product.id).get();
      if (mounted) setState(() { _isFavorite = doc.exists; _loadingFavorite = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingFavorite = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_currentUser == null) { _showLoginSnack(); return; }
    _heartCtrl.forward(from: 0);
    setState(() => _isFavorite = !_isFavorite);
    final favRef = _firestore
        .collection('users').doc(_currentUser!.uid)
        .collection('favorites').doc(widget.product.id);
    try {
      if (_isFavorite) {
        await favRef.set({'productId': widget.product.id, 'addedAt': Timestamp.now()});
      } else {
        await favRef.delete();
      }
    } catch (_) {
      setState(() => _isFavorite = !_isFavorite);
    }
  }

  Future<void> _addToCart() async {
    if (_currentUser == null) { _showLoginSnack(); return; }
    if (widget.product.stock <= 0) return;
    setState(() => _isAddingToCart = true);
    _cartCtrl.forward(from: 0);
    try {
      final cartRef = _firestore
          .collection('users').doc(_currentUser!.uid)
          .collection('cart').doc(widget.product.id);
      final existing = await cartRef.get();
      if (existing.exists) {
        if (mounted) _showSnack(_t('detail_already_in_cart'),
            color: Colors.orange.shade700, icon: Icons.shopping_cart_outlined);
        return;
      }
      await cartRef.set({
        'productId': widget.product.id,
        'quantity':  _quantity,
        'addedAt':   Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      if (mounted) _showSnack(_t('detail_added_to_cart'),
          color: const Color(0xFF16A34A), icon: Icons.check_circle_rounded);
    } catch (_) {
      _showSnack(_t('detail_add_to_cart_error'),
          color: Colors.red, icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
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

  void _showLoginSnack() => _showSnack(
      _t('detail_login_required'), color: Colors.deepPurple, icon: Icons.lock_rounded);

  Uint8List? _decodeImage(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try { return base64Decode(b64); } catch (_) { return null; }
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD — ✅ Directionality RTL/LTR
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final product      = widget.product;
    final bottomPad    = MediaQuery.of(context).padding.bottom;
    final isOutOfStock = product.stock <= 0;
    final isRtl        = AppLocalizations.isRtl; // ✅

    return Directionality( // ✅
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        body: FadeTransition(
          opacity: _fadeAnim,
          child: Stack(children: [
            RefreshIndicator(
              onRefresh: () async {
                setState(() => _loadingBuyerCountry = true);
                await _loadBuyerAddress();
              },
              child: CustomScrollView(slivers: [
                SliverToBoxAdapter(child: _buildImageCarousel(product, isRtl)), // ✅ passe isRtl
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, (_isSeller ? 24 : 130) + bottomPad),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SizedBox(height: 24),
                      _buildTitleRow(product),
                      const SizedBox(height: 8),
                      _buildCategoryBadge(product),
                      const SizedBox(height: 20),
                      _buildPriceBlock(product),
                      const SizedBox(height: 20),
                      _buildStockProgressBar(product),
                      const SizedBox(height: 20),
                      if (product.hiddenAfterAt != null &&
                          product.hiddenAfterAt!.isAfter(DateTime.now())) ...[
                        _buildVisibilityBanner(product.hiddenAfterAt!),
                        const SizedBox(height: 20),
                      ],
                      _buildQuantitySelector(product),
                      const SizedBox(height: 20),
                      _buildShippingSection(product),
                      const SizedBox(height: 28),
                      _buildSectionTitle(_t('detail_description')),
                      const SizedBox(height: 12),
                      _buildDescription(product),
                      if (product.reward != null) ...[
                        const SizedBox(height: 28),
                        _buildRewardSection(product),
                      ],
                      const SizedBox(height: 28),
                      _ProductReviewsSection(productId: widget.product.id),
                      const SizedBox(height: 28),
                      _buildInfoRow(product),
                    ]),
                  ),
                ),
              ]),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _isSeller ? const SizedBox.shrink() : _buildBottomBar(isOutOfStock, bottomPad),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  IMAGE CAROUSEL — ✅ isRtl param
  // ─────────────────────────────────────────────────────────────

  Widget _buildImageCarousel(Product product, bool isRtl) {
    final images = product.images;
    final topPad = MediaQuery.of(context).padding.top;
    final height = MediaQuery.of(context).size.height * 0.46 + topPad;

    return SizedBox(
      height: height,
      child: Stack(children: [
        Positioned.fill(
          child: images.isEmpty
              ? Container(color: const Color(0xFFF1F5F9),
              child: Center(child: Icon(Icons.image_outlined, size: 64, color: Colors.grey.shade300)))
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
              }),
        ),
        // Gradient haut
        Positioned(top: 0, left: 0, right: 0, height: topPad + 90,
            child: Container(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.6), Colors.transparent])))),
        // Gradient bas
        Positioned(bottom: 0, left: 0, right: 0, height: 100,
            child: Container(decoration: const BoxDecoration(gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Color(0xFFF4F6FB), Colors.transparent])))),
        // ✅ Bouton retour — PositionedDirectional start
        PositionedDirectional(
            top: topPad + 10, start: 16,
            child: _CircleButton(
                icon: Icons.arrow_back_ios_new_rounded,
                isRtl: isRtl, // ✅ inverse l'icône en RTL
                onTap: () => Navigator.pop(context))),
        // ✅ Bouton favori — PositionedDirectional end
        if (!_isSeller)
          PositionedDirectional(
              top: topPad + 10, end: 16,
              child: ScaleTransition(
                  scale: _heartScale,
                  child: _loadingFavorite
                      ? const SizedBox(width: 44, height: 44,
                      child: Center(child: SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))
                      : _CircleButton(
                      icon: _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      iconColor: _isFavorite ? Colors.red : Colors.white,
                      onTap: _toggleFavorite))),
        // Indicateurs pagination
        if (images.length > 1)
          Positioned(bottom: 20, left: 0, right: 0,
              child: Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(images.length, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentImageIndex == i ? 22 : 7, height: 7,
                      decoration: BoxDecoration(
                          color: _currentImageIndex == i ? Colors.white : Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4)))))),
        // Compteur images
        if (images.length > 1)
          Positioned(top: topPad + 16, left: 0, right: 0,
              child: Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.42),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('${_currentImageIndex + 1} / ${images.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))))),
        // ✅ Badge discount — PositionedDirectional start
        if (widget.product.isDiscountActive && widget.product.discountPercent != null)
          PositionedDirectional(bottom: 28, start: 16,
              child: _DiscountBadge(
                  percent: widget.product.discountPercent!,
                  endsAt: widget.product.discountEndsAt)),
      ]),
    );
  }

  // ── Livraison ────────────────────────────────────────────────────

  Widget _buildShippingSection(Product product) {
    if (!product.shipping.isConfigured) return const SizedBox.shrink();
    if (_currentUser == null) return _buildShippingLoginHint();
    if (_loadingBuyerCountry) {
      return Container(
        height: 72,
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 10, offset: const Offset(0, 3))]),
        child: const Center(child: SizedBox(width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)))),
      );
    }
    if (_buyerAddress == null) return _buildShippingNoAddress();
    return ShippingPriceDisplayWidget(
      buyerCountryCode:    _buyerCountryCode ?? '',
      productWeight:       product.shipping.weightKg ?? 1.0,
      zoneRates:           product.shipping.zoneRates,
      shippingCompanyName: ShippingCompanies.findById(product.shipping.companyId)?.name,
      effectiveZone:       _effectiveZone(),
      isSameCity:          _isSameCity(),
      isSameCountry:       _isSameCountry(),
      buyerCity:           _buyerAddress!['city']        as String? ?? '',
      buyerCountryName:    _buyerAddress!['countryName'] as String? ?? '',
      buyerCountryFlag:    _buyerAddress!['countryFlag'] as String? ?? '',
      sellerCity:          _sellerStoreAddress?['city']  as String? ?? '',
    );
  }

  Widget _buildShippingLoginHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.deepPurple.shade100)),
      child: Row(children: [
        Icon(Icons.local_shipping_rounded, color: Colors.deepPurple.shade400, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Text(_t('shipping_login_to_see'),
            style: TextStyle(fontSize: 13, color: Colors.deepPurple.shade600, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _buildShippingNoAddress() {
    return Container(
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 18)),
            const SizedBox(width: 12),
            Text(_t('shipping_delivery_title'), style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFEFF6FF), Color(0xFFF0F9FF)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF3B82F6), size: 24)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_t('shipping_no_address_title'), style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                const SizedBox(height: 4),
                Text(_t('shipping_no_address_desc'), style: const TextStyle(
                    fontSize: 12, color: Color(0xFF0369A1), height: 1.5)),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () async {
                    await Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AddressPage()));
                    if (!mounted) return;
                    setState(() => _loadingBuyerCountry = true);
                    await _loadBuyerAddress();
                  },
                  child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.3),
                              blurRadius: 8, offset: const Offset(0, 3))]),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(_t('shipping_add_address_btn'), style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                      ])),
                ),
              ])),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Content widgets ──────────────────────────────────────────────

  Widget _buildTitleRow(Product product) => Text(product.name,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
          color: Color(0xFF0F172A), height: 1.25));

  Widget _buildCategoryBadge(Product product) {
    final langCode = AppLocalizations.getLanguage();
    final label    = ProductCategories.labelFromId(product.category, langCode);
    final icon     = ProductCategories.iconFromId(product.category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.deepPurple.shade100)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(icon, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: Colors.deepPurple.shade600)),
      ]),
    );
  }

  Widget _buildPriceBlock(Product product) {
    final discountActive = product.isDiscountActive;
    final effectivePrice = product.discountedPrice;
    final originalPrice  = product.price;
    final pct            = product.discountPercent;

    return Consumer<CurrencyProvider>(
      builder: (context, currency, _) {
        if (!discountActive) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
                    blurRadius: 12, offset: const Offset(0, 4))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_t('detail_price_label'),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(currency.formatPrice(effectivePrice),
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A), letterSpacing: -0.5)),
              if (currency.selectedCode != 'USD') ...[
                const SizedBox(height: 2),
                Text('\$${effectivePrice.toStringAsFixed(2)} USD',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ]),
          );
        }

        final savings = originalPrice - effectivePrice;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.2)),
              boxShadow: [BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.08),
                  blurRadius: 16, offset: const Offset(0, 4))]),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(currency.formatPrice(originalPrice),
                    style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8),
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Color(0xFF94A3B8), decorationThickness: 2)),
                const SizedBox(width: 8),
                if (pct != null)
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(7)),
                      child: Text('-${pct.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 12, color: Colors.white,
                              fontWeight: FontWeight.w900))),
              ]),
              const SizedBox(height: 6),
              Text(currency.formatPrice(effectivePrice),
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900,
                      color: Color(0xFF16A34A), letterSpacing: -1.0)),
              if (currency.selectedCode != 'USD')
                Text('\$${effectivePrice.toStringAsFixed(2)} USD',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.35),
                      blurRadius: 12, offset: const Offset(0, 4))]),
              child: Column(children: [
                const Icon(Icons.savings_rounded, color: Colors.white, size: 18),
                const SizedBox(height: 4),
                Text(_t('detail_you_save'),
                    style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(currency.formatPrice(savings),
                    style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w900)),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildStockProgressBar(Product product) {
    final stock    = product.stock;
    final stockMax = (product.initialStock != null && product.initialStock! > 0)
        ? product.initialStock! : (stock > 0 ? stock : 1);
    final ratio = (stock / stockMax).clamp(0.0, 1.0);
    final pct   = (ratio * 100).round();
    final isOut = stock <= 0;
    final Color barColor = isOut ? const Color(0xFFEF4444)
        : ratio < 0.25 ? const Color(0xFFEF4444)
        : ratio < 0.50 ? const Color(0xFFF97316)
        : ratio < 0.75 ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(width: 9, height: 9,
                decoration: BoxDecoration(color: barColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(isOut ? _t('detail_out_of_stock') : '$stock ${_t('detail_in_stock')}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: barColor)),
          ]),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: barColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('$pct%', style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w700, color: barColor))),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(10),
            child: SizedBox(height: 10, child: LinearProgressIndicator(value: ratio,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation<Color>(barColor)))),
        if (!isOut && ratio < 0.25) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.warning_amber_rounded, size: 14, color: barColor),
            const SizedBox(width: 5),
            Text(_t('detail_low_stock_warning'),
                style: TextStyle(fontSize: 11, color: barColor, fontWeight: FontWeight.w600)),
          ]),
        ],
      ]),
    );
  }

  Widget _buildVisibilityBanner(DateTime endsAt) {
    final diff    = endsAt.difference(DateTime.now());
    final urgent  = diff.inHours < 24;
    final bgColor = urgent ? const Color(0xFF7C3AED) : const Color(0xFF0EA5E9);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(color: bgColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: bgColor.withOpacity(0.3))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(urgent ? Icons.timer_off_rounded : Icons.schedule_rounded,
                size: 18, color: bgColor)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t('detail_visible_for'),
              style: TextStyle(fontSize: 11, color: bgColor.withOpacity(0.7),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          _CountdownText(endsAt: endsAt),
        ])),
        if (urgent)
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(9)),
              child: Text(_t('detail_urgent'), style: const TextStyle(
                  fontSize: 10, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5))),
      ]),
    );
  }

  Widget _buildQuantitySelector(Product product) {
    final isOut = product.stock <= 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Row(children: [
        Text(_t('detail_quantity'), style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
        const Spacer(),
        _QuantityButton(icon: Icons.remove_rounded,
            onTap: isOut || _quantity <= 1 ? null : () => setState(() => _quantity--)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Text('$_quantity', style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)))),
        _QuantityButton(icon: Icons.add_rounded,
            onTap: isOut || _quantity >= product.stock ? null : () => setState(() => _quantity++)),
      ]),
    );
  }

  Widget _buildSectionTitle(String label) {
    return Row(children: [
      Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
          color: Color(0xFF0F172A))),
      const SizedBox(width: 12),
      Expanded(child: Container(height: 1.5, color: const Color(0xFFF1F5F9))),
    ]);
  }

  Widget _buildDescription(Product product) {
    if (product.description.isEmpty) {
      return Text(_t('detail_no_description'),
          style: TextStyle(fontSize: 14, color: Colors.grey.shade400, fontStyle: FontStyle.italic));
    }
    return Container(
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 10, offset: const Offset(0, 3))]),
        child: Text(product.description,
            style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.75)));
  }

  Widget _buildRewardSection(Product product) {
    final reward           = product.reward!;
    final rewardImageBytes = _decodeImage(reward.image);
    return Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.18), blurRadius: 20, offset: const Offset(0, 6)),
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))]),
        child: ClipRRect(borderRadius: BorderRadius.circular(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  decoration: const BoxDecoration(gradient: LinearGradient(
                      colors: [Color(0xFFB45309), Color(0xFFD97706), Color(0xFFEAB308)],
                      begin: Alignment.centerLeft, end: Alignment.centerRight)),
                  child: Row(children: [
                    Container(width: 40, height: 40,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 22)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_t('detail_reward_title'), style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                      Text(_t('detail_reward_subtitle'),
                          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.85))),
                    ])),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.4))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 11),
                          const SizedBox(width: 4),
                          Text(_t('detail_reward_badge'), style: const TextStyle(
                              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                        ])),
                  ])),
              Container(color: const Color(0xFFFFFBEB),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.5), width: 1.5),
                            color: const Color(0xFFFEF3C7),
                            boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.15),
                                blurRadius: 12, offset: const Offset(0, 4))]),
                        child: ClipRRect(borderRadius: BorderRadius.circular(15),
                            child: rewardImageBytes != null
                                ? AspectRatio(aspectRatio: 4 / 3,
                                child: Image.memory(rewardImageBytes, fit: BoxFit.contain, width: double.infinity))
                                : AspectRatio(aspectRatio: 4 / 3,
                                child: Container(color: const Color(0xFFFEF3C7),
                                    child: const Center(child: Icon(Icons.card_giftcard_rounded,
                                        color: Color(0xFFF59E0B), size: 64)))))),
                    Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_t('detail_reward_your_gift'), style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: Color(0xFFB45309), letterSpacing: 0.8)),
                          const SizedBox(height: 4),
                          Text(reward.name ?? _t('detail_reward_surprise'),
                              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900,
                                  color: Color(0xFF92400E))),
                        ])),
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFFDE68A), width: 1.5)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Container(padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.emoji_events_rounded,
                                        color: Color(0xFFF59E0B), size: 20)),
                                const SizedBox(width: 10),
                                Expanded(child: Text(_t('detail_reward_draw_title'),
                                    style: const TextStyle(fontSize: 14,
                                        fontWeight: FontWeight.w800, color: Color(0xFF92400E)))),
                              ]),
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
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFB45309)),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(_t('detail_reward_note'),
                                        style: const TextStyle(fontSize: 12,
                                            color: Color(0xFFB45309), height: 1.5))),
                                  ])),
                            ])))
                  ])),
            ])));
  }

  Widget _buildDrawStep(String number, String text, IconData icon) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 24, height: 24,
          decoration: BoxDecoration(color: const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(7)),
          child: Center(child: Text(number, style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)))),
      const SizedBox(width: 10),
      Icon(icon, size: 17, color: const Color(0xFFB45309)),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(
          fontSize: 13, color: Color(0xFF92400E), height: 1.5))),
    ]);
  }

  Widget _buildInfoRow(Product product) {
    if (product.updatedAt == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 12, offset: const Offset(0, 3))]),
      child: _InfoTile(
        icon: Icons.update_rounded, iconColor: Colors.orange,
        label: _t('detail_last_updated'),
        value: _formatDate(product.updatedAt!),
      ),
    );
  }

  Widget _buildBottomBar(bool isOutOfStock, double bottomPad) {
    final effectivePrice = widget.product.discountedPrice;
    final totalPrice     = _quantity * effectivePrice;

    return Consumer<CurrencyProvider>(
      builder: (context, currency, _) {
        return Container(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottomPad),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10),
                  blurRadius: 24, offset: const Offset(0, -6))]),
          child: Row(children: [
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
                                color: _isFavorite ? Colors.red.shade200 : Colors.grey.shade200)),
                        child: Icon(
                            _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: _isFavorite ? Colors.red : Colors.grey.shade500, size: 24)))),
            const SizedBox(width: 12),
            Expanded(
                child: ScaleTransition(
                    scale: _cartBounce,
                    child: ElevatedButton(
                        onPressed: isOutOfStock || _isAddingToCart ? null : _addToCart,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: isOutOfStock
                                ? Colors.grey.shade300 : const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            elevation: isOutOfStock ? 0 : 6,
                            shadowColor: const Color(0xFF16A34A).withOpacity(0.4),
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16))),
                        child: _isAddingToCart
                            ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.shopping_cart_rounded, size: 20),
                          const SizedBox(width: 8),
                          Flexible(child: Text(
                              isOutOfStock
                                  ? _t('detail_out_of_stock')
                                  : '${_t('detail_add_to_cart')} · ${currency.formatPrice(totalPrice)}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                              overflow: TextOverflow.ellipsis)),
                        ])))),
          ]),
        );
      },
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
}

// ══════════════════════════════════════════════════════════════════
// REVIEWS SECTION
// ══════════════════════════════════════════════════════════════════

class _ProductReviewsSection extends StatefulWidget {
  final String productId;
  const _ProductReviewsSection({required this.productId});

  @override
  State<_ProductReviewsSection> createState() => _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends State<_ProductReviewsSection> {
  final _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  List<Map<String, dynamic>> _reviews = [];
  double _avgRating = 0;
  int? _selectedFilter;

  String _t(String key) => AppLocalizations.get(key);

  @override
  void initState() { super.initState(); _loadReviews(); }

  Future<void> _loadReviews() async {
    try {
      final snap = await _firestore
          .collection('products').doc(widget.productId)
          .collection('reviews')
          .where('status', isEqualTo: 'approved').get();

      final list = snap.docs.map((d) => d.data()).toList()
        ..sort((a, b) {
          final ta = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          final tb = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          return tb.compareTo(ta);
        });

      double avg = 0;
      if (list.isNotEmpty) {
        avg = list.fold<double>(0, (sum, r) =>
        sum + ((r['rating'] as num?)?.toDouble() ?? 0)) / list.length;
      }
      if (mounted) setState(() { _reviews = list; _avgRating = avg; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildStars(double rating, {double size = 16}) {
    return Row(mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          if (i < rating.floor())
            return Icon(Icons.star_rounded, size: size, color: const Color(0xFFF59E0B));
          if (i < rating && rating - i >= 0.5)
            return Icon(Icons.star_half_rounded, size: size, color: const Color(0xFFF59E0B));
          return Icon(Icons.star_outline_rounded, size: size, color: Colors.grey.shade300);
        }));
  }

  Widget _buildRatingBar(int star, int count, int total) {
    final ratio = total == 0 ? 0.0 : count / total;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(children: [
          Text('$star', style: const TextStyle(fontSize: 11,
              color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          const Icon(Icons.star_rounded, size: 11, color: Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: ratio, minHeight: 7,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B))))),
          const SizedBox(width: 8),
          SizedBox(width: 22, child: Text('$count',
              style: const TextStyle(fontSize: 11,
                  color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
              textAlign: TextAlign.end)),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(height: 72,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))]),
          child: const Center(child: SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF59E0B)))));
    }

    if (_reviews.isEmpty) {
      return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))]),
          child: Column(children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.reviews_rounded, size: 18, color: Color(0xFFF59E0B))),
              const SizedBox(width: 10),
              Text(_t('reviews_title'), style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            ]),
            const SizedBox(height: 20),
            Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey.shade200),
            const SizedBox(height: 12),
            Text(_t('reviews_empty'), style: TextStyle(
                fontSize: 14, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(_t('reviews_empty_sub'), textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade300, height: 1.5)),
          ]));
    }

    final Map<int, int> dist = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in _reviews) {
      final star = ((r['rating'] as num?)?.toInt() ?? 0).clamp(1, 5);
      dist[star] = (dist[star] ?? 0) + 1;
    }
    final total = _reviews.length;

    return Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.reviews_rounded, size: 18, color: Color(0xFFF59E0B))),
                const SizedBox(width: 10),
                Text(_t('reviews_title'), style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                const Spacer(),
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('$total ${_t('reviews_count_label')}',
                        style: const TextStyle(fontSize: 12,
                            color: Color(0xFFF59E0B), fontWeight: FontWeight.w700))),
              ])),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Column(children: [
                      Text(_avgRating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900,
                              color: Color(0xFF1E293B), letterSpacing: -2)),
                      _buildStars(_avgRating, size: 14),
                      const SizedBox(height: 4),
                      Text('/ 5', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    ]),
                    const SizedBox(width: 20),
                    Container(width: 1, height: 70, color: const Color(0xFFF59E0B).withOpacity(0.25)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(
                        children: [5, 4, 3, 2, 1]
                            .map((s) => _buildRatingBar(s, dist[s]!, total)).toList())),
                  ]))),
          const SizedBox(height: 16),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _StarFilterChip(
                  label: _t('filter_all'), count: _reviews.length,
                  selected: _selectedFilter == null, color: const Color(0xFF6366F1),
                  onTap: () => setState(() => _selectedFilter = null),
                ),
                const SizedBox(width: 8),
                ...[5, 4, 3, 2, 1].map((star) {
                  final count = _reviews.where((r) =>
                  ((r['rating'] as num?)?.toInt() ?? 0) == star).length;
                  if (count == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _StarFilterChip(
                      label: '$star', count: count,
                      selected: _selectedFilter == star, showStar: true,
                      color: const Color(0xFFF59E0B),
                      onTap: () => setState(() =>
                      _selectedFilter = _selectedFilter == star ? null : star),
                    ),
                  );
                }),
              ]),
            ),
          ),
          _ReviewsCarousel(
            reviews: _selectedFilter == null
                ? _reviews
                : _reviews.where((r) =>
            ((r['rating'] as num?)?.toInt() ?? 0) == _selectedFilter).toList(),
            onAnonymous: () => _t('reviews_anonymous'),
          ),
        ]));
  }
}

// ══════════════════════════════════════════════════════════════════
// STAR FILTER CHIP
// ══════════════════════════════════════════════════════════════════

class _StarFilterChip extends StatelessWidget {
  final String label;
  final int    count;
  final bool   selected;
  final bool   showStar;
  final Color  color;
  final VoidCallback onTap;

  const _StarFilterChip({
    required this.label, required this.count, required this.selected,
    required this.color, required this.onTap, this.showStar = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : color.withOpacity(0.25), width: 1.5),
          boxShadow: selected
              ? [BoxShadow(color: color.withOpacity(0.28), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (showStar) ...[
            Icon(Icons.star_rounded, size: 13, color: selected ? Colors.white : color),
            const SizedBox(width: 3),
          ],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: selected ? Colors.white : color)),
          const SizedBox(width: 5),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: selected ? Colors.white.withOpacity(0.25) : color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : color))),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// REVIEWS CAROUSEL
// ══════════════════════════════════════════════════════════════════

class _ReviewsCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> reviews;
  final String Function() onAnonymous;
  const _ReviewsCarousel({required this.reviews, required this.onAnonymous});

  @override
  State<_ReviewsCarousel> createState() => _ReviewsCarouselState();
}

class _ReviewsCarouselState extends State<_ReviewsCarousel> {
  final PageController _ctrl = PageController(viewportFraction: 0.92);
  int _current = 0;

  Widget _buildStars(double rating, {double size = 14}) {
    return Row(mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          if (i < rating.floor())
            return Icon(Icons.star_rounded,         size: size, color: const Color(0xFFF59E0B));
          if (i < rating && rating - i >= 0.5)
            return Icon(Icons.star_half_rounded,    size: size, color: const Color(0xFFF59E0B));
          return Icon(Icons.star_outline_rounded, size: size, color: Colors.grey.shade300);
        }));
  }

  void _openFullscreen(BuildContext ctx, Uint8List bytes) {
    Navigator.of(ctx).push(PageRouteBuilder(
      opaque: false, barrierDismissible: true, barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => _FullScreenImageViewer(imageBytes: bytes),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final reviews = widget.reviews;
    return Column(children: [
      SizedBox(
        height: 170,
        child: PageView.builder(
          controller: _ctrl, itemCount: reviews.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (ctx, index) {
            final r        = reviews[index];
            final rating   = (r['rating']  as num?)?.toDouble() ?? 0;
            final comment  = r['comment']  as String? ?? '';
            final userName = r['userName'] as String? ?? widget.onAnonymous();
            final imageB64 = r['imageBase64'] as String?;
            final hasImage = r['hasImage'] == true && imageB64 != null && imageB64.isNotEmpty;
            final createdAt = (r['createdAt'] as Timestamp?)?.toDate();

            Uint8List? imageBytes;
            if (hasImage) { try { imageBytes = base64Decode(imageB64!); } catch (_) {} }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                        blurRadius: 12, offset: const Offset(0, 4))]),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 34, height: 34,
                          decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                              shape: BoxShape.circle),
                          child: Center(child: Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 14, fontWeight: FontWeight.w800)))),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(userName, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B))),
                        if (createdAt != null)
                          Text('${createdAt.day.toString().padLeft(2,'0')}/'
                              '${createdAt.month.toString().padLeft(2,'0')}/${createdAt.year}',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                      ])),
                    ]),
                    const SizedBox(height: 6),
                    _buildStars(rating),
                    const SizedBox(height: 8),
                    if (comment.isNotEmpty)
                      Expanded(child: Text(comment, maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.5))),
                  ])),
                  if (imageBytes != null) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _openFullscreen(context, imageBytes!),
                      child: Stack(children: [
                        ClipRRect(borderRadius: BorderRadius.circular(10),
                            child: Image.memory(imageBytes, width: 80, height: 80, fit: BoxFit.cover)),
                        Positioned(bottom: 4, right: 4,
                            child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(6)),
                                child: const Icon(Icons.zoom_in_rounded, size: 12, color: Colors.white))),
                      ]),
                    ),
                  ],
                ]),
              ),
            );
          },
        ),
      ),
      if (reviews.length > 1) ...[
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(reviews.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _current == i ? 18 : 6, height: 6,
                decoration: BoxDecoration(
                    color: _current == i ? const Color(0xFFF59E0B) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3))))),
        const SizedBox(height: 4),
      ],
      const SizedBox(height: 8),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
// FULLSCREEN IMAGE VIEWER — ✅ PositionedDirectional bouton fermer
// ══════════════════════════════════════════════════════════════════

class _FullScreenImageViewer extends StatelessWidget {
  final Uint8List imageBytes;
  const _FullScreenImageViewer({required this.imageBytes});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(children: [
          Container(color: Colors.black.withOpacity(0.92)),
          Center(
            child: InteractiveViewer(
              minScale: 0.8, maxScale: 5.0,
              child: ClipRRect(borderRadius: BorderRadius.circular(12),
                  child: Image.memory(imageBytes, fit: BoxFit.contain,
                      width:  MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height * 0.8)),
            ),
          ),
          // ✅ PositionedDirectional end — s'inverse en RTL
          PositionedDirectional(
            top: MediaQuery.of(context).padding.top + 12,
            end: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3))),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// COUNTDOWN TEXT
// ══════════════════════════════════════════════════════════════════

class _CountdownText extends StatefulWidget {
  final DateTime endsAt;
  const _CountdownText({required this.endsAt});

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  late Timer _timer;
  String _label = '';
  bool   _urgent = false;

  @override
  void initState() { super.initState(); _update(); _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update()); }

  void _update() {
    final diff = widget.endsAt.difference(DateTime.now());
    if (!mounted) return;
    if (diff.isNegative || diff.inSeconds <= 0) { _timer.cancel(); setState(() => _label = ''); return; }
    setState(() { _urgent = diff.inHours < 24; _label = _fmt(diff); });
  }

  String _fmt(Duration d) {
    if (d.inDays > 0)    { final h = d.inHours   % 24; return h > 0 ? '${d.inDays}j ${h}h'      : '${d.inDays}j'; }
    if (d.inHours > 0)   { final m = d.inMinutes  % 60; return m > 0 ? '${d.inHours}h ${m}min'  : '${d.inHours}h'; }
    if (d.inMinutes > 0) { final s = d.inSeconds  % 60; return s > 0 ? '${d.inMinutes}min ${s}s': '${d.inMinutes}min'; }
    return '${d.inSeconds}s';
  }

  @override
  void dispose() { _timer.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_label.isEmpty) return const SizedBox.shrink();
    final color = _urgent ? const Color(0xFF7C3AED) : const Color(0xFF0EA5E9);
    return Text(_label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color));
  }
}

// ══════════════════════════════════════════════════════════════════
// DISCOUNT BADGE
// ══════════════════════════════════════════════════════════════════

class _DiscountBadge extends StatefulWidget {
  final double    percent;
  final DateTime? endsAt;
  const _DiscountBadge({required this.percent, this.endsAt});

  @override
  State<_DiscountBadge> createState() => _DiscountBadgeState();
}

class _DiscountBadgeState extends State<_DiscountBadge>
    with SingleTickerProviderStateMixin {
  Timer?                 _timer;
  late AnimationController _pulse;
  late Animation<double>   _anim;
  String _label  = '';
  bool   _urgent = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 1.0, end: 1.03).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    if (widget.endsAt != null) {
      _update();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
    }
  }

  void _update() {
    if (widget.endsAt == null || !mounted) return;
    final diff = widget.endsAt!.difference(DateTime.now());
    if (diff.isNegative || diff.inSeconds <= 0) {
      _timer?.cancel(); setState(() => _label = ''); return;
    }
    setState(() { _urgent = diff.inHours < 24; _label = _fmt(diff); });
  }

  String _fmt(Duration d) {
    if (d.inDays > 0)    { final h = d.inHours   % 24; return h > 0 ? '${d.inDays}j ${h}h'      : '${d.inDays}j'; }
    if (d.inHours > 0)   { final m = d.inMinutes  % 60; return m > 0 ? '${d.inHours}h ${m}min'  : '${d.inHours}h'; }
    if (d.inMinutes > 0) { final s = d.inSeconds  % 60; return s > 0 ? '${d.inMinutes}min ${s}s': '${d.inMinutes}min'; }
    return '${d.inSeconds}s';
  }

  @override
  void dispose() { _timer?.cancel(); _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25),
                  blurRadius: 8, offset: const Offset(0, 3))]),
          child: Text('-${widget.percent.toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
      if (_label.isNotEmpty) ...[
        const SizedBox(height: 6),
        AnimatedBuilder(
            animation: _anim,
            builder: (_, child) => Transform.scale(scale: _urgent ? _anim.value : 1.0, child: child),
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: _urgent ? const Color(0xFFFF2D55) : const Color(0xFFFF6B35),
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6)]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_urgent ? Icons.local_fire_department_rounded : Icons.timer_rounded,
                      size: 12, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(_label, style: const TextStyle(color: Colors.white,
                      fontSize: 12, fontWeight: FontWeight.w700)),
                ]))),
      ],
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
// SUB-WIDGETS
// ══════════════════════════════════════════════════════════════════

// ✅ _CircleButton — param isRtl pour inverser la flèche retour en RTL
class _CircleButton extends StatelessWidget {
  final IconData     icon;
  final Color?       iconColor;
  final VoidCallback onTap;
  final bool         isRtl; // ✅

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.isRtl = false,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Inverse arrow_back ↔ arrow_forward en RTL
    final effectiveIcon = (icon == Icons.arrow_back_ios_new_rounded && isRtl)
        ? Icons.arrow_forward_ios_rounded
        : icon;
    return GestureDetector(
      onTap: onTap,
      child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.25))),
          child: Icon(effectiveIcon, color: iconColor ?? Colors.white, size: 20)),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData      icon;
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
              color: enabled
                  ? const Color(0xFF16A34A).withOpacity(0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: enabled
                      ? const Color(0xFF16A34A).withOpacity(0.35)
                      : Colors.grey.shade200)),
          child: Icon(icon, size: 19,
              color: enabled ? const Color(0xFF16A34A) : Colors.grey.shade400)),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String   value;
  const _InfoTile({required this.icon, required this.iconColor,
    required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 38, height: 38,
          decoration: BoxDecoration(color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: iconColor, size: 19)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11,
            color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 14,
            color: Color(0xFF0F172A), fontWeight: FontWeight.w700)),
      ])),
    ]);
  }
}
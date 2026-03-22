import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../localization/app_localizations.dart';
import '../../models/shipping_zone_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/currency_provider.dart'; // ✅
import '../payment/checkout_page.dart';
import '../compte/adress/address_page.dart';
import '../../main.dart' show routeObserver;

final GlobalKey<CartPageState> cartPageKey = GlobalKey<CartPageState>();

class CartPage extends StatefulWidget {
  final Function(int)?         onTotalCartItemsChanged;
  final Function(int, double)? onCartSelectionChanged;
  final VoidCallback?          onGoHome;

  const CartPage({
    super.key,
    this.onTotalCartItemsChanged,
    this.onCartSelectionChanged,
    this.onGoHome,
  });

  @override
  State<CartPage> createState() => CartPageState();
}

class CartPageState extends State<CartPage>
    with TickerProviderStateMixin, RouteAware {

  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;

  List<CartItemModel> _cartItems       = [];
  bool                _isLoading       = true;
  bool                _showSummary     = false;
  int                 _hiddenItemCount = 0;

  Map<String, dynamic>? _buyerAddress;
  Map<String, dynamic>? _sellerStoreAddress;
  String?               _buyerCountryCode;
  bool                  _loadingAddress = true;

  late AnimationController _summaryCtrl;
  late Animation<Offset>   _summarySlide;

  User?  get _currentUser => _auth.currentUser;
  String _t(String k) => AppLocalizations.get(k);

  ShippingZone get _effectiveZone {
    if (_buyerCountryCode == null) return ShippingZone.world;
    if (_isSameCity)    return ShippingZone.local;
    if (_isSameCountry) return ShippingZone.national;
    return ShippingZoneExt.zoneForCountry(_buyerCountryCode!);
  }

  bool get _isSameCity {
    if (_buyerAddress == null || _sellerStoreAddress == null) return false;
    final bCity = (_buyerAddress!['city']           as String? ?? '').toLowerCase().trim();
    final sCity = (_sellerStoreAddress!['city']     as String? ?? '').toLowerCase().trim();
    final bProv = (_buyerAddress!['province']       as String? ?? '').toLowerCase().trim();
    final sProv = (_sellerStoreAddress!['province'] as String? ?? '').toLowerCase().trim();
    return bCity.isNotEmpty && bCity == sCity && bProv.isNotEmpty && bProv == sProv;
  }

  bool get _isSameCountry {
    if (_buyerAddress == null || _sellerStoreAddress == null) return false;
    final bFlag = _buyerAddress!['countryFlag']       as String? ?? '';
    final sFlag = _sellerStoreAddress!['countryFlag'] as String? ?? '';
    return bFlag.isNotEmpty && bFlag == sFlag;
  }

  List<CartItemModel> get _selectedItems =>
      _cartItems.where((i) => i.isSelected).toList();

  int    get _selectedCount => _selectedItems.length;
  double get _selectedProductsTotal =>
      _selectedItems.fold(0.0, (s, i) => s + i.price * i.quantity);

  double get _selectedShippingTotal {
    if (_loadingAddress || _buyerAddress == null) return 0.0;
    final zone = _effectiveZone;
    double total = 0.0;
    for (final item in _selectedItems) {
      final price = item.shippingPrice(zone);
      if (price != null) total += price;
    }
    return total;
  }

  double get _grandTotal => _selectedProductsTotal + _selectedShippingTotal;

  List<CartItemModel> get _selectedUndeliverable =>
      _selectedItems.where((i) => !i.canDeliverTo(_effectiveZone)).toList();

  bool get _hasUndeliverableSelected => _selectedUndeliverable.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _summaryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _summarySlide = Tween<Offset>(
      begin: const Offset(0, 1), end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _summaryCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await _loadBuyerAddress();
    await loadCart();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _summaryCtrl.dispose();
    super.dispose();
  }

  @override
  void didPopNext() => _init();

  Future<void> _loadBuyerAddress() async {
    final uid = _currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loadingAddress = false);
      return;
    }
    try {
      final snap = await _firestore
          .collection('users').doc(uid).collection('addresses')
          .limit(10).get();

      Map<String, dynamic>? addr;
      if (snap.docs.isNotEmpty) {
        final docs = snap.docs.map((d) => d.data()).toList();
        addr = docs.firstWhere(
                (d) => d['isDefault'] == true, orElse: () => docs.first);
      }

      String? iso;
      if (addr != null) {
        final flag = addr['countryFlag'] as String? ?? '';
        iso = ShippingZoneExt.isoFromFlag(flag);
      }

      if (!mounted) return;
      setState(() {
        _buyerAddress     = addr;
        _buyerCountryCode = iso;
        _loadingAddress   = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  Future<void> _goToAddAddress() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddressPage()),
    );
    if (!mounted) return;
    setState(() => _loadingAddress = true);
    await _init();
  }

  Future<void> loadCart() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final uid = _currentUser?.uid;
      if (uid == null) {
        setState(() => _isLoading = false);
        return;
      }

      final cartSnap = await _firestore
          .collection('users').doc(uid).collection('cart')
          .orderBy('addedAt', descending: true).get();

      if (cartSnap.docs.isEmpty) {
        if (mounted) {
          context.read<CartProvider>().setItems([]);
          setState(() {
            _cartItems       = [];
            _isLoading       = false;
            _hiddenItemCount = 0;
          });
          _notifyParent();
        }
        return;
      }

      final List<CartItemModel> items = [];
      String? firstSellerId;
      int hiddenCount = 0;

      for (final doc in cartSnap.docs) {
        final data      = doc.data();
        final productId = data['productId'] as String? ?? doc.id;
        final quantity  = (data['quantity'] as num? ?? 1).toInt();

        try {
          final productDoc = await _firestore
              .collection('products').doc(productId).get();
          if (!productDoc.exists) continue;
          final p = productDoc.data()!;

          final isActive = p['isActive'] as bool? ?? true;
          if (!isActive) { hiddenCount++; continue; }

          final sellerId = p['sellerId'] as String? ?? '';
          String storeName = '';

          if (sellerId.isNotEmpty) {
            try {
              final sellerDoc = await _firestore
                  .collection('users').doc(sellerId).get();
              if (sellerDoc.exists) {
                final sd = sellerDoc.data();
                storeName = (sd?['storeName'] as String?)?.trim() ?? '';
              }
            } catch (_) {}
          }

          List<ShippingZoneRate> zoneRates = [];
          double weightKg = 1.0;
          String? companyId;

          final shippingMap = p['shipping'] as Map<String, dynamic>?;
          if (shippingMap != null) {
            weightKg  = (shippingMap['weightKg'] as num? ?? 1.0).toDouble();
            companyId = shippingMap['companyId'] as String?;
            final ratesRaw = shippingMap['zoneRates'] as List<dynamic>? ?? [];
            zoneRates = ratesRaw
                .map((r) => ShippingZoneRate.fromMap(
                Map<String, dynamic>.from(r as Map)))
                .toList();
          }

          if (firstSellerId == null && sellerId.isNotEmpty) {
            firstSellerId = sellerId;
            try {
              final addrSnap = await _firestore
                  .collection('users').doc(sellerId)
                  .collection('addresses')
                  .where('isStoreAddress', isEqualTo: true)
                  .limit(1).get();
              if (addrSnap.docs.isNotEmpty && mounted) {
                setState(() =>
                _sellerStoreAddress = addrSnap.docs.first.data());
              }
            } catch (_) {}
          }

          items.add(CartItemModel(
            productId: productId,
            cartDocId: doc.id,
            name:      p['name']  as String? ?? '',
            price:     (p['price'] as num? ?? 0).toDouble(),
            stock:     (p['stock'] as num? ?? 0).toInt(),
            sellerId:  sellerId,
            storeName: storeName.isNotEmpty ? storeName : _t('cart_unknown_store'),
            images:    List<String>.from(p['images'] ?? []),
            quantity:  quantity,
            zoneRates: zoneRates,
            weightKg:  weightKg,
            companyId: companyId,
          ));
        } catch (_) {}
      }

      if (mounted) {
        context.read<CartProvider>().setItems(items);
        setState(() {
          _cartItems       = items;
          _isLoading       = false;
          _hiddenItemCount = hiddenCount;
        });
        _notifyParent();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateQtyFirestore(String docId, int qty) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('users').doc(uid).collection('cart').doc(docId)
        .update({'quantity': qty, 'updatedAt': Timestamp.now()});
  }

  Future<void> _removeFirestore(String docId) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('users').doc(uid).collection('cart').doc(docId).delete();
  }

  void _updateQuantity(int index, int newQty) {
    if (newQty < 1 || newQty > _cartItems[index].stock) return;
    setState(() => _cartItems[index].quantity = newQty);
    context.read<CartProvider>().updateQuantity(index, newQty);
    _updateQtyFirestore(_cartItems[index].cartDocId, newQty);
    _notifyParent();
  }

  void _removeItem(int index) {
    if (index < 0 || index >= _cartItems.length) return;
    final docId = _cartItems[index].cartDocId;
    _cartItems.removeAt(index);
    setState(() {});
    context.read<CartProvider>().setItems(List.from(_cartItems));
    _removeFirestore(docId);
    _notifyParent();
  }

  void _toggleItem(int index) {
    setState(() => _cartItems[index].isSelected = !_cartItems[index].isSelected);
    context.read<CartProvider>().setItems(List.from(_cartItems));
    _notifyParent();
  }

  void _toggleVendor(String storeName) {
    final vendorItems = _cartItems.where((i) => i.storeName == storeName).toList();
    final allSelected = vendorItems.every((i) => i.isSelected);
    setState(() {
      for (final item in vendorItems) item.isSelected = !allSelected;
    });
    context.read<CartProvider>().setItems(List.from(_cartItems));
    _notifyParent();
  }

  void _toggleAll() {
    final allSelected = _cartItems.every((i) => i.isSelected);
    setState(() {
      for (final item in _cartItems) item.isSelected = !allSelected;
    });
    context.read<CartProvider>().setItems(List.from(_cartItems));
    _notifyParent();
  }

  void _deselectUndeliverable() {
    setState(() {
      for (final item in _selectedUndeliverable) item.isSelected = false;
    });
    context.read<CartProvider>().setItems(List.from(_cartItems));
    _notifyParent();
  }

  void _notifyParent() {
    widget.onTotalCartItemsChanged?.call(_cartItems.length);
    widget.onCartSelectionChanged?.call(_selectedCount, _grandTotal);
  }

  void _openSummary() {
    setState(() => _showSummary = true);
    _summaryCtrl.forward();
  }

  Future<void> _closeSummary() async {
    await _summaryCtrl.reverse();
    if (mounted) setState(() => _showSummary = false);
  }

  Map<String, List<CartItemModel>> get _grouped {
    final map = <String, List<CartItemModel>>{};
    for (final item in _cartItems) {
      (map[item.storeName] ??= []).add(item);
    }
    return map;
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ✅ context.watch → rebuild auto quand devise change
    final currency = context.watch<CurrencyProvider>();
    final isRtl    = AppLocalizations.isRtl;
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: _isLoading
            ? _buildLoading()
            : Stack(children: [
          RefreshIndicator(
            color: Colors.deepPurple,
            onRefresh: _init,
            child: _cartItems.isEmpty
                ? _buildEmpty(isTablet, hiddenCount: _hiddenItemCount)
                : ListView(
              padding: EdgeInsets.fromLTRB(
                  isTablet ? 24 : 16, isTablet ? 30 : 20,
                  isTablet ? 24 : 16, 120),
              children: [
                if (_hiddenItemCount > 0) _buildHiddenProductsBanner(),
                if (!_loadingAddress && _buyerAddress == null)
                  _buildNoAddressBanner(),
                if (!_loadingAddress &&
                    _buyerAddress != null &&
                    _hasUndeliverableSelected)
                  _buildUndeliverableWarning(),
                ..._grouped.entries.map((e) =>
                    _buildVendorSection(e.key, e.value, isTablet, currency)),
              ],
            ),
          ),
          if (_cartItems.isNotEmpty)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildBottomBar(isTablet, currency),
            ),
          if (_showSummary) _buildSummaryOverlay(currency),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  BANNIÈRES
  // ─────────────────────────────────────────────────────────────

  Widget _buildHiddenProductsBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8B4FE), width: 1.5),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.visibility_off_rounded,
              color: Colors.deepPurple, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            _hiddenItemCount == 1
                ? _t('cart_hidden_single')
                : _t('cart_hidden_multi').replaceFirst('{n}', '$_hiddenItemCount'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                color: Color(0xFF6B21A8)),
          ),
          const SizedBox(height: 3),
          Text(_t('cart_hidden_desc'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF7E22CE), height: 1.4)),
        ])),
      ]),
    );
  }

  Widget _buildNoAddressBanner() {
    return GestureDetector(
      onTap: _goToAddAddress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF93C5FD), width: 1.5),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.add_location_alt_rounded,
                color: Color(0xFF3B82F6), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_t('cart_no_address_title'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                    color: Color(0xFF1E40AF))),
            const SizedBox(height: 3),
            Text(_t('cart_no_address_desc'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), height: 1.4)),
          ])),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_forward_rounded,
                color: Color(0xFF3B82F6), size: 18),
          ),
        ]),
      ),
    );
  }

  Widget _buildUndeliverableWarning() {
    final count = _selectedUndeliverable.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFB923C), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFFF97316).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.local_shipping_rounded,
                color: Color(0xFFF97316), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              count == 1
                  ? _t('cart_undeliverable_warning_single')
                  : _t('cart_undeliverable_warning_multi').replaceFirst('{n}', '$count'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                  color: Color(0xFF9A3412)),
            ),
            const SizedBox(height: 3),
            Text(_t('cart_undeliverable_desc'),
                style: const TextStyle(fontSize: 12, color: Color(0xFFC2410C), height: 1.4)),
          ])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: _deselectUndeliverable,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: const Color(0xFFF97316), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(_t('cart_deselect_undeliverable'),
                  style: const TextStyle(color: Colors.white,
                      fontSize: 13, fontWeight: FontWeight.w700))),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: _goToAddAddress,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF97316))),
              child: Center(child: Text(_t('cart_change_address'),
                  style: const TextStyle(color: Color(0xFFF97316),
                      fontSize: 13, fontWeight: FontWeight.w700))),
            ),
          )),
        ]),
      ]),
    );
  }

  Widget _buildLoading() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Colors.deepPurple), strokeWidth: 3),
      const SizedBox(height: 16),
      Text(_t('loading'), style: TextStyle(color: Colors.grey[600], fontSize: 14)),
    ]));
  }

  Widget _buildEmpty(bool isTablet, {int hiddenCount = 0}) {
    final hasHidden = hiddenCount > 0;
    return ListView(children: [
      if (hasHidden)
        Padding(
          padding: EdgeInsets.fromLTRB(isTablet ? 24 : 16, isTablet ? 24 : 16,
              isTablet ? 24 : 16, 0),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF5FF), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD8B4FE), width: 1.5),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.visibility_off_rounded,
                    color: Colors.deepPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  hiddenCount == 1
                      ? _t('cart_hidden_single')
                      : _t('cart_hidden_multi').replaceFirst('{n}', '$hiddenCount'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                      color: Color(0xFF6B21A8)),
                ),
                const SizedBox(height: 3),
                Text(_t('cart_hidden_desc'),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF7E22CE), height: 1.4)),
              ])),
            ]),
          ),
        ),
      SizedBox(height: hasHidden
          ? MediaQuery.of(context).size.height * 0.06
          : MediaQuery.of(context).size.height * 0.15),
      Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
            child: Container(
              width: isTablet ? 140 : 110, height: isTablet ? 140 : 110,
              decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.08), shape: BoxShape.circle),
              child: Icon(Icons.shopping_cart_outlined,
                  size: isTablet ? 70 : 54, color: Colors.deepPurple.withOpacity(0.35)),
            ),
          ),
          const SizedBox(height: 28),
          Text(hasHidden ? _t('cart_empty_after_hidden') : _t('cart_empty_title'),
              style: TextStyle(fontSize: isTablet ? 22 : 20,
                  fontWeight: FontWeight.w800, color: Colors.black87),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(hasHidden ? _t('cart_empty_after_hidden_desc') : _t('cart_empty_desc'),
              style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (widget.onGoHome != null) {
                  widget.onGoHome!();
                } else {
                  Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
                }
              },
              icon: const Icon(Icons.shopping_bag_outlined, size: 20),
              label: Text(_t('cart_discover_products'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4, shadowColor: Colors.deepPurple.withOpacity(0.35),
              ),
            ),
          ),
        ]),
      )),
    ]);
  }

  // ─────────────────────────────────────────────────────────────
  //  SECTION VENDEUR
  // ─────────────────────────────────────────────────────────────

  Widget _buildVendorSection(String storeName, List<CartItemModel> items,
      bool isTablet, CurrencyProvider currency) {
    final allSelected = items.every((i) => i.isSelected);
    final zone = _effectiveZone;
    final selectedVendorItems = items.where((i) => i.isSelected).toList();
    double? vendorShipping;
    if (!_loadingAddress && _buyerAddress != null && selectedVendorItems.isNotEmpty) {
      double sum = 0.0;
      bool anyDeliverable = false;
      for (final item in selectedVendorItems) {
        final p = item.shippingPrice(zone);
        if (p != null) { sum += p; anyDeliverable = true; }
      }
      if (anyDeliverable) vendorShipping = sum;
    }

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => _toggleVendor(storeName),
          child: Container(
            padding: EdgeInsets.all(isTablet ? 16 : 14),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              _CheckCircle(checked: allSelected),
              const SizedBox(width: 10),
              const Icon(Icons.storefront_rounded, size: 18, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Expanded(child: Text(storeName,
                  style: TextStyle(fontSize: isTablet ? 16 : 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.deepPurple.shade700))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length} ${items.length > 1 ? _t('cart_articles') : _t('cart_article')}',
                  style: TextStyle(color: Colors.deepPurple.shade600,
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        ...items.asMap().entries.map((e) {
          final item  = e.value;
          final index = _cartItems.indexWhere((c) => c.cartDocId == item.cartDocId);
          return _buildItemCard(item, index, isTablet, currency);
        }),
        if (!_loadingAddress && _buyerAddress != null)
          _buildVendorShippingRow(vendorShipping, selectedVendorItems.isEmpty, currency),
      ]),
    );
  }

  Widget _buildVendorShippingRow(double? shippingPrice, bool noneSelected,
      CurrencyProvider currency) {
    if (noneSelected) return const SizedBox.shrink();
    final zone = _effectiveZone;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFF),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(children: [
        Icon(Icons.local_shipping_rounded, size: 16,
            color: shippingPrice != null
                ? const Color(0xFF3B82F6) : const Color(0xFFF97316)),
        const SizedBox(width: 8),
        Expanded(child: Text(
          shippingPrice != null
              ? '${_t('cart_shipping')} · ${zone.emoji} ${zone.label(AppLocalizations.getLanguage())}'
              : _t('cart_shipping_unavailable'),
          style: TextStyle(fontSize: 12,
              color: shippingPrice != null
                  ? const Color(0xFF475569) : const Color(0xFFF97316),
              fontWeight: FontWeight.w500),
        )),
        // ✅ frais livraison par vendeur dans la devise choisie
        Text(
          shippingPrice != null
              ? '+ ${currency.formatPrice(shippingPrice)}'
              : '—',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: shippingPrice != null
                  ? const Color(0xFF3B82F6) : const Color(0xFFF97316)),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  CARD PRODUIT
  // ─────────────────────────────────────────────────────────────

  Widget _buildItemCard(CartItemModel item, int index, bool isTablet,
      CurrencyProvider currency) {
    final imageBytes = item.images.isNotEmpty
        ? () { try { return base64Decode(item.images.first); } catch (_) { return null; } }()
        : null;

    final zone       = _effectiveZone;
    final canDeliver = _loadingAddress || _buyerAddress == null
        ? null : item.canDeliverTo(zone);
    final shipPrice  = item.shippingPrice(zone);

    return Column(children: [
      Padding(
        padding: EdgeInsets.all(isTablet ? 16 : 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () => _toggleItem(index),
            child: Padding(padding: const EdgeInsets.only(top: 4),
                child: _CheckCircle(checked: item.isSelected)),
          ),
          const SizedBox(width: 12),
          Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: isTablet ? 100 : 82, height: isTablet ? 100 : 82,
                color: Colors.grey.shade100,
                child: imageBytes != null
                    ? Image.memory(imageBytes, fit: BoxFit.cover)
                    : Icon(Icons.image_outlined,
                    color: Colors.grey.shade400, size: 32),
              ),
            ),
            if (canDeliver == false)
              Positioned(top: 0, left: 0, right: 0, bottom: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(color: Colors.black.withOpacity(0.45),
                        child: const Center(child: Icon(Icons.block_rounded,
                            color: Colors.white, size: 28))),
                  )),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name,
                style: TextStyle(fontWeight: FontWeight.w700,
                    fontSize: isTablet ? 16 : 14, color: const Color(0xFF1E293B)),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            // ✅ prix article dans la devise choisie
            Text(currency.formatPrice(item.price),
                style: const TextStyle(color: Colors.deepPurple,
                    fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 6),
            if (_loadingAddress)
              _ShippingBadge.loading()
            else if (_buyerAddress == null)
              _ShippingBadge.unknown(_t('cart_shipping_no_address'))
            else if (canDeliver == true && shipPrice != null)
              // ✅ frais livraison dans la devise choisie
                _ShippingBadge.available(currency.formatPrice(shipPrice), zone.emoji)
              else
                _ShippingBadge.unavailable(_t('cart_not_deliverable')),
            const SizedBox(height: 10),
            Row(children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _QtyBtn(icon: Icons.remove_rounded,
                      onTap: item.quantity > 1
                          ? () => _updateQuantity(index, item.quantity - 1) : null),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text('${item.quantity}',
                          style: const TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w700, color: Color(0xFF1E293B)))),
                  _QtyBtn(icon: Icons.add_rounded,
                      onTap: item.quantity < item.stock
                          ? () => _updateQuantity(index, item.quantity + 1) : null),
                ]),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _removeItem(index),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade100)),
                  child: Icon(Icons.delete_outline_rounded,
                      color: Colors.red.shade400, size: isTablet ? 22 : 18),
                ),
              ),
            ]),
          ])),
        ]),
      ),
      if (index >= 0 && index < _cartItems.length - 1)
        const Divider(height: 1, indent: 12, endIndent: 12, color: Color(0xFFF0F0F0)),
    ]);
  }

  // ─────────────────────────────────────────────────────────────
  //  BOTTOM BAR
  // ─────────────────────────────────────────────────────────────

  Widget _buildBottomBar(bool isTablet, CurrencyProvider currency) {
    final allSelected = _cartItems.isNotEmpty && _cartItems.every((i) => i.isSelected);
    final bottomPad   = MediaQuery.of(context).padding.bottom;
    final hasUndeliverable = _hasUndeliverableSelected &&
        !_loadingAddress && _buyerAddress != null;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10),
            blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        if (_selectedCount > 0) ...[
          Row(children: [
            Text(_t('cart_products_subtotal'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            const Spacer(),
            // ✅ sous-total produits
            Text(currency.formatPrice(_selectedProductsTotal),
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Text(_t('cart_shipping_subtotal'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            const Spacer(),
            _loadingAddress
                ? const SizedBox(width: 60, height: 14,
                child: LinearProgressIndicator(backgroundColor: Color(0xFFF1F5F9),
                    color: Colors.deepPurple))
                : _buyerAddress == null
                ? Text(_t('cart_shipping_to_calculate'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8)))
            // ✅ frais livraison
                : Text(
                _selectedShippingTotal > 0
                    ? '+ ${currency.formatPrice(_selectedShippingTotal)}'
                    : _t('cart_shipping_free'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: _selectedShippingTotal > 0
                        ? const Color(0xFF3B82F6) : const Color(0xFF10B981))),
          ]),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: Color(0xFFF1F5F9))),
        ],

        Row(children: [
          GestureDetector(
            onTap: _toggleAll,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _CheckCircle(checked: allSelected),
              const SizedBox(width: 6),
              Text(_t('cart_select_all'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: Color(0xFF475569))),
            ]),
          ),
          const Spacer(),
          if (_selectedCount > 0) ...[
            Column(crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min, children: [
                  // ✅ grand total
                  Text(currency.formatPrice(_grandTotal),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                          color: Colors.deepPurple)),
                  Text('$_selectedCount ${_selectedCount > 1 ? _t('cart_articles') : _t('cart_article')}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ]),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: GestureDetector(
                onTap: hasUndeliverable ? null : _openSummary,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: hasUndeliverable ? null
                        : const LinearGradient(colors: [Colors.deepPurple, Color(0xFF7C3AED)]),
                    color: hasUndeliverable ? Colors.grey.shade300 : null,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: hasUndeliverable ? [] : [BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.35),
                        blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Text(
                    hasUndeliverable ? _t('cart_fix_selection') : _t('cart_order'),
                    style: TextStyle(
                        color: hasUndeliverable ? Colors.grey.shade500 : Colors.white,
                        fontWeight: FontWeight.w700, fontSize: 13),
                    overflow: TextOverflow.ellipsis, maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  OVERLAY RÉSUMÉ
  // ─────────────────────────────────────────────────────────────

  Widget _buildSummaryOverlay(CurrencyProvider currency) {
    final selectedItems = _selectedItems;
    final bottomPad     = MediaQuery.of(context).padding.bottom;
    final zone          = _effectiveZone;

    final vendorShipping = <String, double>{};
    for (final item in selectedItems) {
      final p = item.shippingPrice(zone);
      if (p == null) continue;
      vendorShipping[item.storeName] = (vendorShipping[item.storeName] ?? 0.0) + p;
    }

    return Stack(children: [
      Positioned.fill(
        child: FadeTransition(
          opacity: _summaryCtrl,
          child: GestureDetector(
            onTap: _closeSummary,
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),
        ),
      ),
      Positioned(
        bottom: 0, left: 0, right: 0,
        child: SlideTransition(
          position: _summarySlide,
          child: GestureDetector(
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) > 300) _closeSummary();
            },
            child: Container(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.88),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20,
                    offset: Offset(0, -5))],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(children: [
                    Text(_t('cart_summary_title'),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    GestureDetector(
                      onTap: _closeSummary,
                      child: Container(width: 32, height: 32,
                          decoration: BoxDecoration(color: Colors.grey.shade100,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 18)),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),

                Flexible(child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        itemCount: selectedItems.length,
                        itemBuilder: (_, i) {
                          final item = selectedItems[i];
                          final bytes = item.images.isNotEmpty
                              ? () { try { return base64Decode(item.images.first); }
                          catch (_) { return null; } }() : null;
                          return Container(
                            width: 70, margin: const EdgeInsets.only(right: 10),
                            child: Column(children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(width: 70, height: 54,
                                  child: Container(color: Colors.grey.shade100,
                                      child: bytes != null
                                          ? Image.memory(bytes, fit: BoxFit.cover)
                                          : Icon(Icons.image_outlined,
                                          color: Colors.grey.shade400, size: 28)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              // ✅ prix mini dans la devise choisie
                              Text('${currency.formatPrice(item.price)} ×${item.quantity}',
                                  style: const TextStyle(fontSize: 10,
                                      fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.center),
                            ]),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14)),
                      child: Column(children: [
                        // ✅ sous-total produits
                        _summaryRow(_t('cart_products_subtotal'),
                            currency.formatPrice(_selectedProductsTotal)),
                        const SizedBox(height: 4),

                        if (vendorShipping.isNotEmpty) ...[
                          const Divider(height: 14),
                          Align(alignment: Alignment.centerLeft,
                              child: Text(_t('cart_shipping_detail'),
                                  style: const TextStyle(fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF94A3B8)))),
                          const SizedBox(height: 6),
                          ...vendorShipping.entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(children: [
                              Icon(Icons.storefront_rounded,
                                  size: 13, color: Colors.deepPurple.shade300),
                              const SizedBox(width: 6),
                              Expanded(child: Text(e.key,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  maxLines: 1, overflow: TextOverflow.ellipsis)),
                              // ✅ livraison par vendeur
                              Text('+ ${currency.formatPrice(e.value)}',
                                  style: const TextStyle(fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF3B82F6))),
                            ]),
                          )),
                          const Divider(height: 14),
                          // ✅ sous-total livraison
                          _summaryRow(
                            '${_t('cart_shipping_subtotal')} '
                                '(${zone.emoji} ${zone.label(AppLocalizations.getLanguage())})',
                            currency.formatPrice(_selectedShippingTotal),
                            valueColor: const Color(0xFF3B82F6),
                          ),
                        ] else if (_buyerAddress == null) ...[
                          _summaryRow(_t('cart_shipping_subtotal'),
                              _t('cart_shipping_to_calculate'),
                              valueColor: const Color(0xFF94A3B8)),
                        ] else ...[
                          _summaryRow(_t('cart_shipping_subtotal'),
                              _t('cart_shipping_free'),
                              valueColor: const Color(0xFF10B981)),
                        ],

                        const Divider(height: 16),
                        // ✅ grand total
                        _summaryRow(_t('cart_total'),
                            currency.formatPrice(_grandTotal),
                            isBold: true, isLarge: true,
                            valueColor: Colors.deepPurple),
                      ]),
                    ),
                  ]),
                )),

                Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomPad),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await _closeSummary();
                        if (mounted) {
                          Navigator.push(context, MaterialPageRoute(
                              builder: (_) => const CheckoutPage()));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4, shadowColor: Colors.deepPurple.withOpacity(0.4),
                      ),
                      child: Text(_t('cart_go_to_payment'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _summaryRow(String label, String value,
      {bool isBold = false, bool isLarge = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(label, style: TextStyle(
            fontSize: isLarge ? 16 : 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            color: const Color(0xFF475569)))),
        Text(value, style: TextStyle(
            fontSize: isLarge ? 16 : 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? const Color(0xFF1E293B))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────

class _CheckCircle extends StatelessWidget {
  final bool checked;
  const _CheckCircle({required this.checked});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22, height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? Colors.deepPurple : Colors.transparent,
        border: Border.all(
            color: checked ? Colors.deepPurple : Colors.grey.shade400, width: 2),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
          : null,
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData      icon;
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

class _ShippingBadge extends StatelessWidget {
  final Widget child;
  const _ShippingBadge({required this.child});

  factory _ShippingBadge.available(String price, String emoji) {
    return _ShippingBadge(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 4),
        const Icon(Icons.local_shipping_rounded, size: 12, color: Color(0xFF3B82F6)),
        const SizedBox(width: 4),
        // ✅ price est déjà formaté par currency.formatPrice()
        Text(price, style: const TextStyle(fontSize: 11,
            fontWeight: FontWeight.w700, color: Color(0xFF3B82F6))),
      ]),
    ));
  }

  factory _ShippingBadge.unavailable(String label) {
    return _ShippingBadge(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFB923C)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.block_rounded, size: 12, color: Color(0xFFF97316)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11,
            fontWeight: FontWeight.w600, color: Color(0xFFF97316))),
      ]),
    ));
  }

  factory _ShippingBadge.unknown(String label) {
    return _ShippingBadge(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.help_outline_rounded, size: 12, color: Color(0xFF94A3B8)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      ]),
    ));
  }

  factory _ShippingBadge.loading() {
    return _ShippingBadge(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8)),
      child: const SizedBox(width: 50, height: 12,
          child: LinearProgressIndicator(backgroundColor: Color(0xFFF1F5F9),
              color: Colors.deepPurple)),
    ));
  }

  @override
  Widget build(BuildContext context) => child;
}
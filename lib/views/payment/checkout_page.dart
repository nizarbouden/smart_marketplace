// lib/views/checkout/checkout_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/cart_item_model.dart';
import '../../models/shipping_zone_model.dart';
import '../../providers/cart_provider.dart';
import '../../localization/app_localizations.dart';
import '../../services/create_order_service.dart';
import '../../services/payment_service.dart';
import '../compte/adress/address_picker_page.dart';
import '../compte/payment/payment_methods_page.dart';
import '../compte/adress/address_page.dart';
import '../layout/main_layout.dart';
import '../payment/payment_picker_page.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;

  AddressModel?       _selectedAddress;
  PaymentMethodModel? _selectedPayment;
  bool _loadingAddress = true;
  bool _loadingPayment = true;
  bool _isProcessing   = false;

  // ✅ CLEF DU FIX : adresse boutique vendeur, même logique que CartPage
  Map<String, dynamic>? _sellerStoreAddress;
  bool _loadingSellerAddress = true;

  String _t(String key) => AppLocalizations.get(key);

  // ─────────────────────────────────────────────────────────────
  //  INIT
  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadDefaultAddress();
    _loadDefaultPayment();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSellerStoreAddress());
  }

  // ─────────────────────────────────────────────────────────────
  //  ZONE — copie exacte de CartPage._effectiveZone
  //
  //  CartPage compare _buyerAddress vs _sellerStoreAddress
  //  pour détecter local / national avant de tomber sur zoneForCountry.
  //  Sans _sellerStoreAddress, même adresse acheteur => "world"
  //  => tous les produits semblent non livrables.
  // ─────────────────────────────────────────────────────────────

  ShippingZone get _effectiveZone {
    final addr = _selectedAddress;
    if (addr == null) return ShippingZone.world;

    final iso = ShippingZoneExt.isoFromFlag(addr.countryFlag);
    if (iso == null) return ShippingZone.world;

    if (_sellerStoreAddress != null) {
      // isSameCity ?
      final bCity = (addr.city ?? '').toLowerCase().trim();
      final sCity = (_sellerStoreAddress!['city'] as String? ?? '').toLowerCase().trim();
      final bProv = (addr.province ?? '').toLowerCase().trim();
      final sProv = (_sellerStoreAddress!['province'] as String? ?? '').toLowerCase().trim();
      if (bCity.isNotEmpty && bCity == sCity &&
          bProv.isNotEmpty && bProv == sProv) {
        return ShippingZone.local;
      }
      // isSameCountry ?
      final bFlag = addr.countryFlag;
      final sFlag = _sellerStoreAddress!['countryFlag'] as String? ?? '';
      if (bFlag.isNotEmpty && bFlag == sFlag) return ShippingZone.national;
    }

    return ShippingZoneExt.zoneForCountry(iso);
  }

  ShippingZone get _zone       => _effectiveZone;
  bool         get _zoneReady  => !_loadingAddress && !_loadingSellerAddress;

  // ─────────────────────────────────────────────────────────────
  //  CHARGEMENTS
  // ─────────────────────────────────────────────────────────────

  /// Charge l'adresse boutique (isStoreAddress=true) du 1er vendeur
  /// des articles sélectionnés — identique à CartPage.loadCart()
  Future<void> _loadSellerStoreAddress() async {
    final items    = context.read<CartProvider>().selectedItems;
    final sellerId = items.isNotEmpty ? items.first.sellerId : '';

    if (sellerId.isEmpty) {
      if (mounted) setState(() => _loadingSellerAddress = false);
      return;
    }
    try {
      final snap = await _firestore
          .collection('users').doc(sellerId)
          .collection('addresses')
          .where('isStoreAddress', isEqualTo: true)
          .limit(1).get();

      if (!mounted) return;
      setState(() {
        _sellerStoreAddress   = snap.docs.isNotEmpty ? snap.docs.first.data() : null;
        _loadingSellerAddress = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSellerAddress = false);
    }
  }

  Future<void> _loadDefaultAddress() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) { setState(() => _loadingAddress = false); return; }
    try {
      final snap = await _firestore
          .collection('users').doc(uid).collection('addresses')
          .orderBy('createdAt', descending: false).get();
      final docs = snap.docs.map((d) => d.data()).toList();
      final addr = docs.isNotEmpty
          ? docs.firstWhere((d) => d['isDefault'] == true, orElse: () => docs.first)
          : null;
      if (mounted) setState(() {
        _selectedAddress = addr != null ? AddressModel.fromMap(addr) : null;
        _loadingAddress  = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  Future<void> _loadDefaultPayment() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) { setState(() => _loadingPayment = false); return; }
    try {
      final snap = await _firestore
          .collection('users').doc(uid).collection('payment_methods')
          .orderBy('createdAt', descending: false).get();
      final docs = snap.docs.map((d) => d.data()).toList();
      final pm   = docs.isNotEmpty
          ? docs.firstWhere((d) => d['isDefault'] == true, orElse: () => docs.first)
          : null;
      if (mounted) setState(() {
        _selectedPayment = pm != null ? PaymentMethodModel.fromMap(pm) : null;
        _loadingPayment  = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPayment = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  CALCUL LIVRAISON
  // ─────────────────────────────────────────────────────────────

  double _totalShipping(List<CartItemModel> items) {
    if (!_zoneReady || _selectedAddress == null) return 0.0;
    return items.fold(0.0, (sum, item) => sum + (item.shippingPrice(_zone) ?? 0.0));
  }

  List<CartItemModel> _undeliverableItems(List<CartItemModel> items) =>
      items.where((i) => !i.canDeliverTo(_zone)).toList();

  bool _hasUndeliverable(List<CartItemModel> items) =>
      _undeliverableItems(items).isNotEmpty;

  // ─────────────────────────────────────────────────────────────
  //  NAVIGATION
  // ─────────────────────────────────────────────────────────────

  Future<void> _pickAddress() async {
    final result = await Navigator.push<AddressModel>(context,
        MaterialPageRoute(builder: (_) => AddressPickerPage(
            currentAddressId: _selectedAddress?.id)));
    if (result != null && mounted) {
      // Recharger l'adresse vendeur aussi (la zone peut changer)
      setState(() {
        _selectedAddress      = result;
        _loadingSellerAddress = true;
      });
      await _loadSellerStoreAddress();
    }
  }

  Future<void> _addAddress() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressPage()));
    setState(() => _loadingAddress = true);
    await _loadDefaultAddress();
  }

  Future<void> _pickPayment() async {
    final result = await Navigator.push<PaymentMethodModel>(context,
        MaterialPageRoute(builder: (_) => PaymentPickerPage(
            currentPaymentId: _selectedPayment?.id)));
    if (result != null && mounted) setState(() => _selectedPayment = result);
  }

  Future<void> _addPayment() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const PaymentMethodsPage()));
    setState(() => _loadingPayment = true);
    await _loadDefaultPayment();
  }

  // ─────────────────────────────────────────────────────────────
  //  PAIEMENT
  // ─────────────────────────────────────────────────────────────

  Future<void> _processPayment(List<CartItemModel> items) async {
    if (_selectedAddress == null || _selectedPayment == null) return;
    setState(() => _isProcessing = true);
    try {
      final cart         = context.read<CartProvider>();
      final shippingCost = _totalShipping(items);
      final total        = cart.selectedProductsTotal + shippingCost;
      bool  success      = false;

      switch (_selectedPayment!.type) {
        case 'card':
          final pmId = _selectedPayment!.stripePaymentMethodId;
          final cId  = _selectedPayment!.stripeCustomerId;
          success = (pmId != null && cId != null)
              ? await PaymentService.processPaymentWithSavedCard(
              amount: total, currency: 'usd',
              stripeCustomerId: cId, stripePaymentMethodId: pmId)
              : await PaymentService.processPayment(amount: total, currency: 'usd');
          break;
        case 'paypal':
          final r = await PaymentService.processPayPalPayment(
              amount: total, description: 'Winzy Order');
          if (r.cancelled) { if (mounted) setState(() => _isProcessing = false); return; }
          if (!r.success)  { _showSnack(r.errorMessage ?? _t('checkout_paypal_error'));
          if (mounted) setState(() => _isProcessing = false); return; }
          success = true;
          break;
        case 'cash': success = true; break;
        default:
          success = await PaymentService.processPayment(amount: total, currency: 'usd');
      }

      if (!mounted) return;
      setState(() => _isProcessing = false);
      if (!success) return;
      await _createOrder(cart, items, total, shippingCost);
      if (!mounted) return;
      _showSuccessDialog(total);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showSnack('${_t('checkout_error_prefix')} $e');
    }
  }

  Future<void> _createOrder(CartProvider cart, List<CartItemModel> items,
      double total, double shippingCost) async {
    await CreateOrderService().createOrder(
      items:         items,
      address:       _selectedAddress!,
      paymentMethod: _selectedPayment!.type,
      zone:          _zone,
    );
  }
  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cart          = context.watch<CartProvider>();
    final selectedItems = cart.selectedItems;
    final isTablet      = MediaQuery.of(context).size.width > 600;
    final bottomPad     = MediaQuery.of(context).padding.bottom;
    final isRtl         = AppLocalizations.isRtl;

    // ✅ Ne calculer zone / livraison / non-livrable QUE quand les 2 adresses
    //    sont chargées — évite le faux positif "non livrable"
    final zoneReady     = _zoneReady;
    final zone          = zoneReady ? _zone : ShippingZone.world;
    final shipping      = zoneReady ? _totalShipping(selectedItems) : 0.0;
    final total         = cart.selectedProductsTotal + shipping;
    final undeliverable = zoneReady && _selectedAddress != null
        && _hasUndeliverable(selectedItems);

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(_t('checkout_title'),
              style: const TextStyle(fontSize: 18,
                  fontWeight: FontWeight.w700, color: Colors.black87)),
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
              onPressed: () => Navigator.pop(context)),
          bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: Colors.grey.shade100)),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              isTablet ? 24 : 16, isTablet ? 24 : 16,
              isTablet ? 24 : 16, 100 + bottomPad),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Bannière non livrable — seulement quand zone connue
            if (zoneReady && _selectedAddress != null && undeliverable)
              _buildUndeliverableBanner(selectedItems),

            _buildSectionTitle('${_t('my_articles')} (${selectedItems.length})'),
            const SizedBox(height: 12),
            _buildProductsList(selectedItems, zone, zoneReady),
            const SizedBox(height: 24),
            _buildSectionTitle(_t('delivery_address')),
            const SizedBox(height: 12),
            _buildAddressCard(zone, zoneReady),
            const SizedBox(height: 24),
            _buildSectionTitle(_t('payment_method')),
            const SizedBox(height: 12),
            _buildPaymentCard(),
            const SizedBox(height: 24),
            _buildSectionTitle(_t('summary')),
            const SizedBox(height: 12),
            _buildPriceSummary(cart, selectedItems, zone, zoneReady, shipping, total),
          ]),
        ),
        bottomNavigationBar: _buildBottomBar(
            selectedItems, total, undeliverable, zoneReady, bottomPad),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  BANNIÈRE NON LIVRABLE
  // ─────────────────────────────────────────────────────────────

  Widget _buildUndeliverableBanner(List<CartItemModel> items) {
    final count = _undeliverableItems(items).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
                  ? _t('checkout_undeliverable_single')
                  : _t('checkout_undeliverable_multi').replaceFirst('{n}', '$count'),
              style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.bold, color: Color(0xFF9A3412)),
            ),
            const SizedBox(height: 3),
            Text(_t('checkout_undeliverable_desc'),
                style: const TextStyle(fontSize: 12,
                    color: Color(0xFFC2410C), height: 1.4)),
          ])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: _pickAddress,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: const Color(0xFFF97316),
                    borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(_t('checkout_change_address'),
                    style: const TextStyle(color: Colors.white,
                        fontSize: 13, fontWeight: FontWeight.w700))),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF97316))),
                child: Center(child: Text(_t('checkout_back_to_cart'),
                    style: const TextStyle(color: Color(0xFFF97316),
                        fontSize: 13, fontWeight: FontWeight.w700))),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  LISTE PRODUITS
  // ─────────────────────────────────────────────────────────────

  Widget _buildProductsList(List<CartItemModel> items,
      ShippingZone zone, bool zoneReady) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(children: items.asMap().entries.map((entry) {
        final i    = entry.key;
        final item = entry.value;
        final imageBytes = item.images.isNotEmpty
            ? (() { try { return base64Decode(item.images.first); }
        catch (_) { return null; } })()
            : null;

        // ✅ canDeliver / shipPrice seulement quand zone connue
        final canDeliver = zoneReady ? item.canDeliverTo(zone) : true;
        final shipPrice  = zoneReady ? item.shippingPrice(zone) : null;

        return Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(width: 64, height: 64,
                        color: Colors.grey.shade100,
                        child: imageBytes != null
                            ? Image.memory(imageBytes, fit: BoxFit.cover)
                            : Icon(Icons.image_outlined,
                            color: Colors.grey.shade400, size: 28)),
                  ),
                  if (zoneReady && !canDeliver)
                    Positioned.fill(child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                          color: Colors.black.withOpacity(0.45),
                          child: const Center(child:
                          Icon(Icons.block_rounded, color: Colors.white, size: 22))),
                    )),
                ]),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600,
                          fontSize: 13, color: Color(0xFF1E293B)),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(item.storeName,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('\$${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w800,
                          fontSize: 14, color: Colors.deepPurple)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('×${item.quantity}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700)),
                  ),
                ]),
              ]),
              const SizedBox(height: 8),
              // ✅ Badge livraison — loading pendant résolution zone
              if (!zoneReady)
                _badgeLoading()
              else if (!canDeliver)
                _badgeUnavailable()
              else if (shipPrice != null)
                  _badgeAvailable(shipPrice, zone)
                else
                  _badgeFree(),
            ]),
          ),
          if (i < items.length - 1)
            const Divider(height: 1, color: Color(0xFFF0F0F0),
                indent: 12, endIndent: 12),
        ]);
      }).toList()),
    );
  }

  Widget _badgeAvailable(double price, ShippingZone zone) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF93C5FD))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(zone.emoji, style: const TextStyle(fontSize: 11)),
      const SizedBox(width: 5),
      const Icon(Icons.local_shipping_rounded, size: 12, color: Color(0xFF3B82F6)),
      const SizedBox(width: 5),
      Flexible(child: Text(zone.label(AppLocalizations.getLanguage()),
          style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6)))),
      const SizedBox(width: 5),
      Text('+ ${price.toStringAsFixed(2)} \$',
          style: const TextStyle(fontSize: 12,
              fontWeight: FontWeight.w700, color: Color(0xFF3B82F6))),
    ]),
  );

  Widget _badgeUnavailable() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFB923C))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.block_rounded, size: 12, color: Color(0xFFF97316)),
      const SizedBox(width: 5),
      Text(_t('checkout_not_deliverable'),
          style: const TextStyle(fontSize: 11,
              fontWeight: FontWeight.w600, color: Color(0xFFF97316))),
    ]),
  );

  Widget _badgeFree() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF86EFAC))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.check_circle_outline_rounded, size: 12, color: Color(0xFF22C55E)),
      const SizedBox(width: 5),
      Text(_t('cart_shipping_free'),
          style: const TextStyle(fontSize: 11,
              fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
    ]),
  );

  Widget _badgeLoading() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8)),
    child: const SizedBox(width: 80, height: 12,
        child: LinearProgressIndicator(
            backgroundColor: Color(0xFFF1F5F9), color: Colors.deepPurple)),
  );

  // ─────────────────────────────────────────────────────────────
  //  ADRESSE
  // ─────────────────────────────────────────────────────────────

  Widget _buildAddressCard(ShippingZone zone, bool zoneReady) {
    if (_loadingAddress) return _buildLoadingCard();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 3))]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 40, height: 40,
            decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.location_on_rounded,
                size: 20, color: Colors.deepPurple)),
        const SizedBox(width: 12),
        Expanded(child: _selectedAddress == null
            ? Text(_t('no_address_selected'),
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500,
                fontStyle: FontStyle.italic))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_selectedAddress!.contactName,
              style: const TextStyle(fontWeight: FontWeight.w700,
                  fontSize: 14, color: Color(0xFF1E293B))),
          const SizedBox(height: 3),
          Text('${_selectedAddress!.countryFlag} '
              '${_selectedAddress!.countryCode} ${_selectedAddress!.phone}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 3),
          Text(_selectedAddress!.fullAddress,
              style: TextStyle(fontSize: 13,
                  color: Colors.grey.shade700, height: 1.4)),
          const SizedBox(height: 6),
          // Badge zone — visible seulement quand zone connue
          if (zoneReady)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(zone.emoji, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              Text(
                '${_t('checkout_zone_label')} : '
                    '${zone.label(AppLocalizations.getLanguage())}',
                style: const TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
            ])
          else
            Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 60, height: 10,
                  child: LinearProgressIndicator(
                      backgroundColor: Color(0xFFF1F5F9),
                      color: Colors.deepPurple)),
            ]),
        ])),
        _selectedAddress == null
            ? _actionBtn(_t('add'), _addAddress, isAdd: true)
            : _actionBtn(_t('edit'), _pickAddress),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  PAIEMENT
  // ─────────────────────────────────────────────────────────────

  Widget _buildPaymentCard() {
    if (_loadingPayment) return _buildLoadingCard();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 3))]),
      child: Row(children: [
        Container(width: 44, height: 44,
            decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(_selectedPayment?.icon ?? Icons.payment_rounded,
                size: 22, color: Colors.deepPurple)),
        const SizedBox(width: 12),
        Expanded(child: _selectedPayment == null
            ? Text(_t('no_payment_selected'),
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500,
                fontStyle: FontStyle.italic))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_selectedPayment!.displayName,
              style: const TextStyle(fontWeight: FontWeight.w700,
                  fontSize: 14, color: Color(0xFF1E293B))),
          if (_selectedPayment!.subtitle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(_selectedPayment!.subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ])),
        _selectedPayment == null
            ? _actionBtn(_t('add'), _addPayment, isAdd: true)
            : _actionBtn(_t('edit'), _pickPayment),
      ]),
    );
  }

  Widget _actionBtn(String label, VoidCallback onTap, {bool isAdd = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: isAdd ? Colors.green.withOpacity(0.1)
                : Colors.deepPurple.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (isAdd) ...[
            Icon(Icons.add_rounded, size: 14,
                color: isAdd ? Colors.green.shade700 : Colors.deepPurple.shade600),
            const SizedBox(width: 3),
          ],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: isAdd ? Colors.green.shade700 : Colors.deepPurple.shade600)),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  RÉCAP PRIX
  // ─────────────────────────────────────────────────────────────

  Widget _buildPriceSummary(CartProvider cart, List<CartItemModel> items,
      ShippingZone zone, bool zoneReady, double shipping, double total) {

    // Détail livraison par boutique
    final Map<String, double> byVendor = {};
    if (zoneReady) {
      for (final item in items) {
        final p = item.shippingPrice(zone);
        if (p == null) continue;
        byVendor[item.storeName] = (byVendor[item.storeName] ?? 0.0) + p;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(children: [
        _priceRow(_t('cart_products_subtotal'),
            '\$${cart.selectedProductsTotal.toStringAsFixed(2)}'),
        const SizedBox(height: 10),

        // Livraison
        if (!zoneReady)
          _priceRowLoading(_t('cart_shipping_subtotal'))
        else if (byVendor.isNotEmpty) ...[
          const Divider(height: 14),
          Align(alignment: Alignment.centerLeft,
              child: Text(_t('cart_shipping_detail'),
                  style: const TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)))),
          const SizedBox(height: 6),
          ...byVendor.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Icon(Icons.storefront_rounded,
                  size: 13, color: Colors.deepPurple.shade300),
              const SizedBox(width: 6),
              Expanded(child: Text(e.key,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text('+ \$${e.value.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w600, color: Color(0xFF3B82F6))),
            ]),
          )),
          const Divider(height: 14),
          _priceRow(
            '${_t('cart_shipping_subtotal')} '
                '(${zone.emoji} ${zone.label(AppLocalizations.getLanguage())})',
            '\$${shipping.toStringAsFixed(2)}',
            valueColor: const Color(0xFF3B82F6),
          ),
        ] else
          _priceRow(_t('cart_shipping_subtotal'), _t('cart_shipping_free'),
              valueColor: Colors.green.shade600),

        const Padding(padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1)),
        _priceRow(_t('cart_total'), '\$${total.toStringAsFixed(2)}',
            isBold: true, isLarge: true, valueColor: Colors.deepPurple),
      ]),
    );
  }

  Widget _priceRow(String label, String value,
      {bool isBold = false, bool isLarge = false, Color? valueColor}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Expanded(child: Text(label, style: TextStyle(
          fontSize: isLarge ? 15 : 13,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
          color: const Color(0xFF475569)))),
      Text(value, style: TextStyle(
          fontSize: isLarge ? 16 : 13,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          color: valueColor ?? const Color(0xFF1E293B))),
    ]);
  }

  Widget _priceRowLoading(String label) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
      const SizedBox(width: 60, height: 14,
          child: LinearProgressIndicator(
              backgroundColor: Color(0xFFF1F5F9), color: Colors.deepPurple,
              borderRadius: BorderRadius.all(Radius.circular(8)))),
    ]);
  }

  // ─────────────────────────────────────────────────────────────
  //  BOTTOM BAR
  // ─────────────────────────────────────────────────────────────

  Widget _buildBottomBar(List<CartItemModel> items, double total,
      bool undeliverable, bool zoneReady, double bottomPad) {

    // Bloqué si : en traitement, pas d'adresse, pas de paiement,
    // zone pas encore connue, ou articles non livrables
    final isBlocked = _isProcessing
        || _selectedAddress == null
        || _selectedPayment == null
        || !zoneReady
        || undeliverable;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),
              blurRadius: 16, offset: const Offset(0, -4))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Message d'erreur non livrable
        if (undeliverable && zoneReady && _selectedAddress != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFB923C))),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFF97316), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_t('checkout_blocked_message'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9A3412)))),
            ]),
          ),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isBlocked ? null : () => _processPayment(items),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 4,
                shadowColor: Colors.deepPurple.withOpacity(0.4)),
            child: _isProcessing
                ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Colors.white)))
                : !zoneReady
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white))),
              const SizedBox(width: 10),
              Text(_t('checkout_calculating'),
                  style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ])
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.lock_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                undeliverable
                    ? _t('checkout_fix_selection')
                    : '${_t('pay_button')} \$${total.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  DIALOGS / HELPERS
  // ─────────────────────────────────────────────────────────────

  void _showSuccessDialog(double totalPaid) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 20,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 88, height: 88,
                decoration: BoxDecoration(color: Colors.green.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green.shade200, width: 2)),
                child: Icon(Icons.check_circle_rounded,
                    size: 52, color: Colors.green.shade500)),
            const SizedBox(height: 20),
            Text(_t('order_confirmed'), textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22,
                    fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Text(_t('order_confirmed_desc'), textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14,
                    color: Colors.grey.shade500, height: 1.5)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.2))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.payments_rounded, color: Colors.green.shade600, size: 20),
                const SizedBox(width: 8),
                Text('\$${totalPaid.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                        color: Colors.green.shade600)),
              ]),
            ),
            const SizedBox(height: 28),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                  mainLayoutKey.currentState?.setIndex(0);
                  historyPageKey.currentState?.loadOrders();
                },
                icon: const Icon(Icons.home_rounded, size: 20),
                label: Text(_t('back_to_home'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                    shadowColor: Colors.deepPurple.withOpacity(0.3)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                  mainLayoutKey.currentState?.setIndex(2);
                  historyPageKey.currentState?.loadOrders();
                },
                icon: Icon(Icons.receipt_long_rounded,
                    size: 20, color: Colors.deepPurple.shade600),
                label: Text(_t('view_orders'),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                        color: Colors.deepPurple.shade600)),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.deepPurple.shade200, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.deepPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  Widget _buildSectionTitle(String t) => Text(t,
      style: const TextStyle(fontSize: 16,
          fontWeight: FontWeight.w700, color: Color(0xFF1E293B)));

  Widget _buildLoadingCard() => Container(height: 72,
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(14)),
      child: const Center(child: SizedBox(width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.deepPurple)))));
}
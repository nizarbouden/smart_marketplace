// lib/views/checkout/checkout_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_marketplace/views/payment/payment_picker_page.dart';
import '../../models/product_model.dart';
import '../../models/shipping_zone_model.dart';
import '../../providers/cart_provider.dart';
import '../../localization/app_localizations.dart';
import '../../services/payment_service.dart';
import '../compte/adress/address_picker_page.dart';
import '../compte/payment/payment_methods_page.dart';
import '../compte/adress/address_page.dart';
import '../layout/main_layout.dart';

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

  // ✅ Livraison — nouveau modèle par zones
  List<_ItemShipping> _itemShippings = [];
  bool _loadingShipping = true;

  String _t(String key) => AppLocalizations.get(key);

  @override
  void initState() {
    super.initState();
    _loadDefaultAddress();
    _loadDefaultPayment();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadItemShippings());
  }

  // ── Adresse par défaut ────────────────────────────────────────

  Future<void> _loadDefaultAddress() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) { setState(() => _loadingAddress = false); return; }
    try {
      final snap = await _firestore
          .collection('users').doc(uid).collection('addresses')
          .orderBy('createdAt', descending: false).get();
      final addresses = snap.docs.map((d) => AddressModel.fromMap(d.data())).toList();
      AddressModel? selected;
      if (addresses.length == 1) {
        selected = addresses.first;
      } else if (addresses.isNotEmpty) {
        final defaults = addresses.where((a) => a.isDefault).toList();
        selected = defaults.isNotEmpty ? defaults.first : addresses.first;
      }
      if (mounted) setState(() { _selectedAddress = selected; _loadingAddress = false; });
      // Recalculer la livraison dès qu'on a l'adresse
      if (_selectedAddress != null && _itemShippings.isNotEmpty) _recalcShipping();
    } catch (e) {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  // ── Paiement par défaut ───────────────────────────────────────

  Future<void> _loadDefaultPayment() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) { setState(() => _loadingPayment = false); return; }
    try {
      final snap = await _firestore
          .collection('users').doc(uid).collection('payment_methods')
          .orderBy('createdAt', descending: false).get();
      final methods = snap.docs.map((d) => PaymentMethodModel.fromMap(d.data())).toList();
      PaymentMethodModel? selected;
      if (methods.length == 1) {
        selected = methods.first;
      } else if (methods.isNotEmpty) {
        final defaults = methods.where((m) => m.isDefault).toList();
        selected = defaults.isNotEmpty ? defaults.first : methods.first;
      }
      if (mounted) setState(() { _selectedPayment = selected; _loadingPayment = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingPayment = false);
    }
  }

  // ── Livraison — chargement et calcul ─────────────────────────

  /// Détermine la zone de l'acheteur à partir de l'adresse sélectionnée.
  /// Utilise le countryName stocké dans Firestore → mapping vers zone tarifaire.
  ShippingZone _buyerZone() {
    final addr = _selectedAddress;
    if (addr == null) return ShippingZone.world;
    // countryName est le nom complet du pays (ex: "Tunisie", "France")
    return ShippingZoneExt.zoneForCountryName(addr.countryName);
  }

  /// Charge le ProductShipping de chaque produit du panier depuis Firestore.
  Future<void> _loadItemShippings() async {
    final cart  = context.read<CartProvider>();
    final items = cart.selectedItems;
    if (items.isEmpty) {
      if (mounted) setState(() { _itemShippings = []; _loadingShipping = false; });
      return;
    }
    final shippings = <_ItemShipping>[];
    for (final item in items) {
      try {
        final doc  = await _firestore.collection('products').doc(item.productId).get();
        final data = doc.data();
        ProductShipping ps;
        if (data?['shipping'] != null) {
          // Nouveau format
          ps = ProductShipping.fromMap(data!['shipping'] as Map<String, dynamic>);
        } else {
          // Ancien format (compat descendante)
          ps = ProductShipping.fromLegacy(
            shippingCompanyId: data?['shippingCompanyId'] as String?,
            productWeight:     (data?['productWeight'] as num?)?.toDouble(),
          );
        }
        shippings.add(_ItemShipping(productId: item.productId, shipping: ps, quantity: item.quantity));
      } catch (_) {
        shippings.add(_ItemShipping(productId: item.productId, quantity: 1));
      }
    }
    if (mounted) {
      setState(() { _itemShippings = shippings; _loadingShipping = false; });
    }
  }

  /// Recalcul immédiat quand l'adresse change (sans recharger Firestore).
  void _recalcShipping() {
    if (mounted) setState(() {}); // zone recalculée à chaque build via _buyerZone()
  }

  /// Coût total livraison selon la zone de l'acheteur.
  double get _totalShippingCost {
    final zone = _buyerZone();
    return _itemShippings.fold(0.0, (sum, s) {
      final price = s.shipping?.priceForZone(zone);
      return sum + ((price ?? 0.0) * s.quantity);
    });
  }

  // ── Navigation ────────────────────────────────────────────────

  Future<void> _pickAddress() async {
    final result = await Navigator.push<AddressModel>(context,
        MaterialPageRoute(builder: (_) => AddressPickerPage(
            currentAddressId: _selectedAddress?.id)));
    if (result != null && mounted) {
      setState(() => _selectedAddress = result);
      _recalcShipping();
    }
  }

  Future<void> _addAddress() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const AddressPage()));
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

  // ── Paiement ─────────────────────────────────────────────────

  Future<void> _processPayment() async {
    if (_selectedAddress == null || _selectedPayment == null) return;
    setState(() => _isProcessing = true);
    try {
      final cart  = context.read<CartProvider>();
      final total = cart.estimatedTotal + _totalShippingCost;
      bool  success = false;

      switch (_selectedPayment!.type) {
        case 'card':
          final pmId = _selectedPayment!.stripePaymentMethodId;
          final cId  = _selectedPayment!.stripeCustomerId;
          if (pmId != null && cId != null) {
            success = await PaymentService.processPaymentWithSavedCard(
                amount: total, currency: 'usd',
                stripeCustomerId: cId, stripePaymentMethodId: pmId);
          } else {
            success = await PaymentService.processPayment(
                amount: total, currency: 'usd');
          }
          break;
        case 'paypal':
          final result = await PaymentService.processPayPalPayment(
              amount: total, description: 'Winzy Order');
          if (result.cancelled) {
            if (mounted) setState(() => _isProcessing = false);
            return;
          }
          if (!result.success) {
            _showSnack(result.errorMessage ?? 'Erreur PayPal');
            if (mounted) setState(() => _isProcessing = false);
            return;
          }
          success = true;
          break;
        case 'cash':
          success = true;
          break;
        default:
          success = await PaymentService.processPayment(
              amount: total, currency: 'usd');
      }

      if (!mounted) return;
      setState(() => _isProcessing = false);
      if (!success) return;
      await _createOrder(cart, total);
      if (!mounted) return;
      _showSuccessDialog(total);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showSnack('Erreur: $e');
    }
  }

  Future<void> _createOrder(CartProvider cart, double total) async {
    final uid      = _auth.currentUser!.uid;
    final batch    = _firestore.batch();
    final orderRef = _firestore.collection('orders').doc();
    final zone     = _buyerZone();

    final orderData = {
      'id':            orderRef.id,
      'userId':        uid,
      'items':         cart.selectedItems.map((i) => i.toMap()).toList(),
      'total':         total,
      'shippingCost':  _totalShippingCost,
      'shippingZone':  zone.id,                     // ✅ zone enregistrée
      'address':       _selectedAddress!.toMap(),
      'paymentMethod': _selectedPayment!.type,
      'status':        'paid',
      'createdAt':     Timestamp.now(),
    };
    batch.set(orderRef, orderData);
    batch.set(
        _firestore.collection('users').doc(uid).collection('orders').doc(orderRef.id),
        orderData);

    for (final item in cart.selectedItems) {
      batch.delete(_firestore
          .collection('users').doc(uid).collection('cart').doc(item.cartDocId));
    }
    for (final item in cart.selectedItems) {
      final ref  = _firestore.collection('products').doc(item.productId);
      final snap = await ref.get();
      if (snap.exists) {
        final data     = snap.data() ?? {};
        final cur      = (data['stock'] as num?)?.toInt() ?? 0;
        final newStock = (cur - item.quantity).clamp(0, cur);
        final update   = <String, dynamic>{
          'stock':     newStock,
          'updatedAt': Timestamp.now(),
        };
        if (data['initialStock'] == null) update['initialStock'] = cur;
        batch.update(ref, update);
      }
    }
    await batch.commit();
  }

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
            Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green.shade200, width: 2)),
                child: Icon(Icons.check_circle_rounded,
                    size: 52, color: Colors.green.shade500)),
            const SizedBox(height: 20),
            Text(_t('order_confirmed'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Text(_t('order_confirmed_desc'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: Colors.grey.shade500, height: 1.5)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.2))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.payments_rounded,
                    color: Colors.green.shade600, size: 20),
                const SizedBox(width: 8),
                Text('\$${totalPaid.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.green.shade600)),
              ]),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                  mainLayoutKey.currentState?.setIndex(0);
                  historyPageKey.currentState?.loadOrders();
                },
                icon: const Icon(Icons.home_rounded, size: 20),
                label: Text(_t('back_to_home'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                    shadowColor: Colors.deepPurple.withOpacity(0.3)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
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
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple.shade600)),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                        color: Colors.deepPurple.shade200, width: 1.5),
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

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cart          = context.watch<CartProvider>();
    final selectedItems = cart.selectedItems;
    final isTablet      = MediaQuery.of(context).size.width > 600;
    final bottomPad     = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(_t('checkout_title'),
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
            onPressed: () => Navigator.pop(context)),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: Colors.grey.shade100)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            isTablet ? 24 : 16, isTablet ? 24 : 16,
            isTablet ? 24 : 16, 100 + bottomPad),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionTitle(
              '${_t('my_articles')} (${selectedItems.length})'),
          const SizedBox(height: 12),
          _buildProductsList(selectedItems),
          const SizedBox(height: 24),
          _buildSectionTitle(_t('delivery_address')),
          const SizedBox(height: 12),
          _buildAddressCard(),
          const SizedBox(height: 24),
          _buildSectionTitle(_t('payment_method')),
          const SizedBox(height: 12),
          _buildPaymentCard(),
          const SizedBox(height: 24),
          _buildSectionTitle(_t('summary')),
          const SizedBox(height: 12),
          _buildPriceSummary(cart),
        ]),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4))
            ]),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_isProcessing ||
                _selectedAddress == null ||
                _selectedPayment == null)
                ? null
                : _processPayment,
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
                ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.lock_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                  '${_t('pay_button')} \$${(cart.estimatedTotal + _totalShippingCost).toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(title,
      style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E293B)));

  // ── Liste produits ────────────────────────────────────────────

  Widget _buildProductsList(List<CartItemModel> items) {
    final zone = _buyerZone();
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ]),
      child: Column(
          children: items.asMap().entries.map((entry) {
            final i      = entry.key;
            final item   = entry.value;
            final isLast = i == items.length - 1;
            final imageBytes = item.images.isNotEmpty
                ? (() {
              try { return base64Decode(item.images.first); }
              catch (_) { return null; }
            })()
                : null;
            final shipping = _itemShippings.isNotEmpty
                ? _itemShippings
                .cast<_ItemShipping?>()
                .firstWhere((s) => s?.productId == item.productId,
                orElse: () => null)
                : null;

            return Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 64, height: 64,
                            color: Colors.grey.shade100,
                            child: imageBytes != null
                                ? Image.memory(imageBytes, fit: BoxFit.cover)
                                : Icon(Icons.image_outlined,
                                color: Colors.grey.shade400, size: 28),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: Color(0xFF1E293B)),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text(item.storeName,
                                      style:
                                      TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('\$${item.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Colors.deepPurple)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8)),
                            child: Text('x${item.quantity}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700)),
                          ),
                        ]),
                      ]),

                      // ✅ Ligne livraison calculée selon zone acheteur
                      if (shipping?.shipping != null &&
                          shipping!.shipping!.isConfigured) ...[
                        const SizedBox(height: 8),
                        _buildItemShippingRow(shipping, zone),
                      ],
                    ]),
              ),
              if (!isLast)
                const Divider(
                    height: 1,
                    color: Color(0xFFF0F0F0),
                    indent: 12,
                    endIndent: 12),
            ]);
          }).toList()),
    );
  }

  Widget _buildItemShippingRow(_ItemShipping s, ShippingZone zone) {
    final ps      = s.shipping!;
    final company = ShippingCompanies.findById(ps.companyId);
    if (company == null) return const SizedBox.shrink();

    final price = ps.priceForZone(zone);
    final color = Color(company.colorValue);

    // Zone non couverte par le vendeur pour cette destination
    if (price == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.2))),
        child: Row(children: [
          const Text('⚠️', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Expanded(
              child: Text(
                'Livraison non disponible pour votre pays',
                style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
              )),
        ]),
      );
    }

    final totalCost = price * s.quantity;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.15))),
      child: Row(children: [
        Text(company.logo, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(company.name,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                  // ✅ Affiche la zone détectée
                  Text(zone.labelFr(),
                      style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ])),
        Text('+${totalCost.toStringAsFixed(2)} DT',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  // ── Adresse / Paiement cards ──────────────────────────────────

  Widget _buildAddressCard() {
    if (_loadingAddress) return _buildLoadingCard();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.08),
              shape: BoxShape.circle),
          child: const Icon(Icons.location_on_rounded,
              size: 20, color: Colors.deepPurple),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: _selectedAddress == null
                ? Text(_t('no_address_selected'),
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic))
                : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selectedAddress!.contactName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF1E293B))),
                  const SizedBox(height: 3),
                  Text(
                      '${_selectedAddress!.countryFlag} ${_selectedAddress!.countryCode} ${_selectedAddress!.phone}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 3),
                  Text(_selectedAddress!.fullAddress,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.4)),
                  // ✅ Affiche la zone détectée sous l'adresse
                  const SizedBox(height: 4),
                  _buildZoneBadge(),
                ])),
        _selectedAddress == null
            ? _actionButton(_t('add'), _addAddress, isAdd: true)
            : _actionButton(_t('edit'), _pickAddress),
      ]),
    );
  }

  /// Badge indiquant la zone tarifaire détectée pour l'adresse choisie.
  Widget _buildZoneBadge() {
    if (_selectedAddress == null) return const SizedBox.shrink();
    final zone = _buyerZone();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(zone.emoji, style: const TextStyle(fontSize: 11)),
      const SizedBox(width: 4),
      Text('Zone : ${zone.labelFr()}',
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B))),
    ]);
  }

  Widget _buildPaymentCard() {
    if (_loadingPayment) return _buildLoadingCard();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ]),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(_selectedPayment?.icon ?? Icons.payment_rounded,
              size: 22, color: Colors.deepPurple),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: _selectedPayment == null
                ? Text(_t('no_payment_selected'),
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic))
                : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selectedPayment!.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF1E293B))),
                  if (_selectedPayment!.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(_selectedPayment!.subtitle,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ])),
        _selectedPayment == null
            ? _actionButton(_t('add'), _addPayment, isAdd: true)
            : _actionButton(_t('edit'), _pickPayment),
      ]),
    );
  }

  Widget _actionButton(String label, VoidCallback onTap,
      {bool isAdd = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: isAdd
                ? Colors.green.withOpacity(0.1)
                : Colors.deepPurple.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (isAdd) ...[
            Icon(Icons.add_rounded,
                size: 14,
                color: isAdd
                    ? Colors.green.shade700
                    : Colors.deepPurple.shade600),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isAdd
                      ? Colors.green.shade700
                      : Colors.deepPurple.shade600)),
        ]),
      ),
    );
  }

  // ── Récap prix ────────────────────────────────────────────────

  Widget _buildPriceSummary(CartProvider cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ]),
      child: Column(children: [
        _priceRow(
            _t('total_items'), '\$${cart.selectedTotal.toStringAsFixed(2)}'),
        const SizedBox(height: 10),
        _priceRow(_t('discount_10'),
            '-\$${(cart.selectedTotal * 0.1).toStringAsFixed(2)}',
            valueColor: Colors.green.shade600),
        const SizedBox(height: 10),
        _priceRow(_t('subtotal'), '\$${cart.subtotal.toStringAsFixed(2)}'),
        const SizedBox(height: 10),

        // ✅ Frais de livraison par zone
        if (_loadingShipping)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Livraison',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF475569))),
                  SizedBox(
                      width: 60,
                      height: 14,
                      child: LinearProgressIndicator(
                          borderRadius:
                          BorderRadius.all(Radius.circular(8)))),
                ]),
          )
        else if (_totalShippingCost == 0.0)
          _priceRow('Livraison', 'Gratuite',
              valueColor: Colors.green.shade600)
        else ...[
            ..._buildShippingBreakdown(),
          ],

        const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1)),

        // ✅ Total livraison incluse
        _priceRow(
            _t('estimated_total'),
            '\$${(cart.estimatedTotal + _totalShippingCost).toStringAsFixed(2)}',
            isBold: true,
            isLarge: true,
            valueColor: Colors.deepPurple),
      ]),
    );
  }

  List<Widget> _buildShippingBreakdown() {
    final zone = _buyerZone();
    // Regrouper par société
    final Map<String, double> byCompany = {};
    for (final s in _itemShippings) {
      if (s.shipping == null || !s.shipping!.isConfigured) continue;
      final price = s.shipping!.priceForZone(zone);
      if (price == null) continue;
      final id = s.shipping!.companyId!;
      byCompany[id] = (byCompany[id] ?? 0) + price * s.quantity;
    }

    if (byCompany.isEmpty) {
      return [
        _priceRow('Livraison', 'Non disponible pour votre pays',
            valueColor: Colors.orange)
      ];
    }

    return byCompany.entries.map((entry) {
      final company = ShippingCompanies.findById(entry.key);
      if (company == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text(company.logo, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(company.name,
                    style:
                    const TextStyle(fontSize: 13, color: Color(0xFF475569))),
              ]),
              Text('+${entry.value.toStringAsFixed(2)} DT',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(company.colorValue))),
            ]),
      );
    }).toList();
  }

  Widget _priceRow(String label, String value,
      {bool isBold = false, bool isLarge = false, Color? valueColor}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label,
          style: TextStyle(
              fontSize: isLarge ? 15 : 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              color: const Color(0xFF475569))),
      Text(value,
          style: TextStyle(
              fontSize: isLarge ? 16 : 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? const Color(0xFF1E293B))),
    ]);
  }

  Widget _buildLoadingCard() => Container(
      height: 72,
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: const Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                  AlwaysStoppedAnimation(Colors.deepPurple)))));
}

// ── Modèle interne ────────────────────────────────────────────────────────────

class _ItemShipping {
  final String          productId;
  final ProductShipping? shipping;
  final int             quantity;

  _ItemShipping({
    required this.productId,
    this.shipping,
    required this.quantity,
  });
}
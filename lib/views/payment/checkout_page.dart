import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_marketplace/views/payment/payment_picker_page.dart';
import '../../providers/cart_provider.dart';
import '../../localization/app_localizations.dart';
import '../compte/adress/address_picker_page.dart';


class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  AddressModel? _selectedAddress;
  PaymentMethodModel? _selectedPayment;
  bool _loadingAddress = true;
  bool _loadingPayment = true;
  bool _isProcessing = false;

  // ✅ Helper de traduction
  String _t(String key) => AppLocalizations.get(key);

  @override
  void initState() {
    super.initState();
    _loadDefaultAddress();
    _loadDefaultPayment();
  }

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
    } catch (e) {
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

  Future<void> _pickAddress() async {
    final result = await Navigator.push<AddressModel>(
      context,
      MaterialPageRoute(builder: (_) => AddressPickerPage(currentAddressId: _selectedAddress?.id)),
    );
    if (result != null && mounted) setState(() => _selectedAddress = result);
  }

  Future<void> _pickPayment() async {
    final result = await Navigator.push<PaymentMethodModel>(
      context,
      MaterialPageRoute(builder: (_) => PaymentPickerPage(currentPaymentId: _selectedPayment?.id)),
    );
    if (result != null && mounted) setState(() => _selectedPayment = result);
  }

  Future<void> _processPayment() async {
    // ✅ Messages d'erreur traduits
    if (_selectedAddress == null) {
      _showSnack(_t('select_address_error'));
      return;
    }
    if (_selectedPayment == null) {
      _showSnack(_t('select_payment_error'));
      return;
    }

    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isProcessing = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SuccessDialog(
        // ✅ Textes du dialogue traduits
        title: _t('order_confirmed'),
        message: _t('order_confirmed_desc'),
        buttonLabel: _t('back_to_home'),
        onConfirm: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.deepPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final selectedItems = cart.selectedItems;
    final isTablet = MediaQuery.of(context).size.width > 600;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // ✅ Titre traduit
        title: Text(
          _t('checkout_title'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade100),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isTablet ? 24 : 16, isTablet ? 24 : 16,
          isTablet ? 24 : 16, 100 + bottomPad,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ "Mes articles (X)" traduit
            _buildSectionTitle('${_t('my_articles')} (${selectedItems.length})'),
            const SizedBox(height: 12),
            _buildProductsList(selectedItems, isTablet),
            const SizedBox(height: 24),

            // ✅ "Adresse de livraison" traduit
            _buildSectionTitle(_t('delivery_address')),
            const SizedBox(height: 12),
            _buildAddressCard(),
            const SizedBox(height: 24),

            // ✅ "Méthode de paiement" traduit
            _buildSectionTitle(_t('payment_method')),
            const SizedBox(height: 12),
            _buildPaymentCard(),
            const SizedBox(height: 24),

            // ✅ "Résumé" traduit
            _buildSectionTitle(_t('summary')),
            const SizedBox(height: 12),
            _buildPriceSummary(cart),
          ],
        ),
      ),

      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),
              blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _processPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
              shadowColor: Colors.deepPurple.withOpacity(0.4),
            ),
            child: _isProcessing
                ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_rounded, size: 18),
                const SizedBox(width: 8),
                // ✅ "Payer $X" traduit
                Text(
                  '${_t('pay_button')} \$${cart.estimatedTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)));
  }

  Widget _buildProductsList(List<CartItemModel> items, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final isLast = i == items.length - 1;
          final imageBytes = item.images.isNotEmpty
              ? (() { try { return base64Decode(item.images.first); } catch (_) { return null; } })()
              : null;

          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(width: 64, height: 64, color: Colors.grey.shade100,
                      child: imageBytes != null
                          ? Image.memory(imageBytes, fit: BoxFit.cover)
                          : Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 28)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                          color: Color(0xFF1E293B)),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(item.storeName,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('\$${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                          color: Colors.deepPurple)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('x${item.quantity}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700)),
                  ),
                ]),
              ]),
            ),
            if (!isLast) const Divider(height: 1, color: Color(0xFFF0F0F0), indent: 12, endIndent: 12),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildAddressCard() {
    if (_loadingAddress) return _buildLoadingCard();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.08), shape: BoxShape.circle),
          child: const Icon(Icons.location_on_rounded, size: 20, color: Colors.deepPurple),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _selectedAddress == null
          // ✅ "Aucune adresse sélectionnée" traduit
              ? Text(_t('no_address_selected'),
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_selectedAddress!.contactName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 3),
            Text('${_selectedAddress!.countryFlag} ${_selectedAddress!.countryCode} ${_selectedAddress!.phone}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 3),
            Text(_selectedAddress!.fullAddress,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4)),
          ]),
        ),
        // ✅ "Modifier" traduit
        _editButton(_pickAddress),
      ]),
    );
  }

  Widget _buildPaymentCard() {
    if (_loadingPayment) return _buildLoadingCard();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(_selectedPayment?.icon ?? Icons.payment_rounded,
              size: 22, color: Colors.deepPurple),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _selectedPayment == null
          // ✅ "Aucune méthode sélectionnée" traduit
              ? Text(_t('no_payment_selected'),
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_selectedPayment!.displayName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                    color: Color(0xFF1E293B))),
            if (_selectedPayment!.subtitle.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(_selectedPayment!.subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ]),
        ),
        // ✅ "Modifier" traduit
        _editButton(_pickPayment),
      ]),
    );
  }

  // ✅ Bouton "Modifier" centralisé et traduit
  Widget _editButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(_t('edit'),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: Colors.deepPurple.shade600)),
      ),
    );
  }

  Widget _buildPriceSummary(CartProvider cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        // ✅ Tous les labels traduits
        _priceRow(_t('total_items'), '\$${cart.selectedTotal.toStringAsFixed(2)}'),
        const SizedBox(height: 10),
        _priceRow(_t('discount_10'), '-\$${(cart.selectedTotal * 0.1).toStringAsFixed(2)}',
            valueColor: Colors.green.shade600),
        const SizedBox(height: 10),
        _priceRow(_t('subtotal'), '\$${cart.subtotal.toStringAsFixed(2)}'),
        const SizedBox(height: 10),
        _priceRow(_t('shipping'), '\$${cart.shippingFee.toStringAsFixed(2)}'),
        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
        _priceRow(_t('estimated_total'), '\$${cart.estimatedTotal.toStringAsFixed(2)}',
            isBold: true, isLarge: true, valueColor: Colors.deepPurple),
      ]),
    );
  }

  Widget _priceRow(String label, String value,
      {bool isBold = false, bool isLarge = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isLarge ? 15 : 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            color: const Color(0xFF475569))),
        Text(value, style: TextStyle(fontSize: isLarge ? 16 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? const Color(0xFF1E293B))),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 72,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: const Center(child: SizedBox(width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.deepPurple)))),
    );
  }
}

// ── Dialogue de succès ────────────────────────────────────────────
class _SuccessDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  // ✅ Textes passés en paramètres pour la traduction
  final String title;
  final String message;
  final String buttonLabel;

  const _SuccessDialog({
    required this.onConfirm,
    required this.title,
    required this.message,
    required this.buttonLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 72, height: 72,
            decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, size: 40, color: Colors.green.shade600),
          ),
          const SizedBox(height: 20),
          // ✅ Titre traduit
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B))),
          const SizedBox(height: 10),
          // ✅ Message traduit
          Text(message, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              // ✅ Bouton traduit
              child: Text(buttonLabel,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}
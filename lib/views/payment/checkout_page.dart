import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_marketplace/views/payment/payment_picker_page.dart';
import '../../providers/cart_provider.dart';
import '../compte/adress/address_picker_page.dart';


class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ── State ─────────────────────────────────────────────────────
  AddressModel? _selectedAddress;
  PaymentMethodModel? _selectedPayment;
  bool _loadingAddress = true;
  bool _loadingPayment = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadDefaultAddress();
    _loadDefaultPayment();
  }

  // ── Chargement adresse par défaut ─────────────────────────────
  Future<void> _loadDefaultAddress() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) { setState(() => _loadingAddress = false); return; }

    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('addresses')
          .orderBy('createdAt', descending: false)
          .get();

      final addresses = snap.docs
          .map((d) => AddressModel.fromMap(d.data()))
          .toList();

      AddressModel? selected;

      if (addresses.length == 1) {
        selected = addresses.first;
      } else if (addresses.isNotEmpty) {
        // Cherche l'adresse par défaut
        final defaults = addresses.where((a) => a.isDefault).toList();
        selected = defaults.isNotEmpty ? defaults.first : addresses.first;
      }

      if (mounted) setState(() {
        _selectedAddress = selected;
        _loadingAddress = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  // ── Chargement méthode de paiement par défaut ─────────────────
  Future<void> _loadDefaultPayment() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) { setState(() => _loadingPayment = false); return; }

    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('payment_methods')
          .orderBy('createdAt', descending: false)
          .get();

      final methods = snap.docs
          .map((d) => PaymentMethodModel.fromMap(d.data()))
          .toList();

      PaymentMethodModel? selected;

      if (methods.length == 1) {
        selected = methods.first;
      } else if (methods.isNotEmpty) {
        final defaults = methods.where((m) => m.isDefault).toList();
        selected = defaults.isNotEmpty ? defaults.first : methods.first;
      }

      if (mounted) setState(() {
        _selectedPayment = selected;
        _loadingPayment = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingPayment = false);
    }
  }

  // ── Navigation vers AddressPickerPage ─────────────────────────
  Future<void> _pickAddress() async {
    final result = await Navigator.push<AddressModel>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressPickerPage(
          currentAddressId: _selectedAddress?.id,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedAddress = result);
    }
  }

  // ── Navigation vers PaymentPickerPage ─────────────────────────
  Future<void> _pickPayment() async {
    final result = await Navigator.push<PaymentMethodModel>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentPickerPage(
          currentPaymentId: _selectedPayment?.id,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedPayment = result);
    }
  }

  // ── Traitement du paiement ────────────────────────────────────
  Future<void> _processPayment() async {
    if (_selectedAddress == null) {
      _showSnack('Veuillez sélectionner une adresse de livraison');
      return;
    }
    if (_selectedPayment == null) {
      _showSnack('Veuillez sélectionner une méthode de paiement');
      return;
    }

    setState(() => _isProcessing = true);

    // Simuler le traitement
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() => _isProcessing = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SuccessDialog(
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
        title: const Text(
          'Récapitulatif',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
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
          isTablet ? 24 : 16,
          isTablet ? 24 : 16,
          isTablet ? 24 : 16,
          100 + bottomPad,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Produits sélectionnés ──────────────────────────
            _buildSectionTitle('Mes articles (${selectedItems.length})'),
            const SizedBox(height: 12),
            _buildProductsList(selectedItems, isTablet),

            const SizedBox(height: 24),

            // ── Adresse de livraison ───────────────────────────
            _buildSectionTitle('Adresse de livraison'),
            const SizedBox(height: 12),
            _buildAddressCard(),

            const SizedBox(height: 24),

            // ── Méthode de paiement ────────────────────────────
            _buildSectionTitle('Méthode de paiement'),
            const SizedBox(height: 12),
            _buildPaymentCard(),

            const SizedBox(height: 24),

            // ── Résumé des prix ────────────────────────────────
            _buildSectionTitle('Résumé'),
            const SizedBox(height: 12),
            _buildPriceSummary(cart),
          ],
        ),
      ),

      // ── Bouton payer fixé en bas ───────────────────────────────
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _processPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 4,
              shadowColor: Colors.deepPurple.withOpacity(0.4),
            ),
            child: _isProcessing
                ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor:
                AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_rounded, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Payer \$${cart.estimatedTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Section titre ─────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E293B),
      ),
    );
  }

  // ── Liste produits ────────────────────────────────────────────
  Widget _buildProductsList(List<CartItemModel> items, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final isLast = i == items.length - 1;

          final imageBytes = item.images.isNotEmpty
              ? (() {
            try {
              return base64Decode(item.images.first);
            } catch (_) {
              return null;
            }
          })()
              : null;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 64,
                        height: 64,
                        color: Colors.grey.shade100,
                        child: imageBytes != null
                            ? Image.memory(imageBytes, fit: BoxFit.cover)
                            : Icon(Icons.image_outlined,
                            color: Colors.grey.shade400, size: 28),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Infos
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.storeName,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Prix + quantité
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${item.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'x${item.quantity}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isLast)
                const Divider(height: 1, color: Color(0xFFF0F0F0),
                    indent: 12, endIndent: 12),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Carte adresse ─────────────────────────────────────────────
  Widget _buildAddressCard() {
    if (_loadingAddress) {
      return _buildLoadingCard();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_rounded,
                size: 20, color: Colors.deepPurple),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: _selectedAddress == null
                ? Text(
              'Aucune adresse sélectionnée',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            )
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedAddress!.contactName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_selectedAddress!.countryFlag} ${_selectedAddress!.countryCode} ${_selectedAddress!.phone}',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 3),
                Text(
                  _selectedAddress!.fullAddress,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Bouton modifier
          GestureDetector(
            onTap: _pickAddress,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Modifier',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepPurple.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Carte paiement ────────────────────────────────────────────
  Widget _buildPaymentCard() {
    if (_loadingPayment) {
      return _buildLoadingCard();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _selectedPayment?.icon ?? Icons.payment_rounded,
              size: 22,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: _selectedPayment == null
                ? Text(
              'Aucune méthode sélectionnée',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            )
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedPayment!.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (_selectedPayment!.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    _selectedPayment!.subtitle,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
          ),

          GestureDetector(
            onTap: _pickPayment,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Modifier',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepPurple.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Résumé des prix ───────────────────────────────────────────
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
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _priceRow('Total articles', '\$${cart.selectedTotal.toStringAsFixed(2)}'),
          const SizedBox(height: 10),
          _priceRow(
            'Réduction (10%)',
            '-\$${(cart.selectedTotal * 0.1).toStringAsFixed(2)}',
            valueColor: Colors.green.shade600,
          ),
          const SizedBox(height: 10),
          _priceRow('Sous-total', '\$${cart.subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 10),
          _priceRow('Livraison', '\$${cart.shippingFee.toStringAsFixed(2)}'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          _priceRow(
            'Total estimé',
            '\$${cart.estimatedTotal.toStringAsFixed(2)}',
            isBold: true,
            isLarge: true,
            valueColor: Colors.deepPurple,
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value,
      {bool isBold = false, bool isLarge = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isLarge ? 15 : 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            color: const Color(0xFF475569),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 16 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Colors.deepPurple),
          ),
        ),
      ),
    );
  }
}

// ── Dialogue de succès ────────────────────────────────────────────
class _SuccessDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  const _SuccessDialog({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded,
                  size: 40, color: Colors.green.shade600),
            ),
            const SizedBox(height: 20),
            const Text(
              'Commande confirmée !',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Votre commande a été passée avec succès. Vous serez notifié de son suivi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Retour à l\'accueil',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
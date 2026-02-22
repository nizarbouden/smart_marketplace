import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';
import 'add_card_page.dart';
import 'add_digital_wallet_page.dart';
import 'add_paypal_account_page.dart';


class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  List<Map<String, dynamic>> _methods = [];
  bool _isLoading         = true;
  bool _hasCashOnDelivery = false;
  bool _hasPaypal         = false;
  bool _hasApplePay  = false;
  bool _hasGooglePay = false;

  String _t(String key) => AppLocalizations.get(key);

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  // ── Charger tous les moyens de paiement ───────────────────────
  Future<void> _loadMethods() async {
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('payment_methods')
          .orderBy('createdAt', descending: false)
          .get();

      final methods = snapshot.docs
          .map((doc) => {...doc.data(), 'docId': doc.id})
          .toList();

      setState(() {
        _methods           = methods;
        _hasCashOnDelivery = methods.any((m) => m['type'] == 'cash');
        _hasPaypal         = methods.any((m) => m['type'] == 'paypal');
        _hasApplePay  = methods.any((m) => m['type'] == 'apple_pay');
        _hasGooglePay = methods.any((m) => m['type'] == 'google_pay');
      });
    } catch (e) {
      print('❌ Erreur chargement: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Ajouter paiement à la livraison ──────────────────────────
  Future<void> _addCashOnDelivery() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final col    = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('payment_methods');
    final docRef = col.doc();

    await docRef.set({
      'id':        docRef.id,
      'type':      'cash',
      'isDefault': false,
      'createdAt': Timestamp.now(),
    });

    await _loadMethods();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('payment_cash_delivery_added')),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Mettre par défaut ─────────────────────────────────────────
  Future<void> _setDefault(String docId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final col   = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('payment_methods');

    for (final m in _methods) {
      batch.update(col.doc(m['docId']), {'isDefault': false});
    }
    batch.update(col.doc(docId), {'isDefault': true});
    await batch.commit();

    await _loadMethods();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('payment_set_default_success')),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Supprimer ─────────────────────────────────────────────────
  Future<void> _delete(String docId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;

        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 20,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFFF87171)],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                    ),
                    child: const Icon(Icons.credit_card_off_rounded, color: Colors.white, size: 32),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _t('payment_delete_title'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _t('payment_delete_confirm'),
                        style: const TextStyle(
                            fontSize: 16, color: Color(0xFF64748B), height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Text(_t('cancel'),
                                    style: const TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                  shadowColor: const Color(0xFFDC2626).withOpacity(0.3),
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                child: FittedBox(
                                  child: Text(_t('delete'),
                                      style: const TextStyle(
                                          fontSize: 15, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('payment_methods').doc(docId)
        .delete();

    await _loadMethods();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('payment_deleted_success')),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw        = MediaQuery.of(context).size.width;
    final isMobile  = sw < 600;
    final isTablet  = sw >= 600 && sw < 1200;
    final isDesktop = sw >= 1200;

    return Directionality(
      textDirection: AppLocalizations.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _buildAppBar(context, isDesktop, isTablet),
        body: _buildBody(isMobile),
        floatingActionButton: _buildFAB(isDesktop, isMobile),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(
      BuildContext context, bool isDesktop, bool isTablet) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(
          AppLocalizations.isRtl ? Icons.arrow_forward : Icons.arrow_back,
          color: Colors.black87,
        ),
      ),
      title: Text(
        _t('payment_methods_title'),
        style: TextStyle(
          color: Colors.black87,
          fontSize: isDesktop ? 24 : isTablet ? 22 : 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────
  Widget _buildBody(bool isMobile) {
    return Column(
      children: [
        // Bandeau info
        Container(
          margin: EdgeInsets.all(isMobile ? 16 : 20),
          padding: EdgeInsets.all(isMobile ? 14 : 16),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.deepPurple, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _t('payment_manage_info'),
                  style: TextStyle(
                    color: Colors.deepPurple[800],
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Liste
        Expanded(
          child: _isLoading
              ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple))
              : RefreshIndicator(
            onRefresh: _loadMethods,
            color: Colors.deepPurple,
            child: ListView(
              padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 20),
              children: [
                ..._methods.map((m) {
                  if (m['type'] == 'cash')   return _buildCashItem(m, isMobile);
                  if (m['type'] == 'paypal') return _buildPaypalItem(m, isMobile);
                  if (m['type'] == 'apple_pay')  return _buildWalletItem(m, isMobile, isApple: true);
                  if (m['type'] == 'google_pay') return _buildWalletItem(m, isMobile, isApple: false);
                  return _buildCardItem(m, isMobile);
                }),
                SizedBox(height: isMobile ? 100 : 120),
              ],
            ),
          ),
        ),

        _buildSecuritySection(isMobile),
      ],
    );
  }

  // ── Carte bancaire ────────────────────────────────────────────
  Widget _buildCardItem(Map<String, dynamic> card, bool isMobile) {
    final isDefault   = card['isDefault'] == true;
    final cardType    = card['cardType'] ?? 'unknown';
    final last4       = card['lastFourDigits'] ?? '••••';
    final holderName  = card['cardholderName'] ?? '';
    final expiryMonth = card['expiryMonth'] ?? '';
    final expiryYear  = card['expiryYear'] ?? '';
    final docId       = card['docId'] as String;

    return _buildMethodContainer(
      isDefault: isDefault,
      isMobile: isMobile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildCardTypeIcon(cardType, isMobile),
              SizedBox(width: isMobile ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(holderName,
                        style: TextStyle(
                            fontSize: isMobile ? 14 : 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    if (isDefault) ...[
                      const SizedBox(height: 4),
                      _buildDefaultBadge(),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[500]),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (value) async {
                  if (value == 'setDefault') await _setDefault(docId);
                  if (value == 'edit')       _editCard(card);
                  if (value == 'delete')     await _delete(docId);
                },
                itemBuilder: (_) => [
                  if (!isDefault)
                    _menuItem('setDefault', Icons.star_outline,
                        Colors.amber, _t('payment_set_default')),
                  _menuItem('edit', Icons.edit_outlined,
                      Colors.blue, _t('edit')),
                  _menuItem('delete', Icons.delete_outline,
                      Colors.red, _t('delete'), isRed: true),
                ],
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 14),
          Text(
            '•••• •••• •••• $last4',
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_t('payment_expires')} $expiryMonth/$expiryYear',
            style: TextStyle(
                fontSize: isMobile ? 12 : 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ── PayPal ────────────────────────────────────────────────────
  Widget _buildPaypalItem(Map<String, dynamic> paypal, bool isMobile) {
    final isDefault = paypal['isDefault'] == true;
    final email     = paypal['email'] ?? '';
    final holder    = paypal['accountHolderName'] ?? '';
    final docId     = paypal['docId'] as String;

    return _buildMethodContainer(
      isDefault: isDefault,
      isMobile: isMobile,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF003087).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.account_balance_wallet_rounded,
                color: const Color(0xFF003087),
                size: isMobile ? 22 : 24),
          ),
          SizedBox(width: isMobile ? 12 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PayPal',
                    style: TextStyle(
                        fontSize: isMobile ? 14 : 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                if (holder.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(holder,
                      style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54)),
                ],
                const SizedBox(height: 1),
                Text(email,
                    style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: Colors.grey[500])),
                if (isDefault) ...[
                  const SizedBox(height: 4),
                  _buildDefaultBadge(),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[500]),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            onSelected: (value) async {
              if (value == 'setDefault') await _setDefault(docId);
              if (value == 'delete')     await _delete(docId);
            },
            itemBuilder: (_) => [
              if (!isDefault)
                _menuItem('setDefault', Icons.star_outline,
                    Colors.amber, _t('payment_set_default')),
              _menuItem('delete', Icons.delete_outline,
                  Colors.red, _t('delete'), isRed: true),
            ],
          ),
        ],
      ),
    );
  }

  // ── Cash on delivery ──────────────────────────────────────────
  Widget _buildCashItem(Map<String, dynamic> cash, bool isMobile) {
    final isDefault = cash['isDefault'] == true;
    final docId     = cash['docId'] as String;

    return _buildMethodContainer(
      isDefault: isDefault,
      isMobile: isMobile,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.local_shipping_outlined,
                color: Colors.green, size: isMobile ? 22 : 24),
          ),
          SizedBox(width: isMobile ? 12 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('payment_cash_delivery_title'),
                    style: TextStyle(
                        fontSize: isMobile ? 14 : 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 2),
                Text(_t('payment_cash_delivery_desc'),
                    style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: Colors.grey[500])),
                if (isDefault) ...[
                  const SizedBox(height: 4),
                  _buildDefaultBadge(),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[500]),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            onSelected: (value) async {
              if (value == 'setDefault') await _setDefault(docId);
              if (value == 'delete')     await _delete(docId);
            },
            itemBuilder: (_) => [
              if (!isDefault)
                _menuItem('setDefault', Icons.star_outline,
                    Colors.amber, _t('payment_set_default')),
              _menuItem('delete', Icons.delete_outline,
                  Colors.red, _t('delete'), isRed: true),
            ],
          ),
        ],
      ),
    );
  }

// ── Apple Pay / Google Pay ────────────────────────────────────
  Widget _buildWalletItem(Map<String, dynamic> wallet, bool isMobile,
      {required bool isApple}) {
    final isDefault = wallet['isDefault'] == true;
    final docId     = wallet['docId'] as String;
    final color     = isApple ? Colors.black : const Color(0xFF4285F4);
    final label     = isApple ? 'Apple Pay' : 'Google Pay';

    return _buildMethodContainer(
      isDefault: isDefault,
      isMobile: isMobile,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isApple ? Icons.apple : Icons.android,
              color: color,
              size: isMobile ? 22 : 24,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: isMobile ? 14 : 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 2),
                Text(
                  _t('wallet_security_title'),
                  style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      color: Colors.grey[500]),
                ),
                if (isDefault) ...[
                  const SizedBox(height: 4),
                  _buildDefaultBadge(),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[500]),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            onSelected: (value) async {
              if (value == 'setDefault') await _setDefault(docId);
              if (value == 'delete')     await _delete(docId);
            },
            itemBuilder: (_) => [
              if (!isDefault)
                _menuItem('setDefault', Icons.star_outline,
                    Colors.amber, _t('payment_set_default')),
              _menuItem('delete', Icons.delete_outline,
                  Colors.red, _t('delete'), isRed: true),
            ],
          ),
        ],
      ),
    );
  }
  // ── Container commun ──────────────────────────────────────────
  Widget _buildMethodContainer({
    required bool isDefault,
    required bool isMobile,
    required Widget child,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDefault
            ? Border.all(color: Colors.deepPurple, width: 2)
            : Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: child,
      ),
    );
  }

  // ── Badge "Par défaut" ────────────────────────────────────────
  Widget _buildDefaultBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.deepPurple,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _t('by_default'),
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── MenuItem popup ────────────────────────────────────────────
  PopupMenuItem<String> _menuItem(
      String value, IconData icon, Color color, String label,
      {bool isRed = false}) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(color: isRed ? Colors.red : Colors.black87)),
      ]),
    );
  }

  // ── Icône type carte ──────────────────────────────────────────
  Widget _buildCardTypeIcon(String cardType, bool isMobile) {
    final Map<String, Color> colors = {
      'visa': Colors.blue,
      'mastercard': Colors.red,
      'amex': Colors.green,
      'discover': Colors.orange,
    };
    final color = colors[cardType.toLowerCase()] ?? Colors.grey;
    return Container(
      padding: EdgeInsets.all(isMobile ? 8 : 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.credit_card, color: color, size: isMobile ? 20 : 22),
    );
  }

  // ── Section sécurité ─────────────────────────────────────────
  Widget _buildSecuritySection(bool isMobile) {
    return Container(
      margin: EdgeInsets.fromLTRB(
          isMobile ? 16 : 24, 0, isMobile ? 16 : 24, isMobile ? 16 : 24),
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.security, color: Colors.green, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('payment_security_title'),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 2),
                Text(_t('payment_pci_certified'),
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── FAB ──────────────────────────────────────────────────────
  Widget _buildFAB(bool isDesktop, bool isMobile) {
    return FloatingActionButton.extended(
      onPressed: _showAddPaymentMethod,
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.add),
      label: Text(_t('payment_add_fab'),
          style: TextStyle(
              fontSize: isDesktop ? 16 : 14, fontWeight: FontWeight.w600)),
    );
  }

  // ── Bottom sheet ajout ────────────────────────────────────────
  void _showAddPaymentMethod() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Permet au bottom sheet de s'adapter au contenu
      builder: (ctx) => Directionality(
        textDirection:
        AppLocalizations.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85, // Limite à 85% de l'écran
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 32),
          child: SingleChildScrollView( // Ajout du scroll pour éviter l'overflow
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
                Text(_t('payment_add_sheet_title'),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 20),

                // Carte bancaire — toujours visible
                _buildAddOption(
                  _t('payment_card_option_title'),
                  _t('payment_card_option_subtitle'),
                  Icons.credit_card, Colors.blue,
                    () {
                  Navigator.pop(ctx);
                  Navigator.of(context)
                      .push(MaterialPageRoute(
                      builder: (_) => const AddCardPage()))
                      .then((_) => _loadMethods());
                },
                ),
                const SizedBox(height: 10),

                // PayPal — caché si déjà ajouté
                if (!_hasPaypal) ...[
                  _buildAddOption(
                    _t('payment_paypal_option_title'),
                    _t('payment_paypal_option_subtitle'),
                    Icons.account_balance_wallet, Colors.indigo,
                        () {
                      Navigator.pop(ctx);
                      Navigator.of(context)
                          .push(MaterialPageRoute(
                          builder: (_) => const AddPayPalAccountPage()))
                          .then((_) => _loadMethods());
                    },
                  ),
                  const SizedBox(height: 10),
                ],

                // Cash on delivery — caché si déjà ajouté
                if (!_hasCashOnDelivery) ...[
                  _buildAddOption(
                    _t('payment_cash_delivery_title'),
                    _t('payment_cash_delivery_desc'),
                    Icons.local_shipping_outlined, Colors.green,
                        () {
                      Navigator.pop(ctx);
                      _addCashOnDelivery();
                    },
                  ),
                  const SizedBox(height: 10),
                ],

                // Apple Pay / Google Pay
                _buildAddOption(
                  _t('wallet_page_title'),
                  _t('apple_pay_subtitle'),
                  Icons.phone_iphone, Colors.black87,
                    () {
                  Navigator.pop(ctx);
                  Navigator.of(context)
                      .push(MaterialPageRoute(
                      builder: (_) => const AddDigitalWalletPage()))
                      .then((_) => _loadMethods());
                },
              ),
              const SizedBox(height: 20), // Espace supplémentaire en bas
            ],
          ),
        ),
      ),
    ),
    );
  }

  // ── Option du bottom sheet ────────────────────────────────────
  Widget _buildAddOption(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(
              AppLocalizations.isRtl
                  ? Icons.arrow_back_ios
                  : Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ── Modifier carte ────────────────────────────────────────────
  void _editCard(Map<String, dynamic> card) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddCardPage(cardData: card),
      ),
    ).then((result) {
      if (result == true) {
        _loadMethods(); // Rafraîchir la liste après modification
      }
    });
  }
}
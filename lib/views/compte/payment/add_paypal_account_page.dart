import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';
import 'package:smart_marketplace/models/paypal_account_model.dart';
import 'package:smart_marketplace/services/encryption_service.dart';

class AddPayPalAccountPage extends StatefulWidget {
  final Map<String, dynamic>? paypalAccount; // Pour l'édition

  const AddPayPalAccountPage({super.key, this.paypalAccount});

  @override
  State<AddPayPalAccountPage> createState() => _AddPayPalAccountPageState();
}

class _AddPayPalAccountPageState extends State<AddPayPalAccountPage> {
  final _formKey         = GlobalKey<FormState>();
  final _emailCtrl       = TextEditingController();
  final _holderNameCtrl  = TextEditingController();
  final _emailFocus      = FocusNode();
  final _holderNameFocus = FocusNode();
  bool _isLoading        = false;

  @override
  void initState() {
    super.initState();
    // Pré-remplir le formulaire si c'est une édition
    if (widget.paypalAccount != null) {
      _emailCtrl.text = widget.paypalAccount!['email'] ?? '';
      _holderNameCtrl.text = widget.paypalAccount!['accountHolderName'] ?? '';
    }
  }

  final _encryption = EncryptionService();

  String _t(String key) => AppLocalizations.get(key);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _holderNameCtrl.dispose();
    _emailFocus.dispose();
    _holderNameFocus.dispose();
    super.dispose();
  }

  // ── Vérifier si PayPal déjà ajouté ───────────────────────────
  Future<bool> _paypalAlreadyExists(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('payment_methods')
        .where('type', isEqualTo: 'paypal')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // ── Sauvegarder dans Firebase ─────────────────────────────────
  Future<void> _savePaypal() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Utilisateur non connecté');

      // Vérifier si PayPal déjà lié
      if (await _paypalAlreadyExists(uid)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_t('paypal_already_added')),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }

      // Générer et chiffrer le token d'accès via EncryptionService
      final token          = _encryption.generateRandomToken();
      final encryptedToken = _encryption.encrypt(token);

      // Référence du document
      final col    = FirebaseFirestore.instance
          .collection('users').doc(uid).collection('payment_methods');
      final docRef = col.doc();

      // Construire le modèle PayPalAccountModel
      final paypal = PayPalAccountModel(
        id:                   docRef.id,
        userId:               uid,
        email:                _emailCtrl.text.trim().toLowerCase(),
        accountHolderName:    _holderNameCtrl.text.trim(),
        isVerified:           false,
        isDefault:            false,
        createdAt:            DateTime.now(),
        encryptedAccessToken: encryptedToken,
      );

      // Sauvegarder — on ajoute 'type' pour que payment_methods_page
      // puisse distinguer les types (card / paypal / cash)
      await docRef.set({
        ...paypal.toMap(),
        'type': 'paypal',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('paypal_added_success')),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_t('error')}: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              AppLocalizations.isRtl ? Icons.arrow_forward : Icons.arrow_back,
              color: Colors.black87,
            ),
          ),
          title: Row(
            children: [
              Text(
                '💙',
                style: TextStyle(fontSize: 24),
              ),
              SizedBox(width: 8),
              Text(
                widget.paypalAccount != null ? 'Modifier le compte PayPal' : 'Ajouter un compte PayPal',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 20 : isTablet ? 28 : 36),
          child: Column(
            children: [
              _buildPaypalHeader(isMobile),
              SizedBox(height: isMobile ? 32 : 40),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Nom du titulaire ──────────────────────
                    _buildLabel(_t('paypal_holder_label')),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller:         _holderNameCtrl,
                      focusNode:          _holderNameFocus,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      decoration: _inputDecoration(
                        hint: _t('paypal_holder_hint'),
                        icon: Icons.person_outline,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? _t('paypal_holder_required') : null,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(_emailFocus),
                    ),

                    SizedBox(height: isMobile ? 20 : 24),

                    // ── Email PayPal ──────────────────────────
                    _buildLabel(_t('paypal_email_label')),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller:   _emailCtrl,
                      focusNode:    _emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      decoration: _inputDecoration(
                        hint: _t('paypal_email_hint'),
                        icon: Icons.email_outlined,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return _t('paypal_email_required');
                        // ✅ Utilise isValidPayPalEmail de EncryptionService
                        if (!_encryption.isValidPayPalEmail(v.trim()))
                          return _t('paypal_email_invalid');
                        return null;
                      },
                    ),

                    SizedBox(height: isMobile ? 24 : 32),

                    _buildInfoBox(isMobile),

                    SizedBox(height: isMobile ? 32 : 40),

                    _buildSubmitButton(isMobile, isTablet, isDesktop),

                    const SizedBox(height: 16),

                    Center(
                      child: TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.open_in_new,
                            size: 16, color: Color(0xFF003087)),
                        label: Text(
                          _t('paypal_no_account'),
                          style: const TextStyle(
                            color: Color(0xFF003087),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header PayPal ─────────────────────────────────────────────
  Widget _buildPaypalHeader(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 24 : 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF003087), Color(0xFF009CDE)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF003087).withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: isMobile ? 64 : 80,
            height: isMobile ? 64 : 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.account_balance_wallet_rounded,
                color: Colors.white, size: isMobile ? 36 : 44),
          ),
          SizedBox(height: isMobile ? 16 : 20),
          const Text('PayPal',
              style: TextStyle(color: Colors.white, fontSize: 30,
                  fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(
            _t('paypal_header_subtitle'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.85),
                fontSize: isMobile ? 13 : 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ── Info box sécurité ─────────────────────────────────────────
  Widget _buildInfoBox(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF009CDE).withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF009CDE).withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.security, color: Color(0xFF003087), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _t('paypal_info_text'),
              style: TextStyle(color: const Color(0xFF003087),
                  fontSize: isMobile ? 12 : 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── Décoration champs ─────────────────────────────────────────
  InputDecoration _inputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText:  hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      prefixIcon: Icon(icon,
          color: const Color(0xFF003087).withOpacity(0.7), size: 20),
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[200]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[200]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF003087), width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildLabel(String text) => Text(text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
          color: Color(0xFF1E293B)));

  // ── Bouton Lier ───────────────────────────────────────────────
  Widget _buildSubmitButton(bool isMobile, bool isTablet, bool isDesktop) {
    return SizedBox(
      width: double.infinity,
      height: isMobile ? 52 : 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _savePaypal,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF003087),
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: const Color(0xFF003087).withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const SizedBox(width: 22, height: 22,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link_rounded, size: 20),
            const SizedBox(width: 10),
            Text(
              widget.paypalAccount != null ? 'Mettre à jour' : _t('paypal_link_btn'),
              style: TextStyle(
                fontSize: isDesktop ? 17 : isTablet ? 16 : 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
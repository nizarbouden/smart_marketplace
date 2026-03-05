import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';
import 'package:smart_marketplace/services/paypal_oauth_service.dart';

class AddPayPalAccountPage extends StatefulWidget {
  const AddPayPalAccountPage({super.key});

  @override
  State<AddPayPalAccountPage> createState() => _AddPayPalAccountPageState();
}

class _AddPayPalAccountPageState extends State<AddPayPalAccountPage> {
  bool _isLoading = false;
  final _paypalOAuth = PayPalOAuthService();

  String _t(String key) => AppLocalizations.get(key);

  // ── Vérifie si PayPal déjà lié ────────────────────────────────
  Future<bool> _paypalAlreadyExists(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('payment_methods')
        .where('type', isEqualTo: 'paypal')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // ── Lance le OAuth PayPal ─────────────────────────────────────
  Future<void> _connectWithPayPal() async {
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Utilisateur non connecté');

      // Vérifie doublon
      if (await _paypalAlreadyExists(uid)) {
        print('⚠️ [PayPal] Compte déjà lié pour uid: $uid');
        _showSnackBar(_t('paypal_already_added'), Colors.orange);
        return;
      }

      print('🚀 [PayPal] Lancement du flow OAuth...');

      // Lance le flow OAuth
      final result = await _paypalOAuth.connectPayPalAccount();

      print('📦 [PayPal] Résultat reçu: $result');
      print('   isSuccess   : ${result?.isSuccess}');
      print('   isCancelled : ${result?.isCancelled}');
      print('   errorMessage: ${result?.errorMessage}');
      print('   email       : ${result?.email}');
      print('   name        : ${result?.name}');
      print('   paypalId    : ${result?.paypalId}');
      print('   isVerified  : ${result?.isVerified}');

      if (result == null || result.isCancelled) {
        print('❌ [PayPal] Connexion annulée par l\'utilisateur');
        _showSnackBar(_t('paypal_connection_cancelled'), Colors.orange);
        return;
      }

      if (!result.isSuccess) {
        print('❌ [PayPal] Échec OAuth: ${result.errorMessage}');
        _showSnackBar(result.errorMessage ?? _t('error'), Colors.red);
        return;
      }

      print('✅ [PayPal] Compte vérifié — sauvegarde dans Firestore...');

      // ✅ Compte PayPal vérifié → sauvegarder dans Firestore
      final col    = FirebaseFirestore.instance
          .collection('users').doc(uid).collection('payment_methods');
      final docRef = col.doc();

      await docRef.set({
        'id':                docRef.id,
        'type':              'paypal',
        'email':             result.email,
        'accountHolderName': result.name,
        'paypalUserId':      result.paypalId,
        'isVerified':        result.isVerified,
        'isDefault':         false,
        'createdAt':         Timestamp.now(),
      });

      print('✅ [PayPal] Sauvegardé dans Firestore avec succès — docId: ${docRef.id}');

      _showSnackBar(_t('paypal_added_success'), Colors.green);
      if (mounted) Navigator.of(context).pop(true);

    } catch (e, stack) {
      print('💥 [PayPal] Exception inattendue: $e');
      print('   StackTrace: $stack');
      _showSnackBar('${_t('error')}: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final sw       = MediaQuery.of(context).size.width;
    final isMobile = sw < 600;

    return Directionality(
      textDirection: AppLocalizations.isRtl
          ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              AppLocalizations.isRtl
                  ? Icons.arrow_forward : Icons.arrow_back,
              color: Colors.black87,
            ),
          ),
          title: Text(_t('paypal_page_title'),
              style: const TextStyle(
                  color: Colors.black87, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 24 : 36),
          child: Column(
            children: [
              _buildHeader(isMobile),
              SizedBox(height: isMobile ? 32 : 40),
              _buildStepsList(isMobile),
              SizedBox(height: isMobile ? 32 : 40),
              _buildInfoBox(isMobile),
              SizedBox(height: isMobile ? 32 : 40),
              _buildConnectButton(isMobile),
              const SizedBox(height: 16),
              _buildCreateAccountLink(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader(bool isMobile) {
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
            style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: isMobile ? 13 : 14,
                height: 1.4),
          ),
        ],
      ),
    );
  }

  // ── Étapes expliquées ─────────────────────────────────────────
  Widget _buildStepsList(bool isMobile) {
    final steps = [
      (Icons.touch_app_outlined, Colors.blue,
      _t('paypal_step1_title'), _t('paypal_step1_desc')),
      (Icons.lock_outline, Colors.orange,
      _t('paypal_step2_title'), _t('paypal_step2_desc')),
      (Icons.verified_outlined, Colors.green,
      _t('paypal_step3_title'), _t('paypal_step3_desc')),
    ];

    return Column(
      children: steps.asMap().entries.map((e) {
        final step = e.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: step.$2.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(step.$1, color: step.$2, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.$3,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B))),
                    const SizedBox(height: 3),
                    Text(step.$4,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                            height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Info sécurité ─────────────────────────────────────────────
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
              style: TextStyle(
                  color: const Color(0xFF003087),
                  fontSize: isMobile ? 12 : 13,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bouton principal OAuth ────────────────────────────────────
  Widget _buildConnectButton(bool isMobile) {
    return SizedBox(
      width: double.infinity,
      height: isMobile ? 54 : 58,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _connectWithPayPal,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF003087),
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: const Color(0xFF003087).withOpacity(0.3),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2.5),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet_rounded, size: 22),
            const SizedBox(width: 10),
            Text(
              _t('paypal_connect_btn'),
              style: TextStyle(
                  fontSize: isMobile ? 15 : 16,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  // ── Lien création compte ──────────────────────────────────────
  Widget _buildCreateAccountLink() {
    return TextButton.icon(
      onPressed: () async {
        final url = Uri.parse('https://www.paypal.com/signin/create-account');
        // launchUrl(url, mode: LaunchMode.externalApplication);
      },
      icon: const Icon(Icons.open_in_new, size: 16, color: Color(0xFF003087)),
      label: Text(
        _t('paypal_no_account'),
        style: const TextStyle(
            color: Color(0xFF003087),
            fontSize: 13,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}
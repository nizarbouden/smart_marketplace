import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';

class AddDigitalWalletPage extends StatefulWidget {
  const AddDigitalWalletPage({super.key});

  @override
  State<AddDigitalWalletPage> createState() => _AddDigitalWalletPageState();
}

class _AddDigitalWalletPageState extends State<AddDigitalWalletPage>
    with SingleTickerProviderStateMixin {
  // 0 = Apple Pay, 1 = Google Pay
  int _selectedWallet = 0;
  bool _isLoading     = false;
  bool _hasApplePay   = false;
  bool _hasGooglePay  = false;

  late TabController _tabController;

  String _t(String key) => AppLocalizations.get(key);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _selectedWallet = _tabController.index);
    });
    _checkExistingWallets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Vérifier si wallet déjà ajouté ───────────────────────────
  Future<void> _checkExistingWallets() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('payment_methods')
        .where('type', whereIn: ['apple_pay', 'google_pay'])
        .get();

    setState(() {
      _hasApplePay  = snap.docs.any((d) => d['type'] == 'apple_pay');
      _hasGooglePay = snap.docs.any((d) => d['type'] == 'google_pay');
    });
  }

  // ── Ajouter le wallet dans Firebase ──────────────────────────
  Future<void> _addWallet() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final walletType = _selectedWallet == 0 ? 'apple_pay' : 'google_pay';
    final alreadyAdded = _selectedWallet == 0 ? _hasApplePay : _hasGooglePay;

    if (alreadyAdded) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('wallet_already_added')),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final col    = FirebaseFirestore.instance
          .collection('users').doc(uid).collection('payment_methods');
      final docRef = col.doc();

      await docRef.set({
        'id':        docRef.id,
        'userId':    uid,
        'type':      walletType,
        'isDefault': false,
        'createdAt': Timestamp.now(),
        'updatedAt': null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('wallet_added_success')),
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
          title: Text(
            _t('wallet_page_title'),
            style: TextStyle(
              color: Colors.black87,
              fontSize: isDesktop ? 24 : isTablet ? 22 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 20 : 28),
          child: Column(
            children: [
              // ── Sélecteur Apple Pay / Google Pay ─────────────
              _buildWalletSelector(isMobile),

              SizedBox(height: isMobile ? 28 : 36),

              // ── Contenu selon le wallet sélectionné ──────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _selectedWallet == 0
                    ? _buildApplePayContent(isMobile, key: const ValueKey('apple'))
                    : _buildGooglePayContent(isMobile, key: const ValueKey('google')),
              ),

              SizedBox(height: isMobile ? 28 : 36),

              // ── Étapes de configuration ───────────────────────
              _buildSteps(isMobile),

              SizedBox(height: isMobile ? 28 : 36),

              // ── Info sécurité ─────────────────────────────────
              _buildSecurityInfo(isMobile),

              SizedBox(height: isMobile ? 32 : 40),

              // ── Bouton Activer ────────────────────────────────
              _buildSubmitButton(isMobile, isTablet, isDesktop),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sélecteur Apple / Google ──────────────────────────────────
  Widget _buildWalletSelector(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: _buildWalletTab(0, isMobile)),
          Expanded(child: _buildWalletTab(1, isMobile)),
        ],
      ),
    );
  }

  Widget _buildWalletTab(int index, bool isMobile) {
    final isSelected = _selectedWallet == index;
    final isApple    = index == 0;

    return GestureDetector(
      onTap: () {
        _tabController.animateTo(index);
        setState(() => _selectedWallet = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(
            vertical: isMobile ? 12 : 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isApple ? Colors.black : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isApple ? Icons.apple : Icons.android,
              color: isSelected
                  ? (isApple ? Colors.white : const Color(0xFF34A853))
                  : Colors.grey[500],
              size: isMobile ? 20 : 22,
            ),
            const SizedBox(width: 8),
            Text(
              isApple ? 'Apple Pay' : 'Google Pay',
              style: TextStyle(
                color: isSelected
                    ? (isApple ? Colors.white : Colors.black87)
                    : Colors.grey[500],
                fontSize: isMobile ? 14 : 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Apple Pay content ─────────────────────────────────────────
  Widget _buildApplePayContent(bool isMobile, {Key? key}) {
    final alreadyAdded = _hasApplePay;

    return Column(
      key: key,
      children: [
        // Header Apple Pay
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? 28 : 36),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(Icons.apple, color: Colors.white, size: isMobile ? 48 : 56),
              const SizedBox(height: 12),
              Text(
                'Apple Pay',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _t('apple_pay_subtitle'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: isMobile ? 13 : 14,
                  height: 1.4,
                ),
              ),
              if (alreadyAdded) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Text(_t('wallet_already_configured'),
                          style: const TextStyle(
                              color: Colors.green, fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Compatibilité
        _buildCompatibilityBadge(
          icon: Icons.phone_iphone,
          text: _t('apple_pay_compatibility'),
          color: Colors.black,
          isMobile: isMobile,
        ),
      ],
    );
  }

  // ── Google Pay content ────────────────────────────────────────
  Widget _buildGooglePayContent(bool isMobile, {Key? key}) {
    final alreadyAdded = _hasGooglePay;

    return Column(
      key: key,
      children: [
        // Header Google Pay
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? 28 : 36),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4285F4), Color(0xFF34A853)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4285F4).withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Logo Google Pay avec icône au-dessus de l'écriture
              Column(
                children: [
                  // Icône Google depuis assets
                  Image.asset(
                    'assets/icons/google-icon.png',
                    width: isMobile ? 40 : 48,
                    height: isMobile ? 40 : 48,
                  ),
                  const SizedBox(height: 8),
                  // Lettres Google colorées
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildGoogleLetter('G', const Color(0xFF4285F4)),
                        _buildGoogleLetter('o', const Color(0xFFEA4335)),
                        _buildGoogleLetter('o', const Color(0xFFFBBC05)),
                        _buildGoogleLetter('g', const Color(0xFF4285F4)),
                        _buildGoogleLetter('l', const Color(0xFF34A853)),
                        _buildGoogleLetter('e', const Color(0xFFEA4335)),
                        const SizedBox(width: 8),
                        Text(
                          'Pay',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _t('google_pay_subtitle'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: isMobile ? 13 : 14,
                  height: 1.4,
                ),
              ),
              if (alreadyAdded) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Text(_t('wallet_already_configured'),
                          style: const TextStyle(
                              color: Colors.green, fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Compatibilité
        _buildCompatibilityBadge(
          icon: Icons.android,
          text: _t('google_pay_compatibility'),
          color: const Color(0xFF34A853),
          isMobile: isMobile,
        ),
      ],
    );
  }

  Widget _buildGoogleLetter(String letter, Color color) {
    return Text(
      letter,
      style: TextStyle(
        color: color,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        shadows: [
          Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 2),
          Shadow(color: color.withOpacity(0.8), blurRadius: 1),
        ],
      ),
    );
  }

  Widget _buildCompatibilityBadge({
    required IconData icon,
    required String text,
    required Color color,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: color,
                    fontSize: isMobile ? 12 : 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Étapes de configuration ───────────────────────────────────
  Widget _buildSteps(bool isMobile) {
    final isApple  = _selectedWallet == 0;
    final color    = isApple ? Colors.black : const Color(0xFF4285F4);

    final steps = isApple ? [
      (_t('apple_pay_step1_title'), _t('apple_pay_step1_desc'), Icons.settings),
      (_t('apple_pay_step2_title'), _t('apple_pay_step2_desc'), Icons.credit_card),
      (_t('apple_pay_step3_title'), _t('apple_pay_step3_desc'), Icons.face),
    ] : [
      (_t('google_pay_step1_title'), _t('google_pay_step1_desc'), Icons.account_circle),
      (_t('google_pay_step2_title'), _t('google_pay_step2_desc'), Icons.add_card),
      (_t('google_pay_step3_title'), _t('google_pay_step3_desc'), Icons.nfc),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_t('wallet_how_to_use'),
            style: TextStyle(
                fontSize: isMobile ? 16 : 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 16),
        ...steps.asMap().entries.map((entry) {
          final i     = entry.key;
          final step  = entry.value;
          final isLast = i == steps.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(step.$3, color: Colors.white, size: 18),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2, height: 40,
                      color: color.withOpacity(0.2),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(step.$1,
                          style: TextStyle(
                              fontSize: isMobile ? 14 : 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(step.$2,
                          style: TextStyle(
                              fontSize: isMobile ? 12 : 13,
                              color: Colors.grey[600],
                              height: 1.4)),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ── Info sécurité ─────────────────────────────────────────────
  Widget _buildSecurityInfo(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.security, color: Colors.green, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('wallet_security_title'),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: Colors.green)),
                const SizedBox(height: 4),
                Text(_t('wallet_security_desc'),
                    style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: Colors.grey[600], height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bouton Activer ────────────────────────────────────────────
  Widget _buildSubmitButton(bool isMobile, bool isTablet, bool isDesktop) {
    final isApple      = _selectedWallet == 0;
    final alreadyAdded = isApple ? _hasApplePay : _hasGooglePay;
    final btnColor     = isApple ? Colors.black : const Color(0xFF4285F4);

    return SizedBox(
      width: double.infinity,
      height: isMobile ? 52 : 56,
      child: ElevatedButton(
        onPressed: (_isLoading || alreadyAdded) ? null : _addWallet,
        style: ElevatedButton.styleFrom(
          backgroundColor: alreadyAdded ? Colors.grey[300] : btnColor,
          foregroundColor: alreadyAdded ? Colors.grey[600] : Colors.white,
          elevation: alreadyAdded ? 0 : 4,
          shadowColor: btnColor.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2.5))
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(alreadyAdded ? Icons.check_circle : Icons.add,
                size: 20),
            const SizedBox(width: 10),
            Text(
              alreadyAdded
                  ? _t('wallet_already_configured')
                  : _t('wallet_activate_btn'),
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
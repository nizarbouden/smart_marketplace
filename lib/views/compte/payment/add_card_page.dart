import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';

// ── Utilitaire de chiffrement simple (XOR + Base64) ──────────────
// Pour la production, utiliser flutter_secure_storage ou encrypt package
class CardEncryption {
  static const String _key = 'SM_S3CR3T_K3Y_2025!'; // ← changer en prod

  static String encrypt(String data) {
    final keyBytes = _key.codeUnits;
    final dataBytes = data.codeUnits;
    final encrypted = List<int>.generate(
      dataBytes.length,
          (i) => dataBytes[i] ^ keyBytes[i % keyBytes.length],
    );
    // Encode en hex lisible
    return encrypted.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String decrypt(String hex) {
    final keyBytes = _key.codeUnits;
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return String.fromCharCodes(
      List<int>.generate(bytes.length, (i) => bytes[i] ^ keyBytes[i % keyBytes.length]),
    );
  }
}

class AddCardPage extends StatefulWidget {
  const AddCardPage({super.key});

  @override
  State<AddCardPage> createState() => _AddCardPageState();
}

class _AddCardPageState extends State<AddCardPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _cardNumberCtrl   = TextEditingController();
  final _holderNameCtrl   = TextEditingController();
  final _expiryCtrl       = TextEditingController();
  final _cvvCtrl          = TextEditingController();

  // Focus nodes
  final _cardNumberFocus  = FocusNode();
  final _holderNameFocus  = FocusNode();
  final _expiryFocus      = FocusNode();
  final _cvvFocus         = FocusNode();

  bool _isLoading   = false;
  bool _showCvv     = false;
  bool _isFlipped   = false; // animation flip carte
  String _cardType  = 'unknown';

  late AnimationController _flipController;
  late Animation<double>    _flipAnimation;

  String _t(String key) => AppLocalizations.get(key);

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _cvvFocus.addListener(() {
      if (_cvvFocus.hasFocus && !_isFlipped) {
        _flipController.forward();
        setState(() => _isFlipped = true);
      } else if (!_cvvFocus.hasFocus && _isFlipped) {
        _flipController.reverse();
        setState(() => _isFlipped = false);
      }
    });

    _cardNumberCtrl.addListener(_detectCardType);
  }

  @override
  void dispose() {
    _flipController.dispose();
    _cardNumberCtrl.dispose();
    _holderNameCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _cardNumberFocus.dispose();
    _holderNameFocus.dispose();
    _expiryFocus.dispose();
    _cvvFocus.dispose();
    super.dispose();
  }

  // ── Détection type de carte ───────────────────────────────────
  void _detectCardType() {
    final number = _cardNumberCtrl.text.replaceAll(' ', '');
    String type = 'unknown';
    if (number.startsWith('4'))                             type = 'visa';
    else if (number.startsWith('5') || number.startsWith('2')) type = 'mastercard';
    else if (number.startsWith('34') || number.startsWith('37')) type = 'amex';
    else if (number.startsWith('6'))                        type = 'discover';
    if (type != _cardType) setState(() => _cardType = type);
  }

  // ── Couleur selon type de carte ───────────────────────────────
  List<Color> get _cardGradient {
    switch (_cardType) {
      case 'visa':       return [const Color(0xFF1A1F71), const Color(0xFF2563EB)];
      case 'mastercard': return [const Color(0xFF7C2D12), const Color(0xFFDC2626)];
      case 'amex':       return [const Color(0xFF064E3B), const Color(0xFF059669)];
      case 'discover':   return [const Color(0xFF78350F), const Color(0xFFD97706)];
      default:           return [const Color(0xFF1E293B), const Color(0xFF475569)];
    }
  }

  // ── Preview numéro formaté ────────────────────────────────────
  String get _displayNumber {
    final raw = _cardNumberCtrl.text.replaceAll(' ', '');
    if (raw.isEmpty) return '•••• •••• •••• ••••';
    final padded = raw.padRight(16, '•');
    final chunks = [padded.substring(0, 4), padded.substring(4, 8),
      padded.substring(8, 12), padded.substring(12, 16)];
    return chunks.join(' ');
  }

  // ── Sauvegarde dans Firebase ──────────────────────────────────
  Future<void> _saveCard() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final rawNumber = _cardNumberCtrl.text.replaceAll(' ', '');
      final rawCvv    = _cvvCtrl.text.trim();
      final expiry    = _expiryCtrl.text.trim().split('/');

      // Chiffrement des données sensibles
      final encryptedNumber = CardEncryption.encrypt(rawNumber);
      final encryptedCvv    = CardEncryption.encrypt(rawCvv);

      // Vérifier si c'est la première carte (→ défaut)
      final existingCards = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('payment_methods')
          .get();
      final isFirst = existingCards.docs.isEmpty;

      // Si on veut cette carte par défaut → retirer le défaut des autres
      if (isFirst) {
        for (final doc in existingCards.docs) {
          await doc.reference.update({'isDefault': false});
        }
      }

      // Créer le document
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('payment_methods')
          .doc();

      await docRef.set({
        'id':                  docRef.id,
        'userId':              user.uid,
        'type':                'card',
        'cardType':            _cardType,
        'lastFourDigits':      rawNumber.substring(rawNumber.length - 4),
        'cardholderName':      _holderNameCtrl.text.trim(),
        'expiryMonth':         expiry[0].trim(),
        'expiryYear':          expiry.length > 1 ? expiry[1].trim() : '',
        'isDefault':           isFirst,
        'encryptedCardNumber': encryptedNumber,
        'encryptedCvv':        encryptedCvv,
        'createdAt':           Timestamp.now(),
        'updatedAt':           null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('payment_card_added_success')),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop(true); // retour avec refresh
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile    = screenWidth < 600;
    final isTablet    = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop   = screenWidth >= 1200;

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
            _t('payment_add_card_title'),
            style: TextStyle(
              color: Colors.black87,
              fontSize: isDesktop ? 24 : isTablet ? 22 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 20 : isTablet ? 28 : 36),
          child: Column(
            children: [
              // ── Preview de la carte ───────────────────────────
              _buildCardPreview(isMobile, isTablet, isDesktop),

              SizedBox(height: isMobile ? 32 : 40),

              // ── Formulaire ────────────────────────────────────
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Numéro de carte
                    _buildLabel(_t('payment_card_number_label')),
                    const SizedBox(height: 8),
                    _buildCardNumberField(),
                    SizedBox(height: isMobile ? 20 : 24),

                    // Nom du titulaire
                    _buildLabel(_t('payment_cardholder_label')),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _holderNameCtrl,
                      focusNode:  _holderNameFocus,
                      hint:       _t('payment_cardholder_hint'),
                      icon:       Icons.person_outline,
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? _t('payment_cardholder_required') : null,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(_expiryFocus),
                    ),
                    SizedBox(height: isMobile ? 20 : 24),

                    // Expiration + CVV côte à côte
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel(_t('payment_expiry_label')),
                              const SizedBox(height: 8),
                              _buildExpiryField(),
                            ],
                          ),
                        ),
                        SizedBox(width: isMobile ? 12 : 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel(_t('payment_cvv_label')),
                              const SizedBox(height: 8),
                              _buildCvvField(),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isMobile ? 32 : 40),

                    // Bandeau sécurité
                    _buildSecurityBadge(),

                    SizedBox(height: isMobile ? 24 : 32),

                    // Bouton Ajouter
                    _buildSubmitButton(isMobile, isTablet, isDesktop),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Preview carte animée ──────────────────────────────────────
  Widget _buildCardPreview(bool isMobile, bool isTablet, bool isDesktop) {
    final cardW = isMobile ? double.infinity : isTablet ? 380.0 : 440.0;
    final cardH = isMobile ? 200.0 : isTablet ? 220.0 : 240.0;

    return Center(
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final angle = _flipAnimation.value * pi;
          final isFront = angle < pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: Container(
              width: cardW,
              height: cardH,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _cardGradient,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _cardGradient.last.withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: isFront
                  ? _buildCardFront(isMobile)
                  : Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..rotateY(pi),
                child: _buildCardBack(isMobile),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardFront(bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo type carte
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44, height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.wifi, color: Colors.white, size: 18),
              ),
              Text(
                _cardType == 'unknown' ? 'CARD' : _cardType.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Puce
          Container(
            width: 40, height: 30,
            decoration: BoxDecoration(
              color: Colors.amber[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          // Numéro
          Text(
            _displayNumber,
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 17 : 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.5,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          // Titulaire + expiry
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('payment_card_holder_label_preview'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    _holderNameCtrl.text.isEmpty
                        ? _t('payment_card_holder_placeholder')
                        : _holderNameCtrl.text.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _t('payment_expires_preview'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    _expiryCtrl.text.isEmpty ? 'MM/YY' : _expiryCtrl.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(bool isMobile) {
    return Column(
      children: [
        const SizedBox(height: 28),
        Container(height: 44, color: Colors.black.withOpacity(0.6)),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 60, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    _cvvCtrl.text.isEmpty ? 'CVV' : '•' * _cvvCtrl.text.length,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Champ numéro de carte ─────────────────────────────────────
  Widget _buildCardNumberField() {
    return TextFormField(
      controller:  _cardNumberCtrl,
      focusNode:   _cardNumberFocus,
      keyboardType: TextInputType.number,
      maxLength:   19,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _CardNumberFormatter(),
      ],
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.5),
      decoration: _inputDecoration(
        hint: '0000 0000 0000 0000',
        icon: Icons.credit_card,
        counterText: '',
        suffix: _buildCardTypeIcon(),
      ),
      validator: (v) {
        final digits = (v ?? '').replaceAll(' ', '');
        if (digits.length < 13) return _t('payment_card_number_invalid');
        return null;
      },
      onFieldSubmitted: (_) =>
          FocusScope.of(context).requestFocus(_holderNameFocus),
    );
  }

  Widget? _buildCardTypeIcon() {
    if (_cardType == 'unknown') return null;
    final Map<String, Color> colors = {
      'visa': Colors.blue, 'mastercard': Colors.red,
      'amex': Colors.green, 'discover': Colors.orange,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (colors[_cardType] ?? Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: (colors[_cardType] ?? Colors.grey).withOpacity(0.3)),
      ),
      child: Text(
        _cardType.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: colors[_cardType] ?? Colors.grey,
        ),
      ),
    );
  }

  // ── Champ expiration ─────────────────────────────────────────
  Widget _buildExpiryField() {
    return TextFormField(
      controller:   _expiryCtrl,
      focusNode:    _expiryFocus,
      keyboardType: TextInputType.number,
      maxLength:    5,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _ExpiryDateFormatter(),
      ],
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      decoration: _inputDecoration(
        hint: 'MM/YY',
        icon: Icons.calendar_today,
        counterText: '',
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return _t('payment_expiry_required');
        final parts = v.split('/');
        if (parts.length != 2) return _t('payment_expiry_invalid');
        final month = int.tryParse(parts[0]) ?? 0;
        final year  = int.tryParse(parts[1]) ?? 0;
        if (month < 1 || month > 12) return _t('payment_expiry_invalid');
        final now = DateTime.now();
        final expiry = DateTime(2000 + year, month);
        if (expiry.isBefore(DateTime(now.year, now.month))) {
          return _t('payment_card_expired');
        }
        return null;
      },
      onFieldSubmitted: (_) =>
          FocusScope.of(context).requestFocus(_cvvFocus),
    );
  }

  // ── Champ CVV ────────────────────────────────────────────────
  Widget _buildCvvField() {
    return TextFormField(
      controller:   _cvvCtrl,
      focusNode:    _cvvFocus,
      keyboardType: TextInputType.number,
      maxLength:    4,
      obscureText:  !_showCvv,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      decoration: _inputDecoration(
        hint: '•••',
        icon: Icons.lock_outline,
        counterText: '',
        suffix: GestureDetector(
          onTap: () => setState(() => _showCvv = !_showCvv),
          child: Icon(
            _showCvv ? Icons.visibility_off : Icons.visibility,
            size: 18, color: Colors.grey[500],
          ),
        ),
      ),
      validator: (v) {
        if (v == null || v.length < 3) return _t('payment_cvv_invalid');
        return null;
      },
    );
  }

  // ── Champ générique ───────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller:  controller,
      focusNode:   focusNode,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: _inputDecoration(hint: hint, icon: icon),
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
    );
  }

  // ── Décoration commune des champs ─────────────────────────────
  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    String? counterText,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText:    hint,
      counterText: counterText,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.deepPurple.withOpacity(0.7), size: 20),
      suffixIcon: suffix != null ? Padding(
        padding: const EdgeInsets.only(right: 12),
        child: suffix,
      ) : null,
      filled:    true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.deepPurple, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E293B),
      ),
    );
  }

  // ── Badge sécurité ────────────────────────────────────────────
  Widget _buildSecurityBadge() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock, color: Colors.green, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('payment_security_title'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _t('payment_security_desc'),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bouton Ajouter ────────────────────────────────────────────
  Widget _buildSubmitButton(bool isMobile, bool isTablet, bool isDesktop) {
    return SizedBox(
      width: double.infinity,
      height: isMobile ? 52 : 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveCard,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: Colors.deepPurple.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_card, size: 20),
            const SizedBox(width: 10),
            Text(
              _t('payment_add_card_btn'),
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

// ── Formatter numéro de carte (groupes de 4) ──────────────────
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    final digits = next.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return next.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

// ── Formatter date d'expiration (MM/YY) ───────────────────────
class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    final digits = next.text.replaceAll('/', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 4; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return next.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}
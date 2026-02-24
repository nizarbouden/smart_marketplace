import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../localization/app_localizations.dart';
import '../../../providers/language_provider.dart';

class TermsConditionsPage extends StatefulWidget {
  const TermsConditionsPage({super.key});

  @override
  State<TermsConditionsPage> createState() => _TermsConditionsPageState();
}

class _TermsConditionsPageState extends State<TermsConditionsPage> {
  String _role        = 'buyer';
  bool   _loadingRole = true;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (doc.exists && mounted) {
          setState(() =>
          _role = doc.data()?['role'] as String? ?? 'buyer');
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingRole = false);
  }

  bool get _isSeller => _role == 'seller';

  // ── Palette dynamique selon rôle ───────────────────────────
  Color get _primary    => _isSeller ? const Color(0xFF16A34A) : const Color(0xFF8700FF);
  Color get _secondary  => _isSeller ? const Color(0xFF15803D) : const Color(0xFF6366F1);
  Color get _light      => _isSeller ? const Color(0xFFF0FDF4) : const Color(0xFFF5F3FF);
  Color get _numberBg   => _isSeller ? const Color(0xFFDCFCE7) : const Color(0xFFEDE9FE);

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          lang.translate('terms_conditions'),
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: _loadingRole
          ? Center(child: CircularProgressIndicator(color: _primary))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────
            _buildHeader(lang),
            const SizedBox(height: 28),

            // ── Sections communes (1 → 5) ───────────
            // Toutes en vert si vendeur, toutes en violet si acheteur
            _buildNumberedSection(
              number:  1,
              title:   lang.translate('terms_section_1_title'),
              content: lang.translate('terms_section_1_content'),
            ),
            const SizedBox(height: 16),
            _buildNumberedSection(
              number:  2,
              title:   lang.translate('terms_section_2_title'),
              content: lang.translate('terms_section_2_content'),
            ),
            const SizedBox(height: 16),
            _buildNumberedSection(
              number:  3,
              title:   lang.translate('terms_section_3_title'),
              content: lang.translate('terms_section_3_content'),
            ),
            const SizedBox(height: 16),
            _buildNumberedSection(
              number:  4,
              title:   lang.translate('terms_section_4_title'),
              content: lang.translate('terms_section_4_content'),
            ),
            const SizedBox(height: 16),
            _buildNumberedSection(
              number:  5,
              title:   lang.translate('terms_section_5_title'),
              content: lang.translate('terms_section_5_content'),
            ),

            // ── Sections vendeur (6 → 10) conditionnelles ──
            if (_isSeller) ...[
              const SizedBox(height: 32),
              _buildSellerDivider(lang),
              const SizedBox(height: 24),

              _buildNumberedSection(
                number:  6,
                title:   lang.translate('terms_seller_section_1_title'),
                content: lang.translate('terms_seller_section_1_content'),
              ),
              const SizedBox(height: 16),
              _buildNumberedSection(
                number:  7,
                title:   lang.translate('terms_seller_section_2_title'),
                content: lang.translate('terms_seller_section_2_content'),
              ),
              const SizedBox(height: 16),
              _buildNumberedSection(
                number:  8,
                title:   lang.translate('terms_seller_section_3_title'),
                content: lang.translate('terms_seller_section_3_content'),
              ),
              const SizedBox(height: 16),
              _buildNumberedSection(
                number:  9,
                title:   lang.translate('terms_seller_section_4_title'),
                content: lang.translate('terms_seller_section_4_content'),
              ),
              const SizedBox(height: 16),
              _buildNumberedSection(
                number:  10,
                title:   lang.translate('terms_seller_section_5_title'),
                content: lang.translate('terms_seller_section_5_content'),
              ),
            ],

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _secondary],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre + badge rôle
          Row(
            children: [
              Expanded(
                child: Text(
                  lang.translate('terms_title'),
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isSeller
                          ? Icons.store_rounded
                          : Icons.person_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isSeller
                          ? lang.translate('seller_role_label')
                          : lang.translate('buyer_role_label'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            lang.translate('terms_description'),
            style: const TextStyle(
                fontSize: 15, color: Colors.white, height: 1.5),
          ),

          const SizedBox(height: 14),

          // Dernière mise à jour
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              lang.translate('terms_last_updated'),
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w500),
            ),
          ),

          // Notice spécifique vendeur
          if (_isSeller) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lang.translate('terms_seller_notice'),
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Section numérotée — couleur 100% dynamique selon rôle ──

  Widget _buildNumberedSection({
    required int    number,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _primary.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Bulle numéro ────────────────────────────
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _numberBg,
              shape: BoxShape.circle,
              border: Border.all(
                  color: _primary.withOpacity(0.35), width: 1.5),
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  color: _primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // ── Titre + contenu ─────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barre colorée + titre
                Row(
                  children: [
                    Container(
                      width: 4, height: 20,
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.65,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Séparateur sections vendeur ────────────────────────────

  Widget _buildSellerDivider(LanguageProvider lang) {
    return Row(
      children: [
        Expanded(
          child: Container(
              height: 1,
              color: const Color(0xFF16A34A).withOpacity(0.3)),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFF16A34A).withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.store_rounded,
                  color: Color(0xFF16A34A), size: 14),
              const SizedBox(width: 6),
              Text(
                lang.translate('terms_seller_section_label'),
                style: const TextStyle(
                  color: Color(0xFF16A34A),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
              height: 1,
              color: const Color(0xFF16A34A).withOpacity(0.3)),
        ),
      ],
    );
  }
}
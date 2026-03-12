import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../localization/app_localizations.dart';
import '../../models/sub_order_model.dart';
import '../../models/shipping_company_model.dart';  // ✅ ShippingCompanies

// ─────────────────────────────────────────────────────────────────
//  HISTORY PAGE — côté acheteur
//  1 carte par sous-commande (1 article indépendant)
//
//  Query :
//    collectionGroup('subOrders')
//      .where('userId', isEqualTo: uid)
//      .orderBy('createdAt', descending: true)
//
//  Index requis (Firebase Console) :
//    Collection group : subOrders
//    Fields           : userId ASC  +  createdAt DESC
// ─────────────────────────────────────────────────────────────────

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;

  String _selectedFilter = 'all';
  bool   _isLoading      = true;
  List<SubOrderModel> _subOrders = [];
  late AnimationController _animController;

  // Cache productId → true si l'utilisateur a déjà laissé un avis
  final Map<String, bool> _hasReviewed = {};

  String _t(String key) => AppLocalizations.get(key);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    loadOrders().then((_) => _checkReviews());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) loadOrders();
  }

  // ─────────────────────────────────────────────────────────────
  //  CHARGEMENT
  // ─────────────────────────────────────────────────────────────

  Future<void> loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      // ✅ collectionGroup → toutes les sous-commandes de l'acheteur
      final snap = await _firestore
          .collectionGroup('subOrders')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _subOrders = snap.docs
            .map((d) => SubOrderModel.fromFirestore(d))
            .toList();
      });
      _animController.forward(from: 0);
    } catch (e) {
      debugPrint('❌ Erreur chargement sous-commandes: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  VÉRIFICATION AVIS EXISTANTS
  // ─────────────────────────────────────────────────────────────

  Future<void> _checkReviews() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final delivered = _subOrders.where((o) => o.status == 'delivered');
    for (final order in delivered) {
      final snap = await _firestore
          .collection('products')
          .doc(order.productId)
          .collection('reviews')
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();
      if (mounted) {
        setState(() => _hasReviewed[order.productId] = snap.docs.isNotEmpty);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────────

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'delivered':
        return {'color': const Color(0xFF16A34A), 'bg': const Color(0xFFDCFCE7),
          'icon': Icons.check_circle_rounded,    'label': _t('status_delivered')};
      case 'shipping':
        return {'color': const Color(0xFF2563EB), 'bg': const Color(0xFFDBEAFE),
          'icon': Icons.local_shipping_rounded,  'label': _t('status_shipping')};
      case 'cancelled':
        return {'color': const Color(0xFFDC2626), 'bg': const Color(0xFFFEE2E2),
          'icon': Icons.cancel_rounded,          'label': _t('status_cancelled')};
      case 'paid':
        return {'color': const Color(0xFF7C3AED), 'bg': const Color(0xFFEDE9FE),
          'icon': Icons.payments_rounded,        'label': _t('status_paid')};
      default:
        return {'color': const Color(0xFFD97706), 'bg': const Color(0xFFFEF3C7),
          'icon': Icons.pending_rounded,         'label': _t('status_pending')};
    }
  }

  List<SubOrderModel> get _filtered {
    if (_selectedFilter == 'all') return _subOrders;
    return _subOrders.where((o) => o.status == _selectedFilter).toList();
  }

  int _countByStatus(String status) {
    if (status == 'all') return _subOrders.length;
    return _subOrders.where((o) => o.status == status).length;
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/'
          '${d.month.toString().padLeft(2,'0')}/'
          '${d.year}  '
          '${d.hour.toString().padLeft(2,'0')}:'
          '${d.minute.toString().padLeft(2,'0')}';

  String _formatDateShort(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/'
          '${d.month.toString().padLeft(2,'0')}/'
          '${d.year}';

  /// Traduit "3–5" → "3–5 jours" / "3–5 days" / "3–5 أيام"
  String _formatDelayLabel(String raw) {
    if (raw == '—' || raw.isEmpty) return '—';
    return '$raw ${_t("days_label")}';
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: RefreshIndicator(
        onRefresh: loadOrders,
        color: const Color(0xFF7C3AED),
        strokeWidth: 2.5,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildStatsBar(isTablet)),
            SliverToBoxAdapter(child: _buildFilters(isTablet)),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(
                    color: Color(0xFF7C3AED))),
              )
            else if (_filtered.isEmpty)
              SliverFillRemaining(child: _buildEmptyState(isTablet))
            else
              SliverPadding(
                padding: EdgeInsets.all(isTablet ? 24 : 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                      final anim = Tween<double>(begin: 0, end: 1).animate(
                        CurvedAnimation(
                          parent: _animController,
                          curve: Interval(
                            (i / _filtered.length) * 0.6,
                            ((i + 1) / _filtered.length) * 0.6 + 0.4,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                      );
                      return AnimatedBuilder(
                        animation: anim,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(0, 30 * (1 - anim.value)),
                          child: Opacity(
                              opacity: anim.value.clamp(0.0, 1.0),
                              child: child),
                        ),
                        child: _buildSubOrderCard(_filtered[i], isTablet),
                      );
                    },
                    childCount: _filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  STATS BAR
  // ─────────────────────────────────────────────────────────────

  Widget _buildStatsBar(bool isTablet) {
    final stats = [
      {'status': 'paid',      'icon': Icons.payments_rounded},
      {'status': 'shipping',  'icon': Icons.local_shipping_rounded},
      {'status': 'delivered', 'icon': Icons.check_circle_rounded},
      {'status': 'cancelled', 'icon': Icons.cancel_rounded},
    ];

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          isTablet ? 24 : 16, 16, isTablet ? 24 : 16, 16),
      child: Row(
        children: stats.map((s) {
          final config = _getStatusConfig(s['status'] as String);
          final color  = config['color'] as Color;
          final bg     = config['bg']    as Color;
          final count  = _countByStatus(s['status'] as String);
          final active = _selectedFilter == s['status'];

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = s['status'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                decoration: BoxDecoration(
                  color: active ? color : bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active ? color : color.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(s['icon'] as IconData,
                      size: 22, color: active ? Colors.white : color),
                  const SizedBox(height: 6),
                  Text('$count', style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800,
                      color: active ? Colors.white : color)),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  FILTRES
  // ─────────────────────────────────────────────────────────────

  Widget _buildFilters(bool isTablet) {
    final filters = [
      {'key': 'all',       'label': '${_t('filter_all')} (${_subOrders.length})'},
      {'key': 'paid',      'label': _t('status_paid')},
      {'key': 'shipping',  'label': _t('status_shipping')},
      {'key': 'delivered', 'label': _t('status_delivered')},
      {'key': 'cancelled', 'label': _t('status_cancelled')},
    ];

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 24 : 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final isActive = _selectedFilter == f['key'];
            final color = f['key'] == 'all'
                ? const Color(0xFF7C3AED)
                : _getStatusConfig(f['key']!)['color'] as Color;

            return GestureDetector(
              onTap: () => setState(() => _selectedFilter = f['key']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 18 : 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? color : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isActive ? [BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8, offset: const Offset(0, 3))] : null,
                ),
                child: Text(f['label']!, style: TextStyle(
                    fontSize: isTablet ? 13 : 12,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? Colors.white : Colors.grey.shade600)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  CARTE SOUS-COMMANDE (1 article)
  // ─────────────────────────────────────────────────────────────

  Widget _buildSubOrderCard(SubOrderModel s, bool isTablet) {
    final config  = _getStatusConfig(s.status);
    final color   = config['color'] as Color;
    final bg      = config['bg']    as Color;
    final icon    = config['icon']  as IconData;
    final label   = config['label'] as String;

    final shortId = s.subOrderId.length >= 8
        ? s.subOrderId.substring(0, 8).toUpperCase()
        : s.subOrderId.toUpperCase();

    // Image
    Widget imageWidget;
    if (s.images.isNotEmpty) {
      try {
        final bytes = base64Decode(s.images.first);
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(bytes,
              width: isTablet ? 100 : 90,
              height: isTablet ? 100 : 90,
              fit: BoxFit.cover),
        );
      } catch (_) {
        imageWidget = _imagePlaceholder(isTablet);
      }
    } else {
      imageWidget = _imagePlaceholder(isTablet);
    }

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 20 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(children: [

        // ── Header coloré ──────────────────────────────────────
        Container(
          padding: EdgeInsets.all(isTablet ? 18 : 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Container(
              width: isTablet ? 44 : 38,
              height: isTablet ? 44 : 38,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, size: isTablet ? 22 : 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('#$shortId', style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: isTablet ? 15 : 13,
                  color: const Color(0xFF1E293B))),
              Text(s.storeName, style: TextStyle(
                  fontSize: isTablet ? 12 : 11,
                  color: Colors.grey.shade600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(_formatDate(s.createdAt), style: TextStyle(
                  fontSize: isTablet ? 11 : 10,
                  color: Colors.grey.shade500)),
            ])),
            // Badge statut
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 12 : 10, vertical: 5),
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(20)),
              child: Text(label, style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700,
                  fontSize: isTablet ? 12 : 10)),
            ),
          ]),
        ),

        // ── Corps ──────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.all(isTablet ? 18 : 14),
          child: Column(children: [

            // Produit
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              imageWidget,
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: isTablet ? 14 : 13,
                        color: const Color(0xFF1E293B)),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    // Quantité + prix unitaire
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text('×${s.quantity}',
                            style: TextStyle(fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600)),
                      ),
                      const SizedBox(width: 8),
                      Text('${s.price.toStringAsFixed(2)} TND',
                          style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500)),
                    ]),
                    const SizedBox(height: 6),
                    // Badge méthode livraison
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _methodBadgeBg(s.shippingMethod),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _methodBadgeBorder(s.shippingMethod)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_methodIcon(s.shippingMethod),
                            size: 11,
                            color: _methodColor(s.shippingMethod)),
                        const SizedBox(width: 4),
                        // ✅ Nom de la société (FedEx, DHL...)
                        Text(
                          ShippingCompanies.findById(s.shippingMethod)?.name
                              ?? s.shippingMethod,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _methodColor(s.shippingMethod)),
                        ),
                        const SizedBox(width: 4),
                        Text('· ${s.shippingZone}', style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade400)),
                      ]),
                    ),
                  ])),
            ]),

            const SizedBox(height: 14),

            // ── Estimation livraison ───────────────────────────
            if (s.estimatedDateMin != null && s.estimatedDateMax != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(children: [
                  const Icon(Icons.event_rounded,
                      size: 14, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Expanded(child: RichText(text: TextSpan(
                      style: const TextStyle(fontSize: 12,
                          color: Color(0xFF15803D)),
                      children: [
                        TextSpan(text: '${_t('seller_estimated_delay')}: ',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        TextSpan(text: _formatDelayLabel(s.estimatedDelayLabel)),
                        TextSpan(
                          text: '  (${_formatDateShort(s.estimatedDateMin!)}'
                              ' → ${_formatDateShort(s.estimatedDateMax!)})',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 11),
                        ),
                      ]))),
                ]),
              ),

            // ── Récap prix ─────────────────────────────────────
            Container(
              padding: EdgeInsets.all(isTablet ? 14 : 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(children: [
                // Sous-total produit
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_t('cart_products_subtotal'),
                          style: TextStyle(fontSize: 12,
                              color: Colors.grey.shade500)),
                      Text('${s.subtotal.toStringAsFixed(2)} TND',
                          style: const TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B))),
                    ]),
                const SizedBox(height: 6),
                // Livraison
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_t('seller_shipping_cost'),
                          style: TextStyle(fontSize: 12,
                              color: Colors.grey.shade500)),
                      Text('${s.shippingCost.toStringAsFixed(2)} TND',
                          style: const TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3B82F6))),
                    ]),
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1)),
                // Total
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_t('cart_total'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF1E293B))),
                      Text('${s.total.toStringAsFixed(2)} TND',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF7C3AED))),
                    ]),
              ]),
            ),

            const SizedBox(height: 10),

            // ── Boutons ────────────────────────────────────
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showDetails(s, isTablet),
                  icon: const Icon(Icons.receipt_long_rounded, size: 15),
                  label: Text(_t('details'), style: TextStyle(
                      fontSize: isTablet ? 13 : 12,
                      fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                        vertical: isTablet ? 12 : 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              // ✅ Bouton avis — visible uniquement si livré
              if (s.status == 'delivered') ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _hasReviewed[s.productId] == true
                  // Déjà noté
                      ? Container(
                    padding: EdgeInsets.symmetric(
                        vertical: isTablet ? 12 : 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 15, color: Color(0xFF16A34A)),
                        const SizedBox(width: 6),
                        Text(_t('review_done'),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF16A34A))),
                      ],
                    ),
                  )
                  // Pas encore noté
                      : ElevatedButton.icon(
                    onPressed: () => _showReviewSheet(s),
                    icon: const Icon(Icons.star_rounded, size: 15),
                    label: Text(_t('review_add'),
                        style: TextStyle(
                            fontSize: isTablet ? 13 : 12,
                            fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                          vertical: isTablet ? 12 : 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }


  // ─────────────────────────────────────────────────────────────
  //  BOTTOM SHEET AVIS
  // ─────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────
  //  BOTTOM SHEET AVIS — avec image + statut modération
  // ─────────────────────────────────────────────────────────────

  void _showReviewSheet(SubOrderModel s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // ✅ Vrai StatefulWidget — controller géré dans son propre State.dispose()
      builder: (ctx) => _ReviewSheet(
        subOrder: s,
        onSubmit: (rating, comment, image) =>
            _submitReview(s, rating, comment, image),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  SOUMETTRE L'AVIS DANS FIRESTORE
  // ─────────────────────────────────────────────────────────────

  Future<void> _submitReview(
      SubOrderModel s, int rating, String comment, File? image) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final reviewRef = _firestore
          .collection('products')
          .doc(s.productId)
          .collection('reviews')
          .doc();

      // Récup infos acheteur
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final rawName = userDoc.exists
          ? ('${userDoc.data()?['prenom'] ?? ''} '
          '${userDoc.data()?['nom'] ?? ''}')
          .trim()
          : '';
      final userName = rawName.isEmpty ? 'Anonyme' : rawName;

      // Encode image en base64 si présente
      String? imageBase64;
      if (image != null) {
        final bytes = await image.readAsBytes();
        imageBase64 = base64Encode(bytes);
      }

      // ✅ status: 'pending' — en attente de validation admin
      await reviewRef.set({
        'userId':      uid,
        'userName':    userName,
        'productId':   s.productId,
        'productName': s.name,
        'subOrderId':  s.subOrderId,
        'sellerId':    s.sellerId,
        'rating':      rating,
        'comment':     comment,
        'imageBase64': imageBase64,   // null si pas d'image
        'hasImage':    imageBase64 != null,
        'status':      'pending',     // pending | approved | rejected
        'rejectedReason': null,
        'reviewedAt':  null,
        'reviewedBy':  null,
        'createdAt':   Timestamp.now(),
      });

      // Le rating moyen n'est mis à jour qu'après approbation admin
      // → pas d'appel _updateProductRating ici

      if (mounted) {
        setState(() => _hasReviewed[s.productId] = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(_t('review_success'))),
            ]),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('review_error')),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  // Met à jour avgRating + reviewCount (seulement avis approuvés)
  Future<void> _updateProductRating(String productId) async {
    try {
      final reviews = await _firestore
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .where('status', isEqualTo: 'approved')
          .get();

      if (reviews.docs.isEmpty) {
        await _firestore.collection('products').doc(productId).update({
          'avgRating':   0.0,
          'reviewCount': 0,
        });
        return;
      }

      final total = reviews.docs.fold<int>(
          0,
              (sum, d) =>
          sum + ((d.data()['rating'] as num?) ?? 0).toInt());
      final avg = total / reviews.docs.length;

      await _firestore.collection('products').doc(productId).update({
        'avgRating':   double.parse(avg.toStringAsFixed(1)),
        'reviewCount': reviews.docs.length,
      });
    } catch (_) {}
  }

  Widget _imagePlaceholder(bool isTablet) => Container(
    width: isTablet ? 100 : 90,
    height: isTablet ? 100 : 90,
    decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14)),
    child: Icon(Icons.image_outlined,
        color: Colors.grey.shade400, size: isTablet ? 32 : 28),
  );

  // ─────────────────────────────────────────────────────────────
  //  BOTTOM SHEET DÉTAILS
  // ─────────────────────────────────────────────────────────────

  void _showDetails(SubOrderModel s, bool isTablet) {
    final config = _getStatusConfig(s.status);
    final color  = config['color'] as Color;
    final bg     = config['bg']    as Color;
    final shortId = s.subOrderId.length >= 8
        ? s.subOrderId.substring(0, 8).toUpperCase()
        : s.subOrderId.toUpperCase();

    Widget imageWidget;
    if (s.images.isNotEmpty) {
      try {
        final bytes = base64Decode(s.images.first);
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes, width: 80, height: 80, fit: BoxFit.cover),
        );
      } catch (_) { imageWidget = _imagePlaceholder(false); }
    } else { imageWidget = _imagePlaceholder(false); }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(children: [

            // Header
            Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(children: [
                Center(child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2)),
                )),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('#$shortId', style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B))),
                            Text(s.storeName,
                                style: TextStyle(fontSize: 13,
                                    color: Colors.grey.shade600)),
                            Text(_formatDateShort(s.createdAt),
                                style: TextStyle(fontSize: 12,
                                    color: Colors.grey.shade500)),
                          ]),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(config['icon'] as IconData,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(config['label'] as String,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ]),
                      ),
                    ]),
              ]),
            ),

            // Contenu scrollable
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(24),
                children: [

                  // ── Article ──────────────────────────────────
                  _sectionTitle(Icons.shopping_bag_rounded,
                      _t('my_articles'), color),
                  const SizedBox(height: 12),
                  Row(children: [
                    imageWidget,
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name, style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15,
                              color: Color(0xFF1E293B)),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Text('${s.price.toStringAsFixed(2)} TND × ${s.quantity}',
                              style: TextStyle(fontSize: 13,
                                  color: Colors.grey.shade500)),
                        ])),
                  ]),

                  const SizedBox(height: 20),

                  // ── Livraison ─────────────────────────────────
                  _sectionTitle(Icons.local_shipping_rounded,
                      _t('seller_shipping_cost'), color),
                  const SizedBox(height: 12),
                  _infoTile(Icons.category_rounded,
                      _t('seller_shipping_zone'), s.shippingZone),
                  const SizedBox(height: 8),
                  _infoTile(Icons.directions_run_rounded,
                      _t('shipping_method'),
                      ShippingCompanies.findById(s.shippingMethod)?.name
                          ?? s.shippingMethod),
                  if (s.estimatedDelayLabel != '—') ...[
                    const SizedBox(height: 8),
                    _infoTile(Icons.timer_rounded,
                        _t('seller_estimated_delay'), _formatDelayLabel(s.estimatedDelayLabel)),
                  ],
                  if (s.estimatedDateMin != null &&
                      s.estimatedDateMax != null) ...[
                    const SizedBox(height: 8),
                    _infoTile(Icons.event_rounded,
                        _t('seller_estimated_date'),
                        '${_formatDateShort(s.estimatedDateMin!)} → '
                            '${_formatDateShort(s.estimatedDateMax!)}'),
                  ],

                  const SizedBox(height: 20),

                  // ── Récap ─────────────────────────────────────
                  _sectionTitle(Icons.receipt_rounded,
                      _t('summary'), color),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(children: [
                      _priceRow(_t('cart_products_subtotal'),
                          '${s.subtotal.toStringAsFixed(2)} TND'),
                      const SizedBox(height: 8),
                      _priceRow(_t('seller_shipping_cost'),
                          '${s.shippingCost.toStringAsFixed(2)} TND',
                          valueColor: const Color(0xFF3B82F6)),
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1)),
                      _priceRow(_t('cart_total'),
                          '${s.total.toStringAsFixed(2)} TND',
                          bold: true,
                          valueColor: const Color(0xFF7C3AED)),
                    ]),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  WIDGETS UTILITAIRES
  // ─────────────────────────────────────────────────────────────

  Widget _sectionTitle(IconData icon, String title, Color color) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontSize: 15,
          fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
    ]);
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200)),
      child: Row(children: [
        Icon(icon, size: 15, color: Colors.grey.shade400),
        const SizedBox(width: 10),
        Text('$label: ', style: TextStyle(
            fontSize: 12, color: Colors.grey.shade500)),
        Expanded(child: Text(value, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B)),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _priceRow(String label, String value,
      {bool bold = false, Color? valueColor}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(
          fontSize: bold ? 15 : 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: const Color(0xFF475569))),
      Text(value, style: TextStyle(
          fontSize: bold ? 18 : 13,
          fontWeight: FontWeight.w700,
          color: valueColor ?? const Color(0xFF1E293B))),
    ]);
  }

  // ─────────────────────────────────────────────────────────────
  //  HELPERS COULEUR MÉTHODE LIVRAISON
  // ─────────────────────────────────────────────────────────────

  Color _methodColor(String companyId) {
    final c = ShippingCompanies.findById(companyId);
    return c != null ? Color(c.colorValue) : const Color(0xFF2563EB);
  }

  Color _methodBadgeBg(String companyId) {
    final c = ShippingCompanies.findById(companyId);
    return c != null
        ? Color(c.colorValue).withOpacity(0.10)
        : const Color(0xFFEFF6FF);
  }

  Color _methodBadgeBorder(String companyId) {
    final c = ShippingCompanies.findById(companyId);
    return c != null
        ? Color(c.colorValue).withOpacity(0.30)
        : const Color(0xFF93C5FD);
  }

  IconData _methodIcon(String companyId) {
    switch (companyId) {
      case 'dhl':
      case 'fedex':        return Icons.rocket_launch_rounded;
      case 'rapid_poste':  return Icons.savings_rounded;
      default:             return Icons.local_shipping_rounded;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  ÉTAT VIDE
  // ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState(bool isTablet) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 100, height: 100,
            decoration: const BoxDecoration(
                color: Color(0xFFEDE9FE), shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long_outlined,
                size: 48, color: Color(0xFF7C3AED)),
          ),
          const SizedBox(height: 24),
          Text(_t('no_orders_title'), style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B))),
          const SizedBox(height: 8),
          Text(_t('no_orders_desc'), textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14,
                  color: Colors.grey.shade500, height: 1.5)),
        ]),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────
//  _ReviewSheet — StatefulWidget propre
//  Le TextEditingController est dans son State.dispose() → jamais
//  disposé avant que le widget soit vraiment détruit.
// ─────────────────────────────────────────────────────────────────

class _ReviewSheet extends StatefulWidget {
  final SubOrderModel subOrder;
  final Future<void> Function(int rating, String comment, File? image) onSubmit;

  const _ReviewSheet({
    required this.subOrder,
    required this.onSubmit,
  });

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _commentCtrl = TextEditingController();
  final _picker      = ImagePicker();

  int   _rating     = 0;
  File? _pickedImage;
  bool  _submitting  = false;

  String _t(String key) => AppLocalizations.get(key);

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final xFile = await _picker.pickImage(
      source:       ImageSource.gallery,
      maxWidth:     1080,
      maxHeight:    1080,
      imageQuality: 75,
    );
    if (xFile != null && mounted) {
      setState(() => _pickedImage = File(xFile.path));
    }
  }

  Future<void> _submit() async {
    if (_rating == 0 || _submitting) return;
    setState(() => _submitting = true);
    await widget.onSubmit(_rating, _commentCtrl.text.trim(), _pickedImage);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.subOrder;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize:     0.95,
          minChildSize:     0.5,
          expand:           false,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [

              // ── Poignée ───────────────────────────────────────
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // ── Titre ─────────────────────────────────────────
              Text(_t('review_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B))),
              const SizedBox(height: 6),
              Text(s.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),

              const SizedBox(height: 24),

              // ── Étoiles ───────────────────────────────────────
              Text(_t('review_stars_label'),
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final filled = i < _rating;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        filled ? Icons.star_rounded : Icons.star_outline_rounded,
                        size:  44,
                        color: filled
                            ? const Color(0xFFF59E0B)
                            : Colors.grey.shade300,
                      ),
                    ),
                  );
                }),
              ),

              // Label note
              if (_rating > 0) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _rating == 1 ? _t('review_rate_1')
                        : _rating == 2 ? _t('review_rate_2')
                        : _rating == 3 ? _t('review_rate_3')
                        : _rating == 4 ? _t('review_rate_4')
                        : _t('review_rate_5'),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _rating >= 4
                            ? const Color(0xFF16A34A)
                            : _rating == 3
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFDC2626)),
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // ── Commentaire ───────────────────────────────────
              Text(_t('review_comment_label'),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              TextField(
                controller:  _commentCtrl,
                maxLines:    4,
                maxLength:   300,
                decoration: InputDecoration(
                  hintText:  _t('review_comment_hint'),
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  filled:    true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Color(0xFFF59E0B), width: 1.5)),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),

              const SizedBox(height: 18),

              // ── Photo (optionnelle) ───────────────────────────
              Text(_t('review_photo_label'),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700)),
              const SizedBox(height: 10),

              if (_pickedImage == null)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFFF59E0B).withOpacity(0.4),
                          width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_photo_alternate_rounded,
                              size: 30, color: Color(0xFFF59E0B)),
                        ),
                        const SizedBox(height: 8),
                        Text(_t('review_photo_add'),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFF59E0B))),
                        Text(_t('review_photo_optional'),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade400)),
                      ],
                    ),
                  ),
                )
              else
                Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(_pickedImage!,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _pickedImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                            color: Color(0xFFDC2626), shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8, left: 8,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.edit_rounded,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(_t('review_photo_change'),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ),
                ]),

              const SizedBox(height: 10),

              // ── Info modération ───────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF7DD3FC)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_rounded,
                        size: 16, color: Color(0xFF0284C7)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_t('review_moderation_info'),
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0369A1),
                              height: 1.4)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Bouton soumettre ──────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _rating == 0 || _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _rating == 0
                        ? Colors.grey.shade300
                        : const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(_t('review_submit'),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
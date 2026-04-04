import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../localization/app_localizations.dart';
import '../../models/sub_order_model.dart';
import '../../models/shipping_company_model.dart';
import '../../providers/currency_provider.dart';
import '../order chat/order_chat_page.dart';

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

  final Map<String, bool> _hasReviewed = {};

  String _t(String key) => AppLocalizations.get(key);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
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

  Future<void> loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      final snap = await _firestore
          .collectionGroup('subOrders')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();
      setState(() {
        _subOrders = snap.docs.map((d) => SubOrderModel.fromFirestore(d)).toList();
      });
      _animController.forward(from: 0);
    } catch (e) {
      debugPrint('Erreur: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkReviews() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final delivered = _subOrders.where((o) => o.status == 'delivered');
    for (final order in delivered) {
      final snap = await _firestore
          .collection('products').doc(order.productId)
          .collection('reviews')
          .where('userId',     isEqualTo: uid)
          .where('subOrderId', isEqualTo: order.subOrderId)
          .limit(1).get();
      if (mounted) setState(() => _hasReviewed[order.subOrderId] = snap.docs.isNotEmpty);
    }
  }

  _StatusConfig _getStatus(String status) {
    switch (status) {
      case 'delivered':
        return _StatusConfig(
          color: const Color(0xFF059669), light: const Color(0xFFD1FAE5),
          gradient: [const Color(0xFF059669), const Color(0xFF10B981)],
          icon: Icons.check_circle_rounded, label: _t('status_delivered'),
        );
      case 'shipping':
        return _StatusConfig(
          color: const Color(0xFF2563EB), light: const Color(0xFFDBEAFE),
          gradient: [const Color(0xFF1D4ED8), const Color(0xFF3B82F6)],
          icon: Icons.local_shipping_rounded, label: _t('status_shipping'),
        );
      case 'cancelled':
        return _StatusConfig(
          color: const Color(0xFFDC2626), light: const Color(0xFFFEE2E2),
          gradient: [const Color(0xFFB91C1C), const Color(0xFFEF4444)],
          icon: Icons.cancel_rounded, label: _t('status_cancelled'),
        );
      case 'paid':
        return _StatusConfig(
          color: const Color(0xFF7C3AED), light: const Color(0xFFEDE9FE),
          gradient: [const Color(0xFF6D28D9), const Color(0xFF8B5CF6)],
          icon: Icons.payments_rounded, label: _t('status_paid'),
        );
      default:
        return _StatusConfig(
          color: const Color(0xFFD97706), light: const Color(0xFFFEF3C7),
          gradient: [const Color(0xFFB45309), const Color(0xFFF59E0B)],
          icon: Icons.pending_rounded, label: _t('status_pending'),
        );
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
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}  '
          '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';

  String _formatDateShort(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  String _formatDelayLabel(String raw) {
    if (raw == '—' || raw.isEmpty) return '—';
    return '$raw ${_t("days_label")}';
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = AppLocalizations.isRtl; // ✅ détection RTL
    final currency = context.watch<CurrencyProvider>();
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
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
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
                )
              else if (_filtered.isEmpty)
                SliverFillRemaining(child: _buildEmptyState(isTablet))
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                      isTablet ? 24 : 16, 16, isTablet ? 24 : 16, 24),
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
                            offset: Offset(0, 24 * (1 - anim.value)),
                            child: Opacity(opacity: anim.value.clamp(0.0, 1.0), child: child),
                          ),
                          child: _buildSubOrderCard(_filtered[i], isTablet, currency, isRtl), // ✅ isRtl passé
                        );
                      },
                      childCount: _filtered.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBar(bool isTablet) {
    final stats = [
      {'status': 'paid',      'icon': Icons.payments_rounded},
      {'status': 'shipping',  'icon': Icons.local_shipping_rounded},
      {'status': 'delivered', 'icon': Icons.check_circle_rounded},
      {'status': 'cancelled', 'icon': Icons.cancel_rounded},
    ];
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(isTablet ? 24 : 16, 16, isTablet ? 24 : 16, 16),
      child: Row(
        children: stats.map((s) {
          final cfg    = _getStatus(s['status'] as String);
          final count  = _countByStatus(s['status'] as String);
          final active = _selectedFilter == s['status'];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = s['status'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                decoration: BoxDecoration(
                  gradient: active
                      ? LinearGradient(colors: cfg.gradient,
                      begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : null,
                  color: active ? null : cfg.light,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: active ? [BoxShadow(
                      color: cfg.color.withOpacity(0.35),
                      blurRadius: 12, offset: const Offset(0, 4))] : null,
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(s['icon'] as IconData,
                      size: 22, color: active ? Colors.white : cfg.color),
                  const SizedBox(height: 6),
                  Text('$count', style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800,
                      color: active ? Colors.white : cfg.color)),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

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
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final isActive = _selectedFilter == f['key'];
            final color = f['key'] == 'all'
                ? const Color(0xFF7C3AED)
                : _getStatus(f['key']!).color;
            return GestureDetector(
              onTap: () => setState(() => _selectedFilter = f['key']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 18 : 14, vertical: 8),
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

  // ✅ currency parameter added + isRtl
  Widget _buildSubOrderCard(SubOrderModel s, bool isTablet, CurrencyProvider currency, bool isRtl) {
    final cfg     = _getStatus(s.status);
    final shortId = s.subOrderId.length >= 8
        ? s.subOrderId.substring(0, 8).toUpperCase()
        : s.subOrderId.toUpperCase();

    Widget imageWidget;
    if (s.images.isNotEmpty) {
      try {
        final bytes = base64Decode(s.images.first);
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(bytes,
              width: isTablet ? 96 : 84, height: isTablet ? 96 : 84,
              fit: BoxFit.cover),
        );
      } catch (_) { imageWidget = _imagePlaceholder(cfg, isTablet); }
    } else {
      imageWidget = _imagePlaceholder(cfg, isTablet);
    }

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: cfg.color.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cfg.color.withOpacity(0.12), cfg.color.withOpacity(0.04)],
              begin: Alignment.centerLeft, end: Alignment.centerRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: cfg.gradient,
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: cfg.color.withOpacity(0.4),
                    blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Icon(cfg.icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('#$shortId', style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: isTablet ? 15 : 13,
                    color: const Color(0xFF0F172A), letterSpacing: 0.5)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: cfg.gradient),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(cfg.label, style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10)),
                ),
              ]),
              const SizedBox(height: 2),
              Text(s.storeName, style: TextStyle(fontSize: 12, color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(_formatDate(s.createdAt), style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ])),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),
                      blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: imageWidget,
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: isTablet ? 15 : 13.5,
                    color: const Color(0xFF0F172A), height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(children: [
                  _miniTag('×${s.quantity}', Colors.grey.shade600, Colors.grey.shade100),
                  const SizedBox(width: 6),
                  _miniTag(currency.formatPrice(s.price),
                      const Color(0xFF7C3AED), const Color(0xFFEDE9FE)),
                ]),
                const SizedBox(height: 8),
                _shippingBadge(s),
              ])),
            ]),
            const SizedBox(height: 14),
            if (s.estimatedDateMin != null && s.estimatedDateMax != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
                    begin: Alignment.centerLeft, end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6EE7B7)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        color: const Color(0xFF059669).withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.event_rounded, size: 13, color: Color(0xFF059669)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: RichText(text: TextSpan(
                      style: const TextStyle(fontSize: 12, color: Color(0xFF065F46)),
                      children: [
                        TextSpan(text: _formatDelayLabel(s.estimatedDelayLabel),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(
                          text: '  ${_formatDateShort(s.estimatedDateMin!)}'
                              ' → ${_formatDateShort(s.estimatedDateMax!)}',
                          style: const TextStyle(color: Color(0xFF6EE7B7)),
                        ),
                      ]))),
                ]),
              ),
            _buildPriceRecap(s, cfg, currency),
            const SizedBox(height: 14),
            _buildActionsZone(s, cfg, isTablet, currency, isRtl), // ✅ isRtl passé
          ]),
        ),
      ]),
    );
  }

  Widget _buildPriceRecap(SubOrderModel s, _StatusConfig cfg, CurrencyProvider currency) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_t('cart_products_subtotal'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(currency.formatPrice(s.subtotal),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: Color(0xFF334155))),
        ]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_t('seller_shipping_cost'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(currency.formatPrice(s.shippingCost),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: Color(0xFF2563EB))),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Expanded(child: Container(height: 1, color: const Color(0xFFE2E8F0))),
          ]),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_t('cart_total'), style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: cfg.gradient),
                borderRadius: BorderRadius.circular(20)),
            child: Text(currency.formatPrice(s.total),
                style: const TextStyle(fontWeight: FontWeight.w800,
                    fontSize: 14, color: Colors.white)),
          ),
        ]),
      ]),
    );
  }

  Widget _buildActionsZone(SubOrderModel s, _StatusConfig cfg, bool isTablet,
      CurrencyProvider currency, bool isRtl) {
    final bool isDelivered = s.status == 'delivered';
    final bool isShipping  = s.status == 'shipping';

    return Column(children: [
      if (isShipping && s.buyerConfirmed) ...[
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFCD34D)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.hourglass_top_rounded, size: 14, color: Color(0xFFD97706)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_t('buyer_waiting_seller_confirm'), style: const TextStyle(
                  fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                  maxLines: 2),
              const SizedBox(height: 2),
              Text(_t('buyer_confirmed_your_side'),
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade400)),
            ])),
            const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFFF59E0B)),
          ]),
        ),
      ],
      if (isShipping && !s.buyerConfirmed) ...[
        _buildConfirmDeliveryButton(s, isTablet, isRtl), // ✅ isRtl passé
        const SizedBox(height: 10),
      ],
      Row(children: [
        _buildActionButton(
          label: _t('details'),
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF7C3AED),
          bgColor: const Color(0xFFEDE9FE),
          onTap: () => _showDetails(s, isTablet, currency),
          flex: 2,
        ),
        if (!isDelivered) ...[
          const SizedBox(width: 8),
          _ChatButtonNew(
            subOrderId: s.subOrderId, isSeller: false,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => OrderChatPage(subOrder: s, isSeller: false),
            )),
          ),
        ],
        if (isDelivered) ...[
          const SizedBox(width: 8),
          _hasReviewed[s.subOrderId] == true
              ? _buildReviewDoneTag(isTablet)
              : _buildActionButton(
            label: _t('review_add'), icon: Icons.star_rounded,
            color: const Color(0xFFF59E0B), bgColor: const Color(0xFFFFFBEB),
            onTap: () => _showReviewSheet(s), flex: 2,
          ),
        ],
      ]),
    ]);
  }

  // ✅ isRtl added to flip arrow icon
  Widget _buildConfirmDeliveryButton(SubOrderModel s, bool isTablet, bool isRtl) {
    return GestureDetector(
      onTap: () => _confirmDelivery(s),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
            begin: Alignment.centerLeft, end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: const Color(0xFF059669).withOpacity(0.45),
              blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25), shape: BoxShape.circle),
              child: const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_t('buyer_confirm_delivery'), style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800,
                  fontSize: 14, letterSpacing: 0.2)),
              const SizedBox(height: 2),
              Text(_t('buyer_confirm_delivery_subtitle'), style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w500)),
            ])),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Icon(
                isRtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                color: Colors.white, size: 16,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label, required IconData icon, required Color color,
    required Color bgColor, required VoidCallback onTap, int flex = 1,
  }) {
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
              color: bgColor, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  Widget _buildReviewDoneTag(bool isTablet) {
    return Expanded(
      flex: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
            color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6EE7B7))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF059669)),
          const SizedBox(width: 6),
          Text(_t('review_done'), style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
        ]),
      ),
    );
  }

  Future<void> _confirmDelivery(SubOrderModel s) async {
    final confirmed = await showDialog<bool>(
      context: context, barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.transparent, elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: const Color(0xFF059669).withOpacity(0.15),
                blurRadius: 40, offset: const Offset(0, 16))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF34D399)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: const Color(0xFF059669).withOpacity(0.35),
                    blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: const Icon(Icons.verified_rounded, color: Colors.white, size: 38),
            ),
            const SizedBox(height: 24),
            Text(_t('confirm_delivery_title'), textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            Text(_t('confirm_delivery_message'), textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.6)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6EE7B7))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.shopping_bag_rounded, size: 15, color: Color(0xFF059669)),
                const SizedBox(width: 8),
                Flexible(child: Text(s.name, textAlign: TextAlign.center,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: Color(0xFF065F46)))),
              ]),
            ),
            const SizedBox(height: 28),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(_t('cancel'), style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
              )),
              const SizedBox(width: 12),
              Expanded(child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: const Color(0xFF059669).withOpacity(0.4),
                      blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(_t('confirm_delivery_btn'), textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800,
                          fontSize: 14, color: Colors.white)),
                ),
              )),
            ]),
          ]),
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final docRef = _firestore
          .collection('orders').doc(s.parentOrderId)
          .collection('subOrders').doc(s.subOrderId);
      final snap = await docRef.get();
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final sellerAlreadyConfirmed = data['sellerConfirmed'] as bool? ?? false;
      final Map<String, dynamic> update = {
        'buyerConfirmed': true,
        'updatedAt':      Timestamp.now(),
      };
      if (sellerAlreadyConfirmed) update['status'] = 'delivered';
      await docRef.update(update);
      await loadOrders();
      await _checkReviews();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(_t('delivery_confirmed_success'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          ]),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('error')), backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  void _showReviewSheet(SubOrderModel s) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => _ReviewSheet(
        subOrder: s,
        onSubmit: (rating, comment, image) => _submitReview(s, rating, comment, image),
      ),
    );
  }

  Future<void> _submitReview(SubOrderModel s, int rating, String comment, File? image) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final reviewRef = _firestore.collection('products').doc(s.productId).collection('reviews').doc();
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final rawName = userDoc.exists
          ? '${userDoc.data()?['prenom'] ?? ''} ${userDoc.data()?['nom'] ?? ''}'.trim()
          : '';
      final userName = rawName.isEmpty ? 'Anonyme' : rawName;
      String? imageBase64;
      if (image != null) {
        final bytes = await image.readAsBytes();
        imageBase64 = base64Encode(bytes);
      }
      await reviewRef.set({
        'userId': uid, 'userName': userName,
        'productId': s.productId, 'productName': s.name,
        'subOrderId': s.subOrderId, 'sellerId': s.sellerId,
        'rating': rating, 'comment': comment,
        'imageBase64': imageBase64, 'hasImage': imageBase64 != null,
        'status': 'pending', 'rejectedReason': null,
        'reviewedAt': null, 'reviewedBy': null,
        'createdAt': Timestamp.now(),
      });
      if (mounted) {
        setState(() => _hasReviewed[s.subOrderId] = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(_t('review_success'))),
          ]),
          backgroundColor: const Color(0xFF059669), behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('review_error')),
          backgroundColor: const Color(0xFFDC2626), behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  Future<void> _updateProductRating(String productId) async {
    try {
      final reviews = await _firestore.collection('products').doc(productId)
          .collection('reviews').where('status', isEqualTo: 'approved').get();
      if (reviews.docs.isEmpty) {
        await _firestore.collection('products').doc(productId)
            .update({'avgRating': 0.0, 'reviewCount': 0});
        return;
      }
      final total = reviews.docs.fold<int>(0,
              (sum, d) => sum + ((d.data()['rating'] as num?) ?? 0).toInt());
      final avg = total / reviews.docs.length;
      await _firestore.collection('products').doc(productId).update({
        'avgRating': double.parse(avg.toStringAsFixed(1)),
        'reviewCount': reviews.docs.length,
      });
    } catch (_) {}
  }

  void _showDetails(SubOrderModel s, bool isTablet, CurrencyProvider currency) {
    final cfg = _getStatus(s.status);
    final shortId = s.subOrderId.length >= 8
        ? s.subOrderId.substring(0, 8).toUpperCase()
        : s.subOrderId.toUpperCase();

    Widget imageWidget;
    if (s.images.isNotEmpty) {
      try {
        final bytes = base64Decode(s.images.first);
        imageWidget = ClipRRect(borderRadius: BorderRadius.circular(12),
            child: Image.memory(bytes, width: 80, height: 80, fit: BoxFit.cover));
      } catch (_) { imageWidget = _imagePlaceholder(cfg, false); }
    } else { imageWidget = _imagePlaceholder(cfg, false); }

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  cfg.color.withOpacity(0.10), cfg.color.withOpacity(0.03)]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(children: [
                Center(child: Container(
                  width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: cfg.color.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2)),
                )),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('#$shortId', style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    Text(s.storeName, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    Text(_formatDateShort(s.createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ]),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: cfg.gradient),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: cfg.color.withOpacity(0.35),
                          blurRadius: 10, offset: const Offset(0, 3))],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(cfg.icon, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(cfg.label, style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    ]),
                  ),
                ]),
              ]),
            ),
            Expanded(child: ListView(
              controller: controller,
              padding: const EdgeInsets.all(24),
              children: [
                _sectionTitle(Icons.shopping_bag_rounded, _t('my_articles'), cfg.color),
                const SizedBox(height: 12),
                Row(children: [
                  imageWidget,
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.name, style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A)),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text('${currency.formatPrice(s.price)} × ${s.quantity}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  ])),
                ]),
                const SizedBox(height: 20),
                _sectionTitle(Icons.local_shipping_rounded, _t('seller_shipping_cost'), cfg.color),
                const SizedBox(height: 12),
                _infoTile(Icons.category_rounded, _t('seller_shipping_zone'), s.shippingZone),
                const SizedBox(height: 8),
                _infoTile(Icons.directions_run_rounded, _t('shipping_method'),
                    ShippingCompanies.findById(s.shippingMethod)?.name ?? s.shippingMethod),
                if (s.estimatedDelayLabel != '—') ...[
                  const SizedBox(height: 8),
                  _infoTile(Icons.timer_rounded, _t('seller_estimated_delay'),
                      _formatDelayLabel(s.estimatedDelayLabel)),
                ],
                if (s.estimatedDateMin != null && s.estimatedDateMax != null) ...[
                  const SizedBox(height: 8),
                  _infoTile(Icons.event_rounded, _t('seller_estimated_date'),
                      '${_formatDateShort(s.estimatedDateMin!)} → ${_formatDateShort(s.estimatedDateMax!)}'),
                ],
                const SizedBox(height: 20),
                _sectionTitle(Icons.receipt_rounded, _t('summary'), cfg.color),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Column(children: [
                    _priceRow(_t('cart_products_subtotal'), currency.formatPrice(s.subtotal)),
                    const SizedBox(height: 8),
                    _priceRow(_t('seller_shipping_cost'), currency.formatPrice(s.shippingCost),
                        valueColor: const Color(0xFF2563EB)),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0))),
                    _priceRow(_t('cart_total'), currency.formatPrice(s.total),
                        bold: true, valueColor: cfg.color),
                  ]),
                ),
                const SizedBox(height: 32),
              ],
            )),
          ]),
        ),
      ),
    );
  }

  Widget _miniTag(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(7)),
      child: Text(text, style: TextStyle(fontSize: 11,
          fontWeight: FontWeight.w600, color: textColor)),
    );
  }

  Widget _shippingBadge(SubOrderModel s) {
    final company = ShippingCompanies.findById(s.shippingMethod);
    final color  = company != null ? Color(company.colorValue) : const Color(0xFF2563EB);
    final bg     = color.withOpacity(0.09);
    final border = color.withOpacity(0.25);
    final IconData icon;
    switch (s.shippingMethod) {
      case 'dhl':
      case 'fedex':       icon = Icons.rocket_launch_rounded; break;
      case 'rapid_poste': icon = Icons.savings_rounded; break;
      default:            icon = Icons.local_shipping_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9),
          border: Border.all(color: border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 5),
        Text(company?.name ?? s.shippingMethod, style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 4),
        Text('· ${s.shippingZone}',
            style: TextStyle(fontSize: 10, color: color.withOpacity(0.6))),
      ]),
    );
  }

  Widget _imagePlaceholder(_StatusConfig cfg, bool isTablet) => Container(
    width: isTablet ? 96 : 84, height: isTablet ? 96 : 84,
    decoration: BoxDecoration(color: cfg.light, borderRadius: BorderRadius.circular(14)),
    child: Icon(cfg.icon, color: cfg.color.withOpacity(0.5), size: isTablet ? 32 : 28),
  );

  Widget _sectionTitle(IconData icon, String title, Color color) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color)),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontSize: 15,
          fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
    ]);
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(children: [
        Icon(icon, size: 15, color: Colors.grey.shade400),
        const SizedBox(width: 10),
        Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        Expanded(child: Text(value, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _priceRow(String label, String value, {bool bold = false, Color? valueColor}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(
          fontSize: bold ? 15 : 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: const Color(0xFF475569))),
      Text(value, style: TextStyle(
          fontSize: bold ? 17 : 13, fontWeight: FontWeight.w700,
          color: valueColor ?? const Color(0xFF0F172A))),
    ]);
  }

  Widget _buildEmptyState(bool isTablet) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 100, height: 100,
              decoration: const BoxDecoration(color: Color(0xFFEDE9FE), shape: BoxShape.circle),
              child: const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF7C3AED))),
          const SizedBox(height: 24),
          Text(_t('no_orders_title'), style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Text(_t('no_orders_desc'), textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5)),
        ]),
      ),
    );
  }
}

class _StatusConfig {
  final Color         color;
  final Color         light;
  final List<Color>   gradient;
  final IconData      icon;
  final String        label;

  const _StatusConfig({
    required this.color, required this.light, required this.gradient,
    required this.icon, required this.label,
  });
}

class _ReviewSheet extends StatefulWidget {
  final SubOrderModel subOrder;
  final Future<void> Function(int rating, String comment, File? image) onSubmit;

  const _ReviewSheet({required this.subOrder, required this.onSubmit});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _commentCtrl = TextEditingController();
  final _picker      = ImagePicker();
  int   _rating      = 0;
  File? _pickedImage;
  bool  _submitting  = false;

  String _t(String key) => AppLocalizations.get(key);

  @override
  void dispose() { _commentCtrl.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    final xFile = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1080, maxHeight: 1080, imageQuality: 75);
    if (xFile != null && mounted) setState(() => _pickedImage = File(xFile.path));
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5, expand: false,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              Center(child: Container(
                width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              )),
              Text(_t('review_title'), textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 6),
              Text(s.name, textAlign: TextAlign.center,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              const SizedBox(height: 24),
              Text(_t('review_stars_label'), style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return GestureDetector(
                      onTap: () => setState(() => _rating = i + 1),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 44,
                          color: i < _rating ? const Color(0xFFF59E0B) : Colors.grey.shade300,
                        ),
                      ),
                    );
                  })),
              if (_rating > 0) ...[
                const SizedBox(height: 8),
                Center(child: Text(
                  _rating == 1 ? _t('review_rate_1') : _rating == 2 ? _t('review_rate_2')
                      : _rating == 3 ? _t('review_rate_3') : _rating == 4 ? _t('review_rate_4')
                      : _t('review_rate_5'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: _rating >= 4 ? const Color(0xFF059669)
                          : _rating == 3 ? const Color(0xFFF59E0B) : const Color(0xFFDC2626)),
                )),
              ],
              const SizedBox(height: 22),
              Text(_t('review_comment_label'), style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              TextField(
                controller: _commentCtrl, maxLines: 4, maxLength: 300,
                decoration: InputDecoration(
                  hintText: _t('review_comment_hint'),
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  filled: true, fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5)),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 18),
              Text(_t('review_photo_label'), style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              const SizedBox(height: 10),
              if (_pickedImage == null)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4), width: 1.5),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.12),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.add_photo_alternate_rounded,
                              size: 30, color: Color(0xFFF59E0B))),
                      const SizedBox(height: 8),
                      Text(_t('review_photo_add'), style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B))),
                      Text(_t('review_photo_optional'),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    ]),
                  ),
                )
              else
                Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(16),
                      child: Image.file(_pickedImage!, width: double.infinity,
                          height: 180, fit: BoxFit.cover)),
                  Positioned(top: 8, right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _pickedImage = null),
                        child: Container(padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                                color: Color(0xFFDC2626), shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded, size: 16, color: Colors.white)),
                      )),
                  Positioned(top: 8, left: 8,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(_t('review_photo_change'), style: const TextStyle(
                                fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      )),
                ]),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF7DD3FC))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_rounded, size: 16, color: Color(0xFF0284C7)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_t('review_moderation_info'),
                      style: const TextStyle(fontSize: 12,
                          color: Color(0xFF0369A1), height: 1.4))),
                ]),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _rating == 0 || _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _rating == 0 ? Colors.grey.shade300 : const Color(0xFFF59E0B),
                    foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.send_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(_t('review_submit'), style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatButtonNew extends StatelessWidget {
  final String       subOrderId;
  final bool         isSeller;
  final VoidCallback onTap;

  const _ChatButtonNew({
    required this.subOrderId, required this.isSeller, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('chats').doc(subOrderId).get(),
      builder: (context, snap) {
        int unread = 0;
        if (snap.connectionState == ConnectionState.done &&
            snap.hasData && snap.data!.exists && !snap.hasError) {
          final data = snap.data!.data() as Map<String, dynamic>;
          unread = isSeller
              ? (data['unreadSeller'] as num? ?? 0).toInt()
              : (data['unreadBuyer']  as num? ?? 0).toInt();
        }
        return GestureDetector(
          onTap: onTap,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.35),
                    blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: const Icon(Icons.chat_rounded, color: Colors.white, size: 18),
            ),
            if (unread > 0)
              Positioned(top: -6, right: -6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5)),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(color: Colors.white, fontSize: 9,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  )),
          ]),
        );
      },
    );
  }
}
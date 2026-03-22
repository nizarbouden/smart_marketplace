import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:smart_marketplace/providers/currency_provider.dart'; // ✅
import 'package:smart_marketplace/providers/language_provider.dart';
import 'package:smart_marketplace/views/notifications/notifications_page.dart';
import '../../models/shipping_company_model.dart';
import '../../models/sub_order_model.dart';
import '../order chat/order_chat_page.dart';

class SellerSubOrdersPage extends StatefulWidget {
  const SellerSubOrdersPage({super.key});

  @override
  State<SellerSubOrdersPage> createState() => _SellerSubOrdersPageState();
}

class _SellerSubOrdersPageState extends State<SellerSubOrdersPage>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  int  _unreadCount  = 0;
  bool _isRefreshing = false;
  int  _streamKey    = 0;
  StreamSubscription<QuerySnapshot>? _notifSub;
  StreamSubscription<User?>?         _authSub;

  final List<String> _statuses = [
    'all', 'paid', 'shipping', 'delivered', 'cancelled',
  ];

  final Map<String, String> _buyerNameCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statuses.length, vsync: this);
    _listenUnreadCount();

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) _notifSub?.cancel();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _notifSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _listenUnreadCount() {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    _notifSub = _firestore
        .collection('users').doc(uid).collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _unreadCount = snap.docs.length);
    });
  }

  Future<void> _onRefresh() async {
    setState(() { _isRefreshing = true; _streamKey++; });
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _isRefreshing = false);
  }

  void _openNotifications() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()));

  Future<String> _getBuyerName(String userId) async {
    if (userId.isEmpty) return '—';
    if (_buyerNameCache.containsKey(userId)) return _buyerNameCache[userId]!;
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final d    = doc.data()!;
        final name = (d['displayName'] as String?)?.trim()
            ?? (d['email']        as String?)?.trim()
            ?? userId.substring(0, 8);
        _buyerNameCache[userId] = name;
        return name;
      }
    } catch (_) {}
    final fallback = userId.length >= 8 ? userId.substring(0, 8) : userId;
    _buyerNameCache[userId] = fallback;
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    String t(String key) => lang.translate(key);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16A34A),
        elevation: 0,
        title: Text(t('seller_orders_title'),
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _openNotifications,
              child: Stack(clipBehavior: Clip.none, children: [
                const Icon(Icons.notifications_rounded,
                    color: Colors.white, size: 30),
                if (_unreadCount > 0)
                  Positioned(
                    top: -5, right: -5,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        _unreadCount > 99 ? '99+' : '$_unreadCount',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: _statuses.map((s) => Tab(text: t('seller_status_$s'))).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statuses.map((s) => _buildList(s, t)).toList(),
      ),
    );
  }

  Widget _buildList(String status, String Function(String) t) {
    final uid = _currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    Query query = _firestore
        .collectionGroup('subOrders')
        .where('sellerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true);

    return RefreshIndicator(
      onRefresh:   _onRefresh,
      color:       const Color(0xFF16A34A),
      strokeWidth: 2.5,
      child: StreamBuilder<QuerySnapshot>(
        key: ValueKey('$status-$_streamKey'),
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !_isRefreshing) {
            return const Center(child: CircularProgressIndicator(
                color: Color(0xFF16A34A)));
          }

          final allDocs = snapshot.data?.docs ?? [];

          final docs = status == 'all'
              ? allDocs
              : allDocs.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return (d['status'] as String? ?? 'paid') == status;
          }).toList();

          if (docs.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_rounded,
                            size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(t('seller_no_orders'),
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 15)),
                      ])),
                ),
              ],
            );
          }

          return LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            final subOrders = docs
                .map((d) => SubOrderModel.fromFirestore(d))
                .toList();

            if (isWide) {
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate:
                const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 520,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.75,
                ),
                itemCount: subOrders.length,
                itemBuilder: (_, i) => _SubOrderCard(
                  subOrder:     subOrders[i],
                  t:            t,
                  getBuyerName: _getBuyerName,
                  onUpdate:     _updateSubOrderStatus,
                  statusConfig: _getStatusConfig,
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: subOrders.length,
              itemBuilder: (_, i) => _SubOrderCard(
                subOrder:     subOrders[i],
                t:            t,
                getBuyerName: _getBuyerName,
                onUpdate:     _updateSubOrderStatus,
                statusConfig: _getStatusConfig,
              ),
            );
          });
        },
      ),
    );
  }

  Future<void> _updateSubOrderStatus(
      SubOrderModel subOrder, String action) async {

    if (action == 'seller_confirm') {
      final docRef = _firestore
          .collection('orders')
          .doc(subOrder.parentOrderId)
          .collection('subOrders')
          .doc(subOrder.subOrderId);

      final snap = await docRef.get();
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final buyerAlreadyConfirmed = data['buyerConfirmed'] as bool? ?? false;

      await docRef.update({
        'sellerConfirmed': true,
        'status':    buyerAlreadyConfirmed ? 'delivered' : 'shipping',
        'updatedAt': Timestamp.now(),
      });
    } else {
      await _firestore
          .collection('orders')
          .doc(subOrder.parentOrderId)
          .collection('subOrders')
          .doc(subOrder.subOrderId)
          .update({'status': action, 'updatedAt': Timestamp.now()});
    }
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'paid':
        return {'color': const Color(0xFFF59E0B), 'icon': Icons.pending_rounded};
      case 'shipping':
        return {'color': const Color(0xFF3B82F6), 'icon': Icons.local_shipping_rounded};
      case 'delivered':
        return {'color': const Color(0xFF16A34A), 'icon': Icons.check_circle_rounded};
      case 'cancelled':
        return {'color': const Color(0xFFDC2626), 'icon': Icons.cancel_rounded};
      default:
        return {'color': const Color(0xFF94A3B8), 'icon': Icons.receipt_rounded};
    }
  }
}

// ─────────────────────────────────────────────────────────────────
//  _SubOrderCard
// ─────────────────────────────────────────────────────────────────

class _SubOrderCard extends StatefulWidget {
  final SubOrderModel                               subOrder;
  final String Function(String)                     t;
  final Future<String> Function(String)             getBuyerName;
  final Future<void> Function(SubOrderModel, String) onUpdate;
  final Map<String, dynamic> Function(String)       statusConfig;

  const _SubOrderCard({
    required this.subOrder,
    required this.t,
    required this.getBuyerName,
    required this.onUpdate,
    required this.statusConfig,
  });

  @override
  State<_SubOrderCard> createState() => _SubOrderCardState();
}

class _SubOrderCardState extends State<_SubOrderCard> {
  bool _isUpdating = false;

  Future<void> _confirmAndUpdate(String newStatus) async {
    final t = widget.t;

    final bool isCancel  = newStatus == 'cancelled';
    final bool isShip    = newStatus == 'shipping';
    final bool isConfirm = newStatus == 'seller_confirm';

    final Color accentColor = isCancel
        ? const Color(0xFFDC2626)
        : isShip
        ? const Color(0xFF3B82F6)
        : const Color(0xFF16A34A);

    final IconData accentIcon = isCancel
        ? Icons.cancel_rounded
        : isShip
        ? Icons.local_shipping_rounded
        : Icons.check_circle_outline_rounded;

    final String title = isCancel
        ? t('confirm_cancel_title')
        : isShip
        ? t('confirm_ship_title')
        : t('confirm_seller_delivery_title');

    final String message = isCancel
        ? t('confirm_cancel_message')
        : isShip
        ? t('confirm_ship_message')
        : t('confirm_seller_delivery_message');

    final String confirmLabel = isCancel
        ? t('seller_cancel_order')
        : isShip
        ? t('seller_mark_shipping')
        : t('seller_confirm_delivery');

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: accentColor.withOpacity(0.15),
                  blurRadius: 30, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 68, height: 68,
              decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.10), shape: BoxShape.circle),
              child: Icon(accentIcon, color: accentColor, size: 34),
            ),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18,
                    fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14,
                    color: Colors.grey.shade500, height: 1.5)),
            const SizedBox(height: 8),
            if (isConfirm)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 15, color: Color(0xFFF97316)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t('confirm_seller_delivery_note'),
                          style: const TextStyle(fontSize: 12,
                              color: Color(0xFFC2410C), height: 1.4))),
                    ]),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200)),
                child: Text(widget.subOrder.name,
                    textAlign: TextAlign.center,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
              ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(t('cancel'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(confirmLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _isUpdating = true);
      try {
        await widget.onUpdate(widget.subOrder, newStatus);
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s   = widget.subOrder;
    final t   = widget.t;
    final cfg = widget.statusConfig(s.status);

    final shortId = s.subOrderId.length >= 8
        ? s.subOrderId.substring(0, 8).toUpperCase()
        : s.subOrderId.toUpperCase();

    Widget imageWidget;
    if (s.images.isNotEmpty) {
      try {
        final bytes = base64Decode(s.images.first);
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes, width: 72, height: 72, fit: BoxFit.cover),
        );
      } catch (_) { imageWidget = _imagePlaceholder(); }
    } else {
      imageWidget = _imagePlaceholder();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: (cfg['color'] as Color).withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Icon(cfg['icon'] as IconData, color: cfg['color'] as Color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('#$shortId',
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 13, color: Color(0xFF1E293B))),
                Text(s.storeName,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (cfg['color'] as Color).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(t('seller_status_${s.status}'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: cfg['color'] as Color)),
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Produit ──────────────────────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              imageWidget,
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B)),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${context.watch<CurrencyProvider>().formatPrice(s.price)} × ${s.quantity}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 4),
                Builder(builder: (context) {
                  final company = ShippingCompanies.findById(s.shippingMethod);
                  final Color badgeColor = company != null
                      ? Color(company.colorValue) : const Color(0xFF2563EB);
                  final Color badgeBg = company != null
                      ? Color(company.colorValue).withOpacity(0.10)
                      : const Color(0xFFEFF6FF);
                  final Color badgeBorder = company != null
                      ? Color(company.colorValue).withOpacity(0.30)
                      : const Color(0xFF93C5FD);
                  final IconData badgeIcon = () {
                    switch (s.shippingMethod) {
                      case 'dhl':
                      case 'fedex':       return Icons.rocket_launch_rounded;
                      case 'rapid_poste': return Icons.savings_rounded;
                      default:            return Icons.local_shipping_rounded;
                    }
                  }();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: badgeBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: badgeBorder)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(badgeIcon, size: 11, color: badgeColor),
                      const SizedBox(width: 4),
                      Text(company?.name ?? s.shippingMethod,
                          style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w600, color: badgeColor)),
                    ]),
                  );
                }),
              ])),
            ]),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // ── Acheteur ─────────────────────────────────────────
            if (s.userId.isNotEmpty)
              FutureBuilder<String>(
                future: widget.getBuyerName(s.userId),
                builder: (_, snap) => _InfoRow(
                  icon:  Icons.person_rounded,
                  label: t('seller_buyer'),
                  value: snap.data ?? '...',
                ),
              ),
            const SizedBox(height: 8),

            _InfoRow(icon: Icons.calendar_today_rounded,
                label: t('seller_order_date'), value: _formatDate(s.createdAt)),
            const SizedBox(height: 8),

            if (s.estimatedDelayLabel != '—') ...[
              _InfoRow(icon: Icons.timer_rounded,
                  label: t('seller_estimated_delay'),
                  value: _formatDelayLabel(s.estimatedDelayLabel)),
              const SizedBox(height: 8),
            ],
            if (s.estimatedDateMin != null && s.estimatedDateMax != null) ...[
              _InfoRow(icon: Icons.event_rounded,
                  label: t('seller_estimated_date'),
                  value: '${_formatDateShort(s.estimatedDateMin!)} → ${_formatDateShort(s.estimatedDateMax!)}'),
              const SizedBox(height: 8),
            ],

            _InfoRow(icon: Icons.location_on_rounded,
                label: t('seller_shipping_zone'), value: s.shippingZone),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            _PriceRow(label: t('seller_products_subtotal'),
                value: context.watch<CurrencyProvider>().formatPrice(s.subtotal)),
            const SizedBox(height: 6),
            _PriceRow(label: t('seller_shipping_cost'),
                value: context.watch<CurrencyProvider>().formatPrice(s.shippingCost),
                valueColor: const Color(0xFF3B82F6)),
            const SizedBox(height: 6),
            _PriceRow(label: t('seller_total'),
                value: context.watch<CurrencyProvider>().formatPrice(s.total),
                bold: true, valueColor: const Color(0xFF16A34A)),

            // ── Boutons d'action ──────────────────────────────────
            if (!_isUpdating) ...[
              if (s.status == 'paid') ...[
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _ActionBtn(
                    label: t('seller_mark_shipping'),
                    color: const Color(0xFF3B82F6),
                    icon:  Icons.local_shipping_rounded,
                    onTap: () => _confirmAndUpdate('shipping'),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _ActionBtn(
                    label: t('seller_cancel_order'),
                    color: const Color(0xFFDC2626),
                    icon:  Icons.cancel_rounded,
                    onTap: () => _confirmAndUpdate('cancelled'),
                  )),
                ]),
              ],

              if (s.status == 'shipping') ...[
                const SizedBox(height: 14),
                if (s.buyerConfirmed) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.how_to_reg_rounded,
                          size: 15, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t('seller_buyer_already_confirmed'),
                          style: const TextStyle(fontSize: 12,
                              color: Color(0xFF15803D),
                              fontWeight: FontWeight.w500))),
                    ]),
                  ),
                ],
                if (!s.sellerConfirmed)
                  SizedBox(
                    width: double.infinity,
                    child: _ActionBtn(
                      label: t('seller_confirm_delivery'),
                      color: const Color(0xFF16A34A),
                      icon:  Icons.check_circle_outline_rounded,
                      onTap: () => _confirmAndUpdate('seller_confirm'),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.hourglass_top_rounded,
                          size: 16, color: Color(0xFFF97316)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t('seller_waiting_buyer_confirm'),
                          style: const TextStyle(fontSize: 12,
                              color: Color(0xFFC2410C),
                              fontWeight: FontWeight.w500))),
                    ]),
                  ),
              ],

              // ── Bouton chat ───────────────────────────────────────
              // Visible pour tous les statuts SAUF 'delivered'
              // (paid, shipping, cancelled → chat accessible)
              if (s.status != 'delivered') ...[
                const SizedBox(height: 12),
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(s.subOrderId)
                      .get(),
                  builder: (context, snap) {
                    int unread = 0;
                    if (snap.connectionState == ConnectionState.done &&
                        snap.hasData && snap.data!.exists && !snap.hasError) {
                      final data = snap.data!.data() as Map<String, dynamic>;
                      unread = (data['unreadSeller'] as num? ?? 0).toInt();
                    }
                    return Stack(clipBehavior: Clip.none, children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) =>
                                OrderChatPage(subOrder: s, isSeller: true)),
                          ),
                          icon: const Icon(Icons.chat_rounded, size: 16),
                          label: Text(t('chat_with_buyer'),
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF16A34A),
                            side: const BorderSide(
                                color: Color(0xFF16A34A), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      if (unread > 0)
                        Positioned(
                          top: -6, right: -6,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            constraints: const BoxConstraints(
                                minWidth: 18, minHeight: 18),
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 9, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ]);
                  },
                ),
              ],

              // ── Bandeau chat désactivé pour 'delivered' ───────────
              if (s.status == 'delivered') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF16A34A), size: 16),
                      const SizedBox(width: 8),
                      Text(t('chat_order_delivered_closed'),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF15803D))),
                    ],
                  ),
                ),
              ],

            ] else ...[
              const SizedBox(height: 14),
              const Center(child: SizedBox(width: 32, height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2.5,
                      color: Color(0xFF16A34A)))),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _imagePlaceholder() => Container(
    width: 72, height: 72,
    decoration: BoxDecoration(color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12)),
    child: Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 28),
  );

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}  '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';

  String _formatDateShort(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';

  String _formatDelayLabel(String raw) {
    if (raw == '—' || raw.isEmpty) return '—';
    return '$raw ${widget.t("days_label")}';
  }
}

// ─────────────────────────────────────────────────────────────────
//  Widgets utilitaires
// ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 15, color: Colors.grey[400])),
      const SizedBox(width: 8),
      Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      Expanded(child: Text(value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B)),
          maxLines: 2, overflow: TextOverflow.ellipsis)),
    ]);
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool   bold;
  final Color? valueColor;
  const _PriceRow({required this.label, required this.value,
    this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(
          fontSize: bold ? 15 : 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: bold ? const Color(0xFF1E293B) : Colors.grey[500])),
      Text(value, style: TextStyle(
          fontSize: bold ? 16 : 13,
          fontWeight: FontWeight.bold,
          color: valueColor ?? const Color(0xFF1E293B))),
    ]);
  }
}

class _ActionBtn extends StatelessWidget {
  final String       label;
  final Color        color;
  final IconData     icon;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.color,
    required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
      icon: Icon(icon, size: 14),
      label: Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
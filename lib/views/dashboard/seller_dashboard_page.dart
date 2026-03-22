import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:smart_marketplace/providers/currency_provider.dart';
import 'package:smart_marketplace/providers/language_provider.dart';
import 'package:smart_marketplace/views/notifications/notifications_page.dart';

class SellerDashboardPage extends StatefulWidget {
  const SellerDashboardPage({super.key});

  @override
  State<SellerDashboardPage> createState() => _SellerDashboardPageState();
}

class _SellerDashboardPageState extends State<SellerDashboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  // ── Stats de base ────────────────────────────────────────────
  int    _totalProducts   = 0;
  int    _totalOrders     = 0;   // tous statuts sauf cancelled
  double _totalRevenue    = 0;   // somme subtotal des subOrders delivered
  int    _pendingOrders   = 0;   // statut 'paid'
  int    _shippingOrders  = 0;   // statut 'shipping'
  int    _deliveredOrders = 0;   // statut 'delivered'
  int    _cancelledOrders = 0;   // statut 'cancelled'
  double _avgOrderValue   = 0;   // valeur moyenne par commande livrée
  int    _totalQtySold    = 0;   // quantité totale vendue (delivered)
  bool   _isLoading       = true;

  // ── Notifications ────────────────────────────────────────────
  int _unreadCount = 0;
  StreamSubscription<QuerySnapshot>? _notifSub;

  // ── Streams temps réel ───────────────────────────────────────
  StreamSubscription<QuerySnapshot>? _subOrdersSub;
  StreamSubscription<QuerySnapshot>? _productsSub;
  StreamSubscription<User?>?         _authSub;

  // ── Activité récente ─────────────────────────────────────────
  List<Map<String, dynamic>> _recentSubOrders = [];

  // ── Top 3 articles vendus ────────────────────────────────────
  // Structure : { productId, name, images, qtySold, revenue, orderCount }
  List<Map<String, dynamic>> _topProducts = [];

  @override
  void initState() {
    super.initState();
    _listenUnreadCount();
    _listenStats();

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _notifSub?.cancel();
        _subOrdersSub?.cancel();
        _productsSub?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _notifSub?.cancel();
    _subOrdersSub?.cancel();
    _productsSub?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  //  STREAM NOTIFICATIONS
  // ─────────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────
  //  STREAM STATS — temps réel
  // ─────────────────────────────────────────────────────────────

  void _listenStats() {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    // ── Produits ─────────────────────────────────────────────
    _productsSub = _firestore
        .collection('products')
        .where('sellerId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _totalProducts = snap.docs.length);
    });

    // ── SubOrders ────────────────────────────────────────────
    _subOrdersSub = _firestore
        .collectionGroup('subOrders')
        .where('sellerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;

      int    totalOrders     = 0;
      double totalRevenue    = 0;
      int    pendingOrders   = 0;
      int    shippingOrders  = 0;
      int    deliveredOrders = 0;
      int    cancelledOrders = 0;
      int    totalQtySold    = 0;

      final recent = <Map<String, dynamic>>[];

      // Agrégation par produit pour le top
      // clé = productId (ou name si absent)
      final Map<String, Map<String, dynamic>> productAgg = {};

      for (final doc in snap.docs) {
        final d      = doc.data();
        final status = d['status'] as String? ?? 'paid';
        final price  = (d['price']    as num? ?? 0).toDouble();
        final qty    = (d['quantity'] as num? ?? 1).toInt();

        // Compteurs statuts
        switch (status) {
          case 'paid':      pendingOrders++;   totalOrders++; break;
          case 'shipping':  shippingOrders++;  totalOrders++; break;
          case 'delivered': deliveredOrders++; totalOrders++; break;
          case 'cancelled': cancelledOrders++; break;
        }

        // Revenu + quantités vendues uniquement si livré
        if (status == 'delivered') {
          totalRevenue += price * qty;
          totalQtySold += qty;

          // Agrégation produit
          final productId = (d['productId'] as String?)
              ?? (d['name']      as String? ?? doc.id);
          if (!productAgg.containsKey(productId)) {
            productAgg[productId] = {
              'productId':  productId,
              'name':       d['name']   as String? ?? '—',
              'images':     d['images'] as List<dynamic>? ?? [],
              'qtySold':    0,
              'revenue':    0.0,
              'orderCount': 0,
            };
          }
          productAgg[productId]!['qtySold']    = (productAgg[productId]!['qtySold'] as int) + qty;
          productAgg[productId]!['revenue']    = (productAgg[productId]!['revenue'] as double) + price * qty;
          productAgg[productId]!['orderCount'] = (productAgg[productId]!['orderCount'] as int) + 1;
        }

        // Activité récente — 5 dernières
        if (recent.length < 5) recent.add({...d, '_docId': doc.id});
      }

      // Top 3 triés par qtySold décroissant
      final topList = productAgg.values.toList()
        ..sort((a, b) =>
            (b['qtySold'] as int).compareTo(a['qtySold'] as int));

      final double avgVal = deliveredOrders > 0
          ? totalRevenue / deliveredOrders
          : 0;

      setState(() {
        _totalOrders     = totalOrders;
        _totalRevenue    = totalRevenue;
        _pendingOrders   = pendingOrders;
        _shippingOrders  = shippingOrders;
        _deliveredOrders = deliveredOrders;
        _cancelledOrders = cancelledOrders;
        _totalQtySold    = totalQtySold;
        _avgOrderValue   = avgVal;
        _recentSubOrders = recent;
        _topProducts     = topList.take(3).toList();
        _isLoading       = false;
      });
    }, onError: (_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 600));
  }

  void _openNotifications() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const NotificationsPage()));

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final currency = context.watch<CurrencyProvider>(); // ✅ devise sélectionnée
    String t(String key) => lang.translate(key);

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: RefreshIndicator(
        color: const Color(0xFF16A34A),
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(t),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                            color: Color(0xFF16A34A)),
                      ),
                    )
                  else ...[
                    _buildWelcomeCard(t),
                    const SizedBox(height: 24),
                    _buildStatsGrid(t, currency),
                    const SizedBox(height: 24),
                    _buildOrderStatusBreakdown(t),
                    const SizedBox(height: 24),
                    _buildExtraStats(t, currency),
                    const SizedBox(height: 24),
                    _buildTopProducts(t, currency),
                    const SizedBox(height: 24),
                    _buildRecentActivity(t, currency),
                    const SizedBox(height: 80),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  APP BAR
  // ─────────────────────────────────────────────────────────────

  Widget _buildAppBar(String Function(String) t) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF16A34A),
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF16A34A),
                Color(0xFF15803D),
                Color(0xFF166534),
              ],
            ),
          ),
        ),
        title: Text(t('seller_dashboard_title'),
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
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
                    constraints:
                    const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      _unreadCount > 99 ? '99+' : '$_unreadCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  WELCOME CARD
  // ─────────────────────────────────────────────────────────────

  Widget _buildWelcomeCard(String Function(String) t) {
    final name = _currentUser?.displayName ?? t('seller_default_name');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.storefront_rounded,
              color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t('seller_welcome')}, $name 👋',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(t('seller_welcome_subtitle'),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85), fontSize: 13)),
              ]),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  STATS GRID PRINCIPALE
  // ─────────────────────────────────────────────────────────────

  Widget _buildStatsGrid(String Function(String) t, CurrencyProvider currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('seller_stats_title'),
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B))),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.4,
          children: [
            _buildStatCard(
              icon:    Icons.inventory_2_rounded,
              label:   t('seller_stat_products'),
              value:   '$_totalProducts',
              color:   const Color(0xFF3B82F6),
              bgColor: const Color(0xFFEFF6FF),
            ),
            _buildStatCard(
              icon:    Icons.receipt_long_rounded,
              label:   t('seller_stat_orders'),
              value:   '$_totalOrders',
              color:   const Color(0xFF8B5CF6),
              bgColor: const Color(0xFFF5F3FF),
            ),
            _buildStatCard(
              icon:    Icons.attach_money_rounded,
              label:   t('seller_stat_revenue'),
              value:   currency.formatPrice(_totalRevenue),
              color:   const Color(0xFF16A34A),
              bgColor: const Color(0xFFF0FDF4),
            ),
            _buildStatCard(
              icon:    Icons.pending_actions_rounded,
              label:   t('seller_stat_pending'),
              value:   '$_pendingOrders',
              color:   const Color(0xFFF59E0B),
              bgColor: const Color(0xFFFFFBEB),
              showBadge: _pendingOrders > 0,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
    bool showBadge = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (showBadge)
                Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(
                      color: Color(0xFFDC2626), shape: BoxShape.circle),
                ),
            ],
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ]),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  RÉPARTITION STATUTS DES COMMANDES (barres horizontales)
  // ─────────────────────────────────────────────────────────────

  Widget _buildOrderStatusBreakdown(String Function(String) t) {
    final total = _totalOrders + _cancelledOrders;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.pie_chart_rounded,
                color: Color(0xFF16A34A), size: 18),
            const SizedBox(width: 8),
            Text(t('seller_stat_orders_breakdown'),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B))),
          ]),
          const SizedBox(height: 18),
          _buildStatusBar(
            label:  t('seller_status_paid'),
            count:  _pendingOrders,
            total:  total,
            color:  const Color(0xFFF59E0B),
            icon:   Icons.pending_rounded,
          ),
          const SizedBox(height: 12),
          _buildStatusBar(
            label:  t('seller_status_shipping'),
            count:  _shippingOrders,
            total:  total,
            color:  const Color(0xFF3B82F6),
            icon:   Icons.local_shipping_rounded,
          ),
          const SizedBox(height: 12),
          _buildStatusBar(
            label:  t('seller_status_delivered'),
            count:  _deliveredOrders,
            total:  total,
            color:  const Color(0xFF16A34A),
            icon:   Icons.check_circle_rounded,
          ),
          const SizedBox(height: 12),
          _buildStatusBar(
            label:  t('seller_status_cancelled'),
            count:  _cancelledOrders,
            total:  total,
            color:  const Color(0xFFDC2626),
            icon:   Icons.cancel_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar({
    required String  label,
    required int     count,
    required int     total,
    required Color   color,
    required IconData icon,
  }) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 8),
      SizedBox(
        width: 80,
        child: Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 28,
        child: Text('$count',
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color)),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────
  //  STATS SUPPLÉMENTAIRES (ligne de 3 mini-cartes)
  // ─────────────────────────────────────────────────────────────

  Widget _buildExtraStats(String Function(String) t, CurrencyProvider currency) {
    // Taux de livraison réussie
    final totalAttempted = _deliveredOrders + _cancelledOrders;
    final deliveryRate   = totalAttempted > 0
        ? (_deliveredOrders / totalAttempted * 100).toStringAsFixed(0)
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('seller_stat_performance'),
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B))),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _buildMiniStatCard(
            icon:    Icons.local_mall_rounded,
            label:   t('seller_stat_qty_sold'),
            value:   '$_totalQtySold',
            color:   const Color(0xFF0EA5E9),
            bgColor: const Color(0xFFE0F2FE),
          )),
          const SizedBox(width: 12),
          Expanded(child: _buildMiniStatCard(
            icon:    Icons.trending_up_rounded,
            label:   t('seller_stat_avg_order'),
            value:   _avgOrderValue > 0
                ? currency.formatPrice(_avgOrderValue)
                : '—',
            color:   const Color(0xFF8B5CF6),
            bgColor: const Color(0xFFF5F3FF),
          )),
          const SizedBox(width: 12),
          Expanded(child: _buildMiniStatCard(
            icon:    Icons.verified_rounded,
            label:   t('seller_stat_delivery_rate'),
            value:   deliveryRate != '—' ? '$deliveryRate%' : '—',
            color:   const Color(0xFF16A34A),
            bgColor: const Color(0xFFF0FDF4),
          )),
        ]),
      ],
    );
  }

  Widget _buildMiniStatCard({
    required IconData icon,
    required String   label,
    required String   value,
    required Color    color,
    required Color    bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  TOP 3 ARTICLES VENDUS
  // ─────────────────────────────────────────────────────────────

  Widget _buildTopProducts(String Function(String) t, CurrencyProvider currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              const Text('🏆', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(t('seller_top_products'),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B))),
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Text(t('seller_top_delivered_only'),
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF97316))),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_topProducts.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.04), blurRadius: 8)],
            ),
            child: Center(child: Column(children: [
              Icon(Icons.emoji_events_outlined,
                  size: 44, color: Colors.grey[300]),
              const SizedBox(height: 10),
              Text(t('seller_no_top_products'),
                  style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            ])),
          )
        else
          ...(_topProducts.asMap().entries.map(
                (e) => _buildTopProductTile(e.key, e.value, t, currency),
          )),
      ],
    );
  }

  Widget _buildTopProductTile(
      int rank, Map<String, dynamic> data, String Function(String) t, CurrencyProvider currency) {

    // Médailles
    final medals   = ['🥇', '🥈', '🥉'];
    final medal    = rank < medals.length ? medals[rank] : '${rank + 1}';

    // Couleurs podium
    final rankColors = [
      const Color(0xFFFFB800), // or
      const Color(0xFF94A3B8), // argent
      const Color(0xFFCD7F32), // bronze
    ];
    final rankColor = rank < rankColors.length
        ? rankColors[rank]
        : const Color(0xFF94A3B8);

    final name       = data['name']       as String? ?? '—';
    final qtySold    = data['qtySold']    as int;
    final revenue    = data['revenue']    as double;
    final orderCount = data['orderCount'] as int;
    final images     = data['images']     as List<dynamic>? ?? [];

    // Image produit
    Widget imgWidget;
    if (images.isNotEmpty) {
      try {
        final bytes = base64Decode(images.first as String);
        imgWidget = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes, width: 60, height: 60, fit: BoxFit.cover),
        );
      } catch (_) { imgWidget = _topImgPlaceholder(rankColor); }
    } else {
      imgWidget = _topImgPlaceholder(rankColor);
    }

    // Barre de progression relative au top 1
    final maxQty = (_topProducts.isNotEmpty
        ? _topProducts.first['qtySold'] as int
        : 1);
    final progress = maxQty > 0 ? qtySold / maxQty : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: rank == 0
            ? Border.all(color: const Color(0xFFFFB800).withOpacity(0.4),
            width: 1.5)
            : null,
        boxShadow: [BoxShadow(
            color: rank == 0
                ? const Color(0xFFFFB800).withOpacity(0.10)
                : Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Médaille
            Text(medal, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),

            // Image
            Stack(children: [
              imgWidget,
              if (rank == 0)
                Positioned(
                  top: -4, right: -4,
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB800),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.star_rounded,
                        color: Colors.white, size: 10),
                  ),
                ),
            ]),
            const SizedBox(width: 12),

            // Nom + stats texte
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E293B)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  _topChip(
                    icon: Icons.shopping_bag_rounded,
                    label: '$qtySold ${t("seller_units_sold")}',
                    color: rankColor,
                  ),
                  _topChip(
                    icon: Icons.receipt_rounded,
                    label: '$orderCount ${t("seller_orders_label")}',
                    color: const Color(0xFF6366F1),
                  ),
                ]),
              ],
            )),

            // Revenu
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(currency.formatPrice(revenue),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: rankColor)),
              Text(currency.selectedCode, style: TextStyle(
                  fontSize: 10, color: Colors.grey[400])),
            ]),
          ]),

          // Barre de progression relative
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: rankColor.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(rankColor),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: rankColor)),
          ]),
        ],
      ),
    );
  }

  Widget _topChip({
    required IconData icon,
    required String   label,
    required Color    color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color)),
      ]),
    );
  }

  Widget _topImgPlaceholder(Color color) => Container(
    width: 60, height: 60,
    decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12)),
    child: Icon(Icons.inventory_2_rounded,
        color: color.withOpacity(0.5), size: 26),
  );

  // ─────────────────────────────────────────────────────────────
  //  ACTIVITÉ RÉCENTE
  // ─────────────────────────────────────────────────────────────

  Widget _buildRecentActivity(String Function(String) t, CurrencyProvider currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(t('seller_recent_activity'),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B))),
            Row(children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: Color(0xFF16A34A), shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text('Live',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500)),
            ]),
          ],
        ),
        const SizedBox(height: 16),

        if (_recentSubOrders.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10)],
            ),
            child: Center(child: Column(children: [
              Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(t('seller_no_orders_yet'),
                  style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            ])),
          )
        else
          ...(_recentSubOrders.map((data) => _buildSubOrderTile(data, t, currency))),
      ],
    );
  }

  Widget _buildSubOrderTile(
      Map<String, dynamic> data, String Function(String) t, CurrencyProvider currency) {
    final status   = data['status']    as String? ?? 'paid';
    final name     = data['name']      as String? ?? '—';
    final price    = (data['price']    as num?    ?? 0).toDouble();
    final qty      = (data['quantity'] as num?    ?? 1).toInt();
    final total    = price * qty;
    final rawId    = data['_docId']    as String? ?? '';
    final shortId  = rawId.length >= 8
        ? rawId.substring(0, 8).toUpperCase()
        : rawId.toUpperCase();

    Widget leading;
    final images = data['images'] as List<dynamic>? ?? [];
    if (images.isNotEmpty) {
      try {
        final bytes = base64Decode(images.first as String);
        leading = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(bytes, width: 46, height: 46,
              fit: BoxFit.cover),
        );
      } catch (_) { leading = _tileImagePlaceholder(status); }
    } else {
      leading = _tileImagePlaceholder(status);
    }

    final cfg         = _statusConfig(status);
    final Color  statusColor = cfg['color'] as Color;
    final IconData statusIcon = cfg['icon'] as IconData;

    String dateStr = '—';
    final ts = data['createdAt'];
    if (ts is Timestamp) {
      final d = ts.toDate();
      dateStr = '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(children: [
        Stack(children: [
          leading,
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Icon(statusIcon, size: 10, color: Colors.white),
            ),
          ),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF1E293B))),
              const SizedBox(height: 2),
              Row(children: [
                Text('#$shortId',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                const SizedBox(width: 6),
                Text('• $dateStr',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ]),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  t('seller_status_$status'),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(currency.formatPrice(total),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF16A34A))),
          Text(currency.selectedCode,
              style: TextStyle(fontSize: 10, color: Colors.grey[400])),
        ]),
      ]),
    );
  }

  Widget _tileImagePlaceholder(String status) {
    final cfg = _statusConfig(status);
    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        color: (cfg['color'] as Color).withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(cfg['icon'] as IconData,
          color: cfg['color'] as Color, size: 22),
    );
  }

  Map<String, dynamic> _statusConfig(String status) {
    switch (status) {
      case 'paid':
        return {'color': const Color(0xFFF59E0B),
          'icon': Icons.pending_rounded};
      case 'shipping':
        return {'color': const Color(0xFF3B82F6),
          'icon': Icons.local_shipping_rounded};
      case 'delivered':
        return {'color': const Color(0xFF16A34A),
          'icon': Icons.check_circle_rounded};
      case 'cancelled':
        return {'color': const Color(0xFFDC2626),
          'icon': Icons.cancel_rounded};
      default:
        return {'color': const Color(0xFF94A3B8),
          'icon': Icons.receipt_rounded};
    }
  }
}
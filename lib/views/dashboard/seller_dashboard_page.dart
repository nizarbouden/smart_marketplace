import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
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

  // ── Stats ────────────────────────────────────────────────────
  int    _totalProducts = 0;
  int    _totalOrders   = 0;   // tous statuts sauf cancelled
  double _totalRevenue  = 0;   // somme subtotal des subOrders delivered
  int    _pendingOrders = 0;   // statut 'paid' (en attente expédition)
  bool   _isLoading     = true;

  // ── Notifications ────────────────────────────────────────────
  int _unreadCount = 0;
  StreamSubscription<QuerySnapshot>? _notifSub;

  // ── Streams temps réel ───────────────────────────────────────
  StreamSubscription<QuerySnapshot>? _subOrdersSub;
  StreamSubscription<QuerySnapshot>? _productsSub;

  // Dernières sous-commandes pour activité récente
  List<Map<String, dynamic>> _recentSubOrders = [];

  @override
  void initState() {
    super.initState();
    _listenUnreadCount();
    _listenStats();
  }

  @override
  void dispose() {
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
  //  STREAM STATS — tout en temps réel via collectionGroup
  // ─────────────────────────────────────────────────────────────

  void _listenStats() {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    // ── 1. Produits ─────────────────────────────────────────────
    _productsSub = _firestore
        .collection('products')
        .where('sellerId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _totalProducts = snap.docs.length);
    });

    // ── 2. SubOrders → commandes + revenus + en attente ─────────
    _subOrdersSub = _firestore
        .collectionGroup('subOrders')
        .where('sellerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;

      int    totalOrders   = 0;
      double totalRevenue  = 0;
      int    pendingOrders = 0;
      final  recent        = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        final d      = doc.data();
        final status = d['status'] as String? ?? 'paid';

        // On exclut les annulées du compteur commandes
        if (status != 'cancelled') totalOrders++;

        // Revenu = sous-total des commandes livrées uniquement
        if (status == 'delivered') {
          final price = (d['price'] as num? ?? 0).toDouble();
          final qty   = (d['quantity'] as num? ?? 1).toInt();
          totalRevenue += price * qty;
        }

        // En attente = statut 'paid' (pas encore expédié)
        if (status == 'paid') pendingOrders++;

        // Activité récente — 5 dernières
        if (recent.length < 5) {
          recent.add({...d, '_docId': doc.id});
        }
      }

      setState(() {
        _totalOrders   = totalOrders;
        _totalRevenue  = totalRevenue;
        _pendingOrders = pendingOrders;
        _recentSubOrders = recent;
        _isLoading     = false;
      });
    }, onError: (_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  // ─────────────────────────────────────────────────────────────
  //  PULL TO REFRESH — inutile puisque temps réel, mais garde UX
  // ─────────────────────────────────────────────────────────────

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
                    _buildStatsGrid(t),
                    const SizedBox(height: 24),
                    _buildRecentActivity(t),
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
  //  STATS GRID — données temps réel
  // ─────────────────────────────────────────────────────────────

  Widget _buildStatsGrid(String Function(String) t) {
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
              value:   '${_totalRevenue.toStringAsFixed(2)} TND',
              color:   const Color(0xFF16A34A),
              bgColor: const Color(0xFFF0FDF4),
            ),
            _buildStatCard(
              icon:    Icons.pending_actions_rounded,
              label:   t('seller_stat_pending'),
              value:   '$_pendingOrders',
              color:   const Color(0xFFF59E0B),
              bgColor: const Color(0xFFFFFBEB),
              // badge rouge si commandes en attente
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
              // Indicateur point rouge si badge actif
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
  //  ACTIVITÉ RÉCENTE — depuis _recentSubOrders (temps réel)
  // ─────────────────────────────────────────────────────────────

  Widget _buildRecentActivity(String Function(String) t) {
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
            // Indicateur temps réel
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
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10),
              ],
            ),
            child: Center(
              child: Column(children: [
                Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(t('seller_no_orders_yet'),
                    style:
                    TextStyle(color: Colors.grey[500], fontSize: 14)),
              ]),
            ),
          )
        else
          ...(_recentSubOrders.map((data) => _buildSubOrderTile(data, t))),
      ],
    );
  }

  Widget _buildSubOrderTile(
      Map<String, dynamic> data, String Function(String) t) {
    final status   = data['status']   as String? ?? 'paid';
    final name     = data['name']     as String? ?? '—';
    final price    = (data['price']   as num?    ?? 0).toDouble();
    final qty      = (data['quantity'] as num?   ?? 1).toInt();
    final total    = price * qty;
    final rawId    = data['_docId']   as String? ?? '';
    final shortId  = rawId.length >= 8
        ? rawId.substring(0, 8).toUpperCase()
        : rawId.toUpperCase();

    // Image produit (base64)
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
      } catch (_) {
        leading = _tileImagePlaceholder(status);
      }
    } else {
      leading = _tileImagePlaceholder(status);
    }

    // Config statut
    final cfg = _statusConfig(status);
    final Color statusColor = cfg['color'] as Color;
    final IconData statusIcon = cfg['icon'] as IconData;

    // Date
    String dateStr = '—';
    final ts = data['createdAt'];
    if (ts is Timestamp) {
      final d = ts.toDate();
      dateStr = '${d.day.toString().padLeft(2,'0')}/'
          '${d.month.toString().padLeft(2,'0')}/'
          '${d.year}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Row(children: [
        // Image ou icône statut
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF1E293B))),
              const SizedBox(height: 2),
              Row(children: [
                Text('#$shortId',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[400])),
                const SizedBox(width: 6),
                Text('• $dateStr',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[400])),
              ]),
              const SizedBox(height: 3),
              // Badge statut inline
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

        // Total
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${total.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF16A34A))),
          Text('TND',
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
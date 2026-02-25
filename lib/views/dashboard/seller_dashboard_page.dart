import 'dart:async';
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

  int    _totalProducts = 0;
  int    _totalOrders   = 0;
  double _totalRevenue  = 0;
  int    _pendingOrders = 0;
  bool   _isLoading     = true;
  int    _unreadCount   = 0;

  StreamSubscription<QuerySnapshot>? _notifSub; // ✅ stream temps réel

  @override
  void initState() {
    super.initState();
    _loadStats();
    _listenUnreadCount(); // ✅ écoute en continu
  }

  @override
  void dispose() {
    _notifSub?.cancel(); // ✅ arrêter le stream
    super.dispose();
  }

  // ✅ Stream temps réel → badge mis à jour instantanément
  void _listenUnreadCount() {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    _notifSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _unreadCount = snap.docs.length);
    });
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final uid = _currentUser?.uid;
      if (uid == null) return;

      final products = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: uid)
          .get();

      final orders = await _firestore
          .collection('orders')
          .where('sellerId', isEqualTo: uid)
          .get();

      final pending = await _firestore
          .collection('orders')
          .where('sellerId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .get();

      double revenue = 0;
      for (final doc in orders.docs) {
        revenue += (doc.data()['totalPrice'] as num? ?? 0).toDouble();
      }

      setState(() {
        _totalProducts = products.docs.length;
        _totalOrders   = orders.docs.length;
        _totalRevenue  = revenue;
        _pendingOrders = pending.docs.length;
        _isLoading     = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _reload() => _loadStats();
  // ✅ pas besoin de recharger les notifs au pull-to-refresh : le stream s'en charge

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    String _t(String key) => lang.translate(key);

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: RefreshIndicator(
        color: const Color(0xFF16A34A),
        onRefresh: _reload,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(_t),
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
                    _buildWelcomeCard(_t),
                    const SizedBox(height: 24),
                    _buildStatsGrid(_t),
                    const SizedBox(height: 24),
                    _buildRecentActivitySection(_t),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(String Function(String) _t) {
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
        title: Text(
          _t('seller_dashboard_title'),
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: _openNotifications,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_rounded,
                    color: Colors.white, size: 30),
                if (_unreadCount > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      constraints: const BoxConstraints(
                          minWidth: 18, minHeight: 18),
                      child: Text(
                        _unreadCount > 99 ? '99+' : '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard(String Function(String) _t) {
    final name = _currentUser?.displayName ?? _t('seller_default_name');
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
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_t('seller_welcome')}, $name 👋',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _t('seller_welcome_subtitle'),
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(String Function(String) _t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('seller_stats_title'),
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B)),
        ),
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
              icon: Icons.inventory_2_rounded,
              label: _t('seller_stat_products'),
              value: '$_totalProducts',
              color: const Color(0xFF3B82F6),
              bgColor: const Color(0xFFEFF6FF),
            ),
            _buildStatCard(
              icon: Icons.receipt_long_rounded,
              label: _t('seller_stat_orders'),
              value: '$_totalOrders',
              color: const Color(0xFF8B5CF6),
              bgColor: const Color(0xFFF5F3FF),
            ),
            _buildStatCard(
              icon: Icons.attach_money_rounded,
              label: _t('seller_stat_revenue'),
              value: '${_totalRevenue.toStringAsFixed(2)} TND',
              color: const Color(0xFF16A34A),
              bgColor: const Color(0xFFF0FDF4),
            ),
            _buildStatCard(
              icon: Icons.pending_actions_rounded,
              label: _t('seller_stat_pending'),
              value: '$_pendingOrders',
              color: const Color(0xFFF59E0B),
              bgColor: const Color(0xFFFFFBEB),
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(label,
                  style:
                  TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection(String Function(String) _t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('seller_recent_activity'),
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('orders')
              .where('sellerId', isEqualTo: _currentUser?.uid)
              .orderBy('createdAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child:
                CircularProgressIndicator(color: Color(0xFF16A34A)),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Container(
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
                  child: Column(
                    children: [
                      Icon(Icons.inbox_rounded,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(_t('seller_no_orders_yet'),
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 14)),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildOrderTile(data, _t);
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildOrderTile(
      Map<String, dynamic> data, String Function(String) _t) {
    final status  = data['status']     as String? ?? 'pending';
    final total   = (data['totalPrice'] as num?   ?? 0).toDouble();
    final rawId   = data['orderId']    as String? ?? '';
    final orderId = rawId.length >= 8 ? rawId.substring(0, 8) : rawId;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'delivered':
        statusColor = const Color(0xFF16A34A);
        statusIcon  = Icons.check_circle_rounded;
        break;
      case 'shipping':
        statusColor = const Color(0xFF3B82F6);
        statusIcon  = Icons.local_shipping_rounded;
        break;
      case 'cancelled':
        statusColor = const Color(0xFFDC2626);
        statusIcon  = Icons.cancel_rounded;
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusIcon  = Icons.pending_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#$orderId...',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1E293B)),
                ),
                Text(
                  _t('seller_order_status_$status'),
                  style: TextStyle(fontSize: 12, color: statusColor),
                ),
              ],
            ),
          ),
          Text(
            '${total.toStringAsFixed(2)} TND',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF16A34A)),
          ),
        ],
      ),
    );
  }
}
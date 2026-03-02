import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';

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
  List<Map<String, dynamic>> _orders = [];
  late AnimationController _animController;

  String _t(String key) => AppLocalizations.get(key);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    loadOrders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadOrders();
    }
  }
  Future<void> loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      final snap = await _firestore
          .collection('users').doc(uid)
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .get();
      setState(() => _orders = snap.docs.map((d) => d.data()).toList());
      _animController.forward(from: 0);
    } catch (e) {
      debugPrint('❌ Erreur chargement commandes: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'delivered':
        return {
          'color':    const Color(0xFF16A34A),
          'bg':       const Color(0xFFDCFCE7),
          'icon':     Icons.check_circle_rounded,
          'label':    _t('status_delivered'),
        };
      case 'shipping':
        return {
          'color':    const Color(0xFF2563EB),
          'bg':       const Color(0xFFDBEAFE),
          'icon':     Icons.local_shipping_rounded,
          'label':    _t('status_shipping'),
        };
      case 'cancelled':
        return {
          'color':    const Color(0xFFDC2626),
          'bg':       const Color(0xFFFEE2E2),
          'icon':     Icons.cancel_rounded,
          'label':    _t('status_cancelled'),
        };
      case 'paid':
        return {
          'color':    const Color(0xFF7C3AED),
          'bg':       const Color(0xFFEDE9FE),
          'icon':     Icons.payments_rounded,
          'label':    _t('status_paid'),
        };
      default:
        return {
          'color':    const Color(0xFFD97706),
          'bg':       const Color(0xFFFEF3C7),
          'icon':     Icons.pending_rounded,
          'label':    _t('status_pending'),
        };
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_selectedFilter == 'all') return _orders;
    return _orders.where((o) => o['status'] == _selectedFilter).toList();
  }

  // ── Compteur par statut ───────────────────────────────────────
  int _countByStatus(String status) {
    if (status == 'all') return _orders.length;
    return _orders.where((o) => o['status'] == status).length;
  }

  @override
  Widget build(BuildContext context) {
    final sw       = MediaQuery.of(context).size.width;
    final isTablet = sw > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: NotificationListener<ScrollNotification>(
        // ✅ Pull-to-refresh via scroll au-delà du top
        onNotification: (_) => false,
        child: RefreshIndicator(
          onRefresh:loadOrders,
          color: const Color(0xFF7C3AED),
          strokeWidth: 2.5,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ✅ Stats bar
              SliverToBoxAdapter(child: _buildStatsBar(isTablet)),
              // ✅ Filtres
              SliverToBoxAdapter(child: _buildFilters(isTablet)),
              // ✅ Contenu
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF7C3AED)),
                  ),
                )
              else if (_filteredOrders.isEmpty)
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
                              (i / _filteredOrders.length) * 0.6,
                              ((i + 1) / _filteredOrders.length) * 0.6 + 0.4,
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
                          child: _buildOrderCard(
                              _filteredOrders[i], isTablet),
                        );
                      },
                      childCount: _filteredOrders.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stats bar ─────────────────────────────────────────────────
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
          final bg     = config['bg'] as Color;
          final count  = _countByStatus(s['status'] as String);

          return Expanded(
            child: GestureDetector(
              onTap: () =>
                  setState(() => _selectedFilter = s['status'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 4),
                decoration: BoxDecoration(
                  color: _selectedFilter == s['status'] ? color : bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedFilter == s['status']
                        ? color
                        : color.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      s['icon'] as IconData,
                      size: 22,
                      color: _selectedFilter == s['status']
                          ? Colors.white
                          : color,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _selectedFilter == s['status']
                            ? Colors.white
                            : color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Filtres ───────────────────────────────────────────────────
  Widget _buildFilters(bool isTablet) {
    final filters = [
      {'key': 'all',       'label': '${_t('filter_all')} (${_orders.length})'},
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
            final config   = _getStatusConfig(f['key']!);
            final color    = f['key'] == 'all'
                ? const Color(0xFF7C3AED)
                : config['color'] as Color;

            return GestureDetector(
              onTap: () =>
                  setState(() => _selectedFilter = f['key']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 18 : 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive ? color : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isActive
                      ? [BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3))]
                      : null,
                ),
                child: Text(
                  f['label']!,
                  style: TextStyle(
                    fontSize: isTablet ? 13 : 12,
                    fontWeight: isActive
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: isActive
                        ? Colors.white
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Carte commande ────────────────────────────────────────────
  Widget _buildOrderCard(Map<String, dynamic> order, bool isTablet) {
    final status    = order['status'] as String? ?? 'pending';
    final config    = _getStatusConfig(status);
    final color     = config['color'] as Color;
    final bg        = config['bg'] as Color;
    final icon      = config['icon'] as IconData;
    final label     = config['label'] as String;
    final total     = (order['total'] as num?)?.toDouble() ?? 0.0;
    final createdAt = (order['createdAt'] as Timestamp?)?.toDate();
    final rawId     = order['id'] as String? ?? '';
    final orderId   = rawId.length >= 8
        ? rawId.substring(0, 8).toUpperCase()
        : rawId.toUpperCase();
    final items     = List<Map<String, dynamic>>.from(
        order['items'] ?? []);

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 20 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── En-tête coloré ────────────────────────────────────
          Container(
            padding: EdgeInsets.all(isTablet ? 18 : 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: isTablet ? 44 : 38,
                  height: isTablet ? 44 : 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      size: isTablet ? 22 : 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#$orderId',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: isTablet ? 15 : 13,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          '${createdAt.day.toString().padLeft(2, '0')}/'
                              '${createdAt.month.toString().padLeft(2, '0')}/'
                              '${createdAt.year}  '
                              '${createdAt.hour.toString().padLeft(2, '0')}:'
                              '${createdAt.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                // Badge statut
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 12 : 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: isTablet ? 12 : 10,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Articles ──────────────────────────────────────────
          Padding(
            padding: EdgeInsets.all(isTablet ? 18 : 14),
            child: Column(
              children: [
                ...items.take(2).map(
                        (item) => _buildItemRow(item, isTablet)),
                if (items.length > 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const SizedBox(width: 4),
                        Icon(Icons.more_horiz,
                            size: 16, color: Colors.grey.shade400),
                        const SizedBox(width: 6),
                        Text(
                          '+ ${items.length - 2} ${_t('more_items')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 14),

                // ── Ligne séparatrice avec total ──────────────
                Container(
                  padding: EdgeInsets.all(isTablet ? 14 : 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.grey.shade100),
                  ),
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t('estimated_total'),
                            style: TextStyle(
                              fontSize: isTablet ? 12 : 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '\$${total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: isTablet ? 20 : 18,
                              color: const Color(0xFF7C3AED),
                            ),
                          ),
                        ],
                      ),
                      // Bouton détails
                      ElevatedButton.icon(
                        onPressed: () =>
                            _showOrderDetails(order, isTablet),
                        icon: const Icon(
                            Icons.receipt_long_rounded,
                            size: 16),
                        label: Text(
                          _t('details'),
                          style: TextStyle(
                            fontSize: isTablet ? 13 : 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 18 : 14,
                            vertical: isTablet ? 10 : 8,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Ligne article ─────────────────────────────────────────────
  // ── Ligne article ─────────────────────────────────────────────
  Widget _buildItemRow(Map<String, dynamic> item, bool isTablet) {
    final imageList  = List<String>.from(item['images'] ?? []);
    final imageBytes = imageList.isNotEmpty
        ? (() {
      try { return base64Decode(imageList.first); }
      catch (_) { return null; }
    })()
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // ✅ Image plus grande
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: isTablet ? 100 : 90,   // ✅ AVANT: 54/44 → APRÈS: 80/70
              height: isTablet ? 100 : 90,  // ✅ AVANT: 54/44 → APRÈS: 80/70
              color: Colors.grey.shade100,
              child: imageBytes != null
                  ? Image.memory(imageBytes, fit: BoxFit.cover)
                  : Icon(Icons.image_outlined,
                  color: Colors.grey.shade400,
                  size: isTablet ? 32 : 28), // ✅ icône aussi plus grande
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] as String? ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 14 : 13,
                    color: const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'x${item['quantity']}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '\$${(item['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom sheet détails ──────────────────────────────────────
  void _showOrderDetails(
      Map<String, dynamic> order, bool isTablet) {
    final status  = order['status'] as String? ?? 'pending';
    final config  = _getStatusConfig(status);
    final color   = config['color'] as Color;
    final bg      = config['bg'] as Color;
    final items   = List<Map<String, dynamic>>.from(
        order['items'] ?? []);
    final address =
    order['address'] as Map<String, dynamic>?;
    final total   =
        (order['total'] as num?)?.toDouble() ?? 0.0;
    final rawId   = order['id'] as String? ?? '';
    final orderId = rawId.length >= 8
        ? rawId.substring(0, 8).toUpperCase()
        : rawId.toUpperCase();
    final createdAt =
    (order['createdAt'] as Timestamp?)?.toDate();

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
            borderRadius:
            BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle + header coloré
              Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(
                    24, 12, 24, 20),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin:
                        const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.3),
                          borderRadius:
                          BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#$orderId',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            if (createdAt != null)
                              Text(
                                '${createdAt.day.toString().padLeft(2, '0')}/'
                                    '${createdAt.month.toString().padLeft(2, '0')}/'
                                    '${createdAt.year}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius:
                            BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                config['icon'] as IconData,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                config['label'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Contenu scrollable
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Articles
                    _detailSection(
                      icon: Icons.shopping_bag_rounded,
                      title: _t('my_articles'),
                      color: color,
                    ),
                    const SizedBox(height: 12),
                    ...items.map(
                            (item) => _buildItemRow(item, true)),

                    const SizedBox(height: 20),

                    // Adresse
                    if (address != null) ...[
                      _detailSection(
                        icon: Icons.location_on_rounded,
                        title: _t('delivery_address'),
                        color: color,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius:
                          BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.grey.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on,
                                color: color, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    address['contactName']
                                    as String? ??
                                        '',
                                    style: const TextStyle(
                                        fontWeight:
                                        FontWeight.w700),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    [
                                      address['street'],
                                      address['city'],
                                      address['province'],
                                      address['countryName'],
                                    ]
                                        .where((s) =>
                                    s != null &&
                                        s.toString()
                                            .isNotEmpty)
                                        .join(', '),
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors
                                            .grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Total
                    _detailSection(
                      icon: Icons.receipt_rounded,
                      title: _t('summary'),
                      color: color,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _t('estimated_total'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          Text(
                            '\$${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailSection({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  // ── État vide ─────────────────────────────────────────────────
  Widget _buildEmptyState(bool isTablet) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_outlined,
                  size: 48, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(height: 24),
            Text(
              _t('no_orders_title'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _t('no_orders_desc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ Remplacer le delegate par cette version corrigée
class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  _FilterHeaderDelegate({required this.child, this.height = 56});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: Material(
      elevation: overlapsContent ? 2 : 0,
      color: Colors.white,
      child: child,
    ));
  }

  @override double get maxExtent => height;
  @override double get minExtent => height;
  @override bool shouldRebuild(_FilterHeaderDelegate old) => old.child != child;
}
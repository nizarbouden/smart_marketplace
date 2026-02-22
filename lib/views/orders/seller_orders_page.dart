import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';

class SellerOrdersPage extends StatefulWidget {
  const SellerOrdersPage({super.key});

  @override
  State<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends State<SellerOrdersPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  String _t(String key) => AppLocalizations.get(key);
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  final List<String> _statuses = [
    'all',
    'pending',
    'shipping',
    'delivered',
    'cancelled'
  ];

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: _statuses.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16A34A),
        elevation: 0,
        title: Text(
          _t('seller_orders_title'),
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13),
          tabs: _statuses
              .map((s) => Tab(text: _t('seller_status_$s')))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children:
        _statuses.map((status) => _buildOrdersList(status)).toList(),
      ),
    );
  }

  Widget _buildOrdersList(String status) {
    Query query = _firestore
        .collection('orders')
        .where('sellerId', isEqualTo: _currentUser?.uid)
        .orderBy('createdAt', descending: true);

    if (status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF16A34A)),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_rounded,
                    size: 60, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  _t('seller_no_orders'),
                  style:
                  TextStyle(color: Colors.grey[500], fontSize: 15),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            if (isWide) {
              // Grid layout for wide screens
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate:
                const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 480,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.85,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildOrderCard(doc.id, data);
                },
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                return _buildOrderCard(doc.id, data);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildOrderCard(String docId, Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'pending';
    final total = (data['totalPrice'] as num? ?? 0).toDouble();
    final buyerName = data['buyerName'] as String? ??
        _t('seller_unknown_buyer');
    final productName = data['productName'] as String? ?? '';
    final quantity = data['quantity'] as int? ?? 1;
    final createdAt =
    (data['createdAt'] as Timestamp?)?.toDate();
    final orderId = docId.substring(0, 8).toUpperCase();
    final statusConfig = _getStatusConfig(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:
              (statusConfig['color'] as Color).withOpacity(0.06),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(statusConfig['icon'] as IconData,
                    color: statusConfig['color'] as Color, size: 18),
                const SizedBox(width: 8),
                Text(
                  '#$orderId',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E293B)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (statusConfig['color'] as Color)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _t('seller_status_$status'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusConfig['color'] as Color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderRow(Icons.person_rounded,
                    _t('seller_buyer'), buyerName),
                const SizedBox(height: 8),
                _buildOrderRow(Icons.inventory_2_rounded,
                    _t('seller_product'), productName),
                const SizedBox(height: 8),
                _buildOrderRow(Icons.numbers_rounded,
                    _t('seller_quantity'), '$quantity'),
                if (createdAt != null) ...[
                  const SizedBox(height: 8),
                  _buildOrderRow(
                    Icons.calendar_today_rounded,
                    _t('seller_order_date'),
                    '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                  ),
                ],
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _t('seller_total'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1E293B)),
                    ),
                    Text(
                      '${total.toStringAsFixed(2)} TND',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF16A34A)),
                    ),
                  ],
                ),
                if (status == 'pending') ...[
                  const SizedBox(height: 14),
                  _buildActionButtons(docId,
                      showShipping: true, showCancel: true),
                ],
                if (status == 'shipping') ...[
                  const SizedBox(height: 14),
                  _buildActionButtons(docId, showDelivered: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      String docId, {
        bool showShipping = false,
        bool showCancel = false,
        bool showDelivered = false,
      }) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        if (showShipping)
          _buildStatusButton(
            docId,
            'shipping',
            _t('seller_mark_shipping'),
            const Color(0xFF3B82F6),
            Icons.local_shipping_rounded,
          ),
        if (showCancel)
          _buildStatusButton(
            docId,
            'cancelled',
            _t('seller_cancel_order'),
            const Color(0xFFDC2626),
            Icons.cancel_rounded,
          ),
        if (showDelivered)
          SizedBox(
            width: double.infinity,
            child: _buildStatusButton(
              docId,
              'delivered',
              _t('seller_mark_delivered'),
              const Color(0xFF16A34A),
              Icons.check_circle_rounded,
            ),
          ),
      ],
    );
  }

  Widget _buildOrderRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusButton(
      String docId,
      String newStatus,
      String label,
      Color color,
      IconData icon,
      ) {
    return ElevatedButton.icon(
      onPressed: () => _updateOrderStatus(docId, newStatus),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
      icon: Icon(icon, size: 16),
      label: Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _updateOrderStatus(
      String docId, String newStatus) async {
    await _firestore.collection('orders').doc(docId).update({
      'status': newStatus,
      'updatedAt': Timestamp.now(),
    });
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'delivered':
        return {
          'color': const Color(0xFF16A34A),
          'icon': Icons.check_circle_rounded
        };
      case 'shipping':
        return {
          'color': const Color(0xFF3B82F6),
          'icon': Icons.local_shipping_rounded
        };
      case 'cancelled':
        return {
          'color': const Color(0xFFDC2626),
          'icon': Icons.cancel_rounded
        };
      default:
        return {
          'color': const Color(0xFFF59E0B),
          'icon': Icons.pending_rounded
        };
    }
  }
}
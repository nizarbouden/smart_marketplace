import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:smart_marketplace/providers/currency_provider.dart';
import 'package:smart_marketplace/providers/language_provider.dart';
import 'package:smart_marketplace/localization/app_localizations.dart'; // ✅ RTL
import 'package:smart_marketplace/views/notifications/notifications_page.dart';
import 'package:smart_marketplace/models/product_model.dart';
import 'package:smart_marketplace/views/products/buyer/Product_detail_page.dart';
import 'add_product_page.dart';

class SellerProductsPage extends StatefulWidget {
  const SellerProductsPage({super.key});

  @override
  State<SellerProductsPage> createState() => _SellerProductsPageState();
}

class _SellerProductsPageState extends State<SellerProductsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  String _translate(String key) {
    try {
      return Provider.of<LanguageProvider>(context, listen: false).translate(key);
    } catch (_) { return key; }
  }

  // ✅ RTL via AppLocalizations
  bool get _isRtl => AppLocalizations.isRtl;

  String get _d   => _translate('time_days');
  String get _h   => _translate('time_hours');
  String get _min => _translate('time_minutes');

  String _formatRemaining(Duration diff) {
    if (diff.inDays > 0) {
      final hours = diff.inHours % 24;
      return hours > 0 ? '${diff.inDays}$_d ${hours}$_h' : '${diff.inDays}$_d';
    } else if (diff.inHours > 0) {
      final minutes = diff.inMinutes % 60;
      return minutes > 0 ? '${diff.inHours}$_h ${minutes}$_min' : '${diff.inHours}$_h';
    } else {
      return '${diff.inMinutes}$_min';
    }
  }

  int  _unreadCount  = 0;
  bool _isRefreshing = false;
  int  _streamKey    = 0;
  StreamSubscription<QuerySnapshot>? _notifSub;
  StreamSubscription<User?>?         _authSub;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery  = '';
  bool   _searchActive = false;

  @override
  void initState() {
    super.initState();
    _listenUnreadCount();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _notifSub?.cancel();
        if (mounted) setState(() => _streamKey++);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _notifSub?.cancel();
    _searchCtrl.dispose();
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

  void _openNotifications() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const NotificationsPage()));

  void _goToAddProduct({String? docId, Map<String, dynamic>? existing}) =>
      Navigator.push(context,
          MaterialPageRoute(builder: (_) =>
              AddProductPage(docId: docId, existing: existing)));

  void _goToProductDetail(String docId, Map<String, dynamic> data) {
    final product = Product(
      id:              docId,
      name:            data['name']            as String? ?? '',
      price:           (data['price']          as num? ?? 0).toDouble(),
      category:        data['category']        as String? ?? '',
      description:     data['description']     as String? ?? '',
      images:          List<String>.from(data['images'] ?? []),
      isActive:        data['isActive']        as bool? ?? false,
      status:          data['status']          as String? ?? '',
      stock:           (data['stock']          as num? ?? 0).toInt(),
      sellerId:        data['sellerId']        as String? ?? '',
      discountPercent: (data['discountPercent'] as num?)?.toDouble(),
      discountEndsAt:  (data['discountEndsAt']  as Timestamp?)?.toDate(),
      initialStock:    (data['initialStock']    as num?)?.toInt(),
      hiddenAfterAt:   (data['hiddenAfterAt']   as Timestamp?)?.toDate(),
      reward: data['reward'] != null
          ? Reward.fromMap(data['reward'] as Map<String, dynamic>)
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ProductDetailPage(product: product)));
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    final isRtl = AppLocalizations.isRtl; // ✅

    return Directionality( // ✅
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: _buildAppBar(isRtl),
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          color: const Color(0xFF16A34A),
          strokeWidth: 2.5,
          displacement: 60,
          child: StreamBuilder<QuerySnapshot>(
            key: ValueKey(_streamKey),
            stream: _firestore
                .collection('products')
                .where('sellerId', isEqualTo: _currentUser?.uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !_isRefreshing) {
                return const Center(child: CircularProgressIndicator(
                    color: Color(0xFF16A34A)));
              }
              final allDocs = snapshot.data?.docs ?? [];
              final docs = _searchQuery.isEmpty
                  ? allDocs
                  : allDocs.where((doc) {
                final name = ((doc.data() as Map<String, dynamic>)['name']
                as String? ?? '').toLowerCase();
                return name.contains(_searchQuery);
              }).toList();

              if (docs.isEmpty) {
                return _searchQuery.isNotEmpty
                    ? _buildNoResultState()
                    : _buildEmptyState();
              }

              return LayoutBuilder(builder: (ctx, constraints) {
                final isWide = constraints.maxWidth >= 700;
                if (isWide) {
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 380,
                        crossAxisSpacing: 16, mainAxisSpacing: 16,
                        childAspectRatio: 0.60),
                    itemCount: docs.length,
                    itemBuilder: (_, i) => _buildProductCard(
                        docs[i].id, docs[i].data() as Map<String, dynamic>),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (_, i) => _buildProductCard(
                      docs[i].id, docs[i].data() as Map<String, dynamic>),
                );
              });
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _goToAddProduct,
          backgroundColor: const Color(0xFF16A34A),
          elevation: 6, shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isRtl) {
    return AppBar(
      backgroundColor: const Color(0xFF16A34A),
      elevation: 0,
      title: _searchActive
          ? TextField(
        controller: _searchCtrl,
        autofocus: true,
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // ✅
        style: const TextStyle(color: Colors.white, fontSize: 16),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: _translate('seller_search_products'),
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15),
          border: InputBorder.none, isDense: true,
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70, size: 22),
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
      )
          : Text(_translate('seller_products_title'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
      actions: [
        IconButton(
          icon: Icon(_searchActive ? Icons.close_rounded : Icons.search_rounded,
              color: Colors.white),
          onPressed: () => setState(() {
            _searchActive = !_searchActive;
            if (!_searchActive) { _searchCtrl.clear(); _searchQuery = ''; }
          }),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 12), // ✅
          child: GestureDetector(
            onTap: _openNotifications,
            child: Stack(clipBehavior: Clip.none, children: [
              const Icon(Icons.notifications_rounded, color: Colors.white, size: 30),
              if (_unreadCount > 0)
                PositionedDirectional(top: -5, end: -5, // ✅
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5)),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(_unreadCount > 99 ? '99+' : '$_unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildNoResultState() {
    return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
      SizedBox(height: MediaQuery.of(context).size.height * 0.65,
          child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 90, height: 90,
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.08),
                    shape: BoxShape.circle),
                child: Icon(Icons.search_off_rounded, size: 42, color: Colors.grey[400])),
            const SizedBox(height: 20),
            Text(_translate('seller_search_no_result'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B)), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('"$_searchQuery"', style: const TextStyle(fontSize: 14,
                color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_translate('seller_search_no_result_hint'),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                textAlign: TextAlign.center),
          ]))),
    ]);
  }

  Widget _buildEmptyState() {
    return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
      SizedBox(height: MediaQuery.of(context).size.height * 0.72,
          child: Center(child: Padding(padding: const EdgeInsets.all(40),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 110, height: 110,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [
                      const Color(0xFF16A34A).withOpacity(0.15),
                      const Color(0xFF22C55E).withOpacity(0.08)
                    ]), shape: BoxShape.circle),
                    child: const Icon(Icons.inventory_2_rounded, size: 52,
                        color: Color(0xFF16A34A))),
                const SizedBox(height: 24),
                Text(_translate('seller_no_products'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B)), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(_translate('seller_no_products_subtitle'),
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    textAlign: TextAlign.center),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _goToAddProduct,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(_translate('seller_add_first_product'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ])))),
    ]);
  }

  Widget _buildProductCard(String docId, Map<String, dynamic> data) {
    final name         = data['name']     as String? ?? '';
    final price        = (data['price']   as num? ?? 0).toDouble();
    final stock        = (data['stock']   as num? ?? 0).toInt();
    final initialStock = (data['initialStock'] as num?)?.toInt();
    final isActive     = data['isActive'] as bool? ?? false;
    final status       = data['status']   as String? ?? 'pending';
    final hasReward    = data['reward']   != null;

    final discountPct  = (data['discountPercent'] as num?)?.toDouble();
    final discountEnds = (data['discountEndsAt']  as Timestamp?)?.toDate();
    final hasDiscount  = discountPct != null && discountPct > 0 &&
        (discountEnds == null || DateTime.now().isBefore(discountEnds));

    final hiddenAfterAt = (data['hiddenAfterAt'] as Timestamp?)?.toDate();
    final hasHideTimer  = hiddenAfterAt != null && DateTime.now().isBefore(hiddenAfterAt);

    final images    = (data['images'] as List<dynamic>?)?.map((e) => e.toString()).toList();
    final legacyUrl = data['imageUrl'] as String?;

    Color statusColor; IconData statusIcon; String statusLabel;
    if (status == 'pending') {
      statusColor = const Color(0xFFF59E0B); statusIcon = Icons.access_time_rounded;
      statusLabel = _translate('seller_product_pending');
    } else if (status == 'rejected') {
      statusColor = const Color(0xFFEF4444); statusIcon = Icons.cancel_rounded;
      statusLabel = _translate('seller_product_rejected');
    } else {
      statusColor = isActive ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24);
      statusIcon  = isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded;
      statusLabel = isActive ? _translate('seller_product_active') : _translate('seller_product_inactive');
    }

    final currency = context.watch<CurrencyProvider>();

    return GestureDetector(
      onTap: () => _goToProductDetail(docId, data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07),
                blurRadius: 20, offset: const Offset(0, 6))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(height: 190, width: double.infinity,
                    child: _buildHeroImage(images, legacyUrl))),
            Positioned(bottom: 0, left: 0, right: 0,
                child: Container(height: 90,
                    decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        gradient: LinearGradient(begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.6)])))),
            // ✅ Badge prix — start
            PositionedDirectional(bottom: 12, start: 12,
                child: _buildPriceBadge(price, hasDiscount, discountPct, currency)),
            // ✅ Badge statut — end
            PositionedDirectional(top: 10, end: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(statusIcon, color: statusColor, size: 11),
                    const SizedBox(width: 4),
                    Text(statusLabel, style: TextStyle(color: statusColor,
                        fontSize: 10, fontWeight: FontWeight.bold)),
                  ]),
                )),
            // ✅ Badges reward/discount/timer — start
            PositionedDirectional(top: 10, start: 10,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (hasReward) _buildBadge(icon: Icons.card_giftcard_rounded,
                      label: _translate('seller_reward_label'), color: const Color(0xFFF59E0B)),
                  if (hasDiscount) ...[
                    if (hasReward) const SizedBox(height: 4),
                    _buildBadge(label: '-${discountPct!.toStringAsFixed(0)}%',
                        color: const Color(0xFFEF4444)),
                  ],
                  if (hasHideTimer) ...[
                    if (hasReward || hasDiscount) const SizedBox(height: 4),
                    _buildHideTimerBadge(hiddenAfterAt!),
                  ],
                ])),
            // ✅ Badge nb photos — end
            if (images != null && images.length > 1)
              PositionedDirectional(bottom: 12, end: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.photo_library_rounded, color: Colors.white, size: 11),
                      const SizedBox(width: 3),
                      Text('${images.length}', style: const TextStyle(
                          color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                    ]),
                  )),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
                  color: Color(0xFF1E293B), height: 1.2),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              _buildStockProgressBar(stock, initialStock),
              if (hasHideTimer) ...[
                const SizedBox(height: 10),
                _buildHideTimerInfoRow(hiddenAfterAt!),
              ],
              if (hasDiscount && discountEnds != null) ...[
                const SizedBox(height: 8),
                _buildDiscountEndRow(discountEnds),
              ],
              const SizedBox(height: 12),
              Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.1)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _actionBtn(label: _translate('edit'),
                    icon: Icons.edit_rounded, color: const Color(0xFF3B82F6),
                    onTap: () => _goToAddProduct(docId: docId, existing: data))),
                const SizedBox(width: 8),
                _iconBtn(
                  icon: status == 'pending' ? Icons.hourglass_empty_rounded
                      : status == 'rejected' ? Icons.block_rounded
                      : isActive ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: status == 'pending' ? const Color(0xFFF59E0B)
                      : status == 'rejected' ? const Color(0xFFDC2626)
                      : isActive ? const Color(0xFFF59E0B) : const Color(0xFF16A34A),
                  onTap: status == 'approved'
                      ? () => _toggleStatus(docId, !isActive)
                      : () => _showStatusInfo(status),
                ),
                const SizedBox(width: 8),
                _iconBtn(icon: Icons.delete_rounded, color: const Color(0xFFEF4444),
                    onTap: () => _confirmDelete(docId)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildPriceBadge(double price, bool hasDiscount,
      double? discountPct, CurrencyProvider currency) {
    if (!hasDiscount) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: const Color(0xFF16A34A),
            borderRadius: BorderRadius.circular(12)),
        child: Text(currency.formatPrice(price), style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      );
    }
    final newPrice = price * (1 - discountPct! / 100);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(currency.formatPrice(price), style: const TextStyle(fontSize: 10,
            color: Colors.white60, decoration: TextDecoration.lineThrough,
            decorationColor: Colors.white60)),
        Text(currency.formatPrice(newPrice), style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }

  Widget _buildBadge({IconData? icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 10, color: Colors.white), const SizedBox(width: 3)],
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white,
            fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildHideTimerBadge(DateTime hiddenAfterAt) {
    final diff = hiddenAfterAt.difference(DateTime.now());
    final isUrgent = diff.inHours < 24;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFFF97316),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.timer_off_rounded, size: 10, color: Colors.white),
        const SizedBox(width: 3),
        Text(_formatRemaining(diff), style: const TextStyle(fontSize: 10,
            color: Colors.white, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildStockProgressBar(int stock, int? initialStock) {
    final max = (initialStock != null && initialStock > 0)
        ? initialStock : (stock > 0 ? stock : 1);
    final ratio = (stock / max).clamp(0.0, 1.0);
    Color barColor;
    if (stock == 0)       barColor = const Color(0xFFEF4444);
    else if (ratio < 0.3) barColor = const Color(0xFFF97316);
    else if (ratio < 0.6) barColor = const Color(0xFFF59E0B);
    else                  barColor = const Color(0xFF16A34A);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Icon(stock == 0 ? Icons.remove_circle_outline_rounded : Icons.layers_rounded,
              size: 12, color: barColor),
          const SizedBox(width: 4),
          Text('${_translate('seller_stock')}: $stock',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: barColor)),
        ]),
        Text('${(ratio * 100).toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: ratio, minHeight: 7,
              backgroundColor: barColor.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(barColor))),
    ]);
  }

  Widget _buildHideTimerInfoRow(DateTime hiddenAfterAt) {
    final diff = hiddenAfterAt.difference(DateTime.now());
    final isUrgent = diff.inHours < 24;
    final mainColor = isUrgent ? const Color(0xFFDC2626) : const Color(0xFFC2410C);
    final iconColor = isUrgent ? const Color(0xFFEF4444) : const Color(0xFFF97316);
    // ✅ Ordre texte RTL-aware
    final label = _isRtl
        ? '${_formatRemaining(diff)} ${_translate('seller_hidden_in')}'
        : '${_translate('seller_hidden_in')} ${_formatRemaining(diff)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: isUrgent ? const Color(0xFFFFF1F2) : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isUrgent ? const Color(0xFFFFCDD2) : const Color(0xFFFED7AA))),
      child: Row(children: [
        Icon(Icons.timer_off_rounded, size: 13, color: iconColor),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: TextStyle(fontSize: 11, color: mainColor,
            fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _buildDiscountEndRow(DateTime endsAt) {
    final diff     = endsAt.difference(DateTime.now());
    final isUrgent = diff.inDays <= 3;
    final mainColor = isUrgent ? const Color(0xFFDC2626) : const Color(0xFFC2410C);
    final subColor  = isUrgent ? const Color(0xFFEF4444) : const Color(0xFFF97316);
    final remaining = _formatRemaining(diff);
    final dateStr   = '${endsAt.day.toString().padLeft(2,'0')}/'
        '${endsAt.month.toString().padLeft(2,'0')}/${endsAt.year}';
    // ✅ Ordre texte RTL-aware
    final dateLabel    = _isRtl ? '$dateStr ${_translate('seller_discount_until')}'
        : '${_translate('seller_discount_until')} $dateStr';
    final expiresLabel = _isRtl ? '$remaining ${_translate('seller_expires_in')}'
        : '${_translate('seller_expires_in')} $remaining';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: isUrgent ? const Color(0xFFFFF1F2) : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isUrgent ? const Color(0xFFFFCDD2) : const Color(0xFFFED7AA))),
      child: Row(children: [
        Icon(Icons.local_offer_rounded, size: 13, color: subColor),
        const SizedBox(width: 6),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(dateLabel, style: TextStyle(fontSize: 11, color: mainColor,
              fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Row(children: [
            Icon(Icons.hourglass_bottom_rounded, size: 11, color: subColor),
            const SizedBox(width: 4),
            Text(expiresLabel, style: TextStyle(fontSize: 10, color: subColor,
                fontWeight: FontWeight.w500)),
          ]),
        ])),
        if (isUrgent) ...[
          const SizedBox(width: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(_translate('seller_urgent'), style: const TextStyle(
                  fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ]),
    );
  }

  Widget _buildHeroImage(List<String>? images, String? legacyUrl) {
    if (images != null && images.isNotEmpty) {
      try {
        return Image.memory(base64Decode(images.first), fit: BoxFit.cover,
            width: double.infinity, errorBuilder: (_, __, ___) => _heroPlaceholder());
      } catch (_) {}
    }
    if (legacyUrl != null) {
      return Image.network(legacyUrl, fit: BoxFit.cover, width: double.infinity,
          errorBuilder: (_, __, ___) => _heroPlaceholder());
    }
    return _heroPlaceholder();
  }

  Widget _heroPlaceholder() => Container(color: const Color(0xFFF0FDF4),
      child: const Center(child: Icon(Icons.image_rounded,
          color: Color(0xFFBBF7D0), size: 52)));

  Widget _actionBtn({required String label, required IconData icon,
    required Color color, required VoidCallback onTap}) {
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque,
      child: Container(padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.2))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 14), const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ])),
    );
  }

  Widget _iconBtn({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque,
      child: Container(padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.2))),
          child: Icon(icon, color: color, size: 16)),
    );
  }

  void _showStatusInfo(String status) {
    final isPending = status == 'pending';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isPending ? Icons.access_time_rounded : Icons.cancel_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(isPending
            ? '${_translate('seller_product_pending')} — ${_translate('seller_product_pending_info')}'
            : '${_translate('seller_product_rejected')} — ${_translate('seller_product_rejected_info')}')),
      ]),
      backgroundColor: isPending ? const Color(0xFFF59E0B) : const Color(0xFFDC2626),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _toggleStatus(String docId, bool isActive) async {
    await _firestore.collection('products').doc(docId).update({'isActive': isActive});
  }

  void _confirmDelete(String docId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext ctx) => Directionality( // ✅ dialog aussi
        textDirection: _isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Dialog(
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 20,
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFFF87171)])),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(padding: const EdgeInsets.all(28),
                  child: Container(width: 70, height: 70,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2)),
                      child: const Icon(Icons.delete_rounded, color: Colors.white, size: 32))),
              Container(width: double.infinity, padding: const EdgeInsets.all(28),
                  decoration: const BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24))),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_translate('seller_delete_product_title'), style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626), letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    Text(_translate('seller_delete_product_confirm'), style: const TextStyle(
                        fontSize: 16, color: Color(0xFF64748B), height: 1.4),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 28),
                    Row(children: [
                      Expanded(child: SizedBox(height: 48,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16))),
                            child: Text(_translate('cancel'), style: const TextStyle(
                                color: Color(0xFFDC2626), fontSize: 15, fontWeight: FontWeight.w600)),
                          ))),
                      const SizedBox(width: 12),
                      Expanded(child: SizedBox(height: 48,
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await _firestore.collection('products').doc(docId).delete();
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                shadowColor: const Color(0xFFDC2626).withOpacity(0.3),
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16))),
                            child: FittedBox(child: Text(_translate('delete'), style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600))),
                          ))),
                    ]),
                  ])),
            ]),
          ),
        ),
      ),
    );
  }
}
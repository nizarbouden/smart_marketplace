import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:smart_marketplace/providers/language_provider.dart';
import 'package:smart_marketplace/views/notifications/notifications_page.dart';
import 'add_product_page.dart';

class SellerProductsPage extends StatefulWidget {
  const SellerProductsPage({super.key});

  @override
  State<SellerProductsPage> createState() => _SellerProductsPageState();
}

class _SellerProductsPageState extends State<SellerProductsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  int  _unreadCount  = 0;
  bool _isRefreshing = false;
  int  _streamKey    = 0; // incrémenter pour forcer le reload du stream
  StreamSubscription<QuerySnapshot>? _notifSub;

  // ── Recherche ────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool   _searchActive = false;

  @override
  void initState() {
    super.initState();
    _listenUnreadCount();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

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

  // ── Pull-to-refresh ─────────────────────────────────────────
  Future<void> _onRefresh() async {
    setState(() {
      _isRefreshing = true;
      _streamKey++;
    });
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _isRefreshing = false);
  }

  void _openNotifications() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const NotificationsPage()));
  }

  void _goToAddProduct({String? docId, Map<String, dynamic>? existing}) {
    Navigator.push(context,
        MaterialPageRoute(
            builder: (_) => AddProductPage(docId: docId, existing: existing)));
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    String t(String key) => lang.translate(key);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildAppBar(t),
      body: RefreshIndicator(
        onRefresh:    _onRefresh,
        color:        const Color(0xFF16A34A),
        strokeWidth:  2.5,
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
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF16A34A)),
              );
            }
            final allDocs = snapshot.data?.docs ?? [];

            // ── Filtre par nom (client-side) ─────────────────
            final docs = _searchQuery.isEmpty
                ? allDocs
                : allDocs.where((doc) {
              final name = ((doc.data()
              as Map<String, dynamic>)['name'] as String? ??
                  '').toLowerCase();
              return name.contains(_searchQuery);
            }).toList();

            if (docs.isEmpty) {
              return _searchQuery.isNotEmpty
                  ? _buildNoResultState(t)
                  : _buildEmptyState(t);
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
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (_, i) => _buildProductCard(
                      docs[i].id,
                      docs[i].data() as Map<String, dynamic>, t),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (_, i) => _buildProductCard(
                    docs[i].id,
                    docs[i].data() as Map<String, dynamic>, t),
              );
            });
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToAddProduct,
        backgroundColor: const Color(0xFF16A34A),
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(String Function(String) t) {
    return AppBar(
      backgroundColor: const Color(0xFF16A34A),
      elevation: 0,
      title: _searchActive
      // ── Mode recherche : champ texte ────────────────────
          ? TextField(
        controller:  _searchCtrl,
        autofocus:   true,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText:  t('seller_search_products'),
          hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.6), fontSize: 15),
          border:      InputBorder.none,
          isDense:     true,
          prefixIcon:  const Icon(Icons.search_rounded,
              color: Colors.white70, size: 22),
          prefixIconConstraints:
          const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        onChanged: (v) =>
            setState(() => _searchQuery = v.trim().toLowerCase()),
      )
      // ── Mode normal : titre ──────────────────────────────
          : Text(t('seller_products_title'),
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20)),
      actions: [
        // Bouton loupe / fermer recherche
        IconButton(
          icon: Icon(
            _searchActive ? Icons.close_rounded : Icons.search_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _searchActive = !_searchActive;
              if (!_searchActive) {
                _searchCtrl.clear();
                _searchQuery = '';
              }
            });
          },
        ),
        // Cloche notifications
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

  // ── No result state (recherche sans résultat) ─────────────────

  Widget _buildNoResultState(String Function(String) t) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.search_off_rounded,
                      size: 42, color: Colors.grey[400]),
                ),
                const SizedBox(height: 20),
                Text(
                  t('seller_search_no_result'),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '"$_searchQuery"',
                  style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  t('seller_search_no_result_hint'),
                  style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Empty state ─────────────────────────────────────────────

  Widget _buildEmptyState(String Function(String) t) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        const Color(0xFF16A34A).withOpacity(0.15),
                        const Color(0xFF22C55E).withOpacity(0.08),
                      ]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.inventory_2_rounded,
                        size: 52, color: Color(0xFF16A34A)),
                  ),
                  const SizedBox(height: 24),
                  Text(t('seller_no_products'),
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B)),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Text(t('seller_no_products_subtitle'),
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 14),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _goToAddProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(t('seller_add_first_product'),
                        style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // PRODUCT CARD — Design vertical moderne
  // ══════════════════════════════════════════════════════════════

  Widget _buildProductCard(
      String docId, Map<String, dynamic> data, String Function(String) t) {
    final name      = data['name']     as String? ?? '';
    final price     = (data['price']   as num?    ?? 0).toDouble();
    final stock     = data['stock']    as int?    ?? 0;
    final isActive  = data['isActive'] as bool?   ?? false;
    final status    = data['status']   as String? ?? 'pending';
    final hasReward = data['reward']   != null;

    final images    = (data['images'] as List<dynamic>?)
        ?.map((e) => e.toString()).toList();
    final legacyUrl = data['imageUrl'] as String?;

    // Config statut
    Color  statusColor;
    IconData statusIcon;
    String statusLabel;
    if (status == 'pending') {
      statusColor = const Color(0xFFF59E0B);
      statusIcon  = Icons.access_time_rounded;
      statusLabel = t('seller_product_pending');
    } else if (status == 'rejected') {
      statusColor = const Color(0xFFEF4444);
      statusIcon  = Icons.cancel_rounded;
      statusLabel = t('seller_product_rejected');
    } else {
      statusColor = isActive
          ? const Color(0xFF4ADE80)
          : const Color(0xFFFBBF24);
      statusIcon  = isActive
          ? Icons.check_circle_rounded
          : Icons.pause_circle_rounded;
      statusLabel = isActive
          ? t('seller_product_active')
          : t('seller_product_inactive');
    }

    // Stock color
    Color stockColor;
    if (stock == 0)       stockColor = const Color(0xFFEF4444);
    else if (stock < 5)   stockColor = const Color(0xFFF59E0B);
    else                  stockColor = const Color(0xFF16A34A);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Zone image avec overlays ───────────────────────
          Stack(
            children: [
              // Image hero
              ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: _buildHeroImage(images, legacyUrl),
                ),
              ),

              // Gradient sombre bas → lisibilité prix
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                  ),
                ),
              ),

              // Prix bas gauche
              Positioned(
                bottom: 12, left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${price.toStringAsFixed(2)} TND',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

              // Badge statut haut droite (sur fond semi-transparent)
              Positioned(
                top: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 11),
                      const SizedBox(width: 4),
                      Text(statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          )),
                    ],
                  ),
                ),
              ),

              // Badge reward haut gauche
              if (hasReward)
                Positioned(
                  top: 10, left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.card_giftcard_rounded,
                            size: 11, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(t('seller_reward_label'),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            )),
                      ],
                    ),
                  ),
                ),

              // Nombre d'images si > 1
              if (images != null && images.length > 1)
                Positioned(
                  bottom: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_library_rounded,
                            color: Colors.white, size: 11),
                        const SizedBox(width: 3),
                        Text('${images.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // ── Info + actions ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Nom produit
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 10),

                // Stock pill
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: stockColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: stockColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            stock == 0
                                ? Icons.remove_circle_outline_rounded
                                : Icons.layers_rounded,
                            size: 12,
                            color: stockColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${t('seller_stock')}: $stock',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: stockColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Séparateur
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.grey.withOpacity(0.1),
                ),
                const SizedBox(height: 12),

                // ── Boutons actions ─────────────────────────
                Row(
                  children: [
                    // Modifier — texte + icône
                    Expanded(
                      child: _actionBtn(
                        label: t('seller_action_edit'),
                        icon:  Icons.edit_rounded,
                        color: const Color(0xFF3B82F6),
                        onTap: () =>
                            _goToAddProduct(docId: docId, existing: data),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Visibilité / statut
                    _iconBtn(
                      icon: status == 'pending'
                          ? Icons.hourglass_empty_rounded
                          : status == 'rejected'
                          ? Icons.block_rounded
                          : isActive
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: status == 'pending'
                          ? const Color(0xFFF59E0B)
                          : status == 'rejected'
                          ? const Color(0xFFDC2626)
                          : isActive
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF16A34A),
                      onTap: status == 'approved'
                          ? () => _toggleStatus(docId, !isActive)
                          : () => _showStatusInfo(status, t),
                    ),
                    const SizedBox(width: 8),

                    // Supprimer
                    _iconBtn(
                      icon:  Icons.delete_rounded,
                      color: const Color(0xFFEF4444),
                      onTap: () => _confirmDelete(docId, t),
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

  // ── Image hero ──────────────────────────────────────────────

  Widget _buildHeroImage(List<String>? images, String? legacyUrl) {
    if (images != null && images.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(images.first),
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) => _heroPlaceholder(),
        );
      } catch (_) {}
    }
    if (legacyUrl != null) {
      return Image.network(
        legacyUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _heroPlaceholder(),
      );
    }
    return _heroPlaceholder();
  }

  Widget _heroPlaceholder() {
    return Container(
      color: const Color(0xFFF0FDF4),
      child: const Center(
        child: Icon(Icons.image_rounded,
            color: Color(0xFFBBF7D0), size: 52),
      ),
    );
  }

  // ── Boutons ─────────────────────────────────────────────────

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  // ── Logic ────────────────────────────────────────────────────

  void _showStatusInfo(String status, String Function(String) t) {
    final isPending = status == 'pending';
    final color = isPending
        ? const Color(0xFFF59E0B) : const Color(0xFFDC2626);
    final icon = isPending
        ? Icons.access_time_rounded : Icons.cancel_rounded;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(isPending
              ? '${t('seller_product_pending')} — ${t('seller_product_pending_info')}'
              : '${t('seller_product_rejected')} — ${t('seller_product_rejected_info')}'),
        ),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _toggleStatus(String docId, bool isActive) async {
    await _firestore
        .collection('products')
        .doc(docId)
        .update({'isActive': isActive});
  }

  void _confirmDelete(String docId, String Function(String) t) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:   Text(t('seller_delete_product_title')),
        content: Text(t('seller_delete_product_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _firestore
                  .collection('products')
                  .doc(docId)
                  .delete();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            child: Text(t('delete'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
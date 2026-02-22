import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';

class SellerProductsPage extends StatefulWidget {
  const SellerProductsPage({super.key});

  @override
  State<SellerProductsPage> createState() => _SellerProductsPageState();
}

class _SellerProductsPageState extends State<SellerProductsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _t(String key) => AppLocalizations.get(key);
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16A34A),
        elevation: 0,
        title: Text(
          _t('seller_products_title'),
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
        actions: [
          IconButton(
            onPressed: () => _showAddProductSheet(context),
            icon: const Icon(Icons.add_circle_rounded,
                color: Colors.white, size: 28),
            tooltip: _t('seller_add_product'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('products')
            .where('sellerId', isEqualTo: _currentUser?.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child:
              CircularProgressIndicator(color: Color(0xFF16A34A)),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) return _buildEmptyState();

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              if (isWide) {
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 420,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildProductCard(doc.id, data);
                  },
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildProductCard(doc.id, data);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddProductSheet(context),
        backgroundColor: const Color(0xFF16A34A),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          _t('seller_add_product'),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inventory_2_rounded,
                  size: 48, color: Color(0xFF16A34A)),
            ),
            const SizedBox(height: 20),
            Text(
              _t('seller_no_products'),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _t('seller_no_products_subtitle'),
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddProductSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(_t('seller_add_first_product')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(String docId, Map<String, dynamic> data) {
    final name = data['name'] as String? ?? '';
    final price = (data['price'] as num? ?? 0).toDouble();
    final stock = data['stock'] as int? ?? 0;
    final imageUrl = data['imageUrl'] as String?;
    final isActive = data['isActive'] as bool? ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Product image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            child: imageUrl != null
                ? Image.network(
              imageUrl,
              width: 100,
              height: 110,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _buildImagePlaceholder(),
            )
                : _buildImagePlaceholder(),
          ),

          // Product info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isActive
                              ? _t('seller_product_active')
                              : _t('seller_product_inactive'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${price.toStringAsFixed(2)} TND',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_t('seller_stock')}: $stock',
                    style:
                    TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildActionBtn(
                        icon: Icons.edit_rounded,
                        color: const Color(0xFF3B82F6),
                        onTap: () => _showEditProductSheet(
                            context, docId, data),
                      ),
                      _buildActionBtn(
                        icon: isActive
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: const Color(0xFFF59E0B),
                        onTap: () =>
                            _toggleProductStatus(docId, !isActive),
                      ),
                      _buildActionBtn(
                        icon: Icons.delete_rounded,
                        color: const Color(0xFFDC2626),
                        onTap: () => _confirmDelete(docId),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 100,
      height: 110,
      color: const Color(0xFFF0FDF4),
      child: const Icon(Icons.image_rounded,
          color: Color(0xFF16A34A), size: 36),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  void _showAddProductSheet(BuildContext context) =>
      _showProductSheet(context, null, null);

  void _showEditProductSheet(
      BuildContext context, String docId, Map<String, dynamic> data) =>
      _showProductSheet(context, docId, data);

  void _showProductSheet(BuildContext context, String? docId,
      Map<String, dynamic>? existing) {
    final nameCtrl =
    TextEditingController(text: existing?['name'] as String? ?? '');
    final priceCtrl = TextEditingController(
        text: existing?['price']?.toString() ?? '');
    final stockCtrl = TextEditingController(
        text: existing?['stock']?.toString() ?? '');
    final descCtrl = TextEditingController(
        text: existing?['description'] as String? ?? '');
    final isEditing = docId != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          // Limit width on wide screens
          constraints: const BoxConstraints(maxWidth: 600),
          margin: const EdgeInsets.symmetric(horizontal: 0),
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isEditing
                      ? _t('seller_edit_product')
                      : _t('seller_add_product'),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _buildTextField(nameCtrl, _t('seller_product_name'),
                    Icons.label_rounded),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                          priceCtrl,
                          _t('seller_product_price'),
                          Icons.attach_money_rounded,
                          keyboardType: TextInputType.number),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                          stockCtrl,
                          _t('seller_product_stock'),
                          Icons.inventory_rounded,
                          keyboardType: TextInputType.number),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildTextField(
                    descCtrl,
                    _t('seller_product_description'),
                    Icons.description_rounded,
                    maxLines: 3),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _saveProduct(
                        docId: docId,
                        name: nameCtrl.text.trim(),
                        price: double.tryParse(
                            priceCtrl.text.trim()) ??
                            0,
                        stock:
                        int.tryParse(stockCtrl.text.trim()) ??
                            0,
                        description: descCtrl.text.trim(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      isEditing
                          ? _t('seller_save_changes')
                          : _t('seller_add_product'),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController ctrl,
      String hint,
      IconData icon, {
        TextInputType keyboardType = TextInputType.text,
        int maxLines = 1,
      }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon:
        Icon(icon, color: const Color(0xFF16A34A), size: 20),
        filled: true,
        fillColor: const Color(0xFFF0FDF4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: Color(0xFF16A34A), width: 1.5),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Future<void> _saveProduct({
    String? docId,
    required String name,
    required double price,
    required int stock,
    required String description,
  }) async {
    if (name.isEmpty) return;
    final uid = _currentUser?.uid;
    if (uid == null) return;

    final data = {
      'name': name,
      'price': price,
      'stock': stock,
      'description': description,
      'sellerId': uid,
      'isActive': true,
      'updatedAt': Timestamp.now(),
    };

    if (docId == null) {
      data['createdAt'] = Timestamp.now();
      await _firestore.collection('products').add(data);
    } else {
      await _firestore.collection('products').doc(docId).update(data);
    }
  }

  Future<void> _toggleProductStatus(String docId, bool isActive) async {
    await _firestore
        .collection('products')
        .doc(docId)
        .update({'isActive': isActive});
  }

  void _confirmDelete(String docId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(_t('seller_delete_product_title')),
        content: Text(_t('seller_delete_product_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel')),
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
                backgroundColor: const Color(0xFFDC2626)),
            child: Text(_t('delete'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
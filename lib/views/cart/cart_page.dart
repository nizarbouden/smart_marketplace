import 'package:flutter/material.dart';
import '../../models/cart_item.dart';
import '../../services/selection_service.dart';
import '../../localization/app_localizations.dart';

class CartPage extends StatefulWidget {
  final Function(int)? onTotalCartItemsChanged;
  final Function(int, double)? onCartSelectionChanged;

  const CartPage({super.key, this.onTotalCartItemsChanged, this.onCartSelectionChanged});

  @override
  State<CartPage> createState() => _CartPageStatefulState();
}

class _CartPageStatefulState extends State<CartPage> {
  final List<CartItem> _cartItems = [
    CartItem(
      id: '1',
      name: 'Produit A',
      vendorName: 'TechStore',
      price: 49.99,
      quantity: 2,
    ),
    CartItem(
      id: '2',
      name: 'Produit B',
      vendorName: 'TechStore',
      price: 29.99,
      quantity: 1,
    ),
    CartItem(
      id: '3',
      name: 'Produit C',
      vendorName: 'TechStore',
      price: 89.99,
      quantity: 1,
    ),
    CartItem(
      id: '4',
      name: 'Produit D',
      vendorName: 'TechStore',
      price: 39.99,
      quantity: 1,
    ),
    CartItem(
      id: '5',
      name: 'Produit E',
      vendorName: 'FashionHub',
      price: 59.99,
      quantity: 2,
    ),
  ];

  final SelectionService _selectionService = SelectionService();

  @override
  void initState() {
    super.initState();
    _selectionService.addListener(_onGlobalSelectionChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onTotalCartItemsChanged?.call(_totalCartItems);
      widget.onCartSelectionChanged?.call(_selectedItemCount, _selectedTotal);
    });
  }

  @override
  void dispose() {
    _selectionService.removeListener(_onGlobalSelectionChanged);
    super.dispose();
  }

  void _onGlobalSelectionChanged() {
    if (mounted) {
      setState(() {
        if (_selectionService.isAllSelected) {
          for (int i = 0; i < _cartItems.length; i++) {
            _cartItems[i] = _cartItems[i].copyWith(isSelected: true);
          }
        } else {
          final allWereSelected = _cartItems.every((item) => item.isSelected);
          if (allWereSelected) {
            for (int i = 0; i < _cartItems.length; i++) {
              _cartItems[i] = _cartItems[i].copyWith(isSelected: false);
            }
          }
        }
        widget.onCartSelectionChanged?.call(_selectedItemCount, _selectedTotal);
      });
    }
  }

  bool _showSummaryOverlay = false;

  Map<String, bool> get _vendorSelections {
    final vendors = <String>{};
    for (final item in _cartItems) {
      vendors.add(item.vendorName);
    }

    final selections = <String, bool>{};
    for (final vendor in vendors) {
      final vendorItems = _cartItems.where((item) => item.vendorName == vendor);
      selections[vendor] = vendorItems.every((item) => item.isSelected);
    }
    return selections;
  }

  void _toggleVendorSelection(String vendorName) {
    setState(() {
      final vendorItems = _cartItems.where((item) => item.vendorName == vendorName);
      final allSelected = vendorItems.every((item) => item.isSelected);

      for (var item in vendorItems) {
        final index = _cartItems.indexOf(item);
        _cartItems[index] = item.copyWith(isSelected: !allSelected);
      }

      final allItemsSelected = _cartItems.every((item) => item.isSelected);
      final noItemsSelected = _cartItems.every((item) => !item.isSelected);

      if (allItemsSelected) {
        _selectionService.setAllSelected(true);
      } else if (noItemsSelected) {
        _selectionService.setAllSelected(false);
      }

      widget.onCartSelectionChanged?.call(_selectedItemCount, _selectedTotal);
    });
  }

  void _toggleItemSelection(int index) {
    setState(() {
      _cartItems[index] = _cartItems[index].copyWith(
        isSelected: !_cartItems[index].isSelected,
      );

      final allItemsSelected = _cartItems.every((item) => item.isSelected);
      final noItemsSelected = _cartItems.every((item) => !item.isSelected);

      if (allItemsSelected) {
        _selectionService.setAllSelected(true);
      } else if (noItemsSelected) {
        _selectionService.setAllSelected(false);
      }

      widget.onCartSelectionChanged?.call(_selectedItemCount, _selectedTotal);
    });
  }

  bool get _isAllSelected {
    return _selectionService.isAllSelected;
  }

  void _toggleAllSelection() {
    setState(() {
      _selectionService.toggleAllSelection();
      final allSelected = _selectionService.isAllSelected;

      for (int i = 0; i < _cartItems.length; i++) {
        _cartItems[i] = _cartItems[i].copyWith(isSelected: allSelected);
      }

      widget.onCartSelectionChanged?.call(_selectedItemCount, _selectedTotal);
    });
  }

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity < 1) return;

    setState(() {
      _cartItems[index] = _cartItems[index].copyWith(quantity: newQuantity);
      widget.onCartSelectionChanged?.call(_selectedItemCount, _selectedTotal);
    });
  }

  void _removeItem(int index) {
    setState(() {
      _cartItems.removeAt(index);

      if (_cartItems.isEmpty) {
        _selectionService.setAllSelected(false);
      } else {
        final allItemsSelected = _cartItems.every((item) => item.isSelected);
        final noItemsSelected = _cartItems.every((item) => !item.isSelected);

        if (allItemsSelected) {
          _selectionService.setAllSelected(true);
        } else if (noItemsSelected) {
          _selectionService.setAllSelected(false);
        }
      }

      widget.onTotalCartItemsChanged?.call(_totalCartItems);
      widget.onCartSelectionChanged?.call(_selectedItemCount, _selectedTotal);
    });
  }

  void _toggleSummaryOverlay() {
    if (_selectedItemCount > 0) {
      setState(() {
        _showSummaryOverlay = !_showSummaryOverlay;
      });
    }
  }

  void _hideSummaryOverlay() {
    setState(() {
      _showSummaryOverlay = false;
    });
  }

  int get _selectedItemCount {
    return _cartItems.where((item) => item.isSelected).length;
  }

  int get _totalCartItems {
    return _cartItems.length;
  }

  double get _selectedTotal {
    return _cartItems
        .where((item) => item.isSelected)
        .fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  // Helper pour les textes traduits
  String _t(String key) => AppLocalizations.get(key);

  // Helper pour le texte article(s) selon la quantité
  String _articleCount(int count) {
    if (count <= 1) return '$count ${_t('article')}';
    return '$count ${_t('articles')}';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isRtl = AppLocalizations.isRtl;

    final groupedItems = <String, List<CartItem>>{};
    for (final item in _cartItems) {
      if (!groupedItems.containsKey(item.vendorName)) {
        groupedItems[item.vendorName] = [];
      }
      groupedItems[item.vendorName]!.add(item);
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Stack(
          children: [
            // Contenu principal
            Padding(
              padding: EdgeInsets.only(
                left: isTablet ? 24 : 16,
                right: isTablet ? 24 : 16,
                top: isTablet ? 30 : 20,
                bottom: 20,
              ),
              child: _cartItems.isEmpty
                  ? _buildEmptyCart(isTablet)
                  : ListView.builder(
                itemCount: groupedItems.keys.length,
                itemBuilder: (context, vendorIndex) {
                  final vendorName = groupedItems.keys.elementAt(vendorIndex);
                  final vendorItems = groupedItems[vendorName]!;
                  return _vendorSection(vendorName, vendorItems, isTablet);
                },
              ),
            ),

            // Overlay résumé
            if (_showSummaryOverlay)
              Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _hideSummaryOverlay,
                      child: Container(color: Colors.black.withOpacity(0.3)),
                    ),
                  ),
                  Positioned(
                    bottom: 140,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.5,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 20,
                            offset: Offset(0, -5),
                          ),
                        ],
                      ),
                      child: _summaryOverlayContent(),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCart(bool isTablet) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: isTablet ? 80 : 60,
            color: Colors.grey[300],
          ),
          SizedBox(height: isTablet ? 24 : 16),
          Text(
            _t('empty_cart'),
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vendorSection(String vendorName, List<CartItem> items, bool isTablet) {
    final vendorSelections = _vendorSelections;
    final isVendorSelected = vendorSelections[vendorName] ?? false;

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header vendeur
          Padding(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleVendorSelection(vendorName),
                  child: Container(
                    width: isTablet ? 24 : 20,
                    height: isTablet ? 24 : 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isVendorSelected ? Colors.deepPurple : Colors.grey[400]!,
                        width: 2,
                      ),
                      color: isVendorSelected ? Colors.deepPurple : Colors.transparent,
                    ),
                    child: isVendorSelected
                        ? Icon(Icons.check, color: Colors.white, size: isTablet ? 16 : 14)
                        : null,
                  ),
                ),
                SizedBox(width: isTablet ? 12 : 8),
                Text(
                  vendorName,
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  _articleCount(items.length),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: isTablet ? 14 : 12,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Articles
          ...items.asMap().entries.map((entry) {
            final index = _cartItems.indexOf(entry.value);
            return _cartItemCard(entry.value, index, isTablet);
          }).toList(),
        ],
      ),
    );
  }

  Widget _cartItemCard(CartItem item, int index, bool isTablet) {
    return Padding(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      child: Row(
        children: [
          // Checkbox sélection
          GestureDetector(
            onTap: () => _toggleItemSelection(index),
            child: Container(
              width: isTablet ? 24 : 20,
              height: isTablet ? 24 : 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: item.isSelected ? Colors.deepPurple : Colors.grey[400]!,
                  width: 2,
                ),
                color: item.isSelected ? Colors.deepPurple : Colors.transparent,
              ),
              child: item.isSelected
                  ? Icon(Icons.check, color: Colors.white, size: isTablet ? 16 : 14)
                  : null,
            ),
          ),

          SizedBox(width: isTablet ? 12 : 8),

          // Image produit
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: isTablet ? 100 : 80,
              height: isTablet ? 100 : 80,
              color: Colors.grey[200],
              child: Icon(Icons.image, color: Colors.grey, size: isTablet ? 40 : 30),
            ),
          ),

          SizedBox(width: isTablet ? 16 : 12),

          // Détails produit
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isTablet ? 18 : 16,
                  ),
                ),
                SizedBox(height: isTablet ? 8 : 4),
                Text(
                  '${item.price.toStringAsFixed(2)} €',
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
                SizedBox(height: isTablet ? 16 : 8),
                Row(
                  children: [
                    // Contrôle quantité
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove, size: isTablet ? 20 : 16),
                            onPressed: () => _updateQuantity(index, item.quantity - 1),
                            tooltip: _t('quantity'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: isTablet ? 12 : 8),
                            child: Text(
                              '${item.quantity}',
                              style: TextStyle(fontSize: isTablet ? 16 : 14),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add, size: isTablet ? 20 : 16),
                            onPressed: () => _updateQuantity(index, item.quantity + 1),
                            tooltip: _t('quantity'),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red, size: isTablet ? 24 : 20),
                      onPressed: () => _removeItem(index),
                      tooltip: _t('delete'),
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

  Widget _summaryOverlayContent() {
    final selectedItems = _cartItems.where((item) => item.isSelected);
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Column(
      children: [
        // Header overlay
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey, width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _t('summary'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: _hideSummaryOverlay,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 18),
                ),
              ),
            ],
          ),
        ),

        // Contenu overlay
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Photos articles
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedItems.length,
                    itemBuilder: (context, index) {
                      final item = selectedItems.elementAt(index);
                      return Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.image, color: Colors.grey, size: 40),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${item.price.toStringAsFixed(0)} €',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'x${item.quantity}',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Résumé des prix
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _summaryRowDrawer(
                        _t('cart_title'),
                        '${_selectedTotal.toStringAsFixed(2)} €',
                      ),
                      _summaryRowDrawer(
                        _t('reductions'),
                        '-${(_selectedTotal * 0.1).toStringAsFixed(2)} €',
                      ),
                      _summaryRowDrawer(
                        _t('subtotal'),
                        '${(_selectedTotal * 0.9).toStringAsFixed(2)} €',
                      ),
                      const Divider(),
                      _summaryRowDrawer(
                        _t('shipping'),
                        '5,00 €',
                        isBold: true,
                      ),
                      const SizedBox(height: 8),
                      _summaryRowDrawer(
                        _t('estimated_total'),
                        '${(_selectedTotal * 0.9 + 5.0).toStringAsFixed(2)} €',
                        isBold: true,
                        isLarge: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRowDrawer(String label, String value, {bool isBold = false, bool isLarge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isLarge ? 18 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isLarge ? 18 : 14,
              color: isLarge ? Colors.deepPurple : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
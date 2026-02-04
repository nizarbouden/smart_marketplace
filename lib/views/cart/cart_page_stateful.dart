import 'package:flutter/material.dart';
import '../../models/cart_item.dart';
import '../../services/selection_service.dart';

class CartPageStateful extends StatefulWidget {
  final Function(int)? onTotalCartItemsChanged;
  final Function(int, double)? onCartSelectionChanged;
  
  const CartPageStateful({super.key, this.onTotalCartItemsChanged, this.onCartSelectionChanged});

  @override
  State<CartPageStateful> createState() => _CartPageStatefulState();
}

class _CartPageStatefulState extends State<CartPageStateful> {
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
  
  // Service de sélection partagé
  final SelectionService _selectionService = SelectionService();

  @override
  void initState() {
    super.initState();
    // Écouter les changements de sélection du service partagé
    _selectionService.addListener(_onGlobalSelectionChanged);
    
    // Notifier le parent du nombre total d'articles et de la sélection initiale
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
        // Ne mettre à jour que si l'état global est "tout sélectionné"
        // Si c'est "false", ne rien faire pour préserver les sélections individuelles
        if (_selectionService.isAllSelected) {
          // Seulement si "Tout" est coché, on sélectionne tout
          for (int i = 0; i < _cartItems.length; i++) {
            _cartItems[i] = _cartItems[i].copyWith(isSelected: true);
          }
        }
        // Si "Tout" est décoché, on ne fait rien pour préserver les sélections existantes
        
        // Notifier le parent du changement
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
      
      // Si on désélectionne un vendeur, mettre à jour l'état global "Tout"
      if (allSelected) {
        _selectionService.setAllSelected(false);
      }
      // Si on sélectionne un vendeur, ne pas automatiquement cocher "Tout"
      // L'utilisateur doit cliquer manuellement sur "Tout" pour tout sélectionner
      
      // Notifier le parent du changement
      widget.onCartSelectionChanged?.call(_selectedItemCount, _selectedTotal);
    });
  }

  void _toggleItemSelection(int index) {
    setState(() {
      _cartItems[index] = _cartItems[index].copyWith(
        isSelected: !_cartItems[index].isSelected,
      );
      
      // Si on désélectionne un élément individuel, mettre à jour l'état global "Tout"
      if (!_cartItems[index].isSelected) {
        _selectionService.setAllSelected(false);
      }
      // Si on sélectionne un élément, ne pas automatiquement cocher "Tout"
      // L'utilisateur doit cliquer manuellement sur "Tout" pour tout sélectionner
      
      // Notifier le parent du changement
      widget.onCartSelectionChanged?.call(_selectedItemCount, _selectedTotal);
    });
  }

  bool get _isAllSelected {
    return _selectionService.isAllSelected;
  }

  void _toggleAllSelection() {
    setState(() {
      // Utiliser le service partagé pour synchroniser
      _selectionService.toggleAllSelection();
      final allSelected = _selectionService.isAllSelected;
      
      for (int i = 0; i < _cartItems.length; i++) {
        _cartItems[i] = _cartItems[i].copyWith(isSelected: allSelected);
      }
      
      // Notifier le parent du changement
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
    return _cartItems.length; // Nombre d'articles uniques, pas la somme des quantités
  }

  double get _selectedTotal {
    return _cartItems
        .where((item) => item.isSelected)
        .fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 1200;
    
    // Group items by vendor
    final groupedItems = <String, List<CartItem>>{};
    for (final item in _cartItems) {
      if (!groupedItems.containsKey(item.vendorName)) {
        groupedItems[item.vendorName] = [];
      }
      groupedItems[item.vendorName]!.add(item);
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          // Contenu principal
          Padding(
            padding: EdgeInsets.only(
              left: isTablet ? 24 : 16,
              right: isTablet ? 24 : 16,
              top: isTablet ? 30 : 20,
              bottom: 20, // Padding normal car la barre est dans la navigation
            ),
            child: ListView.builder(
              itemCount: groupedItems.keys.length,
              itemBuilder: (context, vendorIndex) {
                final vendorName = groupedItems.keys.elementAt(vendorIndex);
                final vendorItems = groupedItems[vendorName]!;
                
                return _vendorSection(vendorName, vendorItems, isTablet);
              },
            ),
          ),
          
          // Overlay pour le résumé avec effet de shadow sur le reste
          if (_showSummaryOverlay)
            Stack(
              children: [
                // Fond sombre pour l'effet de shadow
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: IgnorePointer(
                      child: Container(),
                    ),
                  ),
                ),
                
                // Contenu de l'overlay
                Positioned(
                  bottom: 140, // Juste au-dessus de la barre de total (80) + navigation (60)
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
          // Header du vendeur
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
                        ? Icon(
                            Icons.check,
                            color: Colors.white,
                            size: isTablet ? 16 : 14,
                          )
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
                  '${items.length} article${items.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: isTablet ? 14 : 12,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Articles du vendeur
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
          // Checkbox de sélection
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
                  ? Icon(
                      Icons.check,
                      color: Colors.white,
                      size: isTablet ? 16 : 14,
                    )
                  : null,
            ),
          ),
          
          SizedBox(width: isTablet ? 12 : 8),
          
          // Image du produit
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: isTablet ? 100 : 80,
              height: isTablet ? 100 : 80,
              color: Colors.grey[200],
              child: Icon(
                Icons.image,
                color: Colors.grey,
                size: isTablet ? 40 : 30,
              ),
            ),
          ),
          
          SizedBox(width: isTablet ? 16 : 12),
          
          // Détails du produit
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
                            onPressed: () {
                              // TODO: diminuer la quantité
                            },
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
                            onPressed: () {
                              // TODO: augmenter la quantité
                            },
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red, size: isTablet ? 24 : 20),
                      onPressed: () {
                        // TODO: supprimer l'article
                      },
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
    
    return Column(
      children: [
        // Header de l'overlay
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey, width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Résumé',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
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
        
        // Contenu de l'overlay
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Photos des articles
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
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
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
                      _summaryRowDrawer('Total articles', '${_selectedTotal.toStringAsFixed(2)} €'),
                      _summaryRowDrawer('Réductions', '-${(_selectedTotal * 0.1).toStringAsFixed(2)} €'),
                      _summaryRowDrawer('Sous-total', '${(_selectedTotal * 0.9).toStringAsFixed(2)} €'),
                      const Divider(),
                      _summaryRowDrawer('Livraison', '5,00 €', isBold: true),
                      const SizedBox(height: 8),
                      _summaryRowDrawer(
                        'Total estimé', 
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

import 'package:flutter/material.dart';
import '../home/home_page.dart';
import '../cart/cart_page_stateful.dart';
import '../history/history_page.dart';
import '../profile/profile_page.dart';
import '../notifications/notifications_page.dart';
import '../../services/selection_service.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _totalCartItems = 0;
  int _selectedCartItems = 0;
  double _selectedTotal = 0.0;
  bool _showNotifications = false;
  bool _showCartOverlay = false;
  
  // Service de sélection partagé
  final SelectionService _selectionService = SelectionService();
  
  // Données des produits synchronisées avec la page panier
  final List<Map<String, dynamic>> _cartProducts = [
    {'id': '1', 'name': 'Produit A', 'price': 49.99, 'quantity': 2},
    {'id': '2', 'name': 'Produit B', 'price': 29.99, 'quantity': 1},
    {'id': '3', 'name': 'Produit C', 'price': 89.99, 'quantity': 1},
    {'id': '4', 'name': 'Produit D', 'price': 39.99, 'quantity': 1},
    {'id': '5', 'name': 'Produit E', 'price': 59.99, 'quantity': 2},
  ];
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final List<Widget> _pages = [
    const HomePage(),
    CartPageStateful(
      onTotalCartItemsChanged: (totalCount) {},
      onCartSelectionChanged: (selectedCount, selectedTotal) {},
    ),
    const HistoryPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    // Écouter les changements de sélection
    _selectionService.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _selectionService.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  // Méthode pour calculer les vrais totaux du panier
  Map<String, dynamic> _calculateRealTotals() {
    if (_selectionService.isAllSelected) {
      // Calculer le total réel de tous les produits
      double total = 0.0;
      int count = 0;
      for (var product in _cartProducts) {
        total += (product['price'] as double) * (product['quantity'] as int);
        count += product['quantity'] as int;
      }
      return {'count': count, 'total': total};
    } else {
      return {'count': 0, 'total': 0.0};
    }
  }

  void _onItemTapped(int index) {
    _animationController.forward().then((_) {
      setState(() {
        _currentIndex = index;
        _showNotifications = false;
      });
      _animationController.reverse();
    });
  }

  void _toggleNotifications() {
    setState(() {
      _showNotifications = !_showNotifications;
    });
  }

  void _updateCartItemCount(int totalCount) {
    setState(() {
      _totalCartItems = totalCount;
    });
  }

  void _updateCartSelection(int selectedCount, double selectedTotal) {
    setState(() {
      _selectedCartItems = selectedCount;
      _selectedTotal = selectedTotal;
    });
  }

  void _toggleCartOverlay() {
    setState(() {
      _showCartOverlay = !_showCartOverlay;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Header fixe
              SafeArea(
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        _getAppBarTitle(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Stack(
                        children: [
                          IconButton(
                            icon: Icon(
                              _showNotifications ? Icons.close : Icons.notifications,
                              color: Colors.black,
                            ),
                            onPressed: _toggleNotifications,
                          ),
                          if (!_showNotifications)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ),
              
              // Contenu principal
              Expanded(
                child: _showNotifications 
                  ? const NotificationsPage()
                  : IndexedStack(
                      index: _currentIndex,
                      children: [
                        const HomePage(),
                        CartPageStateful(
                          onTotalCartItemsChanged: _updateCartItemCount,
                          onCartSelectionChanged: _updateCartSelection,
                        ),
                        const HistoryPage(),
                        const ProfilePage(),
                      ],
                    ),
              ),
            ],
          ),
          
          // Overlay du panier
          if (_currentIndex == 1 && _showCartOverlay)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Stack(
                  children: [
                    // Fond pour fermer l'overlay
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _toggleCartOverlay,
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                    
                    // Contenu de l'overlay
                    Positioned(
                      bottom: 161, // Juste au-dessus de la navigation panier (60px nav + 101px total bar)
                      left: 16,
                      right: 16,
                      top: 80, // Laisser de l'espace pour le header
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: _buildCartOverlayContent(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      
      // Barre de navigation inférieure fixe
      bottomNavigationBar: _currentIndex == 1 
        ? _buildCartNavigationBar() // Navigation spéciale pour panier
        : _buildDefaultNavigationBar(), // Navigation normale
    );
  }

  Widget _buildCartOverlayContent() {
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
                'Résumé du panier',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: _toggleCartOverlay,
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
                // Articles sélectionnés
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Articles sélectionnés',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      if (_calculateRealTotals()['count'] > 0)
                        Expanded(
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _cartProducts.length, // Utiliser le vrai nombre de produits
                            itemBuilder: (context, index) {
                              return _selectedItemCard(index);
                            },
                          ),
                        )
                      else
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Aucun article sélectionné',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 20),
                        
                        // Résumé des prix
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _summaryRow('Sous-total', '${_calculateRealTotals()['total'].toStringAsFixed(2)} €'),
                              _summaryRow('Livraison', '5.99 €'),
                              _summaryRow(
                                'Total',
                                '${(_calculateRealTotals()['total'] + 5.99).toStringAsFixed(2)} €',
                                isBold: true,
                                isLarge: true,
                              ),
                            ],
                          ),
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

  Widget _selectedItemCard(int index) {
    return Container(
      width: 120,
      height: 120, // Carré - juste pour la photo
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.image,
            color: Colors.grey[400],
            size: 40,
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, bool isLarge = false}) {
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

  Widget _buildDefaultNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.shopping_cart_outlined,
                activeIcon: Icons.shopping_cart,
                label: 'Panier',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.history_outlined,
                activeIcon: Icons.history,
                label: 'Historique',
                index: 2,
              ),
              _buildNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Compte',
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartNavigationBar() {
    return Container(
      height: 161, // +1 pixel pour corriger l'overflow final
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Barre de total intégrée (en haut)
          Container(
            height: 90, // Hauteur augmentée pour le contenu
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                // Cercle pour tout sélectionner
                GestureDetector(
                  onTap: () {
                    // Utiliser le service de sélection partagé
                    _selectionService.toggleAllSelection();
                    
                    // Mettre à jour la sélection dans l'overlay avec les vraies données
                    final totals = _calculateRealTotals();
                    _updateCartSelection(totals['count'], totals['total']);
                  },
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[400]!, width: 2),
                      color: _selectionService.isAllSelected ? Colors.deepPurple : null,
                    ),
                    child: _selectionService.isAllSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 12,
                          )
                        : null,
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Texte "Tout"
                const Text(
                  'Tout',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Nombre d'articles sélectionnés
                Expanded(
                  child: Text(
                    '${_calculateRealTotals()['count']} article(s)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Prix total avec flèche (uniquement si articles sélectionnés)
                if (_calculateRealTotals()['count'] > 0)
                  GestureDetector(
                    onTap: _toggleCartOverlay,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_calculateRealTotals()['total'].toStringAsFixed(2)} €',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _showCartOverlay ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                            color: Colors.deepPurple,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Text(
                    '${_selectedTotal.toStringAsFixed(2)} €',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                
                const SizedBox(width: 12),
                
                // Bouton paiement
                ElevatedButton(
                  onPressed: _selectedCartItems > 0 ? () {
                    // TODO: procéder au paiement
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedCartItems > 0 ? Colors.deepPurple : Colors.grey[300],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 40), // Hauteur minimum fixe
                  ),
                  child: Text(
                    'Paiement ($_selectedCartItems)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Barre de navigation principale (en dessous)
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      label: 'Home',
                      index: 0,
                    ),
                    _buildNavItem(
                      icon: Icons.shopping_cart_outlined,
                      activeIcon: Icons.shopping_cart,
                      label: 'Panier',
                      index: 1,
                    ),
                    _buildNavItem(
                      icon: Icons.history_outlined,
                      activeIcon: Icons.history,
                      label: 'Historique',
                      index: 2,
                    ),
                    _buildNavItem(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      label: 'Compte',
                      index: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;
    
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isActive ? activeIcon : icon,
              key: ValueKey(isActive),
              color: isActive ? Colors.deepPurple : Colors.grey[600],
              size: 24,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? Colors.deepPurple : Colors.grey[600],
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    if (_showNotifications) {
      return 'Notifications';
    }
    switch (_currentIndex) {
      case 0:
        return 'Smart Market';
      case 1:
        return 'Panier ($_totalCartItems)';
      case 2:
        return 'Historique d\'achat';
      case 3:
        return 'Mon Profil';
      default:
        return 'Smart Market';
    }
  }
}

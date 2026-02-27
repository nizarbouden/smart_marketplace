import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../widgets/filter_drawer.dart';
import '../products/buyer/Product_detail_page.dart';

// Clé globale exposée pour que le parent puisse ouvrir le drawer du filtre
final GlobalKey<HomePageState> homePageKey = GlobalKey<HomePageState>();

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final ProductService _service = ProductService();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _searchQuery = '';
  FilterOptions _filters = FilterOptions(maxPrice: 10000);
  List<Product> _allProducts = [];

  /// Appelé depuis le header parent pour ouvrir le drawer filtre
  void openFilterDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  /// Indique si des filtres sont actifs (pour le badge orange dans le header)
  bool get hasActiveFilters =>
      _filters.selectedCategory != null ||
          _filters.minPrice > 0 ||
          _filters.maxPrice < _getMaxPrice(_allProducts) ||
          _filters.sortOrder != 'none' ||
          _filters.inStockOnly;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _applyFilters(List<Product> products) {
    List<Product> result = products;

    if (_searchQuery.isNotEmpty) {
      result = result
          .where((p) =>
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    if (_filters.selectedCategory != null) {
      result = result
          .where((p) => p.category == _filters.selectedCategory)
          .toList();
    }

    result = result
        .where(
            (p) => p.price >= _filters.minPrice && p.price <= _filters.maxPrice)
        .toList();

    if (_filters.inStockOnly) {
      result = result.where((p) => p.stock > 0).toList();
    }

    if (_filters.sortOrder == 'asc') {
      result.sort((a, b) => a.price.compareTo(b.price));
    } else if (_filters.sortOrder == 'desc') {
      result.sort((a, b) => b.price.compareTo(a.price));
    }

    return result;
  }

  List<String> _getCategories(List<Product> products) {
    return products.map((p) => p.category).toSet().toList()..sort();
  }

  double _getMaxPrice(List<Product> products) {
    if (products.isEmpty) return 10000;
    return products.map((p) => p.price).reduce((a, b) => a > b ? a : b);
  }

  int _gridCrossAxisCount(double width) {
    if (width >= 1200) return 4;
    if (width >= 900) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = _gridCrossAxisCount(width);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F6FA),
      drawer: _allProducts.isEmpty
          ? null
          : FilterDrawer(
        categories: _getCategories(_allProducts),
        currentFilters: _filters,
        absoluteMaxPrice: _getMaxPrice(_allProducts),
        onApply: (newFilters) {
          setState(() => _filters = newFilters);
        },
      ),
      body: StreamBuilder<List<Product>>(
        stream: _service.getApprovedProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: Colors.red.shade300),
                  const SizedBox(height: 12),
                  Text('Erreur: ${snapshot.error}'),
                ],
              ),
            );
          }

          _allProducts = snapshot.data ?? [];
          final filtered = _applyFilters(_allProducts);

          return CustomScrollView(
            slivers: [
              // ── Search Bar ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _SearchBar(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ),

              // ── Active Filter Tags ──
              if (hasActiveFilters)
                SliverToBoxAdapter(
                  child: _ActiveFilterTags(
                    filters: _filters,
                    onClear: () => setState(() => _filters =
                        FilterOptions(maxPrice: _getMaxPrice(_allProducts))),
                  ),
                ),

              // ── Count ──
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    '${filtered.length} produit${filtered.length > 1 ? "s" : ""}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              // ── Grid ──
              filtered.isEmpty
                  ? SliverFillRemaining(
                child: _EmptyState(hasFilters: hasActiveFilters),
              )
                  : SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                        (context, i) => _ProductCard(product: filtered[i]),
                    childCount: filtered.length,
                  ),
                  gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Search Bar ───────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Rechercher un produit...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon:
          Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 22),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
            onPressed: () {
              controller.clear();
              onChanged('');
            },
            icon: Icon(Icons.clear_rounded,
                color: Colors.grey.shade400, size: 18),
          )
              : null,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ── Active Filter Tags ───────────────────────────────────────────

class _ActiveFilterTags extends StatelessWidget {
  final FilterOptions filters;
  final VoidCallback onClear;

  const _ActiveFilterTags({required this.filters, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          if (filters.selectedCategory != null)
            _Tag(label: filters.selectedCategory!),
          if (filters.sortOrder != 'none')
            _Tag(label: filters.sortOrder == 'asc' ? 'Prix ↑' : 'Prix ↓'),
          if (filters.inStockOnly) const _Tag(label: 'En stock'),
          const Spacer(),
          TextButton(
            onPressed: onClear,
            child: Text(
              'Tout effacer',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Product Card ─────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Product product;

  const _ProductCard({required this.product});

  Uint8List? _decodeImage(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    try {
      return base64Decode(base64Str);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageBytes =
    product.images.isNotEmpty ? _decodeImage(product.images.first) : null;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(product: product),
        ),
      ),
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageBytes != null
                        ? Image.memory(imageBytes, fit: BoxFit.cover)
                        : Container(
                      color: Colors.grey.shade100,
                      child: Icon(Icons.image_outlined,
                          size: 40, color: Colors.grey.shade300),
                    ),
                    if (product.stock <= 0)
                      Container(
                        color: Colors.black.withOpacity(0.45),
                        alignment: Alignment.center,
                        child: const Text(
                          'Épuisé',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (product.reward?.name != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 10, color: Colors.white),
                              const SizedBox(width: 3),
                              Text(
                                product.reward!.name!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.description,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${product.price.toStringAsFixed(2)} ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: product.stock > 0
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            product.stock > 0
                                ? '${product.stock} en stock'
                                : 'Épuisé',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: product.stock > 0
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ), // fin Container
    ); // fin GestureDetector
  }
}

// ── Empty State ──────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  const _EmptyState({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilters
                ? Icons.filter_alt_off_rounded
                : Icons.storefront_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'Aucun produit ne correspond\nà ces filtres'
                : 'Aucun produit disponible',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
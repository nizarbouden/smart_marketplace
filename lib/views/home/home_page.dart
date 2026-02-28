import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../models/product_categories.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../widgets/filter_drawer.dart';
import '../products/buyer/Product_detail_page.dart';

final GlobalKey<HomePageState> homePageKey = GlobalKey<HomePageState>();

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final ProductService _service = ProductService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final langCode = AppLocalizations.getLanguage();

  String _searchQuery = '';
  FilterOptions _filters = FilterOptions(maxPrice: 10000);
  List<Product> _allProducts = [];
  bool _productsLoading = true;
  String? _productsError;

  StreamSubscription<List<Product>>? _productsSub;

  // ✅ Helper de traduction local
  String _t(String key) => AppLocalizations.get(key);

  void openFilterDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  bool get hasActiveFilters =>
      _filters.selectedCategory != null ||
          _filters.minPrice > 0 ||
          _filters.maxPrice < _getMaxPrice(_allProducts) ||
          _filters.sortOrder != 'none' ||
          _filters.inStockOnly;

  @override
  void initState() {
    super.initState();
    _productsSub = _service.getApprovedProducts().listen(
          (products) {
        if (mounted) {
          setState(() {
            _allProducts = products;
            _productsLoading = false;
            _productsError = null;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _productsError = error.toString();
            _productsLoading = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
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
    final filtered = _applyFilters(_allProducts);

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
      body: _productsLoading
          ? const Center(child: CircularProgressIndicator())
          : _productsError != null
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            // ✅ Traduit
            Text('${_t('error_prefix')}: $_productsError'),
          ],
        ),
      )
          : CustomScrollView(
        slivers: [
          // ── Search Bar ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _SearchBar(
                controller: _searchController,
                focusNode: _searchFocusNode,
                // ✅ hint traduit passé en paramètre
                hintText: _t('search_hint'),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ),

          // ── Active Filter Tags ──
          if (hasActiveFilters)
            SliverToBoxAdapter(
              child: _ActiveFilterTags(
                filters: _filters,
                // ✅ Labels traduits passés en paramètres
                labelPriceAsc: _t('price_asc'),
                labelPriceDesc: _t('price_desc'),
                labelInStock: _t('in_stock_filter'),
                labelClearAll: _t('clear_all'),
                onClear: () => setState(() =>
                _filters = FilterOptions(maxPrice: _getMaxPrice(_allProducts))),
              ),
            ),

          // ── Count ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                // ✅ Traduit : "X produit(s)" / "X product(s)" / "X منتج/منتجات"
                '${filtered.length} ${filtered.length > 1 ? _t('products') : _t('product')}',
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
            child: _EmptyState(
              hasFilters: hasActiveFilters,
              // ✅ Messages traduits passés en paramètres
              messageWithFilters: _t('no_products_filters'),
              messageEmpty: _t('no_products'),
            ),
          )
              : SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                    (context, i) => _ProductCard(
                  product: filtered[i],
                  // ✅ Labels traduits passés au card
                  labelOutOfStock: _t('out_of_stock'),
                  labelInStock: _t('in_stock'),
                ),
                childCount: filtered.length,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search Bar ───────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  // ✅ Nouveau paramètre traduit
  final String hintText;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.hintText,
  });

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
        focusNode: focusNode,
        onChanged: onChanged,
        decoration: InputDecoration(
          // ✅ Hint traduit
          hintText: hintText,
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
  // ✅ Nouveaux paramètres traduits
  final String labelPriceAsc;
  final String labelPriceDesc;
  final String labelInStock;
  final String labelClearAll;

  const _ActiveFilterTags({
    required this.filters,
    required this.onClear,
    required this.labelPriceAsc,
    required this.labelPriceDesc,
    required this.labelInStock,
    required this.labelClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          if (filters.selectedCategory != null)
            _Tag(
              label: ProductCategories.labelFromId(
                filters.selectedCategory!,
                AppLocalizations.getLanguage(),
              ),
            ),
          // ✅ Labels traduits
          if (filters.sortOrder != 'none')
            _Tag(label: filters.sortOrder == 'asc' ? labelPriceAsc : labelPriceDesc),
          if (filters.inStockOnly) _Tag(label: labelInStock),
          const Spacer(),
          TextButton(
            onPressed: onClear,
            // ✅ Traduit
            child: Text(
              labelClearAll,
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
  // ✅ Nouveaux paramètres traduits
  final String labelOutOfStock;
  final String labelInStock;

  const _ProductCard({
    required this.product,
    required this.labelOutOfStock,
    required this.labelInStock,
  });

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

    final hasReward = product.reward != null;
    final rewardImageBytes =
    hasReward ? _decodeImage(product.reward!.image) : null;
    final rewardName = product.reward?.name;

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
            // ── Image produit + overlays ──
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

                    // ✅ "Épuisé" traduit
                    if (product.stock <= 0)
                      Container(
                        color: Colors.black.withOpacity(0.45),
                        alignment: Alignment.center,
                        child: Text(
                          labelOutOfStock,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),

                    // Badge catégorie — haut gauche
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
                          ProductCategories.labelFromId(
                            product.category,
                            AppLocalizations.getLanguage(),
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    // Reward overlay — bas de l'image
                    if (hasReward)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.amber.shade800.withOpacity(0.92),
                                Colors.amber.shade600.withOpacity(0.75),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              if (rewardImageBytes != null) ...[
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.25),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image.memory(
                                      rewardImageBytes,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ] else ...[
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.2),
                                    border: Border.all(
                                        color: Colors.white, width: 1.5),
                                  ),
                                  child: const Icon(Icons.star_rounded,
                                      size: 16, color: Colors.white),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (rewardName != null)
                                Expanded(
                                  child: Text(
                                    rewardName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black38,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              const Icon(Icons.card_giftcard_rounded,
                                  size: 16, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Infos produit ──
            Expanded(
              flex: 3,
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                      style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${product.price.toStringAsFixed(2)}',
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
                          // ✅ "en stock" / "Épuisé" traduits
                          child: Text(
                            product.stock > 0
                                ? '${product.stock} $labelInStock'
                                : labelOutOfStock,
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
      ),
    );
  }
}

// ── Empty State ──────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  // ✅ Nouveaux paramètres traduits
  final String messageWithFilters;
  final String messageEmpty;

  const _EmptyState({
    required this.hasFilters,
    required this.messageWithFilters,
    required this.messageEmpty,
  });

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
          // ✅ Traduit
          Text(
            hasFilters ? messageWithFilters : messageEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
// lib/views/home/home_page.dart
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

  String _searchQuery = '';
  FilterOptions _filters = FilterOptions(maxPrice: 10000);
  List<Product> _allProducts = [];
  bool _productsLoading = true;
  String? _productsError;

  StreamSubscription<List<Product>>? _productsSub;

  String _t(String key) => AppLocalizations.get(key);
  void openFilterDrawer() => _scaffoldKey.currentState?.openDrawer();

  bool get hasActiveFilters =>
      _filters.selectedCategory != null ||
          _filters.minPrice > 0 ||
          _filters.maxPrice < _getMaxPrice(_allProducts) ||
          _filters.sortOrder != 'none' ||
          _filters.inStockOnly;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _productsSub?.cancel();
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

  /// Appelé uniquement par pull-to-refresh
  Future<void> _onRefresh() async {
    setState(() => _productsLoading = true);
    _subscribe();
    // Attendre que les données arrivent (max 3s)
    int waited = 0;
    while (_productsLoading && waited < 30) {
      await Future.delayed(const Duration(milliseconds: 100));
      waited++;
    }
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<Product> _applyFilters(List<Product> products) {
    final now = DateTime.now();
    List<Product> result = products.where((p) {
      if (!p.isActive) return false;
      if (p.hiddenAfterAt != null && now.isAfter(p.hiddenAfterAt!)) return false;
      return true;
    }).toList();
    if (_searchQuery.isNotEmpty) {
      result = result
          .where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    if (_filters.selectedCategory != null) {
      result = result.where((p) => p.category == _filters.selectedCategory).toList();
    }
    result = result
        .where((p) => p.price >= _filters.minPrice && p.price <= _filters.maxPrice)
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

  List<String> _getCategories(List<Product> products) =>
      products.map((p) => p.category).toSet().toList()..sort();

  double _getMaxPrice(List<Product> products) {
    if (products.isEmpty) return 10000;
    return products.map((p) => p.price).reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilters(_allProducts);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF0F2F7),
      drawer: _allProducts.isEmpty
          ? null
          : FilterDrawer(
        categories: _getCategories(_allProducts),
        currentFilters: _filters,
        absoluteMaxPrice: _getMaxPrice(_allProducts),
        onApply: (newFilters) => setState(() => _filters = newFilters),
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
            Text('${_t('error_prefix')}: $_productsError'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFF16A34A),
        strokeWidth: 2.5,
        displacement: 60,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _SearchBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  hintText: _t('search_hint'),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ),
            if (hasActiveFilters)
              SliverToBoxAdapter(
                child: _ActiveFilterTags(
                  filters: _filters,
                  labelPriceAsc: _t('price_asc'),
                  labelPriceDesc: _t('price_desc'),
                  labelInStock: _t('in_stock_filter'),
                  labelClearAll: _t('clear_all'),
                  onClear: () => setState(
                        () => _filters = FilterOptions(maxPrice: _getMaxPrice(_allProducts)),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  '${filtered.length} ${filtered.length > 1 ? _t('products') : _t('product')}',
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
            filtered.isEmpty
                ? SliverFillRemaining(
              child: _EmptyState(
                hasFilters: hasActiveFilters,
                messageWithFilters: _t('no_products_filters'),
                messageEmpty: _t('no_products'),
              ),
            )
                : SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _ProductCard(
                      // ✅ Key stable basée sur l'id — empêche Flutter de reconstruire
                      key: ValueKey(filtered[i].id),
                      product: filtered[i],
                      labelOutOfStock: _t('out_of_stock'),
                      labelInStock: _t('in_stock'),
                      labelDiscountFlash: _t('discount_flash'),
                      labelDiscountExpires: _t('discount_expires_in'),
                      labelVisibleFor: _t('visible_for'),
                      labelUrgent: _t('urgent'),
                      labelRewardDraw: _t('reward_draw_label'),
                      labelRewardDrawSub: _t('reward_draw_sub'),
                      labelRewardBadge: _t('reward_badge'),
                      labelSavings: _t('savings_prefix'),
                    ),
                  ),
                  childCount: filtered.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search Bar ───────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        decoration: InputDecoration(
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
          if (filters.sortOrder != 'none')
            _Tag(
                label: filters.sortOrder == 'asc'
                    ? labelPriceAsc
                    : labelPriceDesc),
          if (filters.inStockOnly) _Tag(label: labelInStock),
          const Spacer(),
          TextButton(
            onPressed: onClear,
            child: Text(labelClearAll,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12)),
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
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ── Product Card ─────────────────────────────────────────────────
// ✅ Aucun timer dans la carte elle-même.
//    Les chronos (discount / hide) sont dans des sous-widgets isolés
//    qui gèrent leur propre setState sans toucher à la carte parent.

class _ProductCard extends StatelessWidget {
  final Product product;
  final String labelOutOfStock;
  final String labelInStock;
  final String labelDiscountFlash;
  final String labelDiscountExpires;
  final String labelVisibleFor;
  final String labelUrgent;
  final String labelRewardDraw;
  final String labelRewardDrawSub;
  final String labelRewardBadge;
  final String labelSavings;

  const _ProductCard({
    super.key,
    required this.product,
    required this.labelOutOfStock,
    required this.labelInStock,
    required this.labelDiscountFlash,
    required this.labelDiscountExpires,
    required this.labelVisibleFor,
    required this.labelUrgent,
    required this.labelRewardDraw,
    required this.labelRewardDrawSub,
    required this.labelRewardBadge,
    required this.labelSavings,
  });

  Uint8List? _decodeImage(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try { return base64Decode(b64); } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p   = product;
    final now = DateTime.now();
    final sw = MediaQuery.of(context).size.width;
    final isSmall = sw < 360;
    final isLarge = sw >= 420;

    final imageBytes     = p.images.isNotEmpty ? _decodeImage(p.images.first) : null;
    final hasReward      = p.reward != null;
    final rwImgBytes     = hasReward ? _decodeImage(p.reward!.image) : null;
    final rewardName     = p.reward?.name;
    final discountActive = p.isDiscountActive;
    final effectivePrice = p.discountedPrice;

    // Countdown discount
    final discountEndsAt       = p.discountEndsAt;
    final hasDiscountCountdown = discountActive && discountEndsAt != null && now.isBefore(discountEndsAt);

    // Countdown visibilité
    final hiddenAfterAt = p.hiddenAfterAt;
    final hasHideTimer  = hiddenAfterAt != null && now.isBefore(hiddenAfterAt);

    // Stock
    final stock        = p.stock;
    final initialStock = p.initialStock;
    final hasInitial   = initialStock != null && initialStock > 0;
    final stockMax     = hasInitial ? initialStock! : (stock > 0 ? stock : 1);
    final stockRatio   = (stock / stockMax).clamp(0.0, 1.0);
    final stockColor   = stock == 0
        ? const Color(0xFFEF4444)
        : stockRatio < 0.3
        ? const Color(0xFFF97316)
        : stockRatio < 0.6
        ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);

    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => ProductDetailPage(product: p))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 6)),
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ① Chrono remise — widget isolé avec son propre timer
            if (hasDiscountCountdown)
              _CountdownBanner(
                key: ValueKey('discount_${p.id}'),
                endsAt: discountEndsAt!,
                isDiscount: true,
                labelFlash: labelDiscountFlash,
                labelExpires: labelDiscountExpires,
                labelUrgent: labelUrgent,
              ),

            // ② Corps : image gauche | infos droite — hauteur responsive
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.22,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // Image produit — largeur responsive (35% de la carte)
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.32,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        imageBytes != null
                            ? Image.memory(
                          imageBytes,
                          fit: BoxFit.contain,   // ✅ affiche l'image entière sans crop
                          gaplessPlayback: true,
                        )
                            : Container(
                          color: const Color(0xFFF1F5F9),
                          child: Icon(Icons.image_outlined, size: 44, color: Colors.grey.shade300),
                        ),

                        // Overlay épuisé
                        if (stock <= 0)
                          Container(
                            color: Colors.black.withOpacity(0.55),
                            alignment: Alignment.center,
                            child: Transform.rotate(
                              angle: -0.25,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                color: const Color(0xFFEF4444),
                                child: Text(labelOutOfStock,
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.w900,
                                        fontSize: 12, letterSpacing: 0.5)),
                              ),
                            ),
                          ),

                        // Badge % remise
                        if (discountActive && p.discountPercent != null)
                          Positioned(
                            top: 0, left: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                borderRadius: BorderRadius.only(bottomRight: Radius.circular(14)),
                              ),
                              child: Text('-${p.discountPercent!.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                            ),
                          ),
                      ],
                    ),
                  ),

                  Container(width: 1, color: const Color(0xFFF1F5F9)),

                  // Infos droite — prend l'espace restant, hauteur = 160
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Catégorie
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              ProductCategories.labelFromId(p.category, AppLocalizations.getLanguage()),
                              style: TextStyle(
                                  fontSize: 9, color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700, letterSpacing: 0.3),
                            ),
                          ),
                          const SizedBox(height: 5),

                          // Nom
                          Text(p.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: isSmall ? 13 : (isLarge ? 15 : 14),
                                  color: const Color(0xFF0F172A), height: 1.2),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),

                          // Description
                          Text(p.description,
                              style: TextStyle(
                                  fontSize: isSmall ? 10 : 11, color: const Color(0xFF94A3B8), height: 1.3),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),

                          // Prix
                          _buildPriceBlock(effectivePrice, discountActive ? p.price : null,
                              theme, labelSavings),
                          const SizedBox(height: 6),

                          // Barre stock
                          _buildStockBar(stock, initialStock, stockRatio, stockColor, labelInStock, labelOutOfStock),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ), // fin SizedBox 160

            // ③ Reward pleine largeur
            if (hasReward)
              _RewardBanner(
                key: ValueKey('reward_${p.id}'),
                imageBytes: rwImgBytes,
                name: rewardName,
                labelBadge: labelRewardBadge,
                labelDrawSub: labelRewardDrawSub,
              ),

            // ④ Chrono visibilité — widget isolé avec son propre timer
            if (hasHideTimer)
              _CountdownBanner(
                key: ValueKey('hide_${p.id}'),
                endsAt: hiddenAfterAt!,
                isDiscount: false,
                labelFlash: labelVisibleFor,
                labelExpires: labelVisibleFor,
                labelUrgent: labelUrgent,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceBlock(double effectivePrice, double? originalPrice,
      ThemeData theme, String labelSavings) {
    if (originalPrice == null) {
      return Text('${effectivePrice.toStringAsFixed(2)} TND',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w900,
              color: theme.colorScheme.primary, letterSpacing: -0.3));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('${originalPrice.toStringAsFixed(2)} TND',
            style: const TextStyle(
                fontSize: 11, color: Color(0xFFCBD5E1),
                decoration: TextDecoration.lineThrough,
                decorationColor: Color(0xFFCBD5E1), decorationThickness: 2)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
          child: Text(
            '-${((originalPrice - effectivePrice) / originalPrice * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
                fontSize: 9, color: Color(0xFF16A34A), fontWeight: FontWeight.w800),
          ),
        ),
      ]),
      const SizedBox(height: 2),
      Text('${effectivePrice.toStringAsFixed(2)} TND',
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w900,
              color: Color(0xFF16A34A), letterSpacing: -0.5)),
    ]);
  }
  Widget _buildStockBar(int stock, int? initialStock, double ratio, Color color,
      String labelInStock, String labelOutOfStock) {
    final hasInitial = initialStock != null && initialStock > 0;
    final sold       = hasInitial ? (initialStock - stock).clamp(0, initialStock) : 0;
    final pctLeft    = (ratio * 100).round();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        // Gauche : stock restant
        Row(children: [
          Container(width: 7, height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(
            stock > 0 ? '$stock $labelInStock' : labelOutOfStock,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ]),
        // Droite : vendus + % restant
        Row(children: [
          if (hasInitial && sold > 0) ...[
            Text('$sold vendus',
                style: TextStyle(fontSize: 9, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
            const SizedBox(width: 5),
            Container(width: 1, height: 10, color: const Color(0xFFE2E8F0)),
            const SizedBox(width: 5),
          ],
          Text('$pctLeft%',
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
        ]),
      ]),
      const SizedBox(height: 5),
      // Barre : fond = vendus (gris), avant-plan = restant (coloré)
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(children: [
          // Fond gris = totalité du stock initial
          Container(height: 5, color: const Color(0xFFF1F5F9)),
          // Couleur = stock restant
          FractionallySizedBox(
            widthFactor: ratio,
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 3, offset: const Offset(0, 1))],
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ── Reward Banner (StatelessWidget — aucun timer) ─────────────────

class _RewardBanner extends StatelessWidget {
  final Uint8List? imageBytes;
  final String? name;
  final String labelBadge;
  final String labelDrawSub;

  const _RewardBanner({
    super.key,
    this.imageBytes,
    this.name,
    required this.labelBadge,
    required this.labelDrawSub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB45309), Color(0xFFD97706), Color(0xFFEAB308)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4)),
              BoxShadow(color: const Color(0xFFEAB308).withOpacity(0.6), blurRadius: 20, spreadRadius: 2),
            ],
          ),
          child: ClipOval(
            child: imageBytes != null
                ? Image.memory(imageBytes!, fit: BoxFit.cover, gaplessPlayback: true)
                : Container(
                color: const Color(0xFFFDE68A),
                child: const Icon(Icons.card_giftcard_rounded, size: 32, color: Color(0xFFD97706))),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.emoji_events_rounded, size: 12, color: Colors.white),
                const SizedBox(width: 5),
                Text(labelBadge,
                    style: const TextStyle(
                        fontSize: 9, color: Colors.white,
                        fontWeight: FontWeight.w900, letterSpacing: 0.8)),
              ]),
            ),
            const SizedBox(height: 6),
            if (name != null)
              Text(name!,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900,
                      color: Colors.white, height: 1.2),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.confirmation_number_rounded, size: 12, color: Colors.white),
              const SizedBox(width: 5),
              Expanded(
                child: Text(labelDrawSub,
                    style: TextStyle(
                        fontSize: 11, color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 10),
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.5)),
          ),
          child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white),
        ),
      ]),
    );
  }
}

// ── Countdown Banner — StatefulWidget ISOLÉ ───────────────────────
// ✅ Son setState ne touche QUE cette bannière, jamais la carte parent
//    ni les images.

class _CountdownBanner extends StatefulWidget {
  final DateTime endsAt;
  final bool isDiscount;   // true = bannière rouge (remise) | false = bleue (visibilité)
  final String labelFlash;
  final String labelExpires;
  final String labelUrgent;

  const _CountdownBanner({
    super.key,
    required this.endsAt,
    required this.isDiscount,
    required this.labelFlash,
    required this.labelExpires,
    required this.labelUrgent,
  });

  @override
  State<_CountdownBanner> createState() => _CountdownBannerState();
}

class _CountdownBannerState extends State<_CountdownBanner>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.04)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _tick();
    // ✅ Timer UNIQUEMENT pour mettre à jour CE widget
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _tick();
    });
  }

  void _tick() {
    final r = widget.endsAt.difference(DateTime.now());
    if (mounted) setState(() => _remaining = r.isNegative ? Duration.zero : r);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    if (d.inSeconds <= 0) return '0s';
    if (d.inDays > 0) {
      final h = d.inHours % 24;
      return h > 0 ? '${d.inDays}j ${h}h' : '${d.inDays}j';
    }
    if (d.inHours > 0) {
      final m = d.inMinutes % 60;
      return m > 0 ? '${d.inHours}h ${m}min' : '${d.inHours}h';
    }
    if (d.inMinutes > 0) {
      final s = d.inSeconds % 60;
      return s > 0 ? '${d.inMinutes}min ${s}s' : '${d.inMinutes}min';
    }
    return '${d.inSeconds}s';
  }

  List<_TimeSegment> _parse(String label) {
    return label.trim().split(' ').map((part) {
      final m = RegExp(r'^(\d+)([a-zA-Zé]+)$').firstMatch(part);
      return m != null ? _TimeSegment(m.group(1)!, m.group(2)!) : _TimeSegment(part, '');
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent   = _remaining.inHours < 24;
    final isLastMin  = _remaining.inSeconds < 60;
    final segments   = _parse(_fmt(_remaining));

    if (widget.isDiscount) {
      // ── Bannière remise (rouge / orange) ─────────────────────
      return AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Transform.scale(
          scaleY: isUrgent ? _pulse.value : 1.0,
          alignment: Alignment.topCenter,
          child: child,
        ),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isUrgent
                  ? [const Color(0xFFFF2D55), const Color(0xFFFF6B35)]
                  : [const Color(0xFFFF6B35), const Color(0xFFFF8C42)],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(
                  isLastMin ? Icons.local_fire_department_rounded : Icons.local_offer_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isUrgent ? widget.labelFlash : widget.labelExpires,
                style: TextStyle(
                    fontSize: 9, color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w700, letterSpacing: 1.2),
              ),
              const SizedBox(height: 3),
              Row(children: segments.map(_chip).toList()),
            ])),
            if (isUrgent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: Text(widget.labelUrgent,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFFF2D55), fontWeight: FontWeight.w900)),
              ),
          ]),
        ),
      );
    } else {
      // ── Bannière visibilité (bleu / violet) ──────────────────
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isUrgent
                ? [const Color(0xFF4F46E5), const Color(0xFF7C3AED)]
                : [const Color(0xFF0EA5E9), const Color(0xFF38BDF8)],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Icon(isLastMin ? Icons.timer_off_rounded : Icons.schedule_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text(widget.labelExpires,
              style: TextStyle(
                  fontSize: 11, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          Row(children: segments.map(_smallChip).toList()),
          const Spacer(),
          if (isUrgent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white.withOpacity(0.4))),
              child: Text(widget.labelUrgent,
                  style: const TextStyle(
                      fontSize: 9, color: Colors.white,
                      fontWeight: FontWeight.w900, letterSpacing: 0.8)),
            ),
        ]),
      );
    }
  }

  Widget _chip(_TimeSegment seg) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: RichText(text: TextSpan(children: [
      TextSpan(text: seg.value, style: const TextStyle(
          fontSize: 22, color: Colors.white, fontWeight: FontWeight.w900, height: 1.0)),
      TextSpan(text: seg.unit, style: TextStyle(
          fontSize: 12, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600)),
    ])),
  );

  Widget _smallChip(_TimeSegment seg) => Padding(
    padding: const EdgeInsets.only(right: 4),
    child: RichText(text: TextSpan(children: [
      TextSpan(text: seg.value, style: const TextStyle(
          fontSize: 15, color: Colors.white, fontWeight: FontWeight.w900)),
      TextSpan(text: seg.unit, style: TextStyle(
          fontSize: 10, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600)),
    ])),
  );
}

// ── Time Segment helper ──────────────────────────────────────────

class _TimeSegment {
  final String value;
  final String unit;
  const _TimeSegment(this.value, this.unit);
}

// ── Empty State ──────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
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
            hasFilters ? Icons.filter_alt_off_rounded : Icons.storefront_outlined,
            size: 64, color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
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
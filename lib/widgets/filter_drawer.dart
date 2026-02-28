import 'package:flutter/material.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';
import 'package:smart_marketplace/models/product_categories.dart';

class FilterOptions {
  String? selectedCategory;
  double minPrice;
  double maxPrice;
  String sortOrder;
  bool inStockOnly;

  FilterOptions({
    this.selectedCategory,
    this.minPrice = 0,
    this.maxPrice = 10000,
    this.sortOrder = 'none',
    this.inStockOnly = false,
  });

  FilterOptions copyWith({
    String? selectedCategory,
    double? minPrice,
    double? maxPrice,
    String? sortOrder,
    bool? inStockOnly,
    bool clearCategory = false,
  }) {
    return FilterOptions(
      selectedCategory: clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      sortOrder: sortOrder ?? this.sortOrder,
      inStockOnly: inStockOnly ?? this.inStockOnly,
    );
  }
}

class FilterDrawer extends StatefulWidget {
  final List<String> categories;
  final FilterOptions currentFilters;
  final double absoluteMaxPrice;
  final ValueChanged<FilterOptions> onApply;

  const FilterDrawer({
    super.key,
    required this.categories,
    required this.currentFilters,
    required this.onApply,
    this.absoluteMaxPrice = 10000,
  });

  @override
  State<FilterDrawer> createState() => _FilterDrawerState();
}

class _FilterDrawerState extends State<FilterDrawer> {
  late FilterOptions _filters;
  bool _categoryExpanded = false; // ✅ état d'ouverture de la liste

  String _t(String key) => AppLocalizations.get(key);

  @override
  void initState() {
    super.initState();
    _filters = FilterOptions(
      selectedCategory: widget.currentFilters.selectedCategory,
      minPrice: widget.currentFilters.minPrice,
      maxPrice: widget.currentFilters.maxPrice.clamp(0, widget.absoluteMaxPrice),
      sortOrder: widget.currentFilters.sortOrder,
      inStockOnly: widget.currentFilters.inStockOnly,
    );
    // ✅ Si une catégorie est déjà sélectionnée, ouvrir la liste au démarrage
    _categoryExpanded = widget.currentFilters.selectedCategory != null;
  }

  void _update(FilterOptions newFilters) {
    setState(() => _filters = newFilters);
    widget.onApply(newFilters);
  }

  void _resetFilters() {
    final reset = FilterOptions(maxPrice: widget.absoluteMaxPrice);
    setState(() {
      _filters = reset;
      _categoryExpanded = false;
    });
    widget.onApply(reset);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = AppLocalizations.getLanguage();

    // Label de la catégorie sélectionnée (pour l'afficher dans le header fermé)
    final selectedCatLabel = _filters.selectedCategory != null
        ? '${ProductCategories.iconFromId(_filters.selectedCategory!)} ${ProductCategories.labelFromId(_filters.selectedCategory!, lang)}'
        : _t('filter_category_all');

    return Drawer(
      width: 300,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 12, 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    _t('filter_title'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _resetFilters,
                    tooltip: _t('filter_reset'),
                    icon: const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 22),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.15),
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(34, 34),
                    ),
                  ),
                ],
              ),
            ),

            // ── Contenu ──────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [

                  // ── Catégories (liste dépliable) ─────────────
                  _SectionTitle(title: _t('filter_category')),
                  const SizedBox(height: 10),

                  // ✅ Container cliquable qui ouvre/ferme la liste
                  GestureDetector(
                    onTap: () => setState(() => _categoryExpanded = !_categoryExpanded),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _filters.selectedCategory != null
                            ? theme.colorScheme.primary.withOpacity(0.08)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _filters.selectedCategory != null
                              ? theme.colorScheme.primary.withOpacity(0.4)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Icône + label catégorie sélectionnée
                          Expanded(
                            child: Text(
                              selectedCatLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _filters.selectedCategory != null
                                    ? theme.colorScheme.primary
                                    : Colors.grey.shade700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // ✅ Badge nombre de catégories dispo
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${widget.categories.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          // Flèche animée
                          AnimatedRotation(
                            turns: _categoryExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.grey.shade500,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ✅ Liste animée qui s'ouvre/ferme
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 220),
                    crossFadeState: _categoryExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: const SizedBox.shrink(),
                    secondChild: Container(
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      // ✅ Hauteur max avec scroll si beaucoup de catégories
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          children: [
                            // Option "Toutes"
                            _CategoryListTile(
                              icon: '🏷️',
                              label: _t('filter_category_all'),
                              selected: _filters.selectedCategory == null,
                              onTap: () {
                                _update(_filters.copyWith(clearCategory: true));
                                setState(() => _categoryExpanded = false);
                              },
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            // Catégories disponibles
                            ...widget.categories.map((id) {
                              final icon = ProductCategories.iconFromId(id);
                              final label = ProductCategories.labelFromId(id, lang);
                              return _CategoryListTile(
                                icon: icon,
                                label: label,
                                selected: _filters.selectedCategory == id,
                                onTap: () {
                                  _update(_filters.copyWith(selectedCategory: id));
                                  setState(() => _categoryExpanded = false); // ✅ ferme après sélection
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Prix ─────────────────────────────────────
                  _SectionTitle(title: _t('filter_price_range')),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _PriceLabel(value: _filters.minPrice),
                      _PriceLabel(value: _filters.maxPrice),
                    ],
                  ),
                  RangeSlider(
                    values: RangeValues(
                      _filters.minPrice.clamp(0, widget.absoluteMaxPrice),
                      _filters.maxPrice.clamp(0, widget.absoluteMaxPrice),
                    ),
                    min: 0,
                    max: widget.absoluteMaxPrice,
                    divisions: 100,
                    activeColor: theme.colorScheme.primary,
                    inactiveColor: theme.colorScheme.primary.withOpacity(0.15),
                    onChangeEnd: (values) => _update(_filters.copyWith(
                      minPrice: values.start,
                      maxPrice: values.end,
                    )),
                    onChanged: (values) => setState(() => _filters = _filters.copyWith(
                      minPrice: values.start,
                      maxPrice: values.end,
                    )),
                  ),

                  const SizedBox(height: 28),

                  // ── Tri ──────────────────────────────────────
                  _SectionTitle(title: _t('filter_sort_by_price')),
                  const SizedBox(height: 10),
                  _SortTile(
                    label: _t('filter_sort_default'),
                    icon: Icons.sort_rounded,
                    selected: _filters.sortOrder == 'none',
                    onTap: () => _update(_filters.copyWith(sortOrder: 'none')),
                  ),
                  const SizedBox(height: 8),
                  _SortTile(
                    label: _t('filter_sort_asc'),
                    icon: Icons.arrow_upward_rounded,
                    selected: _filters.sortOrder == 'asc',
                    onTap: () => _update(_filters.copyWith(sortOrder: 'asc')),
                  ),
                  const SizedBox(height: 8),
                  _SortTile(
                    label: _t('filter_sort_desc'),
                    icon: Icons.arrow_downward_rounded,
                    selected: _filters.sortOrder == 'desc',
                    onTap: () => _update(_filters.copyWith(sortOrder: 'desc')),
                  ),

                  const SizedBox(height: 28),

                  // ── Disponibilité ────────────────────────────
                  _SectionTitle(title: _t('filter_availability')),
                  const SizedBox(height: 8),
                  _ToggleTile(
                    label: _t('filter_in_stock_only'),
                    value: _filters.inStockOnly,
                    onChanged: (v) => _update(_filters.copyWith(inStockOnly: v)),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category List Tile ────────────────────────────────────────────

class _CategoryListTile extends StatelessWidget {
  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryListTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        color: selected ? primary.withOpacity(0.08) : Colors.transparent,
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? primary : Colors.grey.shade800,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 16, color: primary),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _SortTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SortTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? primary : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: selected ? primary : Colors.grey.shade500),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: selected ? primary : Colors.grey.shade700,
                fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 14,
              ),
            ),
            if (selected) ...[
              const Spacer(),
              Icon(Icons.check_rounded, size: 16, color: primary),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }
}

class _PriceLabel extends StatelessWidget {
  final double value;
  const _PriceLabel({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${value.toStringAsFixed(0)} DT',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
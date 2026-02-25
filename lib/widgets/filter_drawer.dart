import 'package:flutter/material.dart';

class FilterOptions {
  String? selectedCategory;
  double minPrice;
  double maxPrice;
  String sortOrder; // 'none', 'asc', 'desc'
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
      selectedCategory:
      clearCategory ? null : (selectedCategory ?? this.selectedCategory),
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      width: 300,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 16, 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Filtres',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _resetFilters,
                    child: Text(
                      'Réinitialiser',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── Categories ──
                  _SectionTitle(title: 'Catégorie'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CategoryChip(
                        label: 'Toutes',
                        selected: _filters.selectedCategory == null,
                        onTap: () => setState(
                                () => _filters = _filters.copyWith(clearCategory: true)),
                      ),
                      ...widget.categories.map(
                            (cat) => _CategoryChip(
                          label: cat,
                          selected: _filters.selectedCategory == cat,
                          onTap: () => setState(() => _filters =
                              _filters.copyWith(selectedCategory: cat)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── Price Range ──
                  _SectionTitle(title: 'Fourchette de prix'),
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
                    onChanged: (values) {
                      setState(() {
                        _filters = _filters.copyWith(
                          minPrice: values.start,
                          maxPrice: values.end,
                        );
                      });
                    },
                  ),

                  const SizedBox(height: 28),

                  // ── Sort ──
                  _SectionTitle(title: 'Trier par prix'),
                  const SizedBox(height: 10),
                  _SortTile(
                    label: 'Par défaut',
                    icon: Icons.sort_rounded,
                    selected: _filters.sortOrder == 'none',
                    onTap: () => setState(
                            () => _filters = _filters.copyWith(sortOrder: 'none')),
                  ),
                  const SizedBox(height: 8),
                  _SortTile(
                    label: 'Prix croissant',
                    icon: Icons.arrow_upward_rounded,
                    selected: _filters.sortOrder == 'asc',
                    onTap: () => setState(
                            () => _filters = _filters.copyWith(sortOrder: 'asc')),
                  ),
                  const SizedBox(height: 8),
                  _SortTile(
                    label: 'Prix décroissant',
                    icon: Icons.arrow_downward_rounded,
                    selected: _filters.sortOrder == 'desc',
                    onTap: () => setState(
                            () => _filters = _filters.copyWith(sortOrder: 'desc')),
                  ),

                  const SizedBox(height: 28),

                  // ── Stock ──
                  _SectionTitle(title: 'Disponibilité'),
                  const SizedBox(height: 8),
                  _ToggleTile(
                    label: 'En stock uniquement',
                    value: _filters.inStockOnly,
                    onChanged: (v) =>
                        setState(() => _filters = _filters.copyWith(inStockOnly: v)),
                  ),
                ],
              ),
            ),

            // Apply Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_filters);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Appliquer les filtres',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _filters = FilterOptions(maxPrice: widget.absoluteMaxPrice);
    });
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

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? primary : primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? primary : primary.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : primary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
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
            color: selected ? primary : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18, color: selected ? primary : Colors.grey.shade500),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: selected ? primary : Colors.grey.shade700,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 14,
              ),
            ),
            if (selected) ...[
              const Spacer(),
              Icon(Icons.check_rounded, size: 16, color: primary),
            ]
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
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
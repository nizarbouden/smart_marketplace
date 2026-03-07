// lib/views/seller/products/widgets/shipping_section_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../models/shipping_zone_model.dart';
import '../../../../localization/app_localizations.dart';

class ShippingSectionWidget extends StatefulWidget {
  final String?               selectedCompanyId;
  final double?               productWeight;
  final List<ShippingZoneRate>? zoneRates;
  final Function(String? companyId, double? weight, List<ShippingZoneRate> rates) onChanged;

  const ShippingSectionWidget({
    super.key,
    this.selectedCompanyId,
    this.productWeight,
    this.zoneRates,
    required this.onChanged,
  });

  @override
  State<ShippingSectionWidget> createState() => _ShippingSectionWidgetState();
}

class _ShippingSectionWidgetState extends State<ShippingSectionWidget> {
  String? _selectedCompanyId;
  final _weightCtrl = TextEditingController();

  // Zone rates — une entrée par zone
  late List<ShippingZoneRate> _rates;

  // Zones actuellement développées dans l'UI
  final Set<ShippingZone> _expandedZones = {};

  String get _lang => AppLocalizations.getLanguage();
  String _t(String k) => AppLocalizations.get(k);

  @override
  void initState() {
    super.initState();
    _selectedCompanyId = widget.selectedCompanyId;
    if (widget.productWeight != null) {
      _weightCtrl.text = widget.productWeight!.toString();
    }
    _rates = _initRates(widget.zoneRates);
    _weightCtrl.addListener(_notify);
  }

  /// Initialise les zones avec les données existantes ou des defaults
  List<ShippingZoneRate> _initRates(List<ShippingZoneRate>? existing) {
    return ShippingZone.values.map((zone) {
      final found = existing?.where((r) => r.zone == zone).firstOrNull;
      if (found != null) return found;
      // Valeurs par défaut selon la zone
      return ShippingZoneRate(
        zone:       zone,
        enabled:    zone == ShippingZone.local || zone == ShippingZone.national,
        basePrice:  _defaultBase(zone),
        pricePerKg: _defaultPerKg(zone),
      );
    }).toList();
  }

  double _defaultBase(ShippingZone z) {
    switch (z) {
      case ShippingZone.local:      return 3.0;
      case ShippingZone.national:   return 7.0;
      case ShippingZone.maghreb:    return 15.0;
      case ShippingZone.africa:     return 25.0;
      case ShippingZone.middleEast: return 30.0;
      case ShippingZone.europe:     return 20.0;
      case ShippingZone.world:      return 35.0;
    }
  }

  double _defaultPerKg(ShippingZone z) {
    switch (z) {
      case ShippingZone.local:      return 1.0;
      case ShippingZone.national:   return 2.0;
      case ShippingZone.maghreb:    return 4.0;
      case ShippingZone.africa:     return 6.0;
      case ShippingZone.middleEast: return 7.0;
      case ShippingZone.europe:     return 5.0;
      case ShippingZone.world:      return 8.0;
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    final weight = double.tryParse(_weightCtrl.text.trim());
    widget.onChanged(_selectedCompanyId, weight, _rates);
  }

  void _updateRate(ShippingZone zone, ShippingZoneRate newRate) {
    setState(() {
      final idx = _rates.indexWhere((r) => r.zone == zone);
      if (idx != -1) _rates[idx] = newRate;
    });
    _notify();
  }

  bool get _isWeightValid => double.tryParse(_weightCtrl.text.trim()) != null;
  bool get _isCompanySelected => _selectedCompanyId != null;
  bool get _hasAtLeastOneZone => _rates.any((r) => r.enabled);

  // Zones disponibles pour la société sélectionnée
  List<ShippingZone> get _availableZones {
    final company = ShippingCompanies.findById(_selectedCompanyId);
    if (company == null) return ShippingZone.values.toList();
    return company.coveredZones;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        _buildHeader(),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildWeightField(),
            const SizedBox(height: 24),
            _buildCompanySelector(),
            if (_selectedCompanyId != null) ...[
              const SizedBox(height: 24),
              _buildZoneRatesSection(),
            ],
            if (!_isWeightValid || !_isCompanySelected)
              _buildValidationHint(),
          ]),
        ),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.local_shipping_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(_t('shipping_section_title'),
                  style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(width: 4),
              const Text('*', style: TextStyle(
                  color: Color(0xFFEF4444), fontSize: 16,
                  fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 2),
            Text(_t('shipping_section_subtitle'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ],
        )),
        // Indicateur de complétion
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: (_isWeightValid && _isCompanySelected && _hasAtLeastOneZone)
              ? Container(
            key: const ValueKey('ok'),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.check_rounded,
                color: Color(0xFF16A34A), size: 16),
          )
              : Container(
            key: const ValueKey('pending'),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.pending_rounded,
                color: Color(0xFFF59E0B), size: 16),
          ),
        ),
      ]),
    );
  }

  // ── Champ poids ───────────────────────────────────────────────

  Widget _buildWeightField() {
    final hasError = _weightCtrl.text.isNotEmpty && !_isWeightValid;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_t('shipping_weight_label'),
              style: const TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(width: 2),
          const Text('*', style: TextStyle(
              color: Color(0xFFEF4444), fontSize: 14,
              fontWeight: FontWeight.bold)),
        ]),
      ),
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: TextFormField(
          controller: _weightCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
          ],
          style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            hintText: _t('shipping_weight_hint'),
            hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
            prefixIcon: const Icon(Icons.scale_rounded,
                color: Color(0xFF3B82F6), size: 20),
            suffixText: 'kg',
            suffixStyle: const TextStyle(
                color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: Color(0xFF3B82F6), width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: Color(0xFFEF4444), width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
        ),
      ),
      if (hasError)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(_t('shipping_weight_invalid'),
              style: const TextStyle(
                  color: Color(0xFFEF4444), fontSize: 12)),
        ),
    ]);
  }

  // ── Sélecteur de société ──────────────────────────────────────

  Widget _buildCompanySelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 12),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_t('shipping_company_label'),
              style: const TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(width: 2),
          const Text('*', style: TextStyle(
              color: Color(0xFFEF4444), fontSize: 14,
              fontWeight: FontWeight.bold)),
        ]),
      ),
      // Grid de sociétés 2 par ligne
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.4,
        ),
        itemCount: ShippingCompanies.all.length,
        itemBuilder: (_, i) =>
            _buildCompanyChip(ShippingCompanies.all[i]),
      ),
    ]);
  }

  Widget _buildCompanyChip(ShippingCompany company) {
    final isSelected = _selectedCompanyId == company.id;
    final color      = Color(company.colorValue);
    final svcColor   = Color(ShippingCompanies.serviceColorValue(company.serviceType));
    final svcLabel   = ShippingCompanies.serviceLabel(company.serviceType, _lang);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCompanyId = isSelected ? null : company.id;
          // Désactiver les zones non couvertes par la nouvelle société
          if (!isSelected) {
            for (int i = 0; i < _rates.length; i++) {
              if (!company.coveredZones.contains(_rates[i].zone)) {
                _rates[i] = _rates[i].copyWith(enabled: false);
              }
            }
          }
        });
        _notify();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.07) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Text(company.logo, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(company.name,
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold,
                    color: isSelected ? color : const Color(0xFF1E293B),
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: svcColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(svcLabel,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: svcColor)),
              ),
            ],
          )),
          if (isSelected)
            Icon(Icons.check_circle_rounded, color: color, size: 16),
        ]),
      ),
    );
  }

  // ── Zones tarifaires ──────────────────────────────────────────

  Widget _buildZoneRatesSection() {
    final weight = double.tryParse(_weightCtrl.text.trim());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Titre section
      Row(children: [
        Container(width: 3, height: 16,
            decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(_t('shipping_zones_title'),
            style: const TextStyle(fontSize: 13,
                fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
      ]),
      const SizedBox(height: 4),
      Text(_t('shipping_zones_subtitle'),
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      const SizedBox(height: 14),

      // Liste des zones
      ...ShippingZone.values.map((zone) {
        final available = _availableZones.contains(zone);
        final rate = _rates.firstWhere((r) => r.zone == zone);
        return _buildZoneTile(zone, rate, weight, available);
      }),

      // Récap zones activées
      if (_rates.any((r) => r.enabled) && weight != null)
        _buildRatesSummary(weight),
    ]);
  }

  Widget _buildZoneTile(
      ShippingZone zone, ShippingZoneRate rate,
      double? weight, bool available) {
    final isExpanded = _expandedZones.contains(zone);
    final price = weight != null ? rate.calculatePrice(weight) : null;
    final isActive = rate.enabled && available;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: !available
            ? const Color(0xFFF8FAFC)
            : isActive
            ? const Color(0xFFEFF6FF)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: !available
              ? const Color(0xFFE2E8F0)
              : isActive
              ? const Color(0xFF93C5FD)
              : const Color(0xFFE2E8F0),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(children: [
        // Ligne principale
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: available && rate.enabled
              ? () => setState(() {
            if (isExpanded) {
              _expandedZones.remove(zone);
            } else {
              _expandedZones.add(zone);
            }
          })
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: Row(children: [
              // Emoji zone
              Text(zone.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              // Nom + description zone
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(zone.label(_lang),
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: available
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF94A3B8),
                      )),
                  const SizedBox(height: 2),
                  // ✅ Description explicite du périmètre de la zone
                  Text(
                    !available
                        ? _t('shipping_zone_unavailable')
                        : zone.desc(_lang),
                    style: TextStyle(
                        fontSize: 10,
                        color: !available
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF94A3B8)),
                  ),
                  if (isActive && price != null) ...[
                    const SizedBox(height: 3),
                    Text('${price.toStringAsFixed(2)} \$',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w600)),
                  ],
                ],
              )),
              // Toggle
              if (available)
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: rate.enabled,
                    onChanged: (v) {
                      _updateRate(zone, rate.copyWith(enabled: v));
                      if (!v) _expandedZones.remove(zone);
                    },
                    activeColor: const Color(0xFF3B82F6),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              // Chevron expand si activé
              if (available && rate.enabled)
                AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: isExpanded ? 0.5 : 0,
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF94A3B8), size: 18),
                ),
            ]),
          ),
        ),

        // Formulaire prix (si zone activée et expanded)
        if (isActive && isExpanded)
          _buildZonePriceForm(zone, rate),
      ]),
    );
  }

  Widget _buildZonePriceForm(ShippingZone zone, ShippingZoneRate rate) {
    final baseCtrl = TextEditingController(
        text: rate.basePrice.toStringAsFixed(2));
    final perKgCtrl = TextEditingController(
        text: rate.pricePerKg.toStringAsFixed(2));

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(children: [
        const Divider(height: 16, color: Color(0xFFE2E8F0)),
        Row(children: [
          Expanded(child: _buildPriceField(
            ctrl: baseCtrl,
            label: _t('shipping_base_price'),
            hint: '0.00',
            onChanged: (v) {
              final val = double.tryParse(v);
              if (val != null) {
                _updateRate(zone, rate.copyWith(basePrice: val));
              }
            },
          )),
          const SizedBox(width: 10),
          Expanded(child: _buildPriceField(
            ctrl: perKgCtrl,
            label: _t('shipping_per_kg'),
            hint: '0.00',
            onChanged: (v) {
              final val = double.tryParse(v);
              if (val != null) {
                _updateRate(zone, rate.copyWith(pricePerKg: val));
              }
            },
          )),
        ]),
        const SizedBox(height: 8),
        // Info calcul
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: Color(0xFF3B82F6), size: 12),
            const SizedBox(width: 6),
            Text(_t('shipping_price_formula'),
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF1E40AF))),
          ]),
        ),
      ]),
    );
  }

  Widget _buildPriceField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: Color(0xFF64748B))),
      const SizedBox(height: 4),
      TextFormField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
        ],
        style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
          suffixText: '\$',
          suffixStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
              fontSize: 12),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: Color(0xFF3B82F6), width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 8),
        ),
      ),
    ]);
  }

  // ── Récapitulatif ─────────────────────────────────────────────

  Widget _buildRatesSummary(double weight) {
    final activeRates = _rates.where((r) => r.enabled).toList();
    if (activeRates.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.summarize_rounded,
              color: Color(0xFF0284C7), size: 14),
          const SizedBox(width: 6),
          Text(_t('shipping_summary_title'),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold,
                  color: Color(0xFF0C4A6E))),
          const Spacer(),
          Text('${weight.toStringAsFixed(1)} kg',
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF0284C7),
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        ...activeRates.map((r) {
          final price = r.calculatePrice(weight);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Text(r.zone.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(child: Text(r.zone.label(_lang),
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF1E293B)))),
              Text('${price.toStringAsFixed(2)} \$',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold,
                      color: Color(0xFF0284C7))),
            ]),
          );
        }),
      ]),
    );
  }

  // ── Hint validation ───────────────────────────────────────────

  Widget _buildValidationHint() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded,
            color: Color(0xFFF97316), size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(_t('shipping_validation_hint'),
            style: const TextStyle(
                fontSize: 12, color: Color(0xFFC2410C)))),
      ]),
    );
  }
}
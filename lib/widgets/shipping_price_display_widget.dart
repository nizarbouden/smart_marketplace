// lib/widgets/shipping_price_display_widget.dart

import 'package:flutter/material.dart';
import '../models/shipping_zone_model.dart';
import '../models/countries.dart';
import '../localization/app_localizations.dart';

class ShippingPriceDisplayWidget extends StatelessWidget {
  final String  buyerCountryCode;
  final double  productWeight;
  final List<ShippingZoneRate> zoneRates;
  final String? shippingCompanyName;
  final bool    compact;

  // Données contextuelles calculées par la page
  final ShippingZone effectiveZone;
  final bool   isSameCity;
  final bool   isSameCountry;
  final String buyerCity;
  final String buyerCountryName;
  final String buyerCountryFlag;
  final String sellerCity;

  const ShippingPriceDisplayWidget({
    super.key,
    required this.buyerCountryCode,
    required this.productWeight,
    required this.zoneRates,
    this.shippingCompanyName,
    this.compact = false,
    required this.effectiveZone,
    this.isSameCity     = false,
    this.isSameCountry  = false,
    this.buyerCity      = '',
    this.buyerCountryName = '',
    this.buyerCountryFlag = '',
    this.sellerCity     = '',
  });

  String get _lang => AppLocalizations.getLanguage();
  String _t(String k) => AppLocalizations.get(k);
  bool get _isRtl => _lang == 'ar';

  @override
  Widget build(BuildContext context) {
    final rate      = zoneRates.where((r) => r.zone == effectiveZone).firstOrNull;
    final available = rate != null && rate.enabled;

    if (compact) return _buildCompact(rate, available);

    return Directionality(
      textDirection: _isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: available
                ? _buildAvailable(rate!)
                : _buildUnavailable(),
          ),
        ]),
      ),
    );
  }

  // ── Compact ───────────────────────────────────────────────────────

  Widget _buildCompact(ShippingZoneRate? rate, bool available) {
    if (!available) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.block_rounded, color: Color(0xFF94A3B8), size: 13),
        const SizedBox(width: 4),
        Text(_t('shipping_unavailable_short'),
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      ]);
    }
    final price = rate!.calculatePrice(productWeight);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.local_shipping_rounded,
          color: _zoneColor(effectiveZone), size: 13),
      const SizedBox(width: 4),
      Text('${price.toStringAsFixed(2)} \$',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
              color: _zoneColor(effectiveZone))),
    ]);
  }

  // ── Header ────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [_zoneColor(effectiveZone),
                  _zoneColor(effectiveZone).withOpacity(0.7)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_zoneIcon(effectiveZone), color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Text(_t('shipping_delivery_title'),
            style: const TextStyle(fontSize: 15,
                fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        const Spacer(),
        // Badge zone
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _zoneColor(effectiveZone).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(effectiveZone.emoji,
                style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
            Text(effectiveZone.label(_lang),
                style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _zoneColor(effectiveZone))),
          ]),
        ),
      ]),
    );
  }

  // ── Disponible ────────────────────────────────────────────────────

  Widget _buildAvailable(ShippingZoneRate rate) {
    final price = rate.calculatePrice(productWeight);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ✅ Bannière contextuelle selon la situation
      _buildContextBanner(),
      const SizedBox(height: 14),

      // Carte prix
      _buildPriceCard(price),
      const SizedBox(height: 12),

      // Détail calcul
      _buildBreakdown(rate, price),

      if (shippingCompanyName != null) ...[
        const SizedBox(height: 10),
        _buildCompanyRow(),
      ],
    ]);
  }

  // ✅ Bannière qui s'adapte à TOUS les cas
  Widget _buildContextBanner() {
    // ── CAS 1 : Même ville ────────────────────────────────────────
    if (isSameCity) {
      return _buildBanner(
        leftWidget: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('📍', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(buyerCity,
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF065F46))),
              ]),
              const SizedBox(height: 4),
              Text(_t('shipping_same_city_desc'),
                  style: const TextStyle(fontSize: 11,
                      color: Color(0xFF059669))),
            ]),
        badgeText: _t('shipping_zone_local'),
        badgeIcon: Icons.location_on_rounded,
        color: const Color(0xFF10B981),
        bgColor: const Color(0xFFF0FDF4),
        borderColor: const Color(0xFFBBF7D0),
      );
    }

    // ── CAS 2 : Même pays, ville différente ───────────────────────
    if (isSameCountry) {
      return _buildBanner(
        leftWidget: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(buyerCountryFlag,
                    style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(buyerCountryName,
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E3A8A))),
              ]),
              const SizedBox(height: 4),
              Text('$buyerCity → ${_t('shipping_same_country_desc')}',
                  style: const TextStyle(fontSize: 11,
                      color: Color(0xFF2563EB))),
            ]),
        badgeText: _t('shipping_zone_national'),
        badgeIcon: Icons.flag_rounded,
        color: const Color(0xFF3B82F6),
        bgColor: const Color(0xFFEFF6FF),
        borderColor: const Color(0xFFBFDBFE),
      );
    }

    // ── CAS 3 : Maghreb ───────────────────────────────────────────
    if (effectiveZone == ShippingZone.maghreb) {
      return _buildBanner(
        leftWidget: _buildInternationalLeft(
            '🌍', buyerCountryFlag, buyerCountryName, buyerCity),
        badgeText: _t('shipping_zone_maghreb'),
        badgeIcon: Icons.public_rounded,
        color: const Color(0xFF8B5CF6),
        bgColor: const Color(0xFFF5F3FF),
        borderColor: const Color(0xFFDDD6FE),
      );
    }

    // ── CAS 4 : Afrique ───────────────────────────────────────────
    if (effectiveZone == ShippingZone.africa) {
      return _buildBanner(
        leftWidget: _buildInternationalLeft(
            '🌍', buyerCountryFlag, buyerCountryName, buyerCity),
        badgeText: _t('shipping_zone_africa'),
        badgeIcon: Icons.public_rounded,
        color: const Color(0xFFF59E0B),
        bgColor: const Color(0xFFFFFBEB),
        borderColor: const Color(0xFFFDE68A),
      );
    }

    // ── CAS 5 : Moyen-Orient ──────────────────────────────────────
    if (effectiveZone == ShippingZone.middleEast) {
      return _buildBanner(
        leftWidget: _buildInternationalLeft(
            '🕌', buyerCountryFlag, buyerCountryName, buyerCity),
        badgeText: _t('shipping_zone_middle_east'),
        badgeIcon: Icons.public_rounded,
        color: const Color(0xFFEF4444),
        bgColor: const Color(0xFFFFF1F2),
        borderColor: const Color(0xFFFFCDD2),
      );
    }

    // ── CAS 6 : Europe ────────────────────────────────────────────
    if (effectiveZone == ShippingZone.europe) {
      return _buildBanner(
        leftWidget: _buildInternationalLeft(
            '🇪🇺', buyerCountryFlag, buyerCountryName, buyerCity),
        badgeText: _t('shipping_zone_europe'),
        badgeIcon: Icons.public_rounded,
        color: const Color(0xFF06B6D4),
        bgColor: const Color(0xFFF0FDFF),
        borderColor: const Color(0xFFBAE6FD),
      );
    }

    // ── CAS 7 : Monde entier ──────────────────────────────────────
    return _buildBanner(
      leftWidget: _buildInternationalLeft(
          '🌐', buyerCountryFlag, buyerCountryName, buyerCity),
      badgeText: _t('shipping_zone_world'),
      badgeIcon: Icons.language_rounded,
      color: const Color(0xFF6366F1),
      bgColor: const Color(0xFFEEF2FF),
      borderColor: const Color(0xFFC7D2FE),
    );
  }

  Widget _buildInternationalLeft(String zoneEmoji, String countryFlag,
      String countryName, String city) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(countryFlag, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Flexible(child: Text(countryName,
            style: const TextStyle(fontSize: 14,
                fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            overflow: TextOverflow.ellipsis)),
      ]),
      if (city.isNotEmpty) ...[
        const SizedBox(height: 3),
        Row(children: [
          const Icon(Icons.location_on_rounded,
              size: 11, color: Color(0xFF94A3B8)),
          const SizedBox(width: 3),
          Text(city,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ]),
      ],
    ]);
  }

  Widget _buildBanner({
    required Widget leftWidget,
    required String badgeText,
    required IconData badgeIcon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(children: [
        Expanded(child: leftWidget),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(badgeIcon, size: 11, color: color),
            const SizedBox(width: 5),
            Text(badgeText,
                style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
      ]),
    );
  }

  // ── Carte prix ────────────────────────────────────────────────────

  Widget _buildPriceCard(double price) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: _zoneGradient(effectiveZone),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: _zoneColor(effectiveZone).withOpacity(0.28),
            blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Row(children: [
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_t('shipping_cost_label'),
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(price.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 30,
                        fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(width: 4),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('\$', style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: Colors.white70)),
                ),
              ]),
              if (price == 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_t('shipping_free'),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
            ])),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(_zoneDeliveryIcon(effectiveZone),
              color: Colors.white, size: 24),
        ),
      ]),
    );
  }

  // ── Détail calcul ─────────────────────────────────────────────────

  Widget _buildBreakdown(ShippingZoneRate rate, double total) {
    final color = _zoneColor(effectiveZone);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(children: [
        _breakdownRow(Icons.home_rounded,
            _t('shipping_base_price'),
            '${rate.basePrice.toStringAsFixed(2)} \$'),
        const SizedBox(height: 8),
        _breakdownRow(Icons.scale_rounded,
            '${_t('shipping_per_kg')} × ${productWeight.toStringAsFixed(2)} kg',
            '+ ${(rate.pricePerKg * (productWeight > 1 ? productWeight - 1 : 0)).toStringAsFixed(2)} \$'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1, color: color.withOpacity(0.2)),
        ),
        Row(children: [
          Icon(Icons.summarize_rounded, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(_t('shipping_total_label'),
              style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.bold, color: color))),
          Text('${total.toStringAsFixed(2)} \$',
              style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w900, color: color)),
        ]),
      ]),
    );
  }

  Widget _breakdownRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
      const SizedBox(width: 8),
      Expanded(child: Text(label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
      Text(value,
          style: const TextStyle(fontSize: 12,
              fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
    ]);
  }

  Widget _buildCompanyRow() {
    return Row(children: [
      const Icon(Icons.business_rounded, size: 13, color: Color(0xFF94A3B8)),
      const SizedBox(width: 8),
      Text('${_t('shipping_company_label')} : $shippingCompanyName',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
    ]);
  }

  // ── Non disponible ────────────────────────────────────────────────

  Widget _buildUnavailable() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(buyerCountryFlag, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(child: Text(buyerCountryName,
              style: const TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.location_off_rounded,
                color: Color(0xFFF97316), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_t('shipping_unavailable_title'),
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.bold, color: Color(0xFF9A3412))),
            const SizedBox(height: 4),
            Text(_t('shipping_unavailable_desc'),
                style: const TextStyle(fontSize: 12,
                    color: Color(0xFFC2410C), height: 1.5)),
          ])),
        ]),
        // Affiche la zone concernée
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(effectiveZone.emoji,
                style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(effectiveZone.label(_lang),
                style: const TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF97316))),
          ]),
        ),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────

  Color _zoneColor(ShippingZone zone) {
    switch (zone) {
      case ShippingZone.local:      return const Color(0xFF10B981);
      case ShippingZone.national:   return const Color(0xFF3B82F6);
      case ShippingZone.maghreb:    return const Color(0xFF8B5CF6);
      case ShippingZone.africa:     return const Color(0xFFF59E0B);
      case ShippingZone.middleEast: return const Color(0xFFEF4444);
      case ShippingZone.europe:     return const Color(0xFF06B6D4);
      case ShippingZone.world:      return const Color(0xFF6366F1);
    }
  }

  LinearGradient _zoneGradient(ShippingZone zone) {
    switch (zone) {
      case ShippingZone.local:
        return const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.centerLeft, end: Alignment.centerRight);
      case ShippingZone.national:
        return const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
            begin: Alignment.centerLeft, end: Alignment.centerRight);
      case ShippingZone.maghreb:
        return const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
            begin: Alignment.centerLeft, end: Alignment.centerRight);
      case ShippingZone.africa:
        return const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
            begin: Alignment.centerLeft, end: Alignment.centerRight);
      case ShippingZone.middleEast:
        return const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
            begin: Alignment.centerLeft, end: Alignment.centerRight);
      case ShippingZone.europe:
        return const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
            begin: Alignment.centerLeft, end: Alignment.centerRight);
      case ShippingZone.world:
        return const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
            begin: Alignment.centerLeft, end: Alignment.centerRight);
    }
  }

  // Icône header selon zone
  IconData _zoneIcon(ShippingZone zone) {
    switch (zone) {
      case ShippingZone.local:      return Icons.electric_moped_rounded;
      case ShippingZone.national:   return Icons.local_shipping_rounded;
      case ShippingZone.maghreb:
      case ShippingZone.africa:     return Icons.directions_boat_rounded;
      case ShippingZone.middleEast:
      case ShippingZone.europe:
      case ShippingZone.world:      return Icons.flight_rounded;
    }
  }

  // Icône dans la carte prix
  IconData _zoneDeliveryIcon(ShippingZone zone) {
    switch (zone) {
      case ShippingZone.local:      return Icons.electric_moped_rounded;
      case ShippingZone.national:   return Icons.local_shipping_rounded;
      case ShippingZone.maghreb:
      case ShippingZone.africa:     return Icons.directions_boat_rounded;
      case ShippingZone.middleEast:
      case ShippingZone.europe:
      case ShippingZone.world:      return Icons.flight_takeoff_rounded;
    }
  }
}
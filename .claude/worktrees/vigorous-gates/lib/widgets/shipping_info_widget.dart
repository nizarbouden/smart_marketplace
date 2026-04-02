// lib/views/products/widgets/shipping_info_widget.dart
import 'package:flutter/material.dart';
import '../../../../models/product_model.dart';
import '../../../../models/shipping_zone_model.dart';

/// Widget affiché sur la page détail produit.
/// Affiche la société + fourchette de prix (zone la moins chère → la plus chère).
/// L'acheteur ne connaît pas encore sa zone → on montre l'étendue.
class ShippingInfoWidget extends StatelessWidget {
  final ProductShipping? shipping;

  const ShippingInfoWidget({
    super.key,
    this.shipping,
  });

  @override
  Widget build(BuildContext context) {
    final s = shipping;
    if (s == null || !s.isConfigured) return const SizedBox.shrink();

    final company = ShippingCompanies.findById(s.companyId);
    if (company == null) return const SizedBox.shrink();

    final color    = Color(company.colorValue);
    final weight   = s.weightKg!;

    // ── Fourchette : prix min et max parmi les zones activées ──
    final enabledRates = s.zoneRates.where((r) => r.enabled).toList();
    if (enabledRates.isEmpty) return const SizedBox.shrink();

    final prices  = enabledRates.map((r) => r.calculatePrice(weight)).toList()..sort();
    final minPrice = prices.first;
    final maxPrice = prices.last;
    final samePrice = (minPrice - maxPrice).abs() < 0.01;

    // Nombre de zones activées
    final zoneCount = enabledRates.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── En-tête ──────────────────────────────────────────────
        Row(children: [
          Icon(Icons.local_shipping_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          const Text('Livraison disponible',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B))),
          const Spacer(),
          // Badge nombre de zones
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20)),
            child: Text(
              '$zoneCount zone${zoneCount > 1 ? 's' : ''}',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // ── Carte société + prix ──────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(children: [
            // Logo société
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Center(
                  child: Text(company.logo,
                      style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),

            // Nom + type de service
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(company.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B))),
                      const SizedBox(height: 3),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: Color(ShippingCompanies
                                  .serviceColorValue(company.serviceType))
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            ShippingCompanies.serviceLabel(
                                company.serviceType, 'fr'),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(ShippingCompanies
                                    .serviceColorValue(company.serviceType))),
                          ),
                        ),
                      ]),
                    ])),

            // Fourchette de prix
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                samePrice
                    ? '${minPrice.toStringAsFixed(2)} DT'
                    : '${minPrice.toStringAsFixed(2)} – ${maxPrice.toStringAsFixed(2)} DT',
                style: TextStyle(
                    fontSize: samePrice ? 16 : 14,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
              Text(
                samePrice ? 'livraison' : 'selon destination',
                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 10),

        // ── Détail zones activées ─────────────────────────────────
        _buildZonesList(s, weight, color),

        const SizedBox(height: 10),

        // ── Note poids ────────────────────────────────────────────
        Row(children: [
          Icon(Icons.info_outline_rounded, size: 13, color: Colors.grey[400]),
          const SizedBox(width: 6),
          Expanded(
              child: Text(
                'Poids du produit : ${weight.toStringAsFixed(2)} kg',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              )),
        ]),
      ]),
    );
  }

  Widget _buildZonesList(ProductShipping s, double weight, Color color) {
    final enabled = s.zoneRates.where((r) => r.enabled).toList();
    if (enabled.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Zones desservies',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500])),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: enabled.map((rate) {
            final price = rate.calculatePrice(weight);
            return Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.15))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(rate.zone.emoji,
                    style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                Text(rate.zone.labelFr(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700])),
                const SizedBox(width: 4),
                Text('${price.toStringAsFixed(0)} DT',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ]),
            );
          }).toList(),
        ),
      ],
    );
  }
}
// lib/models/shipping_company_model.dart

class ShippingCompany {
  final String id;
  final String name;
  final String logo;        // emoji
  final int    colorValue;  // Color int value
  final double basePrice;   // prix de base DT (jusqu'à 1 kg)
  final double pricePerKg;  // prix par kg supplémentaire
  final String estimatedDays;

  const ShippingCompany({
    required this.id,
    required this.name,
    required this.logo,
    required this.colorValue,
    required this.basePrice,
    required this.pricePerKg,
    required this.estimatedDays,
  });

  /// Calcule le prix selon le poids (kg)
  double calculatePrice(double weightKg) {
    if (weightKg <= 1.0) return basePrice;
    return basePrice + (weightKg - 1.0) * pricePerKg;
  }
}

/// Liste fixe des 4 sociétés de livraison disponibles
class ShippingCompanies {
  static const List<ShippingCompany> all = [
    ShippingCompany(
      id:            'dhl',
      name:          'DHL Express',
      logo:          '🟡',
      colorValue:    0xFFD97706, // amber-600
      basePrice:     12.0,
      pricePerKg:    4.5,
      estimatedDays: '1-2 jours',
    ),
    ShippingCompany(
      id:            'aramex',
      name:          'Aramex',
      logo:          '🔴',
      colorValue:    0xFFDC2626, // red-600
      basePrice:     8.0,
      pricePerKg:    3.0,
      estimatedDays: '2-3 jours',
    ),
    ShippingCompany(
      id:            'rapid_poste',
      name:          'Rapid Poste',
      logo:          '🟢',
      colorValue:    0xFF16A34A, // green-600
      basePrice:     5.0,
      pricePerKg:    2.0,
      estimatedDays: '3-5 jours',
    ),
    ShippingCompany(
      id:            'fedex',
      name:          'FedEx',
      logo:          '🟣',
      colorValue:    0xFF7C3AED, // violet-600
      basePrice:     15.0,
      pricePerKg:    5.0,
      estimatedDays: '1-2 jours',
    ),
  ];

  static ShippingCompany? findById(String? id) {
    if (id == null) return null;
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
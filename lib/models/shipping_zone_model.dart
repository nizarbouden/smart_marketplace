// lib/models/shipping_zone_model.dart
import 'countries.dart'; // ✅ source de vérité pour les pays

// ─────────────────────────────────────────────────────────────
//  ZONES GÉOGRAPHIQUES
// ─────────────────────────────────────────────────────────────

enum ShippingZone {
  local,       // même ville que le vendeur
  national,    // même pays que le vendeur (hors ville locale)
  maghreb,     // Tunisie, Algérie, Maroc, Libye, Mauritanie
  africa,      // Reste de l'Afrique (hors Maghreb)
  middleEast,  // Moyen-Orient
  europe,      // Europe
  world,       // Tous les autres pays
}

extension ShippingZoneExt on ShippingZone {
  String get id {
    switch (this) {
      case ShippingZone.local:      return 'local';
      case ShippingZone.national:   return 'national';
      case ShippingZone.maghreb:    return 'maghreb';
      case ShippingZone.africa:     return 'africa';
      case ShippingZone.middleEast: return 'middle_east';
      case ShippingZone.europe:     return 'europe';
      case ShippingZone.world:      return 'world';
    }
  }

  String get emoji {
    switch (this) {
      case ShippingZone.local:      return '📍';
      case ShippingZone.national:   return '🏠';
      case ShippingZone.maghreb:    return '🌍';
      case ShippingZone.africa:     return '🌍';
      case ShippingZone.middleEast: return '🕌';
      case ShippingZone.europe:     return '🇪🇺';
      case ShippingZone.world:      return '🌐';
    }
  }

  String labelFr() {
    switch (this) {
      case ShippingZone.local:      return 'Local';
      case ShippingZone.national:   return 'National';
      case ShippingZone.maghreb:    return 'Maghreb';
      case ShippingZone.africa:     return 'Afrique';
      case ShippingZone.middleEast: return 'Moyen-Orient';
      case ShippingZone.europe:     return 'Europe';
      case ShippingZone.world:      return 'Monde entier';
    }
  }

  String descFr() {
    switch (this) {
      case ShippingZone.local:      return 'Même ville que votre boutique';
      case ShippingZone.national:   return 'Même pays que votre boutique (hors ville locale)';
      case ShippingZone.maghreb:    return 'TN · DZ · MA · LY · MR';
      case ShippingZone.africa:     return 'Reste du continent africain';
      case ShippingZone.middleEast: return 'SA · AE · QA · KW · EG · TR …';
      case ShippingZone.europe:     return 'FR · DE · GB · IT · ES …';
      case ShippingZone.world:      return 'Tous les autres pays';
    }
  }

  String labelEn() {
    switch (this) {
      case ShippingZone.local:      return 'Local';
      case ShippingZone.national:   return 'National';
      case ShippingZone.maghreb:    return 'Maghreb';
      case ShippingZone.africa:     return 'Africa';
      case ShippingZone.middleEast: return 'Middle East';
      case ShippingZone.europe:     return 'Europe';
      case ShippingZone.world:      return 'Worldwide';
    }
  }

  String descEn() {
    switch (this) {
      case ShippingZone.local:      return 'Same city as your store';
      case ShippingZone.national:   return 'Same country as your store (outside local city)';
      case ShippingZone.maghreb:    return 'TN · DZ · MA · LY · MR';
      case ShippingZone.africa:     return 'Rest of the African continent';
      case ShippingZone.middleEast: return 'SA · AE · QA · KW · EG · TR …';
      case ShippingZone.europe:     return 'FR · DE · GB · IT · ES …';
      case ShippingZone.world:      return 'All other countries';
    }
  }

  String labelAr() {
    switch (this) {
      case ShippingZone.local:      return 'محلي';
      case ShippingZone.national:   return 'وطني';
      case ShippingZone.maghreb:    return 'المغرب العربي';
      case ShippingZone.africa:     return 'أفريقيا';
      case ShippingZone.middleEast: return 'الشرق الأوسط';
      case ShippingZone.europe:     return 'أوروبا';
      case ShippingZone.world:      return 'العالم';
    }
  }

  String descAr() {
    switch (this) {
      case ShippingZone.local:      return 'نفس مدينة متجرك';
      case ShippingZone.national:   return 'نفس بلد متجرك (خارج المدينة المحلية)';
      case ShippingZone.maghreb:    return 'TN · DZ · MA · LY · MR';
      case ShippingZone.africa:     return 'بقية القارة الأفريقية';
      case ShippingZone.middleEast: return 'SA · AE · QA · KW · EG · TR …';
      case ShippingZone.europe:     return 'FR · DE · GB · IT · ES …';
      case ShippingZone.world:      return 'جميع الدول الأخرى';
    }
  }

  String label(String langCode) {
    switch (langCode) {
      case 'ar': return labelAr();
      case 'en': return labelEn();
      default:   return labelFr();
    }
  }

  String desc(String langCode) {
    switch (langCode) {
      case 'ar': return descAr();
      case 'en': return descEn();
      default:   return descFr();
    }
  }

  static ShippingZone fromId(String id) {
    return ShippingZone.values.firstWhere(
          (z) => z.id == id,
      orElse: () => ShippingZone.world,
    );
  }

  /// Liste des pays inclus dans chaque zone (codes ISO 3166-1 alpha-2)
  static const Map<String, List<String>> _zoneCountries = {
    'maghreb':     ['TN', 'DZ', 'MA', 'LY', 'MR'],
    'africa':      ['EG', 'SN', 'CI', 'GH', 'NG', 'CM', 'KE', 'ET', 'TZ', 'UG',
      'ZA', 'AO', 'MZ', 'ZM', 'ZW', 'SD', 'SS', 'ML', 'BF', 'NE',
      'TD', 'SO', 'DJ', 'ER', 'RW', 'BI', 'MW', 'BJ', 'TG', 'GN',
      'SL', 'LR', 'GM', 'GW', 'CV', 'ST', 'GQ', 'GA', 'CG', 'CD',
      'CF', 'MG', 'MU', 'SC', 'KM', 'NA', 'BW', 'LS', 'SZ'],
    'middle_east': ['SA', 'AE', 'QA', 'KW', 'BH', 'OM', 'YE', 'IQ', 'SY', 'LB',
      'JO', 'PS', 'IL', 'IR', 'TR', 'AF'],
    'europe':      ['FR', 'DE', 'IT', 'ES', 'PT', 'BE', 'NL', 'LU', 'AT', 'CH',
      'GB', 'IE', 'DK', 'SE', 'NO', 'FI', 'IS', 'PL', 'CZ', 'SK',
      'HU', 'RO', 'BG', 'HR', 'SI', 'BA', 'RS', 'ME', 'MK', 'AL',
      'GR', 'CY', 'MT', 'EE', 'LV', 'LT', 'UA', 'MD', 'BY', 'RU',
      'GE', 'AM', 'AZ'],
  };

  /// Retourne la zone correspondant à un code pays ISO (ex: 'TN', 'FR')
  static ShippingZone zoneForCountry(String countryCode) {
    for (final entry in _zoneCountries.entries) {
      if (entry.value.contains(countryCode.toUpperCase())) {
        return ShippingZoneExt.fromId(entry.key);
      }
    }
    return ShippingZone.world;
  }

  /// Extrait le code ISO alpha-2 depuis un emoji drapeau (Regional Indicator Symbols).
  ///
  /// Chaque caractère indicateur régional est un code point Unicode dans la
  /// plage 0x1F1E6 (🇦) à 0x1F1FF (🇿).
  /// Pour obtenir la lettre : codePoint - 0x1F1E6 + 0x41 ('A')
  ///
  /// ✅ Exemples : 🇹🇳 → 'TN', 🇫🇷 → 'FR', 🇦🇫 → 'AF'
  ///
  /// ⚠️ Bug corrigé : l'ancienne formule utilisait (0x1F1E6 - 0x41) comme base
  /// puis ajoutait encore 0x41, ce qui décalait doublement le résultat → null.
  static String? isoFromFlag(String flag) {
    // Filtrer uniquement les Regional Indicator Symbols (0x1F1E6–0x1F1FF)
    // pour ignorer les caractères invisibles (ZWJ, variation selectors, etc.)
    final indicators = flag.runes
        .where((r) => r >= 0x1F1E6 && r <= 0x1F1FF)
        .toList();

    if (indicators.length < 2) return null;

    final c1 = indicators[0] - 0x1F1E6; // 0 = A, 1 = B, ..., 25 = Z
    final c2 = indicators[1] - 0x1F1E6;

    if (c1 < 0 || c1 > 25 || c2 < 0 || c2 > 25) return null;

    return String.fromCharCode(c1 + 0x41) + String.fromCharCode(c2 + 0x41);
  }

  /// Retourne la zone à partir du nom de pays stocké dans Firestore (countryName).
  static ShippingZone zoneForCountryName(String countryName) {
    final country = CountryData.findCountryByName(countryName);
    if (country == null) return ShippingZone.world;
    final iso = isoFromFlag(country['flag'] ?? '');
    if (iso == null) return ShippingZone.world;
    return zoneForCountry(iso);
  }
}

// ─────────────────────────────────────────────────────────────
//  TARIF PAR ZONE  (défini par le vendeur pour 1 produit)
// ─────────────────────────────────────────────────────────────

class ShippingZoneRate {
  final ShippingZone zone;
  final bool   enabled;
  final double basePrice;
  final double pricePerKg;

  const ShippingZoneRate({
    required this.zone,
    required this.enabled,
    required this.basePrice,
    required this.pricePerKg,
  });

  double calculatePrice(double weightKg) {
    if (!enabled) return 0;
    if (weightKg <= 1.0) return basePrice;
    return basePrice + (weightKg - 1.0) * pricePerKg;
  }

  Map<String, dynamic> toMap() => {
    'zone':        zone.id,
    'enabled':     enabled,
    'basePrice':   basePrice,
    'pricePerKg':  pricePerKg,
  };

  factory ShippingZoneRate.fromMap(Map<String, dynamic> m) => ShippingZoneRate(
    zone:       ShippingZoneExt.fromId(m['zone'] as String? ?? 'world'),
    enabled:    m['enabled']    as bool?   ?? false,
    basePrice:  (m['basePrice']  as num?   ?? 0).toDouble(),
    pricePerKg: (m['pricePerKg'] as num?   ?? 0).toDouble(),
  );

  ShippingZoneRate copyWith({
    bool?   enabled,
    double? basePrice,
    double? pricePerKg,
  }) => ShippingZoneRate(
    zone:       zone,
    enabled:    enabled    ?? this.enabled,
    basePrice:  basePrice  ?? this.basePrice,
    pricePerKg: pricePerKg ?? this.pricePerKg,
  );
}

// ─────────────────────────────────────────────────────────────
//  SOCIÉTÉS DE LIVRAISON INTERNATIONALES
// ─────────────────────────────────────────────────────────────

class ShippingCompany {
  final String id;
  final String name;
  final String logo;
  final int    colorValue;
  final String serviceType;
  final List<ShippingZone> coveredZones;

  const ShippingCompany({
    required this.id,
    required this.name,
    required this.logo,
    required this.colorValue,
    required this.serviceType,
    required this.coveredZones,
  });
}

class ShippingCompanies {
  static const List<ShippingCompany> all = [
    ShippingCompany(
      id:          'dhl',
      name:        'DHL Express',
      logo:        '🟡',
      colorValue:  0xFFD97706,
      serviceType: 'express',
      coveredZones: ShippingZone.values,
    ),
    ShippingCompany(
      id:          'fedex',
      name:        'FedEx',
      logo:        '🟣',
      colorValue:  0xFF7C3AED,
      serviceType: 'express',
      coveredZones: ShippingZone.values,
    ),
    ShippingCompany(
      id:          'ups',
      name:        'UPS',
      logo:        '🟤',
      colorValue:  0xFF92400E,
      serviceType: 'standard',
      coveredZones: ShippingZone.values,
    ),
    ShippingCompany(
      id:          'aramex',
      name:        'Aramex',
      logo:        '🔴',
      colorValue:  0xFFDC2626,
      serviceType: 'standard',
      coveredZones: [
        ShippingZone.local, ShippingZone.national,
        ShippingZone.maghreb, ShippingZone.africa,
        ShippingZone.middleEast, ShippingZone.europe,
        ShippingZone.world,
      ],
    ),
    ShippingCompany(
      id:          'rapid_poste',
      name:        'Rapid Poste',
      logo:        '🟢',
      colorValue:  0xFF16A34A,
      serviceType: 'economy',
      coveredZones: [
        ShippingZone.local, ShippingZone.national,
        ShippingZone.maghreb,
      ],
    ),
    ShippingCompany(
      id:          'tunisie_poste',
      name:        'Tunisie Poste',
      logo:        '📮',
      colorValue:  0xFF0369A1,
      serviceType: 'economy',
      coveredZones: ShippingZone.values,
    ),
    ShippingCompany(
      id:          'glovo',
      name:        'Glovo / Local',
      logo:        '🛵',
      colorValue:  0xFFEA580C,
      serviceType: 'express',
      coveredZones: [ShippingZone.local],
    ),
    ShippingCompany(
      id:          'other',
      name:        'Autre transporteur',
      logo:        '📦',
      colorValue:  0xFF64748B,
      serviceType: 'standard',
      coveredZones: ShippingZone.values,
    ),
  ];

  static ShippingCompany? findById(String? id) {
    if (id == null) return null;
    try { return all.firstWhere((c) => c.id == id); } catch (_) { return null; }
  }

  static String serviceLabel(String type, String lang) {
    switch (type) {
      case 'express':  return lang == 'ar' ? 'سريع'    : lang == 'en' ? 'Express'  : 'Express';
      case 'standard': return lang == 'ar' ? 'عادي'    : lang == 'en' ? 'Standard' : 'Standard';
      case 'economy':  return lang == 'ar' ? 'اقتصادي' : lang == 'en' ? 'Economy'  : 'Économique';
      default: return type;
    }
  }

  static int serviceColorValue(String type) {
    switch (type) {
      case 'express':  return 0xFFDC2626;
      case 'standard': return 0xFF2563EB;
      case 'economy':  return 0xFF16A34A;
      default:         return 0xFF64748B;
    }
  }
}
// lib/models/product_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'shipping_zone_model.dart';

class Reward {
  final String? image;
  final String? name;

  Reward({this.image, this.name});

  factory Reward.fromMap(Map<String, dynamic> map) => Reward(
    image: map['image'] as String?,
    name:  map['name']  as String?,
  );

  Map<String, dynamic> toMap() => {'image': image, 'name': name};
}

// ─────────────────────────────────────────────────────────────
//  SHIPPING CONFIG — remplace les anciens champs plats
// ─────────────────────────────────────────────────────────────

class ProductShipping {
  final String?               companyId;    // 'dhl' | 'aramex' | ...
  final double?               weightKg;     // poids du produit
  final List<ShippingZoneRate> zoneRates;   // tarifs par zone

  const ProductShipping({
    this.companyId,
    this.weightKg,
    this.zoneRates = const [],
  });

  bool get isConfigured =>
      companyId != null &&
          weightKg  != null &&
          zoneRates.any((r) => r.enabled);

  /// Calcule le prix pour une zone donnée
  double? priceForZone(ShippingZone zone) {
    if (weightKg == null) return null;
    final rate = zoneRates.where((r) => r.zone == zone && r.enabled)
        .firstOrNull;
    return rate?.calculatePrice(weightKg!);
  }

  /// Calcule le prix pour un pays donné (via son code ISO)
  double? priceForCountry(String countryCode) {
    final zone = ShippingZoneExt.zoneForCountry(countryCode);
    return priceForZone(zone);
  }

  Map<String, dynamic> toMap() => {
    'companyId': companyId,
    'weightKg':  weightKg,
    'zoneRates': zoneRates.map((r) => r.toMap()).toList(),
  };

  factory ProductShipping.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const ProductShipping();
    final ratesRaw = m['zoneRates'] as List<dynamic>? ?? [];
    return ProductShipping(
      companyId: m['companyId'] as String?,
      weightKg:  (m['weightKg'] as num?)?.toDouble(),
      zoneRates: ratesRaw
          .map((r) => ShippingZoneRate.fromMap(r as Map<String, dynamic>))
          .toList(),
    );
  }

  // ── Compat descendante avec les anciens champs Firestore ─────
  factory ProductShipping.fromLegacy({
    String? shippingCompanyId,
    double? productWeight,
  }) {
    if (shippingCompanyId == null && productWeight == null) {
      return const ProductShipping();
    }
    // Génère des zones par défaut pour les anciens produits
    final rates = ShippingZone.values.map((z) => ShippingZoneRate(
      zone:       z,
      enabled:    z == ShippingZone.local || z == ShippingZone.national,
      basePrice:  _legacyBase(z),
      pricePerKg: _legacyPerKg(z),
    )).toList();

    return ProductShipping(
      companyId: shippingCompanyId,
      weightKg:  productWeight,
      zoneRates: rates,
    );
  }

  static double _legacyBase(ShippingZone z) {
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
  static double _legacyPerKg(ShippingZone z) {
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
}

// ─────────────────────────────────────────────────────────────
//  PRODUCT MODEL
// ─────────────────────────────────────────────────────────────

class Product {
  final String   id;
  final String   name;
  final double   price;
  final String   category;
  final String   description;
  final List<String> images;
  final bool     isActive;
  final String   status;
  final int      stock;
  final int?     initialStock;
  final String   sellerId;
  final Reward?  reward;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? visibleAt;
  final double?   discountPercent;
  final DateTime? discountEndsAt;
  final DateTime? hiddenAfterAt;

  // ✅ Nouveau champ shipping unifié
  final ProductShipping shipping;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.description,
    required this.images,
    required this.isActive,
    required this.status,
    required this.stock,
    this.initialStock,
    required this.sellerId,
    this.reward,
    this.createdAt,
    this.updatedAt,
    this.visibleAt,
    this.discountPercent,
    this.discountEndsAt,
    this.hiddenAfterAt,
    this.shipping = const ProductShipping(),
  });

  bool get isDiscountActive {
    if (discountPercent == null || discountPercent! <= 0) return false;
    if (discountEndsAt  == null) return true;
    return DateTime.now().isBefore(discountEndsAt!);
  }

  double get discountedPrice {
    if (!isDiscountActive) return price;
    return price * (1 - discountPercent! / 100);
  }

  bool get shouldBeHidden {
    if (hiddenAfterAt == null) return false;
    return DateTime.now().isAfter(hiddenAfterAt!);
  }

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    // ── Shipping : nouveau format ou legacy ──────────────────
    late ProductShipping shipping;
    if (d.containsKey('shipping') && d['shipping'] is Map) {
      shipping = ProductShipping.fromMap(
          d['shipping'] as Map<String, dynamic>);
    } else {
      // Compat anciens documents avec shippingCompanyId / productWeight
      shipping = ProductShipping.fromLegacy(
        shippingCompanyId: d['shippingCompanyId'] as String?,
        productWeight:     (d['productWeight'] as num?)?.toDouble(),
      );
    }

    return Product(
      id:              doc.id,
      name:            d['name']            as String? ?? '',
      price:           (d['price']          as num?    ?? 0).toDouble(),
      category:        d['category']        as String? ?? '',
      description:     d['description']     as String? ?? '',
      images:          List<String>.from(d['images'] ?? []),
      isActive:        d['isActive']        as bool?   ?? false,
      status:          d['status']          as String? ?? '',
      stock:           (d['stock']          as num?    ?? 0).toInt(),
      initialStock:    (d['initialStock']   as num?)?.toInt(),
      sellerId:        d['sellerId']        as String? ?? '',
      reward:          d['reward'] != null
          ? Reward.fromMap(d['reward'] as Map<String, dynamic>)
          : null,
      createdAt:       (d['createdAt']      as Timestamp?)?.toDate(),
      updatedAt:       (d['updatedAt']      as Timestamp?)?.toDate(),
      visibleAt:       (d['visibleAt']      as Timestamp?)?.toDate(),
      discountPercent: (d['discountPercent'] as num?)?.toDouble(),
      discountEndsAt:  (d['discountEndsAt'] as Timestamp?)?.toDate(),
      hiddenAfterAt:   (d['hiddenAfterAt']  as Timestamp?)?.toDate(),
      shipping:        shipping,
    );
  }
}
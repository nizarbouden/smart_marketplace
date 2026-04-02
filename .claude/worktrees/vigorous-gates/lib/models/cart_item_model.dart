import '../models/shipping_zone_model.dart';

class CartItemModel {
  final String       productId;
  final String       cartDocId;
  final String       name;
  final double       price;
  final int          stock;
  final String       sellerId;
  final String       storeName;
  final List<String> images;
  int                quantity;
  bool               isSelected;

  // ✅ Champs livraison
  List<ShippingZoneRate> zoneRates;
  double                 weightKg;
  String?                companyId;  // ✅ société de livraison choisie par le vendeur

  CartItemModel({
    required this.productId,
    required this.cartDocId,
    required this.name,
    required this.price,
    required this.stock,
    required this.sellerId,
    required this.storeName,
    required this.images,
    required this.quantity,
    this.isSelected = false,
    this.zoneRates  = const [],
    this.weightKg   = 1.0,
    this.companyId,
  });

  // ✅ Vérifie si la livraison est disponible pour une zone
  bool canDeliverTo(ShippingZone zone) {
    if (zoneRates.isEmpty) return false;
    final rate = zoneRates.where((r) => r.zone == zone).firstOrNull;
    return rate != null && rate.enabled;
  }

  // ✅ Prix unitaire de livraison (1 article, sans quantité)
  double? shippingUnitPrice(ShippingZone zone) {
    if (zoneRates.isEmpty) return null;
    final rate = zoneRates.where((r) => r.zone == zone).firstOrNull;
    if (rate == null || !rate.enabled) return null;
    return rate.calculatePrice(weightKg);
  }

  // ✅ Prix total de livraison × quantité
  double? shippingPrice(ShippingZone zone) {
    final unit = shippingUnitPrice(zone);
    if (unit == null) return null;
    return unit * quantity;
  }

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'cartDocId': cartDocId,
    'name':      name,
    'price':     price,
    'stock':     stock,
    'sellerId':  sellerId,
    'storeName': storeName,
    'images':    images,
    'quantity':  quantity,
    'companyId': companyId,  // ✅ AJOUT
  };

  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    return CartItemModel(
      productId: map['productId'] as String? ?? '',
      cartDocId: map['cartDocId'] as String? ?? '',
      name:      map['name']      as String? ?? '',
      price:     (map['price']    as num?)?.toDouble() ?? 0.0,
      stock:     map['stock']     as int?    ?? 0,
      sellerId:  map['sellerId']  as String? ?? '',
      storeName: map['storeName'] as String? ?? '',
      images:    List<String>.from(map['images'] ?? []),
      quantity:  map['quantity']  as int?    ?? 1,
      companyId: map['companyId'] as String?,  // ✅ AJOUT
    );
  }
}
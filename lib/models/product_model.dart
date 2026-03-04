import 'package:cloud_firestore/cloud_firestore.dart';

class Reward {
  final String? image;
  final String? name;

  Reward({this.image, this.name});

  factory Reward.fromMap(Map<String, dynamic> map) => Reward(
    image: map['image'] as String?,
    name: map['name'] as String?,
  );

  Map<String, dynamic> toMap() => {'image': image, 'name': name};
}

class Product {
  final String id;
  final String name;
  final double price;
  final String category;
  final String description;
  final List<String> images;
  final bool isActive;
  final String status;
  final int stock;
  final int? initialStock;
  final String sellerId;
  final Reward? reward;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? visibleAt;
  final double? discountPercent;
  final DateTime? discountEndsAt;

  // ✅ Timer masquage automatique : produit masqué APRÈS cette date
  final DateTime? hiddenAfterAt;

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
  });

  // ✅ Remise encore active ?
  bool get isDiscountActive {
    if (discountPercent == null || discountPercent! <= 0) return false;
    if (discountEndsAt == null) return true;
    return DateTime.now().isBefore(discountEndsAt!);
  }

  // ✅ Prix effectif : applique la remise SEULEMENT si encore active,
  //    sinon retourne le prix original
  double get discountedPrice {
    if (!isDiscountActive) return price;
    return price * (1 - discountPercent! / 100);
  }

  // ✅ Le produit doit-il être masqué automatiquement ?
  bool get shouldBeHidden {
    if (hiddenAfterAt == null) return false;
    return DateTime.now().isAfter(hiddenAfterAt!);
  }

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Product(
      id:              doc.id,
      name:            d['name']            as String?  ?? '',
      price:           (d['price']          as num?     ?? 0).toDouble(),
      category:        d['category']        as String?  ?? '',
      description:     d['description']     as String?  ?? '',
      images:          List<String>.from(d['images'] ?? []),
      isActive:        d['isActive']        as bool?    ?? false,
      status:          d['status']          as String?  ?? '',
      stock:           (d['stock']          as num?     ?? 0).toInt(),
      initialStock:    (d['initialStock']   as num?)?.toInt(),
      sellerId:        d['sellerId']        as String?  ?? '',
      reward:          d['reward'] != null
          ? Reward.fromMap(d['reward'] as Map<String, dynamic>)
          : null,
      createdAt:       (d['createdAt']       as Timestamp?)?.toDate(),
      updatedAt:       (d['updatedAt']       as Timestamp?)?.toDate(),
      visibleAt:       (d['visibleAt']       as Timestamp?)?.toDate(),
      discountPercent: (d['discountPercent'] as num?)?.toDouble(),
      discountEndsAt:  (d['discountEndsAt']  as Timestamp?)?.toDate(),
      // ✅ Nouveau champ
      hiddenAfterAt:   (d['hiddenAfterAt']   as Timestamp?)?.toDate(),
    );
  }
}
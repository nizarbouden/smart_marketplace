import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────
//  SUB ORDER MODEL
//  Firestore : orders/{parentOrderId}/subOrders/{subOrderId}
// ─────────────────────────────────────────────────────────────────

class SubOrderModel {
  final String    subOrderId;
  final String    parentOrderId;
  final String    userId;
  final String    sellerId;
  final String    storeName;
  final String    productId;
  final String    name;
  final double    price;
  final int       quantity;
  final List<String> images;
  final String    shippingMethod;   // ex: "express", "standard", "pickup"
  final double    shippingCost;
  final String    shippingZone;     // ex: "local", "national", "international"
  final DateTime? estimatedDateMin;   // date au plus tôt
  final DateTime? estimatedDateMax;   // date au plus tard
  final String    estimatedDelayLabel; // ex: "3–5 jours"
  final String    status;           // paid | shipping | delivered | cancelled
  final DateTime  createdAt;
  final DateTime? updatedAt;

  const SubOrderModel({
    required this.subOrderId,
    required this.parentOrderId,
    required this.userId,
    required this.sellerId,
    required this.storeName,
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.images,
    required this.shippingMethod,
    required this.shippingCost,
    required this.shippingZone,
    required this.estimatedDateMin,
    required this.estimatedDateMax,
    required this.estimatedDelayLabel,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  double get subtotal => price * quantity;
  double get total    => subtotal + shippingCost;

  // ── Firestore → Model ──────────────────────────────────────────
  factory SubOrderModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SubOrderModel(
      subOrderId:     doc.id,
      parentOrderId:  d['parentOrderId']  as String?   ?? '',
      userId:         d['userId']         as String?   ?? '',
      sellerId:       d['sellerId']       as String?   ?? '',
      storeName:      d['storeName']      as String?   ?? '',
      productId:      d['productId']      as String?   ?? '',
      name:           d['name']           as String?   ?? '',
      price:          (d['price']         as num?)?.toDouble() ?? 0.0,
      quantity:       (d['quantity']      as num?)?.toInt()    ?? 1,
      images:         List<String>.from(d['images'] ?? []),
      shippingMethod: d['shippingMethod'] as String?   ?? '',
      shippingCost:   (d['shippingCost']  as num?)?.toDouble() ?? 0.0,
      shippingZone:   d['shippingZone']   as String?   ?? '',
      estimatedDateMin:    (d['estimatedDateMin'] as Timestamp?)?.toDate(),
      estimatedDateMax:    (d['estimatedDateMax'] as Timestamp?)?.toDate(),
      estimatedDelayLabel: d['estimatedDelayLabel'] as String? ?? '—',
      status:         d['status']         as String?   ?? 'paid',
      createdAt:      (d['createdAt']     as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:      (d['updatedAt']     as Timestamp?)?.toDate(),
    );
  }

  // ── Model → Firestore ──────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'parentOrderId':  parentOrderId,
    'userId':         userId,
    'sellerId':       sellerId,
    'storeName':      storeName,
    'productId':      productId,
    'name':           name,
    'price':          price,
    'quantity':       quantity,
    'images':         images,
    'shippingMethod': shippingMethod,
    'shippingCost':   shippingCost,
    'shippingZone':   shippingZone,
    'estimatedDateMin':    estimatedDateMin != null
        ? Timestamp.fromDate(estimatedDateMin!) : null,
    'estimatedDateMax':    estimatedDateMax != null
        ? Timestamp.fromDate(estimatedDateMax!) : null,
    'estimatedDelayLabel': estimatedDelayLabel,
    'status':   status,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
  };

  SubOrderModel copyWith({String? status, DateTime? updatedAt}) {
    return SubOrderModel(
      subOrderId:     subOrderId,
      parentOrderId:  parentOrderId,
      userId:         userId,
      sellerId:       sellerId,
      storeName:      storeName,
      productId:      productId,
      name:           name,
      price:          price,
      quantity:       quantity,
      images:         images,
      shippingMethod: shippingMethod,
      shippingCost:   shippingCost,
      shippingZone:   shippingZone,
      estimatedDateMin:    estimatedDateMin,
      estimatedDateMax:    estimatedDateMax,
      estimatedDelayLabel: estimatedDelayLabel,
      status:         status         ?? this.status,
      createdAt:      createdAt,
      updatedAt:      updatedAt      ?? this.updatedAt,
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cart_item_model.dart';
import '../models/address_model.dart';
import '../models/shipping_zone_model.dart';

class CreateOrderService {
  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;

  Future<String> createOrder({
    required List<CartItemModel> items,
    required AddressModel        address,
    required String              paymentMethod,
    required ShippingZone        zone,
  }) async {
    final uid      = _auth.currentUser!.uid;
    final parentRef = _firestore.collection('orders').doc();
    final parentId  = parentRef.id;

    double totalProducts = 0;
    double totalShipping = 0;

    for (final item in items) {
      totalProducts += item.price * item.quantity;
      totalShipping += item.shippingPrice(zone) ?? 0.0;
    }

    final grandTotal = totalProducts + totalShipping;

    final parentData = {
      'id':              parentId,
      'userId':          uid,
      'sellerIds':       items.map((i) => i.sellerId).toSet().toList(),
      'address':         address.toMap(),
      'paymentMethod':   paymentMethod,
      'paymentStatus':   'paid',
      'totalProducts':   totalProducts,
      'totalShipping':   totalShipping,
      'grandTotal':      grandTotal,
      'shippingZone':    zone.name,
      'subOrdersCount':  items.length,
      'createdAt':       Timestamp.now(),
    };

    final subOrdersData = items.map((item) {
      final subRef   = parentRef.collection('subOrders').doc();
      final unitShip = item.shippingPrice(zone) ?? 0.0;

      return MapEntry(subRef, {
        'parentOrderId':  parentId,
        'userId':         uid,
        'sellerId':       item.sellerId,
        'storeName':      item.storeName,
        'productId':      item.productId,
        'name':           item.name,
        'price':          item.price,
        'quantity':       item.quantity,
        'images':         item.images,
        // ✅ companyId du vendeur (ex: "fedex", "dhl") ou fallback zone.id
        'shippingMethod': _shippingMethodName(item, zone),
        'shippingCost':   unitShip,
        'shippingZone':   zone.name,
        'estimatedDateMin': _estimatedDateMin(zone) != null
            ? Timestamp.fromDate(_estimatedDateMin(zone)!) : null,
        'estimatedDateMax': _estimatedDateMax(zone) != null
            ? Timestamp.fromDate(_estimatedDateMax(zone)!) : null,
        'estimatedDelayLabel': '${_zoneDelays[zone]?.$1}–${_zoneDelays[zone]?.$2}',
        'status':         'paid',
        'createdAt':      Timestamp.now(),
        'updatedAt':      null,
      });
    }).toList();

    final batch = _firestore.batch();

    batch.set(parentRef, parentData);
    batch.set(
      _firestore.collection('users').doc(uid).collection('orders').doc(parentId),
      parentData,
    );
    for (final entry in subOrdersData) {
      batch.set(entry.key, entry.value);
    }
    for (final item in items) {
      batch.delete(
        _firestore.collection('users').doc(uid)
            .collection('cart').doc(item.cartDocId),
      );
    }

    await batch.commit();
    await _decrementStock(items);

    return parentId;
  }

  Future<void> _decrementStock(List<CartItemModel> items) async {
    final batch = _firestore.batch();
    for (final item in items) {
      final ref  = _firestore.collection('products').doc(item.productId);
      final snap = await ref.get();
      if (!snap.exists) continue;
      final data = snap.data()!;
      final cur  = (data['stock'] as num?)?.toInt() ?? 0;
      final upd  = <String, dynamic>{
        'stock':     (cur - item.quantity).clamp(0, cur),
        'updatedAt': Timestamp.now(),
      };
      if (data['initialStock'] == null) upd['initialStock'] = cur;
      batch.update(ref, upd);
    }
    await batch.commit();
  }

  // ✅ Utilise companyId du vendeur en priorité
  String _shippingMethodName(CartItemModel item, ShippingZone zone) {
    if (item.companyId != null && item.companyId!.isNotEmpty) {
      return item.companyId!;  // ex: "fedex", "dhl", "tunisie_poste"
    }
    return zone.id;  // fallback: "national", "local"...
  }

  static const Map<ShippingZone, (int min, int max)> _zoneDelays = {
    ShippingZone.local:      (1, 2),
    ShippingZone.national:   (3, 5),
    ShippingZone.maghreb:    (5, 7),
    ShippingZone.africa:     (7, 10),
    ShippingZone.middleEast: (7, 10),
    ShippingZone.europe:     (10, 14),
    ShippingZone.world:      (14, 21),
  };

  DateTime? _estimatedDateMin(ShippingZone zone) {
    final delay = _zoneDelays[zone];
    if (delay == null) return null;
    return DateTime.now().add(Duration(days: delay.$1));
  }

  DateTime? _estimatedDateMax(ShippingZone zone) {
    final delay = _zoneDelays[zone];
    if (delay == null) return null;
    return DateTime.now().add(Duration(days: delay.$2));
  }

  static String shippingDelayLabel(ShippingZone zone) {
    final delay = _zoneDelays[zone];
    if (delay == null) return '—';
    if (delay.$1 == delay.$2) return '${delay.$1} jour${delay.$1 > 1 ? 's' : ''}';
    return '${delay.$1}–${delay.$2} jours';
  }
}
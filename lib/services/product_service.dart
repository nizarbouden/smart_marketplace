import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';


class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Product>> getApprovedProducts() {
    return _firestore
        .collection('products')
        .where('status', isEqualTo: 'approved')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList());
  }
}
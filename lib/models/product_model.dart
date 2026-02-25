import 'package:cloud_firestore/cloud_firestore.dart';

class Reward {
  final String? image; // base64
  final String? name;

  Reward({this.image, this.name});

  factory Reward.fromMap(Map<String, dynamic> map) {
    return Reward(
      image: map['image'] as String?,
      name: map['name'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'image': image,
    'name': name,
  };
}

class Product {
  final String id;
  final String name;
  final double price;
  final String category;
  final String description;
  final List<String> images; // base64 strings
  final bool isActive;
  final String status;
  final int stock;
  final String sellerId;
  final Reward? reward;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    required this.sellerId,
    this.reward,
    this.createdAt,
    this.updatedAt,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      images: List<String>.from(data['images'] ?? []),
      isActive: data['isActive'] ?? false,
      status: data['status'] ?? '',
      stock: (data['stock'] ?? 0).toInt(),
      sellerId: data['sellerId'] ?? '',
      reward: data['reward'] != null
          ? Reward.fromMap(data['reward'] as Map<String, dynamic>)
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
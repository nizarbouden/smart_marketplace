class CartItemModel {
  final String productId;
  final String cartDocId;
  final String name;
  final double price;
  final int stock;
  final String sellerId;
  final String storeName;
  final List<String> images;
  int quantity;
  bool isSelected;

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
  });

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
  };

  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    return CartItemModel(
      productId: map['productId'] as String? ?? '',
      cartDocId: map['cartDocId'] as String? ?? '',
      name:      map['name'] as String? ?? '',
      price:     (map['price'] as num?)?.toDouble() ?? 0.0,
      stock:     map['stock'] as int? ?? 0,
      sellerId:  map['sellerId'] as String? ?? '',
      storeName: map['storeName'] as String? ?? '',
      images:    List<String>.from(map['images'] ?? []),
      quantity:  map['quantity'] as int? ?? 1,
    );
  }
}
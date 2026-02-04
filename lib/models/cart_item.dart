class CartItem {
  final String id;
  final String name;
  final String vendorName;
  final double price;
  final int quantity;
  bool isSelected;

  CartItem({
    required this.id,
    required this.name,
    required this.vendorName,
    required this.price,
    required this.quantity,
    this.isSelected = false,
  });

  CartItem copyWith({
    String? id,
    String? name,
    String? vendorName,
    double? price,
    int? quantity,
    bool? isSelected,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      vendorName: vendorName ?? this.vendorName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

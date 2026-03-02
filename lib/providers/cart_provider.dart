import 'package:flutter/material.dart';
import '../models/cart_item_model.dart';

// ✅ Plus besoin de définir les modèles ici — juste importer
export '../models/cart_item_model.dart';
export '../models/address_model.dart';
export '../models/payment_method_model.dart';

class CartProvider extends ChangeNotifier {
  List<CartItemModel> _items = [];

  List<CartItemModel> get items => _items;
  List<CartItemModel> get selectedItems =>
      _items.where((i) => i.isSelected).toList();

  int    get selectedCount  => selectedItems.length;
  double get selectedTotal  => selectedItems.fold(0.0, (sum, i) => sum + i.price * i.quantity);
  double get subtotal       => selectedTotal * 0.9;
  double get shippingFee    => 5.0;
  double get estimatedTotal => subtotal + shippingFee;

  void setItems(List<CartItemModel> items) {
    _items = items;
    notifyListeners();
  }

  void updateQuantity(int index, int newQty) {
    if (index < 0 || index >= _items.length) return;
    _items[index].quantity = newQty;
    notifyListeners();
  }

  void removeItem(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    notifyListeners();
  }

  void toggleSelection(int index) {
    if (index < 0 || index >= _items.length) return;
    _items[index].isSelected = !_items[index].isSelected;
    notifyListeners();
  }

  void toggleVendorSelection(String storeName) {
    final vendorItems = _items.where((i) => i.storeName == storeName).toList();
    final allSelected = vendorItems.every((i) => i.isSelected);
    for (final item in vendorItems) {
      item.isSelected = !allSelected;
    }
    notifyListeners();
  }

  void toggleAllSelection() {
    final allSelected = _items.every((i) => i.isSelected);
    for (final item in _items) {
      item.isSelected = !allSelected;
    }
    notifyListeners();
  }

  void clearSelection() {
    for (final item in _items) {
      item.isSelected = false;
    }
    notifyListeners();
  }
}
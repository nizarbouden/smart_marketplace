import 'package:flutter/material.dart';
import '../models/cart_item_model.dart';
import '../models/shipping_zone_model.dart';

export '../models/cart_item_model.dart';
export '../models/address_model.dart';
export '../models/payment_method_model.dart';

class CartProvider extends ChangeNotifier {
  List<CartItemModel> _items = [];

  // ── Adresse acheteur (zone effective) ────────────────────────
  ShippingZone _buyerZone = ShippingZone.world;

  List<CartItemModel> get items => _items;

  List<CartItemModel> get selectedItems =>
      _items.where((i) => i.isSelected).toList();

  int    get selectedCount => selectedItems.length;

  // ── Sous-total produits ──────────────────────────────────────
  double get selectedProductsTotal =>
      selectedItems.fold(0.0, (s, i) => s + i.price * i.quantity);

  // ── Total livraison : somme de tous les produits sélectionnés × quantité ──
  double get selectedShippingTotal {
    double total = 0.0;
    for (final item in selectedItems) {
      final price = item.shippingPrice(_buyerZone);
      if (price != null) total += price;
    }
    return total;
  }

  double get grandTotal => selectedProductsTotal + selectedShippingTotal;

  // ── Compatibilité ancienne API ───────────────────────────────
  double get selectedTotal  => selectedProductsTotal;
  double get subtotal       => selectedProductsTotal;
  double get shippingFee    => selectedShippingTotal;
  double get estimatedTotal => grandTotal;

  // ── Mise à jour zone acheteur (appelé depuis CartPage) ───────
  void setBuyerZone(ShippingZone zone) {
    _buyerZone = zone;
    notifyListeners();
  }

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
    final vendorItems =
    _items.where((i) => i.storeName == storeName).toList();
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
import 'package:flutter/material.dart';

// ── Modèle partagé CartItem ───────────────────────────────────────
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
}

// ── Modèle Adresse ────────────────────────────────────────────────
class AddressModel {
  final String id;
  final String contactName;
  final String phone;
  final String countryCode;
  final String countryFlag;
  final String countryName;
  final String street;
  final String city;
  final String province;
  final String postalCode;
  final String complement;
  final bool isDefault;

  AddressModel({
    required this.id,
    required this.contactName,
    required this.phone,
    required this.countryCode,
    required this.countryFlag,
    required this.countryName,
    required this.street,
    required this.city,
    required this.province,
    required this.postalCode,
    required this.complement,
    required this.isDefault,
  });

  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      id: map['id'] as String? ?? '',
      contactName: map['contactName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      countryCode: map['countryCode'] as String? ?? '',
      countryFlag: map['countryFlag'] as String? ?? '',
      countryName: map['countryName'] as String? ?? '',
      street: map['street'] as String? ?? '',
      city: map['city'] as String? ?? '',
      province: map['province'] as String? ?? '',
      postalCode: map['postalCode'] as String? ?? '',
      complement: map['complement'] as String? ?? '',
      isDefault: map['isDefault'] as bool? ?? false,
    );
  }

  String get fullAddress {
    final parts = [street, city, province, postalCode, countryName]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join(', ');
  }
}

// ── Modèle Méthode de paiement ────────────────────────────────────
class PaymentMethodModel {
  final String id;
  final String type; // card, paypal, apple_pay, google_pay, cash
  final bool isDefault;
  // Card specific
  final String? cardholderName;
  final String? lastFourDigits;
  final String? cardType;
  final String? expiryMonth;
  final String? expiryYear;
  // PayPal specific
  final String? email;
  final String? accountHolderName;

  PaymentMethodModel({
    required this.id,
    required this.type,
    required this.isDefault,
    this.cardholderName,
    this.lastFourDigits,
    this.cardType,
    this.expiryMonth,
    this.expiryYear,
    this.email,
    this.accountHolderName,
  });

  factory PaymentMethodModel.fromMap(Map<String, dynamic> map) {
    return PaymentMethodModel(
      id: map['id'] as String? ?? '',
      type: map['type'] as String? ?? '',
      isDefault: map['isDefault'] as bool? ?? false,
      cardholderName: map['cardholderName'] as String?,
      lastFourDigits: map['lastFourDigits'] as String?,
      cardType: map['cardType'] as String?,
      expiryMonth: map['expiryMonth'] as String?,
      expiryYear: map['expiryYear'] as String?,
      email: map['email'] as String?,
      accountHolderName: map['accountHolderName'] as String?,
    );
  }

  // Label affiché
  String get displayName {
    switch (type) {
      case 'card':
        final brand = cardType?.toUpperCase() ?? 'CARTE';
        return '$brand •••• ${lastFourDigits ?? ''}';
      case 'paypal':
        return 'PayPal${email != null ? ' · $email' : ''}';
      case 'apple_pay':
        return 'Apple Pay';
      case 'google_pay':
        return 'Google Pay';
      case 'cash':
        return 'Paiement en espèces';
      default:
        return type;
    }
  }

  // Sous-titre
  String get subtitle {
    switch (type) {
      case 'card':
        return cardholderName ?? '';
      case 'paypal':
        return accountHolderName ?? '';
      default:
        return '';
    }
  }

  // Icône
  IconData get icon {
    switch (type) {
      case 'card':
        return Icons.credit_card_rounded;
      case 'paypal':
        return Icons.account_balance_wallet_rounded;
      case 'apple_pay':
        return Icons.apple_rounded;
      case 'google_pay':
        return Icons.g_mobiledata_rounded;
      case 'cash':
        return Icons.payments_rounded;
      default:
        return Icons.payment_rounded;
    }
  }
}

// ── CartProvider ──────────────────────────────────────────────────
class CartProvider extends ChangeNotifier {
  List<CartItemModel> _items = [];

  List<CartItemModel> get items => _items;
  List<CartItemModel> get selectedItems =>
      _items.where((i) => i.isSelected).toList();

  int get selectedCount => selectedItems.length;

  double get selectedTotal => selectedItems.fold(
      0.0, (sum, i) => sum + i.price * i.quantity);

  // Subtotal après réduction 10%
  double get subtotal => selectedTotal * 0.9;

  // Frais de livraison fixes
  double get shippingFee => 5.0;

  // Total estimé
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
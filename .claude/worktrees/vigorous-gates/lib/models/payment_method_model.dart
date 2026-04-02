import 'package:flutter/material.dart';

class PaymentMethodModel {
  final String id;
  final String type;
  final bool isDefault;
  final String? cardholderName;
  final String? lastFourDigits;
  final String? cardType;
  final String? expiryMonth;
  final String? expiryYear;
  final String? email;
  final String? accountHolderName;
  // ✅ Stripe
  final String? stripePaymentMethodId;
  final String? stripeCustomerId;

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
    this.stripePaymentMethodId,
    this.stripeCustomerId,
  });

  factory PaymentMethodModel.fromMap(Map<String, dynamic> map) {
    return PaymentMethodModel(
      id:                    map['id']?.toString() ?? '',
      type:                  map['type']?.toString() ?? '',
      isDefault:             map['isDefault'] as bool? ?? false,
      cardholderName:        map['cardholderName']?.toString(),
      lastFourDigits:        map['lastFourDigits']?.toString(),
      cardType:              map['cardType']?.toString(),
      expiryMonth:           map['expiryMonth']?.toString(),
      expiryYear:            map['expiryYear']?.toString(),
      email:                 map['email']?.toString(),
      accountHolderName:     map['accountHolderName']?.toString(),
      stripePaymentMethodId: map['stripePaymentMethodId']?.toString(),
      stripeCustomerId:      map['stripeCustomerId']?.toString(),
    );
  }

  // ✅ Carte liée à Stripe ?
  bool get hasStripe =>
      stripePaymentMethodId != null && stripePaymentMethodId!.isNotEmpty;

  String get displayName {
    switch (type) {
      case 'card':
        final brand = cardType?.toUpperCase() ?? 'CARTE';
        return '$brand •••• ${lastFourDigits ?? ''}';
      case 'paypal':     return 'PayPal${email != null ? ' · $email' : ''}';
      case 'apple_pay':  return 'Apple Pay';
      case 'google_pay': return 'Google Pay';
      case 'cash':       return 'Paiement en espèces';
      default:           return type;
    }
  }

  String get subtitle {
    switch (type) {
      case 'card':   return cardholderName ?? '';
      case 'paypal': return accountHolderName ?? '';
      default:       return '';
    }
  }

  IconData get icon {
    switch (type) {
      case 'card':       return Icons.credit_card_rounded;
      case 'paypal':     return Icons.account_balance_wallet_rounded;
      case 'apple_pay':  return Icons.apple_rounded;
      case 'google_pay': return Icons.g_mobiledata_rounded;
      case 'cash':       return Icons.payments_rounded;
      default:           return Icons.payment_rounded;
    }
  }
}
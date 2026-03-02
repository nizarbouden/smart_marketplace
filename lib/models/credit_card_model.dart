import 'package:cloud_firestore/cloud_firestore.dart';

class CreditCardModel {
  final String id;
  final String userId;
  final String lastFourDigits;
  final String cardholderName;
  final String expiryMonth;
  final String expiryYear;
  final String cardType;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String encryptedCardNumber;
  final String encryptedCvv;
  // ✅ Ajout Stripe
  final String? stripePaymentMethodId;
  final String? stripeCustomerId;

  CreditCardModel({
    required this.id,
    required this.userId,
    required this.lastFourDigits,
    required this.cardholderName,
    required this.expiryMonth,
    required this.expiryYear,
    required this.cardType,
    this.isDefault = false,
    required this.createdAt,
    this.updatedAt,
    required this.encryptedCardNumber,
    required this.encryptedCvv,
    this.stripePaymentMethodId,
    this.stripeCustomerId,
  });

  factory CreditCardModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return CreditCardModel(
      id:                    documentId,
      userId:                data['userId'] ?? '',
      lastFourDigits:        data['lastFourDigits'] ?? '',
      cardholderName:        data['cardholderName'] ?? '',
      expiryMonth:           data['expiryMonth'] ?? '',
      expiryYear:            data['expiryYear'] ?? '',
      cardType:              data['cardType'] ?? 'unknown',
      isDefault:             data['isDefault'] ?? false,
      createdAt:             (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:             (data['updatedAt'] as Timestamp?)?.toDate(),
      encryptedCardNumber:   data['encryptedCardNumber'] ?? '',
      encryptedCvv:          data['encryptedCvv'] ?? '',
      // ✅ Stripe — null si ancienne carte sans Stripe
      stripePaymentMethodId: data['stripePaymentMethodId'] as String?,
      stripeCustomerId:      data['stripeCustomerId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId':                userId,
      'lastFourDigits':        lastFourDigits,
      'cardholderName':        cardholderName,
      'expiryMonth':           expiryMonth,
      'expiryYear':            expiryYear,
      'cardType':              cardType,
      'isDefault':             isDefault,
      'createdAt':             Timestamp.fromDate(createdAt),
      'updatedAt':             updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'encryptedCardNumber':   encryptedCardNumber,
      'encryptedCvv':          encryptedCvv,
      // ✅ Stripe
      'stripePaymentMethodId': stripePaymentMethodId,
      'stripeCustomerId':      stripeCustomerId,
    };
  }

  CreditCardModel copyWith({
    String? id,
    String? userId,
    String? lastFourDigits,
    String? cardholderName,
    String? expiryMonth,
    String? expiryYear,
    String? cardType,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? encryptedCardNumber,
    String? encryptedCvv,
    String? stripePaymentMethodId,
    String? stripeCustomerId,
  }) {
    return CreditCardModel(
      id:                    id ?? this.id,
      userId:                userId ?? this.userId,
      lastFourDigits:        lastFourDigits ?? this.lastFourDigits,
      cardholderName:        cardholderName ?? this.cardholderName,
      expiryMonth:           expiryMonth ?? this.expiryMonth,
      expiryYear:            expiryYear ?? this.expiryYear,
      cardType:              cardType ?? this.cardType,
      isDefault:             isDefault ?? this.isDefault,
      createdAt:             createdAt ?? this.createdAt,
      updatedAt:             updatedAt ?? this.updatedAt,
      encryptedCardNumber:   encryptedCardNumber ?? this.encryptedCardNumber,
      encryptedCvv:          encryptedCvv ?? this.encryptedCvv,
      stripePaymentMethodId: stripePaymentMethodId ?? this.stripePaymentMethodId,
      stripeCustomerId:      stripeCustomerId ?? this.stripeCustomerId,
    );
  }

  // ✅ Vérifier si la carte est liée à Stripe
  bool get hasStripe =>
      stripePaymentMethodId != null && stripePaymentMethodId!.isNotEmpty;

  String get maskedCardNumber => '**** **** **** $lastFourDigits';
  String get formattedExpiry  => '$expiryMonth/$expiryYear';

  bool get isExpired {
    final now        = DateTime.now();
    final expiryDate = DateTime(int.parse(expiryYear), int.parse(expiryMonth));
    return expiryDate.isBefore(now);
  }

  String get cardIcon => '💳';
}
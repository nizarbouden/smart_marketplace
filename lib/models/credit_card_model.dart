import 'package:cloud_firestore/cloud_firestore.dart';

class CreditCardModel {
  final String id;
  final String userId;
  final String lastFourDigits;
  final String cardholderName;
  final String expiryMonth;
  final String expiryYear;
  final String cardType; // visa, mastercard, etc.
  final bool isDefault;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String encryptedCardNumber;
  final String encryptedCvv;

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
  });

  // Créer depuis Firestore
  factory CreditCardModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return CreditCardModel(
      id: documentId,
      userId: data['userId'] ?? '',
      lastFourDigits: data['lastFourDigits'] ?? '',
      cardholderName: data['cardholderName'] ?? '',
      expiryMonth: data['expiryMonth'] ?? '',
      expiryYear: data['expiryYear'] ?? '',
      cardType: data['cardType'] ?? 'unknown',
      isDefault: data['isDefault'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      encryptedCardNumber: data['encryptedCardNumber'] ?? '',
      encryptedCvv: data['encryptedCvv'] ?? '',
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'lastFourDigits': lastFourDigits,
      'cardholderName': cardholderName,
      'expiryMonth': expiryMonth,
      'expiryYear': expiryYear,
      'cardType': cardType,
      'isDefault': isDefault,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'encryptedCardNumber': encryptedCardNumber,
      'encryptedCvv': encryptedCvv,
    };
  }

  // Créer une copie avec mise à jour
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
  }) {
    return CreditCardModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      lastFourDigits: lastFourDigits ?? this.lastFourDigits,
      cardholderName: cardholderName ?? this.cardholderName,
      expiryMonth: expiryMonth ?? this.expiryMonth,
      expiryYear: expiryYear ?? this.expiryYear,
      cardType: cardType ?? this.cardType,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      encryptedCardNumber: encryptedCardNumber ?? this.encryptedCardNumber,
      encryptedCvv: encryptedCvv ?? this.encryptedCvv,
    );
  }

  // Obtenir le format d'affichage de la carte
  String get maskedCardNumber {
    return '**** **** **** $lastFourDigits';
  }

  // Obtenir la date d'expiration formatée
  String get formattedExpiry {
    return '$expiryMonth/$expiryYear';
  }

  // Vérifier si la carte est expirée
  bool get isExpired {
    final now = DateTime.now();
    final expiryDate = DateTime(
      int.parse(expiryYear),
      int.parse(expiryMonth),
    );
    return expiryDate.isBefore(now);
  }

  // Obtenir l'icône de la carte
  String get cardIcon {
    switch (cardType.toLowerCase()) {
      case 'visa':
        return '💳';
      case 'mastercard':
        return '💳';
      case 'amex':
        return '💳';
      default:
        return '💳';
    }
  }
}

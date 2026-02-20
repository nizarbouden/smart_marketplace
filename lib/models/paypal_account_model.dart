import 'package:cloud_firestore/cloud_firestore.dart';

class PayPalAccountModel {
  final String id;
  final String userId;
  final String email;
  final String accountHolderName;
  final bool isVerified;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String encryptedAccessToken; // Token chiffré pour les paiements

  PayPalAccountModel({
    required this.id,
    required this.userId,
    required this.email,
    required this.accountHolderName,
    this.isVerified = false,
    this.isDefault = false,
    required this.createdAt,
    this.updatedAt,
    required this.encryptedAccessToken,
  });

  // Créer depuis Firestore
  factory PayPalAccountModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return PayPalAccountModel(
      id: documentId,
      userId: data['userId'] ?? '',
      email: data['email'] ?? '',
      accountHolderName: data['accountHolderName'] ?? '',
      isVerified: data['isVerified'] ?? false,
      isDefault: data['isDefault'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      encryptedAccessToken: data['encryptedAccessToken'] ?? '',
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'accountHolderName': accountHolderName,
      'isVerified': isVerified,
      'isDefault': isDefault,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'encryptedAccessToken': encryptedAccessToken,
    };
  }

  // Créer une copie avec mise à jour
  PayPalAccountModel copyWith({
    String? id,
    String? userId,
    String? email,
    String? accountHolderName,
    bool? isVerified,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? encryptedAccessToken,
  }) {
    return PayPalAccountModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      isVerified: isVerified ?? this.isVerified,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      encryptedAccessToken: encryptedAccessToken ?? this.encryptedAccessToken,
    );
  }

  // Obtenir l'email masqué pour l'affichage
  String get maskedEmail {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    
    final username = parts[0];
    final domain = parts[1];
    
    if (username.length <= 3) return email;
    
    final maskedUsername = '${username.substring(0, 2)}${'*' * (username.length - 2)}';
    return '$maskedUsername@$domain';
  }

  // Obtenir l'icône PayPal
  String get paypalIcon => '💙';

  // Vérifier si le compte est valide
  bool get isValid {
    return email.isNotEmpty && 
           accountHolderName.isNotEmpty && 
           email.contains('@') && 
           email.contains('.');
  }

  // Obtenir le statut de vérification
  String get verificationStatus {
    if (isVerified) return '✅ Vérifié';
    return '⏳ En attente de vérification';
  }
}

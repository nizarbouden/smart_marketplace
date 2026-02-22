import 'package:cloud_firestore/cloud_firestore.dart';

// Énumération des rôles utilisateur — seulement buyer et seller
enum UserRole {
  buyer,  // Acheteur
  seller, // Vendeur
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.buyer:
        return 'Acheteur';
      case UserRole.seller:
        return 'Vendeur';
    }
  }

  String get description {
    switch (this) {
      case UserRole.buyer:
        return 'Je veux acheter des produits';
      case UserRole.seller:
        return 'Je veux vendre des produits';
    }
  }

  // ✅ Retourne null si rôle absent ou inconnu — plus de défaut buyer
  static UserRole? fromString(String? role) {
    switch (role) {
      case 'buyer':
        return UserRole.buyer;
      case 'seller':
        return UserRole.seller;
      default:
        return null; // ✅ null = l'utilisateur n'a pas encore choisi
    }
  }

  String toJson() {
    switch (this) {
      case UserRole.buyer:
        return 'buyer';
      case UserRole.seller:
        return 'seller';
    }
  }
}

class UserModel {
  final String uid;
  final String email;
  final String nom;
  final String prenom;
  final String? genre;
  final String phoneNumber;
  final String? countryCode;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;
  final bool isActive;
  final bool isGoogleUser;
  final bool isEmailVerified;
  final UserRole? role; // ✅ nullable — null = pas encore choisi
  final int points;

  UserModel({
    required this.uid,
    required this.email,
    required this.nom,
    required this.prenom,
    this.genre,
    required this.phoneNumber,
    this.countryCode,
    this.photoUrl,
    required this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
    this.isActive = true,
    this.isGoogleUser = false,
    this.isEmailVerified = false,
    this.role, // ✅ pas de valeur par défaut
    this.points = 0,
  });

  // Créer un utilisateur à partir d'un Map (Firestore)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      nom: map['nom'] ?? '',
      prenom: map['prenom'] ?? '',
      genre: map['genre'],
      phoneNumber: map['phoneNumber'] ?? '',
      countryCode: map['countryCode'],
      photoUrl: map['photoUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (map['lastLoginAt'] as Timestamp?)?.toDate(),
      isActive: map['isActive'] ?? true,
      isGoogleUser: map['isGoogleUser'] ?? false,
      isEmailVerified: map['isEmailVerified'] ?? map['emailVerified'] ?? false,
      role: UserRoleExtension.fromString(map['role']), // ✅ null si absent
      points: map['points'] ?? 0,
    );
  }

  // Convertir l'utilisateur en Map (pour Firestore)
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'nom': nom,
      'prenom': prenom,
      'genre': genre,
      'phoneNumber': phoneNumber,
      'countryCode': countryCode,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'isActive': isActive,
      'isGoogleUser': isGoogleUser,
      'isEmailVerified': isEmailVerified,
      'role': role?.toJson(), // ✅ null si pas encore choisi
      'points': points,
    };
  }

  // Créer une copie avec des modifications
  UserModel copyWith({
    String? uid,
    String? email,
    String? nom,
    String? prenom,
    String? genre,
    String? phoneNumber,
    String? countryCode,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    bool? isActive,
    bool? isGoogleUser,
    bool? isEmailVerified,
    UserRole? role,
    int? points,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      genre: genre ?? this.genre,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      countryCode: countryCode ?? this.countryCode,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      isGoogleUser: isGoogleUser ?? this.isGoogleUser,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      role: role ?? this.role,
      points: points ?? this.points,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, nom: $nom, prenom: $prenom, phoneNumber: $phoneNumber, role: $role, points: $points)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.uid == uid &&
        other.email == email &&
        other.nom == nom &&
        other.prenom == prenom &&
        other.phoneNumber == phoneNumber &&
        other.role == role &&
        other.points == points;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
    email.hashCode ^
    nom.hashCode ^
    prenom.hashCode ^
    phoneNumber.hashCode ^
    role.hashCode ^
    points.hashCode;
  }

  // ✅ Méthodes utilitaires — sans "both"
  bool get isBuyer => role == UserRole.buyer;
  bool get isSeller => role == UserRole.seller;
  bool get hasRole => role != null; // ✅ vérifier si le rôle a été choisi

  bool canBuy() => isBuyer;
  bool canSell() => isSeller;
  bool canAccessSellerDashboard() => isSeller;
  bool canAccessBuyerFeatures() => isBuyer;
}
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final List<String>? addresses;
  final List<String>? favoris; // Liste des produits favoris
  final List<String>? commandes; // Liste des IDs de commandes
  final Map<String, dynamic>? preferences;
  final int points; // Points de fidélité

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
    this.addresses,
    this.favoris,
    this.commandes,
    this.preferences,
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
      addresses: List<String>.from(map['addresses'] ?? []),
      favoris: List<String>.from(map['favoris'] ?? []),
      commandes: List<String>.from(map['commandes'] ?? []),
      preferences: Map<String, dynamic>.from(map['preferences'] ?? {}),
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
      'addresses': addresses ?? [],
      'favoris': favoris ?? [],
      'commandes': commandes ?? [],
      'preferences': preferences ?? {},
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
    List<String>? addresses,
    List<String>? favoris,
    List<String>? commandes,
    Map<String, dynamic>? preferences,
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
      addresses: addresses ?? this.addresses,
      favoris: favoris ?? this.favoris,
      commandes: commandes ?? this.commandes,
      preferences: preferences ?? this.preferences,
      points: points ?? this.points,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, nom: $nom, prenom: $prenom, phoneNumber: $phoneNumber, points: $points)';
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
      other.points == points;
  }

  @override
  int get hashCode {
    return uid.hashCode ^ email.hashCode ^ nom.hashCode ^ prenom.hashCode ^ phoneNumber.hashCode ^ points.hashCode;
  }
}

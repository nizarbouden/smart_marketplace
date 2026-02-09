import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String phoneNumber;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;
  final bool isActive;
  final bool isGoogleUser;
  final List<String>? addresses;
  final Map<String, dynamic>? preferences;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    this.photoUrl,
    required this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
    this.isActive = true,
    this.isGoogleUser = false,
    this.addresses,
    this.preferences,
  });

  // Créer un utilisateur à partir d'un Map (Firestore)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      photoUrl: map['photoUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (map['lastLoginAt'] as Timestamp?)?.toDate(),
      isActive: map['isActive'] ?? true,
      isGoogleUser: map['isGoogleUser'] ?? false,
      addresses: List<String>.from(map['addresses'] ?? []),
      preferences: Map<String, dynamic>.from(map['preferences'] ?? {}),
    );
  }

  // Convertir l'utilisateur en Map (pour Firestore)
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'isActive': isActive,
      'isGoogleUser': isGoogleUser,
      'addresses': addresses ?? [],
      'preferences': preferences ?? {},
    };
  }

  // Créer une copie avec des modifications
  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? phoneNumber,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    bool? isActive,
    bool? isGoogleUser,
    List<String>? addresses,
    Map<String, dynamic>? preferences,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      isGoogleUser: isGoogleUser ?? this.isGoogleUser,
      addresses: addresses ?? this.addresses,
      preferences: preferences ?? this.preferences,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, fullName: $fullName, phoneNumber: $phoneNumber)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is UserModel &&
      other.uid == uid &&
      other.email == email &&
      other.fullName == fullName &&
      other.phoneNumber == phoneNumber;
  }

  @override
  int get hashCode {
    return uid.hashCode ^ email.hashCode ^ fullName.hashCode ^ phoneNumber.hashCode;
  }
}

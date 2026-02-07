import 'dart:io';

class ProfileModel {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String? gender;
  final String? countryCode;
  final String? countryName;
  final String? countryFlag;
  final File? profileImage;

  ProfileModel({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    this.gender,
    this.countryCode,
    this.countryName,
    this.countryFlag,
    this.profileImage,
  });

  ProfileModel copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? gender,
    String? countryCode,
    String? countryName,
    String? countryFlag,
    File? profileImage,
  }) {
    return ProfileModel(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      countryCode: countryCode ?? this.countryCode,
      countryName: countryName ?? this.countryName,
      countryFlag: countryFlag ?? this.countryFlag,
      profileImage: profileImage ?? this.profileImage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'gender': gender,  // Sera null si "Ne pas préciser"
      'countryCode': countryCode,
      'countryName': countryName,
      'countryFlag': countryFlag,
      'profileImage': profileImage?.path,
    };
  }

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      gender: json['gender'],
      countryCode: json['countryCode'],
      countryName: json['countryName'],
      countryFlag: json['countryFlag'],
      profileImage: json['profileImage'] != null ? File(json['profileImage']) : null,
    );
  }
}

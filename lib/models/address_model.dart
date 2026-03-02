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
      id:          map['id'] as String? ?? '',
      contactName: map['contactName'] as String? ?? '',
      phone:       map['phone'] as String? ?? '',
      countryCode: map['countryCode'] as String? ?? '',
      countryFlag: map['countryFlag'] as String? ?? '',
      countryName: map['countryName'] as String? ?? '',
      street:      map['street'] as String? ?? '',
      city:        map['city'] as String? ?? '',
      province:    map['province'] as String? ?? '',
      postalCode:  map['postalCode'] as String? ?? '',
      complement:  map['complement'] as String? ?? '',
      isDefault:   map['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'id':          id,
    'contactName': contactName,
    'phone':       phone,
    'countryCode': countryCode,
    'countryFlag': countryFlag,
    'countryName': countryName,
    'street':      street,
    'city':        city,
    'province':    province,
    'postalCode':  postalCode,
    'complement':  complement,
    'isDefault':   isDefault,
  };

  String get fullAddress {
    final parts = [street, city, province, postalCode, countryName]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join(', ');
  }
}
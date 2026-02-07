class CountryData {
  // Liste complète des pays avec leurs codes téléphoniques et drapeaux
  // Organisée par régions géographiques pour une meilleure lisibilité
  
  static const List<Map<String, String>> countries = [
    // Afrique du Nord
    {'name': 'Tunisie', 'code': '+216', 'flag': '🇹🇳'},
    {'name': 'Algérie', 'code': '+213', 'flag': '🇩🇿'},
    {'name': 'Maroc', 'code': '+212', 'flag': '🇲🇦'},
    {'name': 'Libye', 'code': '+218', 'flag': '🇱🇾'},
    {'name': 'Égypte', 'code': '+20', 'flag': '🇪🇬'},

    // Europe
    {'name': 'France', 'code': '+33', 'flag': '🇫🇷'},
    {'name': 'Royaume-Uni', 'code': '+44', 'flag': '🇬🇧'},
    {'name': 'Allemagne', 'code': '+49', 'flag': '🇩🇪'},
    {'name': 'Italie', 'code': '+39', 'flag': '🇮🇹'},
    {'name': 'Espagne', 'code': '+34', 'flag': '🇪🇸'},
    {'name': 'Belgique', 'code': '+32', 'flag': '🇧🇪'},
    {'name': 'Suisse', 'code': '+41', 'flag': '🇨🇭'},
    {'name': 'Pays-Bas', 'code': '+31', 'flag': '🇳🇱'},
    {'name': 'Autriche', 'code': '+43', 'flag': '🇦🇹'},
    {'name': 'Suède', 'code': '+46', 'flag': '🇸🇪'},
    {'name': 'Norvège', 'code': '+47', 'flag': '🇳🇴'},
    {'name': 'Danemark', 'code': '+45', 'flag': '🇩🇰'},
    {'name': 'Finlande', 'code': '+358', 'flag': '🇫🇮'},
    {'name': 'Pologne', 'code': '+48', 'flag': '🇵🇱'},
    {'name': 'République Tchèque', 'code': '+420', 'flag': '🇨🇿'},
    {'name': 'Slovaquie', 'code': '+421', 'flag': '🇸🇰'},
    {'name': 'Hongrie', 'code': '+36', 'flag': '🇭🇺'},
    {'name': 'Roumanie', 'code': '+40', 'flag': '🇷🇴'},
    {'name': 'Bulgarie', 'code': '+359', 'flag': '🇧🇬'},
    {'name': 'Grèce', 'code': '+30', 'flag': '🇬🇷'},
    {'name': 'Croatie', 'code': '+385', 'flag': '🇭🇷'},
    {'name': 'Serbie', 'code': '+381', 'flag': '🇷🇸'},
    {'name': 'Ukraine', 'code': '+380', 'flag': '🇺🇦'},
    {'name': 'Russie', 'code': '+7', 'flag': '🇷🇺'},
    {'name': 'Portugal', 'code': '+351', 'flag': '🇵🇹'},
    {'name': 'Irlande', 'code': '+353', 'flag': '🇮🇪'},

    // Moyen-Orient
    {'name': 'Arabie Saoudite', 'code': '+966', 'flag': '🇸🇦'},
    {'name': 'Émirats Arabes Unis', 'code': '+971', 'flag': '🇦🇪'},
    {'name': 'Qatar', 'code': '+974', 'flag': '🇶🇦'},
    {'name': 'Koweït', 'code': '+965', 'flag': '🇰🇼'},
    {'name': 'Bahreïn', 'code': '+973', 'flag': '🇧🇭'},
    {'name': 'Oman', 'code': '+968', 'flag': '🇴🇲'},
    {'name': 'Yémen', 'code': '+967', 'flag': '🇾🇪'},
    {'name': 'Irak', 'code': '+964', 'flag': '🇮🇶'},
    {'name': 'Syrie', 'code': '+963', 'flag': '🇸🇾'},
    {'name': 'Liban', 'code': '+961', 'flag': '🇱🇧'},
    {'name': 'Israël', 'code': '+972', 'flag': '🇮🇱'},
    {'name': 'Palestine', 'code': '+970', 'flag': '🇵🇸'},
    {'name': 'Jordanie', 'code': '+962', 'flag': '🇯🇴'},
    {'name': 'Turquie', 'code': '+90', 'flag': '🇹🇷'},
    {'name': 'Iran', 'code': '+98', 'flag': '🇮🇷'},
    {'name': 'Afghanistan', 'code': '+93', 'flag': '🇦🇫'},

    // Asie
    {'name': 'Japon', 'code': '+81', 'flag': '🇯🇵'},
    {'name': 'Chine', 'code': '+86', 'flag': '🇨🇳'},
    {'name': 'Inde', 'code': '+91', 'flag': '🇮🇳'},
    {'name': 'Thaïlande', 'code': '+66', 'flag': '🇹🇭'},
    {'name': 'Vietnam', 'code': '+84', 'flag': '🇻🇳'},
    {'name': 'Philippines', 'code': '+63', 'flag': '🇵🇭'},
    {'name': 'Indonésie', 'code': '+62', 'flag': '🇮🇩'},
    {'name': 'Malaisie', 'code': '+60', 'flag': '🇲🇾'},
    {'name': 'Singapour', 'code': '+65', 'flag': '🇸🇬'},
    {'name': 'Cambodge', 'code': '+855', 'flag': '🇰🇭'},
    {'name': 'Laos', 'code': '+856', 'flag': '🇱🇦'},
    {'name': 'Myanmar', 'code': '+95', 'flag': '🇲🇲'},
    {'name': 'Bangladesh', 'code': '+880', 'flag': '🇧🇩'},
    {'name': 'Pakistan', 'code': '+92', 'flag': '🇵🇰'},
    {'name': 'Sri Lanka', 'code': '+94', 'flag': '🇱🇰'},
    {'name': 'Népal', 'code': '+977', 'flag': '🇳🇵'},
    {'name': 'Corée du Sud', 'code': '+82', 'flag': '🇰🇷'},
    {'name': 'Corée du Nord', 'code': '+850', 'flag': '🇰🇵'},
    {'name': 'Taïwan', 'code': '+886', 'flag': '🇹🇼'},
    {'name': 'Hong Kong', 'code': '+852', 'flag': '🇭🇰'},
    {'name': 'Macao', 'code': '+853', 'flag': '🇲🇴'},
    {'name': 'Mongolie', 'code': '+976', 'flag': '🇲🇳'},
    {'name': 'Kazakhstan', 'code': '+7', 'flag': '🇰🇿'},
    {'name': 'Ouzbékistan', 'code': '+998', 'flag': '🇺🇿'},
    {'name': 'Turkménistan', 'code': '+993', 'flag': '🇹🇲'},
    {'name': 'Tadjikistan', 'code': '+992', 'flag': '🇹🇯'},
    {'name': 'Kirghizistan', 'code': '+996', 'flag': '🇰🇬'},

    // Amérique du Nord
    {'name': 'États-Unis', 'code': '+1', 'flag': '🇺🇸'},
    {'name': 'Canada', 'code': '+1', 'flag': '🇨🇦'},
    {'name': 'Mexique', 'code': '+52', 'flag': '🇲🇽'},

    // Amérique Centrale et Caraïbes
    {'name': 'Guatemala', 'code': '+502', 'flag': '🇬🇹'},
    {'name': 'Honduras', 'code': '+504', 'flag': '🇭🇳'},
    {'name': 'El Salvador', 'code': '+503', 'flag': '🇸🇻'},
    {'name': 'Nicaragua', 'code': '+505', 'flag': '🇳🇮'},
    {'name': 'Costa Rica', 'code': '+506', 'flag': '🇨🇷'},
    {'name': 'Panama', 'code': '+507', 'flag': '🇵🇦'},
    {'name': 'Cuba', 'code': '+53', 'flag': '🇨🇺'},
    {'name': 'République Dominicaine', 'code': '+1', 'flag': '🇩🇴'},
    {'name': 'Jamaïque', 'code': '+1', 'flag': '🇯🇲'},
    {'name': 'Haïti', 'code': '+509', 'flag': '🇭🇹'},
    {'name': 'Trinité-et-Tobago', 'code': '+1', 'flag': '🇹🇹'},

    // Amérique du Sud
    {'name': 'Colombie', 'code': '+57', 'flag': '🇨🇴'},
    {'name': 'Venezuela', 'code': '+58', 'flag': '🇻🇪'},
    {'name': 'Équateur', 'code': '+593', 'flag': '🇪🇨'},
    {'name': 'Pérou', 'code': '+51', 'flag': '🇵🇪'},
    {'name': 'Bolivie', 'code': '+591', 'flag': '🇧🇴'},
    {'name': 'Brésil', 'code': '+55', 'flag': '🇧🇷'},
    {'name': 'Paraguay', 'code': '+595', 'flag': '🇵🇾'},
    {'name': 'Chili', 'code': '+56', 'flag': '🇨🇱'},
    {'name': 'Argentine', 'code': '+54', 'flag': '🇦🇷'},
    {'name': 'Uruguay', 'code': '+598', 'flag': '🇺🇾'},
    {'name': 'Guyane', 'code': '+592', 'flag': '🇬🇾'},
    {'name': 'Suriname', 'code': '+597', 'flag': '🇸🇷'},

    // Afrique
    {'name': 'Nigeria', 'code': '+234', 'flag': '🇳🇬'},
    {'name': 'Ghana', 'code': '+233', 'flag': '🇬🇭'},
    {'name': 'Côte d\'Ivoire', 'code': '+225', 'flag': '🇨🇮'},
    {'name': 'Cameroun', 'code': '+237', 'flag': '🇨🇲'},
    {'name': 'Afrique du Sud', 'code': '+27', 'flag': '🇿🇦'},
    {'name': 'Kenya', 'code': '+254', 'flag': '🇰🇪'},
    {'name': 'Tanzanie', 'code': '+255', 'flag': '🇹🇿'},
    {'name': 'Ouganda', 'code': '+256', 'flag': '🇺🇬'},
    {'name': 'Éthiopie', 'code': '+251', 'flag': '🇪🇹'},
    {'name': 'Soudan', 'code': '+249', 'flag': '🇸🇩'},
    {'name': 'Sénégal', 'code': '+221', 'flag': '🇸🇳'},
    {'name': 'Mali', 'code': '+223', 'flag': '🇲🇱'},
    {'name': 'Mauritanie', 'code': '+222', 'flag': '🇲🇷'},
    {'name': 'Guinée', 'code': '+224', 'flag': '🇬🇳'},
    {'name': 'Gabon', 'code': '+241', 'flag': '🇬🇦'},
    {'name': 'Angola', 'code': '+244', 'flag': '🇦🇴'},
    {'name': 'Mozambique', 'code': '+258', 'flag': '🇲🇿'},
    {'name': 'Zambie', 'code': '+260', 'flag': '🇿🇲'},
    {'name': 'Zimbabwe', 'code': '+263', 'flag': '🇿🇼'},
    {'name': 'Botswana', 'code': '+267', 'flag': '🇧🇼'},
    {'name': 'Namibie', 'code': '+264', 'flag': '🇳🇦'},
    {'name': 'Mauritius', 'code': '+230', 'flag': '🇲🇺'},
    {'name': 'Seychelles', 'code': '+248', 'flag': '🇸🇨'},

    // Océanie
    {'name': 'Australie', 'code': '+61', 'flag': '🇦🇺'},
    {'name': 'Nouvelle-Zélande', 'code': '+64', 'flag': '🇳🇿'},
    {'name': 'Fidji', 'code': '+679', 'flag': '🇫🇯'},
    {'name': 'Polynésie Française', 'code': '+689', 'flag': '🇵🇫'},
    {'name': 'Papouasie-Nouvelle-Guinée', 'code': '+675', 'flag': '🇵🇬'},
  ];

  // Méthode pour obtenir la liste des pays
  static List<Map<String, String>> getCountries() {
    return countries;
  }

  // Méthode pour obtenir la liste triée par ordre alphabétique
  static List<Map<String, String>> getCountriesSorted() {
    final sortedCountries = List<Map<String, String>>.from(countries);
    sortedCountries.sort((a, b) => a['name']!.compareTo(b['name']!));
    return sortedCountries;
  }

  // Méthode pour trouver un pays par son nom
  static Map<String, String>? findCountryByName(String name) {
    try {
      return countries.firstWhere((country) => country['name'] == name);
    } catch (e) {
      return null;
    }
  }

  // Méthode pour trouver un pays par son code
  static Map<String, String>? findCountryByCode(String code) {
    try {
      return countries.firstWhere((country) => country['code'] == code);
    } catch (e) {
      return null;
    }
  }

  // Méthode pour filtrer les pays par recherche
  static List<Map<String, String>> filterCountries(String query) {
    if (query.isEmpty) {
      return countries;
    }
    
    return countries.where((country) {
      return country['name']!.toLowerCase().contains(query.toLowerCase()) ||
             country['code']!.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  // Méthode pour obtenir les pays favoris (Maghreb + Europe + Amérique du Nord)
  static List<Map<String, String>> getFavoriteCountries() {
    return [
      {'name': 'Tunisie', 'code': '+216', 'flag': '🇹🇳'},
      {'name': 'Algérie', 'code': '+213', 'flag': '🇩🇿'},
      {'name': 'Maroc', 'code': '+212', 'flag': '🇲🇦'},
      {'name': 'France', 'code': '+33', 'flag': '🇫🇷'},
      {'name': 'Belgique', 'code': '+32', 'flag': '🇧🇪'},
      {'name': 'Suisse', 'code': '+41', 'flag': '🇨🇭'},
      {'name': 'Canada', 'code': '+1', 'flag': '🇨🇦'},
      {'name': 'États-Unis', 'code': '+1', 'flag': '🇺🇸'},
    ];
  }
}

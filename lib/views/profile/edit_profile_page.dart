import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController(text: 'Jean');
  final _lastNameController = TextEditingController(text: 'Dupont');
  final _emailController = TextEditingController(text: 'jean.dupont@email.com');
  final _phoneController = TextEditingController(text: '612345678');

  final ImagePicker _imagePicker = ImagePicker();
  File? _profileImage;

  // Liste complète des pays avec leurs codes
  final List<Map<String, String>> _countries = [
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
    {'name': 'Maroc', 'code': '+212', 'flag': '🇲🇦'},
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

  late List<Map<String, String>> _filteredCountries;
  String? _selectedCountryCode = '+216';
  String _selectedCountryName = 'Tunisie';
  String _selectedCountryFlag = '🇹🇳';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _filteredCountries = List.from(_countries);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Colors.deepPurple,
            size: isDesktop ? 28 : isTablet ? 24 : 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Informations personnelles',
          style: TextStyle(
            color: Colors.deepPurple,
            fontSize: isDesktop ? 24 : isTablet ? 20 : 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _saveProfile,
            icon: Icon(
              Icons.save,
              color: Colors.deepPurple,
              size: isDesktop ? 28 : isTablet ? 24 : 20,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 32 : isTablet ? 24 : 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar section
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: isDesktop ? 80 : isTablet ? 70 : 60,
                            backgroundColor: Colors.deepPurple[100],
                            backgroundImage: _profileImage != null
                                ? FileImage(_profileImage!) as ImageProvider
                                : null,
                            child: _profileImage == null
                                ? Icon(
                              Icons.person,
                              size: isDesktop ? 80 : isTablet ? 70 : 60,
                              color: Colors.deepPurple,
                            )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _showImagePickerBottomSheet,
                              child: Container(
                                width: isDesktop ? 40 : isTablet ? 36 : 32,
                                height: isDesktop ? 40 : isTablet ? 36 : 32,
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple,
                                  shape: BoxShape.circle,
                                  border:
                                  Border.all(color: Colors.white, width: 3),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: isDesktop ? 20 : isTablet ? 18 : 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isDesktop ? 16 : isTablet ? 12 : 8),
                      Text(
                        'Changer la photo',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontSize: isDesktop ? 16 : isTablet ? 14 : 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isDesktop ? 40 : isTablet ? 32 : 24),

                // Informations de base
                _buildSectionTitle('Informations de base', isDesktop, isTablet),
                SizedBox(height: isDesktop ? 20 : isTablet ? 16 : 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'Prénom',
                        _firstNameController,
                        Icons.person,
                        isDesktop,
                        isTablet,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le prénom est requis';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(width: isDesktop ? 16 : isTablet ? 12 : 8),
                    Expanded(
                      child: _buildTextField(
                        'Nom',
                        _lastNameController,
                        Icons.person,
                        isDesktop,
                        isTablet,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le nom est requis';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isDesktop ? 20 : isTablet ? 16 : 12),

                _buildTextField(
                  'Email',
                  _emailController,
                  Icons.email,
                  isDesktop,
                  isTablet,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'L\'email est requis';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Veuillez entrer un email valide';
                    }
                    return null;
                  },
                ),
                SizedBox(height: isDesktop ? 20 : isTablet ? 16 : 12),

                _buildPhoneField(isDesktop, isTablet),
                SizedBox(height: isDesktop ? 40 : isTablet ? 32 : 24),

                // Bouton d'enregistrement
                SizedBox(
                  width: double.infinity,
                  height: isDesktop ? 56 : isTablet ? 52 : 48,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveProfile,
                    icon: _isLoading
                        ? SizedBox(
                      width: isDesktop ? 24 : isTablet ? 20 : 16,
                      height: isDesktop ? 24 : isTablet ? 20 : 16,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Icon(
                      Icons.save,
                      size: isDesktop ? 24 : isTablet ? 20 : 16,
                    ),
                    label: Text(
                      _isLoading
                          ? 'Enregistrement...'
                          : 'Enregistrer les modifications',
                      style: TextStyle(
                        fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: Colors.deepPurple.withOpacity(0.3),
                    ),
                  ),
                ),
                SizedBox(height: isDesktop ? 40 : isTablet ? 30 : 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDesktop, bool isTablet) {
    return Text(
      title,
      style: TextStyle(
        fontSize: isDesktop ? 22 : isTablet ? 20 : 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField(
      String label,
      TextEditingController controller,
      IconData icon,
      bool isDesktop,
      bool isTablet, {
        TextInputType? keyboardType,
        List<TextInputFormatter>? inputFormatters,
        String? Function(String?)? validator,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        style: TextStyle(
          fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: isDesktop ? 16 : isTablet ? 14 : 12,
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.deepPurple,
            size: isDesktop ? 24 : isTablet ? 22 : 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 20 : isTablet ? 16 : 12,
            vertical: isDesktop ? 16 : isTablet ? 14 : 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField(bool isDesktop, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Sélecteur de pays
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () => _showCountryDialog(),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 12 : isTablet ? 10 : 8,
                  vertical: isDesktop ? 16 : isTablet ? 14 : 12,
                ),
                child: Row(
                  children: [
                    Text(
                      _selectedCountryFlag,
                      style: const TextStyle(fontSize: 24),
                    ),
                    SizedBox(width: isDesktop ? 12 : isTablet ? 10 : 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedCountryCode ?? '+216',
                            style: TextStyle(
                              fontSize: isDesktop ? 14 : isTablet ? 12 : 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.deepPurple,
                            ),
                          ),
                          Text(
                            _selectedCountryName,
                            style: TextStyle(
                              fontSize: isDesktop ? 12 : isTablet ? 10 : 9,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: Colors.deepPurple,
                      size: isDesktop ? 24 : isTablet ? 22 : 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          VerticalDivider(
            width: 1,
            color: Colors.grey[300],
          ),
          // Champ téléphone
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: TextStyle(
                fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: 'Numéro',
                labelStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: isDesktop ? 16 : isTablet ? 14 : 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 16 : isTablet ? 14 : 12,
                  vertical: isDesktop ? 16 : isTablet ? 14 : 12,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Numéro requis';
                }
                if (value.length < 8) {
                  return 'Numéro invalide';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Vos informations ont été mises à jour avec succès',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

      Navigator.of(context).pop();
    }
  }

  void _showImagePickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Choisir une photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _imagePickerOption(
                  'Caméra',
                  Icons.camera_alt,
                      () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                ),
                _imagePickerOption(
                  'Galerie',
                  Icons.photo_library,
                      () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _imagePickerOption(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: Colors.deepPurple,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la capture de la photo');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (image != null) {
        final file = File(image.path);
        if (await file.exists()) {
          setState(() {
            _profileImage = file;
          });
        } else {
          _showErrorSnackBar('Le fichier sélectionné n\'existe pas');
        }
      }
    } on PlatformException catch (e) {
      String message = 'Erreur lors de la sélection de la photo';

      switch (e.code) {
        case 'photo_access_denied':
          message =
          'Accès à la galerie refusé. Veuillez autoriser l\'accès dans les paramètres.';
          break;
        case 'photo_access_unavailable':
          message = 'La galerie n\'est pas disponible sur cet appareil.';
          break;
        case 'out_of_memory':
          message = 'Mémoire insuffisante pour sélectionner cette image.';
          break;
        default:
          message = 'Erreur: ${e.message ?? 'Erreur inconnue'}';
      }
      _showErrorSnackBar(message);
    } catch (e) {
      _showErrorSnackBar('Erreur inattendue');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showCountryDialog() {
    // Réinitialiser la liste au complet quand le dialog s'ouvre
    setState(() {
      _filteredCountries = List.from(_countries);
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.8,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Header avec titre et bouton fermer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sélectionner un pays',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Barre de recherche
                    TextField(
                      onChanged: (value) {
                        setDialogState(() {
                          _filterCountries(value);
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Rechercher un pays...',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey[400],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.deepPurple,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Liste des pays
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredCountries.length,
                        itemBuilder: (context, index) {
                          final country = _filteredCountries[index];
                          return ListTile(
                            leading: Text(
                              country['flag']!,
                              style: const TextStyle(fontSize: 24),
                            ),
                            title: Text(
                              country['name']!,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              country['code']!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.deepPurple,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                _selectedCountryCode = country['code'];
                                _selectedCountryName = country['name']!;
                                _selectedCountryFlag = country['flag']!;
                              });
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _filterCountries(String query) {
    if (query.isEmpty) {
      _filteredCountries = List.from(_countries);
    } else {
      _filteredCountries = _countries
          .where((country) {
        return country['name']!
            .toLowerCase()
            .contains(query.toLowerCase()) ||
            country['code']!.toLowerCase().contains(query.toLowerCase());
      })
          .toList();
    }
  }
}
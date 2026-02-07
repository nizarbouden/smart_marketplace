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

  // Liste des pays avec leurs codes
  final List<Map<String, String>> _countries = [
    {'name': 'Tunisie', 'code': '+216', 'flag': '🇹🇳'},
    {'name': 'France', 'code': '+33', 'flag': '🇫🇷'},
    {'name': 'Algérie', 'code': '+213', 'flag': '🇩🇿'},
    {'name': 'Maroc', 'code': '+212', 'flag': '🇲🇦'},
    {'name': 'Libye', 'code': '+218', 'flag': '🇱🇾'},
    {'name': 'Égypte', 'code': '+20', 'flag': '🇪🇬'},
    {'name': 'États-Unis', 'code': '+1', 'flag': '🇺🇸'},
    {'name': 'Canada', 'code': '+1', 'flag': '🇨🇦'},
    {'name': 'Royaume-Uni', 'code': '+44', 'flag': '🇬🇧'},
    {'name': 'Allemagne', 'code': '+49', 'flag': '🇩🇪'},
    {'name': 'Italie', 'code': '+39', 'flag': '🇮🇹'},
    {'name': 'Espagne', 'code': '+34', 'flag': '🇪🇸'},
    {'name': 'Belgique', 'code': '+32', 'flag': '🇧🇪'},
    {'name': 'Suisse', 'code': '+41', 'flag': '🇨🇭'},
    {'name': 'Arabie Saoudite', 'code': '+966', 'flag': '🇸🇦'},
    {'name': 'Émirats Arabes Unis', 'code': '+971', 'flag': '🇦🇪'},
    {'name': 'Qatar', 'code': '+974', 'flag': '🇶🇦'},
    {'name': 'Koweït', 'code': '+965', 'flag': '🇰🇼'},
    {'name': 'Turquie', 'code': '+90', 'flag': '🇹🇷'},
    {'name': 'Japon', 'code': '+81', 'flag': '🇯🇵'},
    {'name': 'Chine', 'code': '+86', 'flag': '🇨🇳'},
    {'name': 'Inde', 'code': '+91', 'flag': '🇮🇳'},
    {'name': 'Brésil', 'code': '+55', 'flag': '🇧🇷'},
    {'name': 'Argentine', 'code': '+54', 'flag': '🇦🇷'},
    {'name': 'Mexique', 'code': '+52', 'flag': '🇲🇽'},
    {'name': 'Australie', 'code': '+61', 'flag': '🇦🇺'},
  ];

  String? _selectedCountryCode = '+216'; // Tunisie par défaut
  String _selectedCountryName = 'Tunisie';
  String _selectedCountryFlag = '🇹🇳';

  bool _isLoading = false;

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
    final screenHeight = MediaQuery.of(context).size.height;
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
                                  border: Border.all(color: Colors.white, width: 3),
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
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
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
                      _isLoading ? 'Enregistrement...' : 'Enregistrer les modifications',
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
          // Liste déroulante des pays
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 12 : isTablet ? 10 : 8,
              vertical: isDesktop ? 16 : isTablet ? 14 : 12,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              border: Border(
                right: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCountryCode,
                isDense: true,
                style: TextStyle(
                  fontSize: isDesktop ? 14 : isTablet ? 12 : 11,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                items: _countries.map((country) {
                  return DropdownMenuItem<String>(
                    value: country['code'],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          country['flag']!,
                          style: TextStyle(
                            fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          country['code']!,
                          style: TextStyle(
                            fontSize: isDesktop ? 14 : isTablet ? 12 : 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCountryCode = newValue;
                      final selectedCountry = _countries.firstWhere(
                        (country) => country['code'] == newValue,
                      );
                      _selectedCountryName = selectedCountry['name']!;
                      _selectedCountryFlag = selectedCountry['flag']!;
                    });
                  }
                },
              ),
            ),
          ),
          
          // Séparateur
          Container(
            width: 1,
            height: isDesktop ? 24 : isTablet ? 20 : 16,
            color: Colors.grey[300],
          ),
          
          // Champ téléphone
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: 'Téléphone',
                labelStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: isDesktop ? 16 : isTablet ? 14 : 12,
                ),
                prefixIcon: Icon(
                  Icons.phone,
                  color: Colors.deepPurple,
                  size: isDesktop ? 24 : isTablet ? 22 : 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
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

    // Simuler une sauvegarde
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
          margin: EdgeInsets.all(16),
        ),
      );

      // Retour à la page de profil
      Navigator.of(context).pop();
    }
  }

  void _showImagePickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
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
            SizedBox(height: 20),
            Text(
              'Choisir une photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 20),
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
            SizedBox(height: 20),
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
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
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
      print('Erreur caméra: $e'); // Debug
      _showErrorSnackBar('Erreur lors de la capture de la photo: ${e.toString()}');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      // Vérifier si l'utilisateur a annulé la sélection
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );
      
      if (image != null) {
        // Vérifier que le fichier existe
        final file = File(image.path);
        if (await file.exists()) {
          setState(() {
            _profileImage = file;
          });
        } else {
          _showErrorSnackBar('Le fichier sélectionné n\'existe pas');
        }
      }
      // Si image est null, l'utilisateur a annulé (pas une erreur)
    } on PlatformException catch (e) {
      print('PlatformException galerie: ${e.code} - ${e.message}');
      String message = 'Erreur lors de la sélection de la photo';
      
      switch (e.code) {
        case 'photo_access_denied':
          message = 'Accès à la galerie refusé. Veuillez autoriser l\'accès dans les paramètres.';
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
      print('Erreur galerie: $e');
      _showErrorSnackBar('Erreur inattendue: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(16),
      ),
    );
  }
}

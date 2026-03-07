import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:smart_marketplace/models/countries.dart';
import 'package:smart_marketplace/models/profile_model.dart';
import 'package:smart_marketplace/services/firebase_auth_service.dart';
import 'package:smart_marketplace/providers/auth_provider.dart';

class ProfileViewModel extends ChangeNotifier {
  // Controllers
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  
  // Controllers pour l'adresse
  final TextEditingController streetController;
  final TextEditingController cityController;
  final TextEditingController postalCodeController;
  final TextEditingController countryController;

  // Service d'authentification
  final FirebaseAuthService _authService = FirebaseAuthService();
  bool _isUploadingPhoto = false;
  bool get isUploadingPhoto => _isUploadingPhoto;
  final ImagePicker _picker = ImagePicker();
  // Constructeur avec données utilisateur (par défaut vide)
  ProfileViewModel({
    String firstName = '',
    String lastName = '',
    String email = '',
    String phone = '',
    String countryCode = '+216',
    String? genre,
    String? photoUrl,
  }) 
      : firstNameController = TextEditingController(text: firstName),
        lastNameController = TextEditingController(text: lastName),
        emailController = TextEditingController(text: email), // Utiliser l'email réel passé en paramètre
        phoneController = TextEditingController(text: phone), // Laisser vide si pas de numéro
        streetController = TextEditingController(text: '123 Rue de la République'),
        cityController = TextEditingController(text: 'Tunis'),
        postalCodeController = TextEditingController(text: '1000'),
        countryController = TextEditingController(text: 'Tunisie') {
    _selectedCountryCode = countryCode;
    _selectedGender = genre;
    _profileImageUrl = photoUrl; // Stocker l'URL de la photo
  }

  // État du profil
  ProfileModel _profile = ProfileModel(
    firstName: 'Jean',
    lastName: 'Dupont',
    email: 'jean.dupont@email.com',
    phone: '612345678',
  );

  ProfileModel get profile => _profile;

  // Variables pour les pays
  List<Map<String, String>> _countries = CountryData.getCountriesSorted();
  List<Map<String, String>> _filteredCountries = CountryData.getCountriesSorted();
  String _selectedCountryCode = '+216';
  String _selectedCountryName = 'Tunisie';
  String _selectedCountryFlag = '🇹🇳';

  List<Map<String, String>> get countries => _countries;
  List<Map<String, String>> get filteredCountries => _filteredCountries;
  String get selectedCountryCode => _selectedCountryCode;
  String get selectedCountryName => _selectedCountryName;
  String get selectedCountryFlag => _selectedCountryFlag;

  // Variables pour le genre
  String? _selectedGender;
  final List<String> _genders = ['Homme', 'Femme', 'Ne pas préciser'];

  String? get selectedGender => _selectedGender;
  List<String> get genders => _genders;

  // Variables pour l'image
  File? _profileImage;
  String? _profileImageUrl; // URL de la photo depuis la base de données
  final ImagePicker _imagePicker = ImagePicker();

  File? get profileImage => _profileImage;
  String? get profileImageUrl => _profileImageUrl;

  // Variables d'état
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  // Méthodes pour les pays
  void filterCountries(String query) {
    if (query.isEmpty) {
      _filteredCountries = CountryData.getCountriesSorted();
    } else {
      _filteredCountries = CountryData.filterCountries(query);
    }
    notifyListeners();
  }

  void selectCountry(Map<String, String> country) {
    _selectedCountryCode = country['code'] ?? '+216';
    _selectedCountryName = country['name'] ?? 'Tunisie';
    _selectedCountryFlag = country['flag'] ?? '🇹🇳';
    
    _updateProfile();
    notifyListeners();
  }

  // Méthodes pour le genre
  void selectGender(String gender) {
    if (gender == 'Ne pas préciser') {
      _selectedGender = null;  // Laisse null si "Ne pas préciser"
    } else {
      _selectedGender = gender;
    }
    _updateProfile();
    notifyListeners();
  }

  // Méthodes pour l'image
  Future<void> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800, maxHeight: 800, imageQuality: 85,
      );
      if (image != null) {
        _profileImage = File(image.path);
        notifyListeners();
        await _uploadPhotoToFirebase();
      }
    } catch (e) {
      print('❌ Erreur galerie: $e');
    }
  }
  Future<void> _uploadPhotoToFirebase() async {
    if (_profileImage == null) return;
    _isUploadingPhoto = true;
    notifyListeners();
    try {
      final url = await _authService.uploadProfilePhoto(_profileImage!);
      _profileImageUrl = url;
      _profileImage    = null;
    } catch (e) {
      print('❌ Erreur upload photo: $e');
    } finally {
      _isUploadingPhoto = false;
      notifyListeners();
    }
  }

  Future<void> takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800, maxHeight: 800, imageQuality: 85,
      );
      if (image != null) {
        _profileImage = File(image.path);
        notifyListeners();
        await _uploadPhotoToFirebase();
      }
    } catch (e) {
      print('❌ Erreur caméra: $e');
    }
  }

  Future<void> removePhoto() async {   // ✅ sans BuildContext
    _isUploadingPhoto = true;
    notifyListeners();
    try {
      await _authService.deleteProfilePhoto();
      _profileImageUrl = null;
      _profileImage    = null;
    } catch (e) {
      print('❌ Erreur suppression photo: $e');
    } finally {
      _isUploadingPhoto = false;
      notifyListeners();
    }
  }

  // Méthodes de validation
  String? validateFirstName(String? value) {
    if (value != null && value.isNotEmpty) {
      if (value.length < 2) {
        return 'Le prénom doit contenir au moins 2 caractères';
      }
      if (!RegExp(r'^[a-zA-ZÀ-ÿ\s-]+$').hasMatch(value)) {
        return 'Le prénom ne doit contenir que des lettres';
      }
    }
    return null;
  }

  String? validateLastName(String? value) {
    if (value != null && value.isNotEmpty) {
      if (value.length < 2) {
        return 'Minimum 2 caractères';
      }
      if (!RegExp(r'^[a-zA-ZÀ-ÿ\s-]+$').hasMatch(value)) {
        return 'Lettres uniquement';
      }
    }
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'L\'email est requis';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Veuillez entrer un email valide';
    }
    return null;
  }

  String? validatePhone(String? value) {
    if (value != null && value.isNotEmpty) {
      if (value.length < 8) {
        return 'Le numéro doit contenir au moins 8 chiffres';
      }
      if (!RegExp(r'^[0-9\s-+()]+$').hasMatch(value)) {
        return 'Le numéro ne doit contenir que des chiffres';
      }
    }
    return null;
  }

  // Méthodes de validation pour l'adresse
  String? validateStreet(String? value) {
    if (value == null || value.isEmpty) {
      return 'La rue est requise';
    }
    return null;
  }

  String? validateCity(String? value) {
    if (value == null || value.isEmpty) {
      return 'La ville est requise';
    }
    return null;
  }

  String? validatePostalCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le code postal est requis';
    }
    if (!RegExp(r'^\d{4,5}$').hasMatch(value)) {
      return 'Veuillez entrer un code postal valide';
    }
    return null;
  }

  String? validateCountry(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le pays est requis';
    }
    return null;
  }

  // Méthode de sauvegarde
  Future<bool> saveProfile(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    try {
      print('🔧 Début de la sauvegarde du profil...');
      // Sauvegarder dans Firestore via le service (sans la photo)
      await _authService.updateProfile(
        nom: lastNameController.text.trim(),
        prenom: firstNameController.text.trim(),
        phoneNumber: phoneController.text.trim(),
        countryCode: _selectedCountryCode,
        genre: _selectedGender,

      );
      
      print('🔍 DEBUG: Profil sauvegardé (sans modification photo)');
      
      // Rafraîchir les données dans l'AuthProvider
      if (context.mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.refreshUserProfile();
        print('✅ AuthProvider rafraîchi après sauvegarde');
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('🔍 DEBUG: Erreur lors de la sauvegarde: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Méthode pour rafraîchir les données utilisateur
  Future<void> refreshUserData(BuildContext context) async {
    try {
      // Récupérer les données fraîches depuis Firestore
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.refreshUserProfile();
    } catch (e) {
      // Erreur silencieuse pour ne pas bloquer l'UX
    }
  }

  // Méthode de sauvegarde pour l'adresse
  Future<bool> saveAddress() async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 2));
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Méthode privée pour mettre à jour le profil
  void _updateProfile() {
    _profile = _profile.copyWith(
      firstName: firstNameController.text,
      lastName: lastNameController.text,
      email: emailController.text,
      phone: phoneController.text,
      gender: _selectedGender,
      countryCode: _selectedCountryCode,
      countryName: _selectedCountryName,
      countryFlag: _selectedCountryFlag,
      profileImage: _profileImage,
    );
  }

  // Méthode pour réinitialiser les filtres
  void resetCountryFilter() {
    _filteredCountries = CountryData.getCountriesSorted();
    notifyListeners();
  }

  // Dispose
  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    streetController.dispose();
    cityController.dispose();
    postalCodeController.dispose();
    countryController.dispose();
    super.dispose();
  }
}

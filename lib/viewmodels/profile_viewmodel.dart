import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_marketplace/models/countries.dart';
import 'package:smart_marketplace/models/profile_model.dart';
import 'dart:io';

class ProfileViewModel extends ChangeNotifier {
  // Controllers
  final TextEditingController firstNameController = TextEditingController(text: 'Jean');
  final TextEditingController lastNameController = TextEditingController(text: 'Dupont');
  final TextEditingController emailController = TextEditingController(text: 'jean.dupont@email.com');
  final TextEditingController phoneController = TextEditingController(text: '612345678');
  
  // Controllers pour l'adresse
  final TextEditingController streetController = TextEditingController(text: '123 Rue de la République');
  final TextEditingController cityController = TextEditingController(text: 'Tunis');
  final TextEditingController postalCodeController = TextEditingController(text: '1000');
  final TextEditingController countryController = TextEditingController(text: 'Tunisie');

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
  final ImagePicker _imagePicker = ImagePicker();

  File? get profileImage => _profileImage;

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
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        _profileImage = File(image.path);
        _updateProfile();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
    }
  }

  Future<void> takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        _profileImage = File(photo.path);
        _updateProfile();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
    }
  }

  // Méthodes de validation
  String? validateFirstName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le prénom est requis';
    }
    if (value.length < 2) {
      return 'Le prénom doit contenir au moins 2 caractères';
    }
    return null;
  }

  String? validateLastName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le nom est requis';
    }
    if (value.length < 2) {
      return 'Le nom doit contenir au moins 2 caractères';
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
    if (value == null || value.isEmpty) {
      return 'Le numéro de téléphone est requis';
    }
    if (value.length < 8) {
      return 'Le numéro doit contenir au moins 8 chiffres';
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
  Future<bool> saveProfile() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Simuler une sauvegarde API
      await Future.delayed(const Duration(seconds: 2));
      
      // Mettre à jour le modèle avec les valeurs des controllers
      _updateProfile();
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error saving profile: $e');
      return false;
    }
  }

  // Méthode de sauvegarde pour l'adresse
  Future<bool> saveAddress() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Simuler une sauvegarde API
      await Future.delayed(const Duration(seconds: 2));
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error saving address: $e');
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

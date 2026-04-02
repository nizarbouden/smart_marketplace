import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static const String _languageKey = 'selected_language';
  static const String _defaultLanguage = 'fr'; // Français par défaut

  // Singleton pattern
  static final LanguageService _instance = LanguageService._internal();

  factory LanguageService() {
    return _instance;
  }

  LanguageService._internal();

  // Instance SharedPreferences
  late SharedPreferences _prefs;

  // Langue actuelle
  late String _currentLanguage;

  // ✅ SEULEMENT 3 LANGUES supportées
  static const Map<String, String> _supportedLanguages = {
    'fr': 'Français',
    'en': 'English',
    'ar': 'العربية',
  };

  // Drapeaux pour les 3 langues
  static const Map<String, String> _languageFlags = {
    'fr': '🇫🇷',
    'en': '🇬🇧',
    'ar': '🇸🇦',
  };

  // Initialiser le service au démarrage
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _currentLanguage = _prefs.getString(_languageKey) ?? _defaultLanguage;
      print('🌐 LanguageService: Langue initialisée: $_currentLanguage (${_supportedLanguages[_currentLanguage]})');
    } catch (e) {
      print('❌ LanguageService: Erreur lors de l\'initialisation: $e');
      _currentLanguage = _defaultLanguage;
    }
  }

  // Obtenir la langue actuelle (code)
  String getCurrentLanguageCode() {
    return _currentLanguage;
  }

  // Obtenir le nom de la langue actuelle
  String? getCurrentLanguageName() {
    return _supportedLanguages[_currentLanguage];
  }

  // Obtenir la langue actuelle (nom complet)
  String getCurrentLanguage() {
    return _supportedLanguages[_currentLanguage] ?? _defaultLanguage;
  }

  // Obtenir toutes les langues supportées
  static Map<String, String> getSupportedLanguages() {
    return Map<String, String>.from(_supportedLanguages);
  }

  // Obtenir la liste des codes de langue
  static List<String> getSupportedLanguageCodes() {
    return _supportedLanguages.keys.toList();
  }

  // Vérifier si une langue est supportée
  static bool isLanguageSupported(String languageCode) {
    return _supportedLanguages.containsKey(languageCode);
  }

  // Changer la langue
  Future<void> changeLanguage(String languageCode) async {
    if (!_supportedLanguages.containsKey(languageCode)) {
      print('❌ LanguageService: Langue non supportée: $languageCode');
      return;
    }

    try {
      await _prefs.setString(_languageKey, languageCode);
      _currentLanguage = languageCode;
      print('✅ LanguageService: Langue changée vers $languageCode (${_supportedLanguages[languageCode]})');
    } catch (e) {
      print('❌ LanguageService: Erreur lors du changement de langue: $e');
    }
  }

  // Réinitialiser à la langue par défaut
  Future<void> resetLanguage() async {
    try {
      await _prefs.remove(_languageKey);
      _currentLanguage = _defaultLanguage;
      print('🔄 LanguageService: Langue réinitialisée vers $_defaultLanguage');
    } catch (e) {
      print('❌ LanguageService: Erreur lors de la réinitialisation: $e');
    }
  }

  // Vérifier si la langue actuelle est RTL (droite à gauche)
  bool isCurrentLanguageRTL() {
    return _currentLanguage == 'ar'; // Arabe est RTL
  }

  // Vérifier si une langue spécifique est RTL
  static bool isLanguageRTL(String languageCode) {
    return languageCode == 'ar';
  }

  // Obtenir la direction du texte pour une langue
  String getTextDirection(String languageCode) {
    return isLanguageRTL(languageCode) ? 'rtl' : 'ltr';
  }

  // Obtenir la direction du texte actuelle
  String getCurrentTextDirection() {
    return getTextDirection(_currentLanguage);
  }

  // Sauvegarder les préférences utilisateur
  Future<void> saveUserLanguagePreference(String languageCode) async {
    try {
      await changeLanguage(languageCode);
      print('💾 LanguageService: Préférence linguistique sauvegardée: $languageCode');
    } catch (e) {
      print('❌ LanguageService: Erreur lors de la sauvegarde de la préférence: $e');
    }
  }

  // Charger les préférences utilisateur
  Future<String> loadUserLanguagePreference() async {
    try {
      await init();
      print('📂 LanguageService: Préférence linguistique chargée: $_currentLanguage');
      return _currentLanguage;
    } catch (e) {
      print('❌ LanguageService: Erreur lors du chargement de la préférence: $e');
      return _defaultLanguage;
    }
  }

  // Obtenir tous les détails d'une langue
  static Map<String, dynamic> getLanguageDetails(String languageCode) {
    if (!_supportedLanguages.containsKey(languageCode)) {
      return {};
    }

    return {
      'code': languageCode,
      'name': _supportedLanguages[languageCode],
      'flag': _languageFlags[languageCode],
      'isRTL': isLanguageRTL(languageCode),
      'textDirection': isLanguageRTL(languageCode) ? 'rtl' : 'ltr',
    };
  }

  // Obtenir les détails de la langue actuelle
  Map<String, dynamic> getCurrentLanguageDetails() {
    return getLanguageDetails(_currentLanguage);
  }

  // Obtenir les détails de toutes les langues
  static List<Map<String, dynamic>> getAllLanguagesDetails() {
    return _supportedLanguages.entries.map((entry) {
      return {
        'code': entry.key,
        'name': entry.value,
        'flag': _languageFlags[entry.key],
        'isRTL': isLanguageRTL(entry.key),
        'textDirection': isLanguageRTL(entry.key) ? 'rtl' : 'ltr',
      };
    }).toList();
  }

  // Obtenir la langue par défaut
  static String getDefaultLanguage() {
    return _defaultLanguage;
  }

  // Nombre de langues supportées
  static int getNumberOfSupportedLanguages() {
    return _supportedLanguages.length;
  }

  // Obtenir l'icône drapeau pour une langue (emoji)
  static String getLanguageFlag(String languageCode) {
    return _languageFlags[languageCode] ?? '🌐';
  }

  // Obtenir le drapeau de la langue actuelle
  String getCurrentLanguageFlag() {
    return getLanguageFlag(_currentLanguage);
  }

  // Vérifier si la SharedPreferences est initialisée
  bool get isInitialized {
    try {
      return _prefs != null;
    } catch (e) {
      return false;
    }
  }

  // Obtenir des statistiques
  Map<String, dynamic> getStatistics() {
    return {
      'currentLanguage': _currentLanguage,
      'supportedLanguages': _supportedLanguages.length,
      'isRTL': isCurrentLanguageRTL(),
      'initialized': isInitialized,
    };
  }

  // Afficher les informations du service
  void printInfo() {
    print('═══════════════════════════════════════');
    print('📱 LANGUAGE SERVICE INFO (3 Langues)');
    print('═══════════════════════════════════════');
    print('🌐 Langue actuelle: $_currentLanguage (${_supportedLanguages[_currentLanguage]})');
    print('🏳️ Drapeau: ${getLanguageFlag(_currentLanguage)}');
    print('📍 Direction: ${getCurrentTextDirection()}');
    print('📦 Langues supportées: ${_supportedLanguages.length}');
    print('   - 🇫🇷 Français (fr)');
    print('   - 🇬🇧 English (en)');
    print('   - 🇸🇦 العربية (ar)');
    print('✅ Initialisé: $isInitialized');
    print('═══════════════════════════════════════');
  }

  // Réinitialiser toutes les données
  Future<void> clearAllData() async {
    try {
      await _prefs.clear();
      _currentLanguage = _defaultLanguage;
      print('🧹 LanguageService: Toutes les données supprimées');
    } catch (e) {
      print('❌ LanguageService: Erreur lors de la suppression: $e');
    }
  }
}
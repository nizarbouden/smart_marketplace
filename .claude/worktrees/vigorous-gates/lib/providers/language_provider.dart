import 'package:flutter/material.dart';
import '../services/language_service.dart';
import '../localization/app_localizations.dart';

class LanguageProvider extends ChangeNotifier {
  late LanguageService _languageService;
  String _currentLanguageCode = 'fr';

  LanguageProvider() {
    _languageService = LanguageService();
    _initializeLanguage();
  }

  // Initialiser la langue au démarrage
  Future<void> _initializeLanguage() async {
    try {
      await _languageService.init();
      _currentLanguageCode = _languageService.getCurrentLanguageCode();
      AppLocalizations.setLanguage(_currentLanguageCode);
      notifyListeners();
      print('🌐 LanguageProvider: Langue initialisée: $_currentLanguageCode');
    } catch (e) {
      print('❌ LanguageProvider: Erreur lors de l\'initialisation: $e');
    }
  }

  // Obtenir la langue actuelle
  String get currentLanguageCode => _currentLanguageCode;

  String get currentLanguageName => _languageService.getCurrentLanguageName() ?? 'Français';

  // ✅ SEULEMENT 3 LANGUES supportées
  Map<String, String> get supportedLanguages => <String, String>{
    'fr': '🇫🇷 Français',
    'en': '🇬🇧 English',
    'ar': '🇸🇦 العربية',
  };

  // Changer la langue
  Future<void> setLanguage(String languageCode) async {
    if (!supportedLanguages.containsKey(languageCode)) {
      print('❌ LanguageProvider: Langue non supportée: $languageCode');
      return;
    }

    try {
      await _languageService.changeLanguage(languageCode);
      _currentLanguageCode = languageCode;
      AppLocalizations.setLanguage(languageCode);
      notifyListeners();
      print('✅ LanguageProvider: Langue changée vers $languageCode');
    } catch (e) {
      print('❌ LanguageProvider: Erreur lors du changement de langue: $e');
    }
  }

  // Obtenir la traduction d'une clé
  String translate(String key) => AppLocalizations.get(key, languageCode: _currentLanguageCode);

  // Vérifier si la langue est RTL (droite à gauche)
  bool get isRTL => _currentLanguageCode == 'ar';

  // Obtenir le nom de la langue actuelle avec drapeau
  String get currentLanguageWithFlag {
    return supportedLanguages[_currentLanguageCode] ?? 'Français';
  }

  // Obtenir le drapeau seul
  String get currentLanguageFlag {
    const flags = {
      'fr': '🇫🇷',
      'en': '🇬🇧',
      'ar': '🇸🇦',
    };
    return flags[_currentLanguageCode] ?? '🌐';
  }

  // Obtenir le code court (2 lettres)
  String get languageCode => _currentLanguageCode;
}
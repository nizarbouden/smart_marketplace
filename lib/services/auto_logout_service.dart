import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class AutoLogoutService {
  static final AutoLogoutService _instance = AutoLogoutService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  late SharedPreferences _prefs;

  Timer? _inactivityTimer;

  DateTime _lastActivityTime = DateTime.now();
  bool _warningShown = false;
  bool _isInitialized = false;

  Function? _onLogoutCallback;
  Function(int)? _onWarningCallback;

  factory AutoLogoutService() {
    return _instance;
  }

  AutoLogoutService._internal();

  // ✅ Initialiser une seule fois
  Future<void> init() async {
    if (_isInitialized) {
      print('ℹ️  AutoLogoutService déjà initialisé');
      return;
    }

    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
    print('✅ AutoLogoutService initialisé avec succès');

    // ✅ Charger et démarrer auto-logout si activé
    final settings = await loadAutoLogoutSettings();
    if (settings['enabled'] == true) {
      print('🚀 Auto-logout activé au démarrage: ${settings['duration']}');
      startAutoLogout(settings['duration'] as String);
    }
  }

  void setOnLogoutCallback(Function callback) {
    _onLogoutCallback = callback;
  }

  void setOnWarningCallback(Function(int) callback) {
    _onWarningCallback = callback;
  }

  int _getDurationInSeconds(String duration) {
    switch (duration) {
      case '5 secondes':
        return 15;
      case '15 minutes':
        return 15 * 60;
      case '30 minutes':
        return 30 * 60;
      case '1 heure':
        return 60 * 60;
      case '2 heures':
        return 2 * 60 * 60;
      default:
        return 30 * 60;
    }
  }

  void startAutoLogout(String durationString) {
    if (!_isInitialized) {
      print('❌ AutoLogoutService non initialisé');
      return;
    }

    stopAutoLogout();

    final totalSeconds = _getDurationInSeconds(durationString);

    late int warningThresholdSeconds;

    if (durationString == '5 secondes') {
      warningThresholdSeconds = 5;
      print('⏱️  Auto-logout démarré: 15 secondes total (TEST) 🧪');
      print('⚠️  Avertissement à: 5 secondes (10s d\'affichage)');
    } else {
      warningThresholdSeconds = (totalSeconds * 0.8).toInt();
      print('⏱️  Auto-logout démarré: ${totalSeconds ~/ 60} minutes');
      print('⚠️  Avertissement à: ${warningThresholdSeconds ~/ 60} minutes');
    }

    _lastActivityTime = DateTime.now();
    _warningShown = false;

    _inactivityTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      _checkInactivity(totalSeconds, warningThresholdSeconds);
    });
  }

  void _checkInactivity(int totalSeconds, int warningThresholdSeconds) {
    final now = DateTime.now();
    final elapsedSeconds = now.difference(_lastActivityTime).inSeconds;

    if (elapsedSeconds % 1 == 0 && elapsedSeconds > 0) {
      print('⏲️  Inactivité: ${elapsedSeconds}s / ${totalSeconds}s');
    }

    if (elapsedSeconds >= warningThresholdSeconds &&
        elapsedSeconds < totalSeconds &&
        !_warningShown) {
      _warningShown = true;
      final remainingSeconds = totalSeconds - elapsedSeconds;
      print('⚠️  AVERTISSEMENT! Déconnexion dans ${remainingSeconds}s');
      _onWarningCallback?.call(remainingSeconds);
    }

    if (elapsedSeconds >= totalSeconds) {
      print('❌ DÉCONNEXION! Temps d\'inactivité dépassé');
      _performLogout();
    }
  }

  void stopAutoLogout() {
    _inactivityTimer?.cancel();
    _warningShown = false;
    print('🛑 Auto-logout arrêté');
  }

  // ✅ Enregistrer l'activité avec vérification du service
  void recordActivity() {
    if (!_isInitialized) {
      print('⚠️  AutoLogoutService non initialisé, activité ignorée');
      return;
    }

    _lastActivityTime = DateTime.now();
    _warningShown = false;
    print('✏️  Activité enregistrée, timer réinitialisé');
  }

  Future<void> _performLogout() async {
    stopAutoLogout();
    try {
      await _auth.signOut();
      print('✅ Déconnexion effectuée');
      _onLogoutCallback?.call();
    } catch (e) {
      print('❌ Erreur lors de la déconnexion: $e');
    }
  }

  Future<void> saveAutoLogoutSettings({
    required bool enabled,
    required String duration,
  }) async {
    if (!_isInitialized) {
      print('❌ AutoLogoutService non initialisé');
      return;
    }

    await _prefs.setBool('auto_logout_enabled', enabled);
    await _prefs.setString('auto_logout_duration', duration);
    print('💾 Paramètres auto-logout sauvegardés: enabled=$enabled, duration=$duration');
  }

  Future<Map<String, dynamic>> loadAutoLogoutSettings() async {
    if (!_isInitialized) {
      print('⚠️  AutoLogoutService non initialisé, retour des valeurs par défaut');
      return {
        'enabled': false,
        'duration': '30 minutes',
      };
    }

    final enabled = _prefs.getBool('auto_logout_enabled') ?? false;
    final duration = _prefs.getString('auto_logout_duration') ?? '30 minutes';

    print('📂 Paramètres chargés: enabled=$enabled, duration=$duration');
    return {
      'enabled': enabled,
      'duration': duration,
    };
  }

  bool isAutoLogoutEnabled() {
    if (!_isInitialized) return false;
    return _prefs.getBool('auto_logout_enabled') ?? false;
  }

  String getAutoLogoutDuration() {
    if (!_isInitialized) return '30 minutes';
    return _prefs.getString('auto_logout_duration') ?? '30 minutes';
  }

  int getCurrentInactivitySeconds() {
    return DateTime.now().difference(_lastActivityTime).inSeconds;
  }
}
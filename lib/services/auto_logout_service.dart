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
  bool _warningShown = false; // Suivre si l'avertissement a déjà été affiché

  // Callbacks
  Function? _onLogoutCallback;
  Function(int)? _onWarningCallback;

  factory AutoLogoutService() {
    return _instance;
  }

  AutoLogoutService._internal();

  // Initialiser le service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Enregistrer les callbacks
  void setOnLogoutCallback(Function callback) {
    _onLogoutCallback = callback;
  }

  void setOnWarningCallback(Function(int) callback) {
    _onWarningCallback = callback;
  }

  // Convertir la durée en secondes
  int _getDurationInSeconds(String duration) {
    switch (duration) {
      case '5 secondes':
        return 15; // 5s avant dialog + 10s d'avertissement = 15s total
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

  // Démarrer la surveillance de l'inactivité
  void startAutoLogout(String durationString) {
    // Arrêter les timers existants
    stopAutoLogout();

    final totalSeconds = _getDurationInSeconds(durationString);

    // Calculer le seuil d'avertissement
    // Pour "5 secondes": 5s avant dialog (33% du temps = 5s sur 15s)
    // Pour autres: 80% du temps
    late int warningThresholdSeconds;

    if (durationString == '5 secondes') {
      warningThresholdSeconds = 5; // Dialog après 5 secondes, reste 10 secondes
      print('⏱️  Auto-logout démarré: 15 secondes total (TEST) 🧪');
      print('⚠️  Avertissement à: 5 secondes (10s d\'affichage)');
    } else {
      warningThresholdSeconds = (totalSeconds * 0.8).toInt();
      print('⏱️  Auto-logout démarré: ${totalSeconds ~/ 60} minutes');
      print('⚠️  Avertissement à: ${warningThresholdSeconds ~/ 60} minutes');
    }

    _lastActivityTime = DateTime.now();
    _warningShown = false;

    // Timer principal pour vérifier l'inactivité chaque 100ms (plus précis)
    _inactivityTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      _checkInactivity(totalSeconds, warningThresholdSeconds);
    });
  }

  // Vérifier l'inactivité
  void _checkInactivity(int totalSeconds, int warningThresholdSeconds) {
    final now = DateTime.now();
    final elapsedSeconds = now.difference(_lastActivityTime).inSeconds;

    // Debug: afficher chaque seconde
    if (elapsedSeconds % 1 == 0 && elapsedSeconds > 0) {
      print('⏲️  Inactivité: ${elapsedSeconds}s / ${totalSeconds}s');
    }

    // Si 80% du temps est passé et avertissement non montré
    if (elapsedSeconds >= warningThresholdSeconds &&
        elapsedSeconds < totalSeconds &&
        !_warningShown) {
      _warningShown = true;
      final remainingSeconds = totalSeconds - elapsedSeconds;
      print('⚠️  AVERTISSEMENT! Déconnexion dans ${remainingSeconds}s');
      _onWarningCallback?.call(remainingSeconds);
    }

    // Si le temps limite est atteint
    if (elapsedSeconds >= totalSeconds) {
      print('❌ DÉCONNEXION! Temps d\'inactivité dépassé');
      _performLogout();
    }
  }

  // Arrêter la déconnexion automatique
  void stopAutoLogout() {
    _inactivityTimer?.cancel();
    _warningShown = false;
    print('🛑 Auto-logout arrêté');
  }

  // Enregistrer une activité utilisateur (réinitialiser le timer)
  void recordActivity() {
    _lastActivityTime = DateTime.now();
    _warningShown = false; // Réinitialiser le flag d'avertissement
    print('✏️  Activité enregistrée, timer réinitialisé');
  }

  // Effectuer la déconnexion
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

  // Sauvegarder les paramètres
  Future<void> saveAutoLogoutSettings({
    required bool enabled,
    required String duration,
  }) async {
    await _prefs.setBool('auto_logout_enabled', enabled);
    await _prefs.setString('auto_logout_duration', duration);
    print('💾 Paramètres auto-logout sauvegardés: enabled=$enabled, duration=$duration');
  }

  // Charger les paramètres
  Future<Map<String, dynamic>> loadAutoLogoutSettings() async {
    final enabled = _prefs.getBool('auto_logout_enabled') ?? false;
    final duration = _prefs.getString('auto_logout_duration') ?? '30 minutes';

    print('📂 Paramètres chargés: enabled=$enabled, duration=$duration');
    return {
      'enabled': enabled,
      'duration': duration,
    };
  }

  // Vérifier si l'auto-logout est activé
  bool isAutoLogoutEnabled() {
    return _prefs.getBool('auto_logout_enabled') ?? false;
  }

  // Obtenir la durée configurée
  String getAutoLogoutDuration() {
    return _prefs.getString('auto_logout_duration') ?? '30 minutes';
  }

  // Obtenir le temps d'inactivité actuel (en secondes)
  int getCurrentInactivitySeconds() {
    return DateTime.now().difference(_lastActivityTime).inSeconds;
  }
}
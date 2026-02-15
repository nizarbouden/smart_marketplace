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

  // ✅ NOUVEAU: Utiliser des listeners au lieu de callbacks
  final List<Function(LogoutEvent)> _logoutListeners = [];
  final List<Function(WarningEvent)> _warningListeners = [];

  factory AutoLogoutService() {
    return _instance;
  }

  AutoLogoutService._internal();

  Future<void> init() async {
    if (_isInitialized) {
      print('ℹ️  AutoLogoutService déjà initialisé');
      return;
    }

    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
    print('✅ AutoLogoutService initialisé avec succès');

    final settings = await loadAutoLogoutSettings();
    if (settings['enabled'] == true) {
      print('🚀 Auto-logout activé au démarrage: ${settings['duration']}');
      startAutoLogout(settings['duration'] as String);
    }
  }

  // ✅ ANCIEN système (pour compatibilité)
  Function? _onLogoutCallback;
  Function(int)? _onWarningCallback;

  void setOnLogoutCallback(Function callback) {
    _onLogoutCallback = callback;
  }

  void setOnWarningCallback(Function(int) callback) {
    _onWarningCallback = callback;
  }

  // ✅ NOUVEAU: Système de listeners
  void addLogoutListener(Function(LogoutEvent) listener) {
    _logoutListeners.add(listener);
    print('✅ AutoLogoutService: Logout listener ajouté (total: ${_logoutListeners.length})');
  }

  void removeLogoutListener(Function(LogoutEvent) listener) {
    _logoutListeners.remove(listener);
    print('✅ AutoLogoutService: Logout listener supprimé (total: ${_logoutListeners.length})');
  }

  void addWarningListener(Function(WarningEvent) listener) {
    _warningListeners.add(listener);
    print('✅ AutoLogoutService: Warning listener ajouté (total: ${_warningListeners.length})');
  }

  void removeWarningListener(Function(WarningEvent) listener) {
    _warningListeners.remove(listener);
    print('✅ AutoLogoutService: Warning listener supprimé (total: ${_warningListeners.length})');
  }

  // ✅ Notifier tous les listeners
  void _notifyWarning(int remainingSeconds) {
    print('📢 AutoLogoutService: Notifying ${_warningListeners.length} warning listeners');
    for (var listener in _warningListeners) {
      try {
        listener(WarningEvent(remainingSeconds: remainingSeconds));
      } catch (e) {
        print('❌ Error in warning listener: $e');
      }
    }

    // ✅ Compatibilité avec ancien système
    if (_onWarningCallback != null) {
      try {
        _onWarningCallback!(remainingSeconds);
      } catch (e) {
        print('❌ Error in warning callback: $e');
      }
    }
  }

  void _notifyLogout() {
    print('📢 AutoLogoutService: Notifying ${_logoutListeners.length} logout listeners');
    for (var listener in _logoutListeners) {
      try {
        listener(LogoutEvent());
      } catch (e) {
        print('❌ Error in logout listener: $e');
      }
    }

    // ✅ Compatibilité avec ancien système
    if (_onLogoutCallback != null) {
      try {
        _onLogoutCallback!();
      } catch (e) {
        print('❌ Error in logout callback: $e');
      }
    }
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

    // ✅ Arrêter le timer précédent
    stopAutoLogout();
    print('🛑 Ancien timer arrêté');

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

    print('✅ Nouveau timer créé et démarré');
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

      // ✅ Notifier les listeners
      _notifyWarning(remainingSeconds);
    }

    if (elapsedSeconds >= totalSeconds) {
      print('❌ DÉCONNEXION! Temps d\'inactivité dépassé');
      _performLogout();
    }
  }

  void stopAutoLogout() {
    if (_inactivityTimer != null) {
      _inactivityTimer!.cancel();
      _inactivityTimer = null;
      print('🛑 Auto-logout arrêté');
    }
    _warningShown = false;
  }

  void recordActivity() {
    if (!_isInitialized) {
      print('⚠️  AutoLogoutService non initialisé');
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

      // ✅ Notifier les listeners
      _notifyLogout();
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

    if (enabled) {
      print('🔄 Redémarrage du timer avec la nouvelle durée');
      startAutoLogout(duration);
    } else {
      print('🛑 Arrêt du timer');
      stopAutoLogout();
    }
  }

  Future<Map<String, dynamic>> loadAutoLogoutSettings() async {
    if (!_isInitialized) {
      print('⚠️  AutoLogoutService non initialisé');
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

  bool isTimerRunning() {
    return _inactivityTimer != null && _inactivityTimer!.isActive;
  }

  int? getActiveTimerDuration() {
    if (_inactivityTimer == null || !_inactivityTimer!.isActive) {
      return null;
    }
    return getCurrentInactivitySeconds();
  }
}

// ✅ Classes pour les événements
class LogoutEvent {
  LogoutEvent();
}

class WarningEvent {
  final int remainingSeconds;
  WarningEvent({required this.remainingSeconds});
}
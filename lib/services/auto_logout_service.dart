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

  final List<Function(LogoutEvent)> _logoutListeners = [];
  final List<Function(WarningEvent)> _warningListeners = [];

  factory AutoLogoutService() {
    return _instance;
  }

  AutoLogoutService._internal();

  Future<void> init() async {
    if (_isInitialized) {
      return;
    }

    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;

    final settings = await loadAutoLogoutSettings();
    if (settings['enabled'] == true) {
      startAutoLogout(settings['duration'] as String);
    }
  }

  Function? _onLogoutCallback;
  Function(int)? _onWarningCallback;

  void setOnLogoutCallback(Function callback) {
    _onLogoutCallback = callback;
  }

  void setOnWarningCallback(Function(int) callback) {
    _onWarningCallback = callback;
  }

  void addLogoutListener(Function(LogoutEvent) listener) {
    _logoutListeners.add(listener);
  }

  void removeLogoutListener(Function(LogoutEvent) listener) {
    _logoutListeners.remove(listener);
  }

  void addWarningListener(Function(WarningEvent) listener) {
    _warningListeners.add(listener);
  }

  void removeWarningListener(Function(WarningEvent) listener) {
    _warningListeners.remove(listener);
  }

  void _notifyWarning(int remainingSeconds) {
    for (var listener in _warningListeners) {
      try {
        listener(WarningEvent(remainingSeconds: remainingSeconds));
      } catch (e) {
        print('❌ Error in warning listener: $e');
      }
    }

    if (_onWarningCallback != null) {
      try {
        _onWarningCallback!(remainingSeconds);
      } catch (e) {
        print('❌ Error in warning callback: $e');
      }
    }
  }

  void _notifyLogout() {
    for (var listener in _logoutListeners) {
      try {
        listener(LogoutEvent());
      } catch (e) {
        print('❌ Error in logout listener: $e');
      }
    }

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
      print('❌ AutoLogoutService not initialized');
      return;
    }

    stopAutoLogout();

    final totalSeconds = _getDurationInSeconds(durationString);
    late int warningThresholdSeconds;

    if (durationString == '5 secondes') {
      warningThresholdSeconds = 5;
    } else {
      warningThresholdSeconds = (totalSeconds * 0.8).toInt();
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

    if (elapsedSeconds >= warningThresholdSeconds &&
        elapsedSeconds < totalSeconds &&
        !_warningShown) {
      _warningShown = true;
      final remainingSeconds = totalSeconds - elapsedSeconds;
      _notifyWarning(remainingSeconds);
    }

    if (elapsedSeconds >= totalSeconds) {
      _performLogout();
    }
  }

  void stopAutoLogout() {
    if (_inactivityTimer != null) {
      _inactivityTimer!.cancel();
      _inactivityTimer = null;
    }
    _warningShown = false;
  }

  void recordActivity() {
    if (!_isInitialized) {
      print('⚠️ AutoLogoutService not initialized');
      return;
    }

    _lastActivityTime = DateTime.now();
    _warningShown = false;
  }

  Future<void> _performLogout() async {
    stopAutoLogout();
    try {
      await _auth.signOut();
      _notifyLogout();
    } catch (e) {
      print('❌ Error during logout: $e');
    }
  }

  Future<void> saveAutoLogoutSettings({
    required bool enabled,
    required String duration,
  }) async {
    if (!_isInitialized) {
      print('❌ AutoLogoutService not initialized');
      return;
    }

    try {
      await _prefs.setBool('auto_logout_enabled', enabled);
      await _prefs.setString('auto_logout_duration', duration);

      if (enabled) {
        startAutoLogout(duration);
      } else {
        stopAutoLogout();
      }
    } catch (e) {
      print('❌ Error saving auto-logout settings: $e');
    }
  }

  Future<Map<String, dynamic>> loadAutoLogoutSettings() async {
    if (!_isInitialized) {
      return {
        'enabled': false,
        'duration': '30 minutes',
      };
    }

    try {
      final enabled = _prefs.getBool('auto_logout_enabled') ?? false;
      final duration = _prefs.getString('auto_logout_duration') ?? '30 minutes';

      return {
        'enabled': enabled,
        'duration': duration,
      };
    } catch (e) {
      print('❌ Error loading auto-logout settings: $e');
      return {
        'enabled': false,
        'duration': '30 minutes',
      };
    }
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

class LogoutEvent {
  LogoutEvent();
}

class WarningEvent {
  final int remainingSeconds;
  WarningEvent({required this.remainingSeconds});
}
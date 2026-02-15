import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SessionInfo {
  final String id;
  final String deviceId;
  final String deviceName;
  final String deviceType;
  final String platform;
  final String appVersion;
  final DateTime createdAt;
  final DateTime lastActive;
  final String ipAddress;
  final bool isCurrentSession;
  final String userAgent;

  SessionInfo({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.platform,
    required this.appVersion,
    required this.createdAt,
    required this.lastActive,
    required this.ipAddress,
    required this.isCurrentSession,
    required this.userAgent,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'platform': platform,
      'appVersion': appVersion,
      'createdAt': createdAt.toIso8601String(),
      'lastActive': lastActive.toIso8601String(),
      'ipAddress': ipAddress,
      'isCurrentSession': isCurrentSession,
      'userAgent': userAgent,
    };
  }

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      id: json['id'],
      deviceId: json['deviceId'],
      deviceName: json['deviceName'],
      deviceType: json['deviceType'],
      platform: json['platform'],
      appVersion: json['appVersion'],
      createdAt: DateTime.parse(json['createdAt']),
      lastActive: DateTime.parse(json['lastActive']),
      ipAddress: json['ipAddress'],
      isCurrentSession: json['isCurrentSession'],
      userAgent: json['userAgent'],
    );
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(lastActive);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }
}

class SessionManagementService {
  static final SessionManagementService _instance = SessionManagementService._internal();
  factory SessionManagementService() => _instance;
  SessionManagementService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  SharedPreferences? _prefs;
  final Uuid _uuid = const Uuid();
  
  String? _currentDeviceId;
  String? _currentSessionId;

  // Initialiser le service
  Future<void> init() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    _currentDeviceId = await _getOrCreateDeviceId();
    _currentSessionId = _prefs?.getString('current_session_id') ?? _uuid.v4();
    await _prefs?.setString('current_session_id', _currentSessionId!);
  }

  // S'assurer que le service est initialisé
  Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await init();
    }
  }

  // Obtenir ou créer un ID de device
  Future<String> _getOrCreateDeviceId() async {
    await _ensureInitialized();
    
    String? deviceId = _prefs?.getString('device_id');
    
    if (deviceId == null) {
      try {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        
        if (Platform.isAndroid) {
          AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
          deviceId = 'android_${androidInfo.id}';
        } else if (Platform.isIOS) {
          IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
          deviceId = 'ios_${iosInfo.identifierForVendor}';
        } else {
          deviceId = 'web_${_uuid.v4()}';
        }
        
        await _prefs?.setString('device_id', deviceId!);
      } catch (e) {
        deviceId = 'unknown_${_uuid.v4()}';
        await _prefs?.setString('device_id', deviceId);
      }
    }
    
    return deviceId;
  }

  // Créer une nouvelle session
  Future<SessionInfo> createSession() async {
    if (_currentDeviceId == null) await init();
    
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    try {
      // Obtenir les infos du device
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      String deviceName = 'Appareil inconnu';
      String deviceType = 'unknown';
      String platform = Platform.operatingSystem;

      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.brand} ${androidInfo.model}';
        deviceType = 'android';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceName = '${iosInfo.name} ${iosInfo.model}';
        deviceType = 'ios';
      }

      // Obtenir la version de l'app
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

      final session = SessionInfo(
        id: _currentSessionId!,
        deviceId: _currentDeviceId!,
        deviceName: deviceName,
        deviceType: deviceType,
        platform: platform,
        appVersion: appVersion,
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
        ipAddress: '0.0.0.0', // À implémenter avec un service IP
        isCurrentSession: true,
        userAgent: 'Winzy Marketplace $appVersion',
      );

      // Sauvegarder la session
      await _saveSession(session);
      
      print('✅ Session créée: ${session.deviceName} (${session.deviceType})');
      return session;
    } catch (e) {
      print('❌ Erreur création session: $e');
      rethrow;
    }
  }

  // Sauvegarder une session dans Firestore
  Future<void> _saveSession(SessionInfo session) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Référence à la collection sessions de l'utilisateur
      final sessionsRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions');
      
      // Ajouter la nouvelle session
      await sessionsRef.doc(session.id).set(session.toJson());
      
      print('💾 Session sauvegardée dans Firestore: ${session.deviceName} (${session.deviceType})');
    } catch (e) {
      print('❌ Erreur sauvegarde session Firestore: $e');
    }
  }

  // Obtenir toutes les sessions depuis Firestore
  Future<List<SessionInfo>> getAllSessions() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      // Référence à la collection sessions de l'utilisateur
      final sessionsRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions');
      
      final snapshot = await sessionsRef.get();
      
      final sessions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return SessionInfo.fromJson(data);
      }).toList();
      
      print('📂 Sessions chargées depuis Firestore: ${sessions.length}');
      return sessions;
    } catch (e) {
      print('❌ Erreur chargement sessions Firestore: $e');
      return [];
    }
  }

  // Mettre à jour la dernière activité dans Firestore
  Future<void> updateLastActive() async {
    if (_currentSessionId == null) return;
    
    final sessions = await getAllSessions();
    final sessionIndex = sessions.indexWhere((s) => s.id == _currentSessionId);
    
    if (sessionIndex != -1) {
      try {
        // Créer une SessionInfo mise à jour
        final updatedSession = SessionInfo(
          id: sessions[sessionIndex].id,
          deviceId: sessions[sessionIndex].deviceId,
          deviceName: sessions[sessionIndex].deviceName,
          deviceType: sessions[sessionIndex].deviceType,
          platform: sessions[sessionIndex].platform,
          appVersion: sessions[sessionIndex].appVersion,
          createdAt: sessions[sessionIndex].createdAt,
          lastActive: DateTime.now(), // METTRE À JOUR LE TEMPS
          ipAddress: sessions[sessionIndex].ipAddress,
          isCurrentSession: sessions[sessionIndex].isCurrentSession,
          userAgent: sessions[sessionIndex].userAgent,
        );
        
        // Mettre à jour dans Firestore
        final user = _auth.currentUser;
        if (user != null) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('sessions')
              .doc(sessions[sessionIndex].id)
              .update(updatedSession.toJson());
          
          print('⏰ Session mise à jour dans Firestore: ${sessions[sessionIndex].deviceName}');
        }
      } catch (e) {
        print('❌ Erreur mise à jour session Firestore: $e');
      }
    }
  }

  // Sauvegarder la liste des sessions
  Future<void> _saveSessionList(List<SessionInfo> sessions) async {
    await _ensureInitialized();
    if (_prefs == null) return;
    
    final user = _auth.currentUser;
    if (user == null) return;

    final sessionsJson = sessions.map((s) => s.toJson()).toList();
    await _prefs?.setString('user_sessions_${user.uid}', jsonEncode(sessionsJson));
  }

  // Révoquer une session depuis Firestore
  Future<bool> revokeSession(String sessionId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      // Référence à la session spécifique
      final sessionRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .doc(sessionId);
      
      // Obtenir la session pour vérifier si c'est l'actuelle
      final sessionDoc = await sessionRef.get();
      if (!sessionDoc.exists) return false;
      
      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      final session = SessionInfo.fromJson(sessionData);
      
      if (session.isCurrentSession) {
        print('⚠️ Impossible de révoquer la session actuelle');
        return false;
      }
      
      // Supprimer la session
      await sessionRef.delete();
      print('🗑️ Session révoquée depuis Firestore: ${session.deviceName}');
      return true;
    } catch (e) {
      print('❌ Erreur révocation session Firestore: $e');
      return false;
    }
  }

  // Révoquer toutes les autres sessions depuis Firestore
  Future<int> revokeAllOtherSessions() async {
    try {
      final sessions = await getAllSessions();
      final otherSessions = sessions.where((s) => !s.isCurrentSession).toList();
      
      if (otherSessions.isEmpty) return 0;
      
      // Supprimer toutes les autres sessions
      final user = _auth.currentUser;
      if (user == null) return 0;
      
      final batch = _firestore.batch();
      
      for (final session in otherSessions) {
        final sessionRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('sessions')
            .doc(session.id);
        batch.delete(sessionRef);
      }
      
      await batch.commit();
      print('🗑️ ${otherSessions.length} autres sessions révoquées depuis Firestore');
      return otherSessions.length;
    } catch (e) {
      print('❌ Erreur révocation sessions Firestore: $e');
      return 0;
    }
  }

  // Obtenir le nombre de sessions actives
  Future<int> getActiveSessionsCount() async {
    final sessions = await getAllSessions();
    return sessions.length;
  }

  // Vérifier si la session actuelle est valide
  Future<bool> isCurrentSessionValid() async {
    if (_currentSessionId == null) return false;
    
    final sessions = await getAllSessions();
    return sessions.any((s) => s.id == _currentSessionId);
  }

  // Supprimer toutes les sessions (méthode publique)
  Future<void> deleteAllSessions({BuildContext? context}) async {
    await _ensureInitialized();
    if (_prefs == null) return;
    
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      // Supprimer toutes les sessions de Firestore
      final sessionsRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions');
      
      final snapshot = await sessionsRef.get();
      
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      // Déconnecter l'utilisateur
      await _auth.signOut();
      
      print('🗑️ TOUTES les sessions supprimées et utilisateur déconnecté: ${user.email}');
      
      // Si un contexte est fourni, naviguer vers la page de connexion
      if (context != null && context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    } catch (e) {
      print('❌ Erreur suppression sessions Firestore: $e');
      rethrow;
    }
  }

  // Nettoyer les anciennes sessions (plus de 30 jours)
  Future<int> cleanupOldSessions() async {
    try {
      final sessions = await getAllSessions();
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final validSessions = sessions.where((s) => s.lastActive.isAfter(thirtyDaysAgo)).toList();
      final removedCount = sessions.length - validSessions.length;
      
      if (removedCount > 0) {
        await _saveSessionList(validSessions);
        print('🧹 $removedCount anciennes sessions supprimées');
      }
      
      return removedCount;
    } catch (e) {
      print('❌ Erreur nettoyage sessions: $e');
      return 0;
    }
  }
}

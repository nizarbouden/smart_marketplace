// lib/services/biometric_auth_service.dart
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../localization/app_localizations.dart';

class BiometricAuthService {
  static final BiometricAuthService _instance = BiometricAuthService._internal();
  factory BiometricAuthService() => _instance;
  BiometricAuthService._internal();

  final LocalAuthentication  _localAuth     = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // ── Clés de stockage sécurisé ─────────────────────────────────
  static const String _enabledKey        = 'biometric_enabled';
  static const String _emailKey          = 'biometric_user_email';
  static const String _uidKey            = 'biometric_user_uid';
  static const String _passwordKey       = 'biometric_user_password';
  static const String _providerKey       = 'biometric_provider';      // 'password' | 'google.com'
  static const String _preferredMethodKey = 'biometric_preferred_method'; // 'face' | 'fingerprint'

  // ─────────────────────────────────────────────────────────────────────────────
  //  DISPONIBILITÉ
  // ─────────────────────────────────────────────────────────────────────────────
  Future<bool> isAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics &&
          await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Retourne true si l'appareil supporte à la fois Face et Fingerprint.
  Future<bool> supportsBothMethods() async {
    final types = await getAvailableBiometrics();
    final hasFace        = types.contains(BiometricType.face);
    final hasFingerprint = types.contains(BiometricType.fingerprint) ||
        types.contains(BiometricType.strong) ||
        types.contains(BiometricType.weak);
    return hasFace && hasFingerprint;
  }

  /// Label de la méthode **préférée** (stockée), ou méthode par défaut du device.
  Future<String> getBiometricLabel() async {
    // Si une méthode a déjà été choisie par l'utilisateur, on l'utilise
    final preferred = await getPreferredMethod();
    if (preferred == 'face')        return AppLocalizations.get('biometric_face_id');
    if (preferred == 'fingerprint') return AppLocalizations.get('biometric_fingerprint');

    // Sinon, on retourne la méthode disponible sur l'appareil
    final types = await getAvailableBiometrics();
    if (types.contains(BiometricType.face))        return AppLocalizations.get('biometric_face_id');
    if (types.contains(BiometricType.fingerprint)) return AppLocalizations.get('biometric_fingerprint');
    return AppLocalizations.get('biometric_auth');
  }

  /// Retourne 'face' | 'fingerprint' | null
  Future<String?> getPreferredMethod() async {
    try {
      return await _secureStorage.read(key: _preferredMethodKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> savePreferredMethod(String method) async {
    await _secureStorage.write(key: _preferredMethodKey, value: method);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  ACTIVER LA BIOMÉTRIE
  // ─────────────────────────────────────────────────────────────────────────────

  /// [preferredMethod] : 'face' | 'fingerprint' — choisi par l'utilisateur dans le dialog
  Future<BiometricSetupResult> enableBiometric({
    String? password,
    String? preferredMethod, // ← nouveau paramètre
  }) async {
    try {
      if (!await isAvailable()) return BiometricSetupResult.notAvailable;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return BiometricSetupResult.noUser;

      final provider = user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : 'password';

      if (provider == 'password' && (password == null || password.isEmpty)) {
        return BiometricSetupResult.passwordRequired;
      }

      // ── Authentification biométrique de confirmation ──────────
      final bool authenticated = await _authenticate(
        reason: AppLocalizations.get('biometric_confirm_activation'),
        preferredMethod: preferredMethod,
      );
      if (!authenticated) return BiometricSetupResult.cancelled;

      // ── Stocker toutes les données ────────────────────────────
      await _secureStorage.write(key: _uidKey,      value: user.uid);
      await _secureStorage.write(key: _emailKey,    value: user.email ?? '');
      await _secureStorage.write(key: _providerKey, value: provider);

      if (provider == 'password' && password != null) {
        await _secureStorage.write(key: _passwordKey, value: password);
      }

      // ── Sauvegarder la méthode préférée ───────────────────────
      if (preferredMethod != null) {
        await _secureStorage.write(
            key: _preferredMethodKey, value: preferredMethod);
      }

      await _secureStorage.write(key: _enabledKey, value: 'true');

      return BiometricSetupResult.success;
    } catch (_) {
      return BiometricSetupResult.error;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  DÉSACTIVER
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> disableBiometric() async {
    await _secureStorage.delete(key: _uidKey);
    await _secureStorage.delete(key: _emailKey);
    await _secureStorage.delete(key: _passwordKey);
    await _secureStorage.delete(key: _providerKey);
    await _secureStorage.delete(key: _preferredMethodKey);
    await _secureStorage.write(key: _enabledKey, value: 'false');
  }

  Future<bool> isBiometricEnabled() async {
    try {
      return await _secureStorage.read(key: _enabledKey) == 'true';
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  CONNEXION VIA BIOMÉTRIE
  // ─────────────────────────────────────────────────────────────────────────────
  Future<BiometricLoginResult> loginWithBiometric() async {
    try {
      if (!await isBiometricEnabled()) {
        return BiometricLoginResult(
          success: false,
          error: AppLocalizations.get('biometric_not_enabled'),
        );
      }

      // 1. Récupérer la méthode préférée stockée
      final preferred = await getPreferredMethod();

      // 2. Authentification avec la méthode préférée
      final bool authenticated = await _authenticate(
        reason: AppLocalizations.get('biometric_login_reason'),
        preferredMethod: preferred,
      );
      if (!authenticated) {
        return BiometricLoginResult(
          success: false,
          error: AppLocalizations.get('biometric_cancelled'),
        );
      }

      // 3. Récupérer les données stockées
      final uid      = await _secureStorage.read(key: _uidKey);
      final email    = await _secureStorage.read(key: _emailKey);
      final provider = await _secureStorage.read(key: _providerKey);
      final password = await _secureStorage.read(key: _passwordKey);

      if (uid == null || email == null) {
        return BiometricLoginResult(
          success: false,
          error: AppLocalizations.get('biometric_data_corrupted'),
        );
      }

      // 4. Session encore active → pas besoin de reconnecter
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == uid) {
        return BiometricLoginResult(success: true, user: currentUser, email: email);
      }

      // 5. Session expirée → reconnecter selon le provider
      if (provider == 'google.com') {
        return await _reconnectGoogle(email);
      } else {
        return await _reconnectEmailPassword(email, password);
      }

    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        await disableBiometric();
        return BiometricLoginResult(
          success: false,
          error: AppLocalizations.get('biometric_data_corrupted'),
        );
      }
      return BiometricLoginResult(success: false, error: e.message);
    } catch (e) {
      return BiometricLoginResult(success: false, error: e.toString());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  HELPERS PRIVÉS
  // ─────────────────────────────────────────────────────────────────────────────

  /// Lance l'authentification biométrique.
  /// Sur iOS, [preferredMethod] influence l'UX via LAPolicy (face vs fingerprint).
  /// Sur Android, local_auth utilise le BiometricPrompt natif.
  Future<bool> _authenticate({
    required String reason,
    String? preferredMethod,
  }) async {
    // Note : local_auth ne permet pas de forcer une méthode spécifique via API
    // sur toutes les plateformes. Sur iOS, Face ID est prioritaire si disponible.
    // Le choix utilisateur est surtout utile pour l'UX/affichage — le système
    // biométrique natif reste maître de la méthode d'auth finale.
    // Sur Android, BiometricPrompt gère automatiquement face/fingerprint.
    return await _localAuth.authenticate(
      localizedReason: reason,
      options: AuthenticationOptions(
        stickyAuth:    true,
        // biometricOnly: true force à n'utiliser QUE la bio (pas le PIN)
        biometricOnly: true,
      ),
    );
  }

  Future<BiometricLoginResult> _reconnectGoogle(String email) async {
    try {
      // Tentative silencieuse d'abord
      var googleUser = await GoogleSignIn().signInSilently();
      googleUser ??= await GoogleSignIn().signIn();

      if (googleUser == null) {
        return BiometricLoginResult(
          success: false,
          error:   AppLocalizations.get('biometric_session_expired'),
          email:   email,
        );
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );
      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      return BiometricLoginResult(success: true, user: userCred.user, email: email);

    } catch (_) {
      return BiometricLoginResult(
        success: false,
        error:   AppLocalizations.get('biometric_session_expired'),
        email:   email,
      );
    }
  }

  Future<BiometricLoginResult> _reconnectEmailPassword(
      String email, String? password) async {
    if (password == null || password.isEmpty) {
      return BiometricLoginResult(
        success: false,
        error: AppLocalizations.get('biometric_data_corrupted'),
      );
    }
    final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email, password: password,
    );
    return BiometricLoginResult(success: true, user: userCred.user, email: email);
  }

  Future<void> clearIfUserChanged(String currentUid) async {
    try {
      final storedUid = await _secureStorage.read(key: _uidKey);
      if (storedUid != null && storedUid != currentUid) await disableBiometric();
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ENUMS & RESULT CLASSES
// ─────────────────────────────────────────────────────────────────────────────
enum BiometricSetupResult {
  success,
  notAvailable,
  cancelled,
  noUser,
  passwordRequired,
  error,
}

class BiometricLoginResult {
  final bool    success;
  final User?   user;
  final String? email;
  final String? error;

  const BiometricLoginResult({
    required this.success,
    this.user,
    this.email,
    this.error,
  });
}
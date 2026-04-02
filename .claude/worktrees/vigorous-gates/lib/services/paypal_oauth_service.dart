// lib/services/paypal_oauth_service.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

class PayPalOAuthService {
  static const _clientId     = 'AfDsnNDNKYeatuFh56YrtV5l5y0XFNsFgVwHjvqJqW_L_CvROSYi6IA21x-3OMy7k74ODbhLxZtTywv1';
  static const _clientSecret = 'EIJEDR8sJ9xgqXDEnrIKwA46vYpixHzEnU2nSjFoPevWUPLPu5Jm6ZXDXjD7PO8hVj79CrObJhAtlf6L';

  static const _scheme      = 'com.example.smartmarketplace';
  static const _redirectUri = '$_scheme://paypal-callback';
  static const _isSandbox   = true;

  static String get _baseUrl =>
      _isSandbox ? 'https://www.sandbox.paypal.com' : 'https://www.paypal.com';
  static String get _apiUrl =>
      _isSandbox ? 'https://api-m.sandbox.paypal.com' : 'https://api-m.paypal.com';

  // ── 1. Flow complet OAuth ─────────────────────────────────────
  Future<PayPalAccountResult?> connectPayPalAccount() async {
    try {
      final state = _generateState();

      final authUrl = Uri.parse('$_baseUrl/signin/authorize').replace(
        queryParameters: {
          'client_id':     _clientId,
          'response_type': 'code',
          'scope':         'openid email',
          'redirect_uri':  _redirectUri,
          'state':         state,
        },
      );

      final result = await FlutterWebAuth2.authenticate(
        url:               authUrl.toString(),
        callbackUrlScheme: _scheme,
      );

      final uri           = Uri.parse(result);
      final returnedState = uri.queryParameters['state'];
      final code          = uri.queryParameters['code'];
      final error         = uri.queryParameters['error'];

      if (error != null)          return PayPalAccountResult.cancelled();
      if (returnedState != state) return PayPalAccountResult.error('CSRF détecté');
      if (code == null)           return PayPalAccountResult.error('Code manquant');

      final tokenData = await _exchangeCodeForToken(code);
      if (tokenData == null) return PayPalAccountResult.error('Token invalide');

      final userInfo = await _getUserInfo(
        tokenData['access_token']!,
        idToken: tokenData['id_token'] ?? '',
      );
      if (userInfo == null) return PayPalAccountResult.error('Profil inaccessible');

      return PayPalAccountResult.success(
        email:      userInfo['email']!,
        name:       userInfo['name']!,
        paypalId:   userInfo['paypalId']!,
        isVerified: userInfo['emailVerified'] == 'true',
      );

    } on PlatformException catch (e) {
      if (e.code == 'CANCELED'      ||
          e.code == 'USER_CANCELED' ||
          e.code == 'org.openid.appauth.general') {
        return PayPalAccountResult.cancelled();
      }
      return PayPalAccountResult.error(e.message ?? e.code);
    } catch (e) {
      return PayPalAccountResult.error(e.toString());
    }
  }

  // ── 2. Échange code → tokens ───────────────────────────────────
  Future<Map<String, String>?> _exchangeCodeForToken(String code) async {
    final credentials = base64Encode(utf8.encode('$_clientId:$_clientSecret'));

    final response = await http.post(
      Uri.parse('$_apiUrl/v1/oauth2/token'),
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type':  'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type':   'authorization_code',
        'code':         code,
        'redirect_uri': _redirectUri,
      },
    );

    print('🔑 [PayPal] Token status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // ✅ Log toutes les clés disponibles pour diagnostic
      print('🔑 [PayPal] Token keys: ${data.keys.toList()}');
      print('🔑 [PayPal] id_token present: ${data.containsKey('id_token')}');

      return {
        'access_token': data['access_token'] as String,
        'id_token':     (data['id_token']    as String?) ?? '',
      };
    }

    print('🔑 [PayPal] Token error body: ${response.body}');
    return null;
  }

  // ── 3. Récupère le profil ──────────────────────────────────────
  Future<Map<String, String>?> _getUserInfo(
      String accessToken, {
        String idToken = '',
      }) async {

    // Essai 1 : id_token JWT (pas de réseau)
    if (idToken.isNotEmpty) {
      try {
        final parts = idToken.split('.');
        if (parts.length == 3) {
          String payload = parts[1];
          payload = payload.replaceAll('-', '+').replaceAll('_', '/');
          while (payload.length % 4 != 0) {
            payload += '=';
          }

          final decoded = utf8.decode(base64Decode(payload));
          final data    = jsonDecode(decoded) as Map<String, dynamic>;

          print('🔍 [PayPal] id_token payload: $data');

          final email    = (data['email']         ?? data['sub'] ?? '') as String;
          final name     = (data['name']           ?? data['given_name'] ?? '') as String;
          final sub      = (data['sub']            ?? '') as String;
          final verified = (data['email_verified'] ?? false).toString();

          if (email.isNotEmpty) {
            print('✅ [PayPal] Profil via id_token: email=$email');
            return {
              'email':         email,
              'name':          name,
              'paypalId':      sub,
              'emailVerified': verified,
            };
          }
        }
      } catch (e) {
        print('⚠️ [PayPal] id_token decode failed: $e');
      }
    }

    // Essai 2 : /v1/identity/oauth2/userinfo (endpoint alternatif Sandbox)
    print('🔄 [PayPal] Essai endpoint oauth2/userinfo...');
    final r2 = await http.get(
      Uri.parse('$_apiUrl/v1/identity/oauth2/userinfo?schema=paypalv1.1'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    print('🔍 [PayPal] oauth2/userinfo status: ${r2.statusCode}');
    print('🔍 [PayPal] oauth2/userinfo body: ${r2.body}');

    if (r2.statusCode == 200) {
      final data = jsonDecode(r2.body) as Map<String, dynamic>;
      final emails = data['emails'] as List<dynamic>?;
      final email  = emails != null && emails.isNotEmpty
          ? (emails.first['value'] ?? '') as String
          : (data['email'] ?? '') as String;
      final name   = (data['name'] ?? data['given_name'] ?? '') as String;
      final sub    = (data['user_id'] ?? data['payer_id'] ?? '') as String;
      if (email.isNotEmpty) {
        print('✅ [PayPal] Profil via oauth2/userinfo: email=$email');
        return {
          'email':         email,
          'name':          name,
          'paypalId':      sub,
          'emailVerified': 'true',
        };
      }
    }

    // Essai 3 : /v1/identity/openidconnect/userinfo (endpoint OpenID)
    print('🔄 [PayPal] Essai endpoint openidconnect/userinfo...');
    final r3 = await http.get(
      Uri.parse('$_apiUrl/v1/identity/openidconnect/userinfo?schema=openid'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type':  'application/json',
      },
    );
    print('🔍 [PayPal] openidconnect status: ${r3.statusCode}');
    print('🔍 [PayPal] openidconnect body: ${r3.body}');

    if (r3.statusCode == 200) {
      final data = jsonDecode(r3.body) as Map<String, dynamic>;
      return {
        'email':         (data['email']         ?? '') as String,
        'name':          (data['name']           ?? data['given_name'] ?? '') as String,
        'paypalId':      (data['user_id']        ?? data['sub'] ?? '') as String,
        'emailVerified': (data['email_verified'] ?? false).toString(),
      };
    }

    return null;
  }

  // ── State CSRF ────────────────────────────────────────────────
  String _generateState() {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    return sha256.convert(utf8.encode(ts)).toString().substring(0, 20);
  }
}

// ── Modèle de résultat ────────────────────────────────────────
class PayPalAccountResult {
  final bool    isSuccess;
  final bool    isCancelled;
  final String? errorMessage;
  final String  email;
  final String  name;
  final String  paypalId;
  final bool    isVerified;

  PayPalAccountResult._({
    required this.isSuccess,
    required this.isCancelled,
    this.errorMessage,
    this.email      = '',
    this.name       = '',
    this.paypalId   = '',
    this.isVerified = false,
  });

  factory PayPalAccountResult.success({
    required String email,
    required String name,
    required String paypalId,
    required bool   isVerified,
  }) => PayPalAccountResult._(
    isSuccess:   true,
    isCancelled: false,
    email:       email,
    name:        name,
    paypalId:    paypalId,
    isVerified:  isVerified,
  );

  factory PayPalAccountResult.cancelled() =>
      PayPalAccountResult._(isSuccess: false, isCancelled: true);

  factory PayPalAccountResult.error(String msg) =>
      PayPalAccountResult._(isSuccess: false, isCancelled: false, errorMessage: msg);
}
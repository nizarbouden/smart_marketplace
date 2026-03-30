import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

class PaymentService {
  // ✅ URL Railway
  static const String _baseUrl = 'https://winzy-backend-production.up.railway.app';

  // ✅ PayPal deep link scheme
  static const String _paypalScheme = 'com.example.smartmarketplace';

  // ══════════════════════════════════════════════════════════════
  // STRIPE
  // ══════════════════════════════════════════════════════════════

  // ── Créer un Customer Stripe ──────────────────────────────────
  static Future<String> createStripeCustomer({
    required String email,
    required String name,
    required String firebaseUid,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/create-customer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'name': name, 'firebaseUid': firebaseUid}),
      );

      debugPrint('📡 create-customer status: ${res.statusCode}');
      debugPrint('📡 create-customer body: ${res.body}');

      if (res.statusCode != 200) {
        throw Exception('Backend error ${res.statusCode}: ${res.body}');
      }

      final data       = jsonDecode(res.body) as Map<String, dynamic>;
      final customerId = data['customerId']?.toString()
          ?? data['customer_id']?.toString()
          ?? data['id']?.toString()
          ?? '';

      if (customerId.isEmpty) {
        throw Exception('customerId vide — réponse backend: ${res.body}');
      }

      debugPrint('✅ customerId extrait: $customerId');
      return customerId;

    } catch (e) {
      debugPrint('❌ createStripeCustomer error: $e');
      rethrow;
    }
  }

  // ── Sauvegarder carte avec Stripe ─────────────────────────────
  static Future<Map<String, dynamic>?> saveCard({
    required String customerId,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/create-setup-intent'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'customerId': customerId}),
    );
    final clientSecret = jsonDecode(res.body)['clientSecret'] as String;

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        setupIntentClientSecret: clientSecret,
        merchantDisplayName:     'Smart Marketplace',
      ),
    );

    try {
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return null;
      rethrow;
    }

    final setupIntent     = await Stripe.instance.retrieveSetupIntent(clientSecret);
    final paymentMethodId = setupIntent.paymentMethodId;

    final detailsRes = await http.post(
      Uri.parse('$_baseUrl/get-payment-method'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'paymentMethodId': paymentMethodId}),
    );
    final details = jsonDecode(detailsRes.body);

    return {
      'stripePaymentMethodId': paymentMethodId,
      'stripeCustomerId':      customerId,
      'lastFourDigits':        details['last4']?.toString() ?? '',
      'cardType':              details['brand']?.toString() ?? 'unknown',
      'expiryMonth':           details['exp_month']?.toString() ?? '',
      'expiryYear':            details['exp_year']?.toString() ?? '',
    };
  }

  // ── Payer avec carte sauvegardée ──────────────────────────────
  static Future<bool> processPaymentWithSavedCard({
    required double amount,
    required String currency,
    required String stripeCustomerId,
    required String stripePaymentMethodId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/create-payment-intent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount':          amount,
          'currency':        currency,
          'customerId':      stripeCustomerId,
          'paymentMethodId': stripePaymentMethodId,
        }),
      );
      final data   = jsonDecode(res.body);
      final status = data['status'] as String;

      if (status == 'requires_action') {
        await Stripe.instance.handleNextAction(data['clientSecret']);
      }

      return status == 'succeeded' || status == 'requires_action';

    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return false;
      rethrow;
    }
  }

  // ── Payer sans carte sauvegardée (Payment Sheet normal) ────────
  static Future<bool> processPayment({
    required double amount,
    required String currency,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/create-payment-intent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'amount': amount, 'currency': currency}),
      );
      final clientSecret = jsonDecode(res.body)['clientSecret'] as String;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Smart Marketplace',
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      return true;

    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return false;
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // PAYPAL
  // ══════════════════════════════════════════════════════════════

  /// Paiement PayPal complet :
  /// 1. Crée l'order sur le backend Express
  /// 2. Ouvre la page d'approbation PayPal via flutter_web_auth_2
  /// 3. Capture le paiement après approbation
  static Future<PayPalPaymentResult> processPayPalPayment({
    required double amount,
    String currency    = 'USD',
    String description = 'Winzy Order',
  }) async {
    try {
      // ── Étape 1 : Créer l'order ──────────────────────────────
      debugPrint('💰 [PayPal] Création order: \$$amount $currency');

      final createRes = await http.post(
        Uri.parse('$_baseUrl/paypal/create-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount':      amount,
          'currency':    currency,
          'description': description,
        }),
      );

      debugPrint('💰 [PayPal] create-order status: ${createRes.statusCode}');
      debugPrint('💰 [PayPal] create-order body: ${createRes.body}');

      if (createRes.statusCode != 200) {
        return PayPalPaymentResult.error(
            'Échec création order: ${createRes.body}');
      }

      final createData  = jsonDecode(createRes.body) as Map<String, dynamic>;
      final orderId     = createData['orderId']     as String?;
      final approvalUrl = createData['approvalUrl'] as String?;

      if (orderId == null || approvalUrl == null) {
        return PayPalPaymentResult.error('Réponse backend invalide');
      }

      debugPrint('✅ [PayPal] Order créé: $orderId');

      // ── Étape 2 : Approbation utilisateur ────────────────────
      final callbackResult = await FlutterWebAuth2.authenticate(
        url:               approvalUrl,
        callbackUrlScheme: _paypalScheme,
      );

      // Annulé si redirigé vers cancel URL
      if (callbackResult.contains('paypal-cancel')) {
        debugPrint('⚠️ [PayPal] Annulé par l\'utilisateur');
        return PayPalPaymentResult.cancelled();
      }

      debugPrint('✅ [PayPal] Approuvé — callback: $callbackResult');

      // ── Étape 3 : Capturer le paiement ───────────────────────
      final captureRes = await http.post(
        Uri.parse('$_baseUrl/paypal/capture-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'orderId': orderId}),
      );

      debugPrint('💰 [PayPal] capture status: ${captureRes.statusCode}');
      debugPrint('💰 [PayPal] capture body: ${captureRes.body}');

      final captureData = jsonDecode(captureRes.body) as Map<String, dynamic>;

      if (captureRes.statusCode == 200 && captureData['success'] == true) {
        final captureId = captureData['captureId'] as String? ?? '';
        debugPrint('✅ [PayPal] Paiement capturé: $captureId');
        return PayPalPaymentResult.success(
          orderId:   orderId,
          captureId: captureId,
        );
      }

      return PayPalPaymentResult.error(
          'Capture échouée: ${captureRes.body}');

    } on PlatformException catch (e) {
      if (e.code == 'CANCELED' || e.code == 'USER_CANCELED') {
        return PayPalPaymentResult.cancelled();
      }
      return PayPalPaymentResult.error(e.message ?? e.code);
    } catch (e) {
      debugPrint('❌ [PayPal] Exception: $e');
      return PayPalPaymentResult.error(e.toString());
    }
  }
}

// ── Résultat paiement PayPal ──────────────────────────────────
class PayPalPaymentResult {
  final bool    success;
  final bool    cancelled;
  final String? errorMessage;
  final String  orderId;
  final String  captureId;

  PayPalPaymentResult._({
    required this.success,
    required this.cancelled,
    this.errorMessage,
    this.orderId   = '',
    this.captureId = '',
  });

  factory PayPalPaymentResult.success({
    required String orderId,
    required String captureId,
  }) => PayPalPaymentResult._(
    success:   true,
    cancelled: false,
    orderId:   orderId,
    captureId: captureId,
  );

  factory PayPalPaymentResult.cancelled() =>
      PayPalPaymentResult._(success: false, cancelled: true);

  factory PayPalPaymentResult.error(String msg) =>
      PayPalPaymentResult._(success: false, cancelled: false, errorMessage: msg);
}
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

class PaymentService {
  // ✅ URL Railway au lieu de 10.0.2.2
  static const String _baseUrl = 'https://winzy-backend-production.up.railway.app';

  // ── Créer un Customer Stripe ──────────────────────────────
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

      // ── DEBUG : voir la réponse brute du backend ──────────────
      debugPrint('📡 create-customer status: ${res.statusCode}');
      debugPrint('📡 create-customer body: ${res.body}');

      if (res.statusCode != 200) {
        throw Exception('Backend error ${res.statusCode}: ${res.body}');
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      debugPrint('📦 data reçu: $data');

      // ✅ Chercher customerId avec plusieurs noms possibles
      final customerId = data['customerId']?.toString()
          ?? data['customer_id']?.toString()
          ?? data['id']?.toString()
          ?? '';

      debugPrint('✅ customerId extrait: $customerId');

      if (customerId.isEmpty) {
        throw Exception('customerId vide — réponse backend: ${res.body}');
      }

      return customerId;

    } catch (e) {
      debugPrint('❌ createStripeCustomer error: $e');
      rethrow;
    }
  }

  // ── Sauvegarder carte avec Stripe ─────────────────────────
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
      // ✅ Utilisateur a annulé → pas une erreur
      if (e.error.code == FailureCode.Canceled) return null;
      rethrow;
    }

    final setupIntent     = await Stripe.instance.retrieveSetupIntent(clientSecret);
    final paymentMethodId = setupIntent.paymentMethodId!;

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

  // ── Payer avec carte sauvegardée ──────────────────────────
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

  // ── Payer sans carte sauvegardée (Payment Sheet normal) ───
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
}
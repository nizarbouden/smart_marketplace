import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailJSService {
  static final EmailJSService _instance = EmailJSService._internal();
  factory EmailJSService() => _instance;
  EmailJSService._internal();

  // Configuration EmailJS - À remplacer avec vos vraies valeurs
  static const String _serviceId = 'service_ji6jhpj'; // Remplacez avec votre ID de service EmailJS
  static const String _templateId = 'template_53j2rpf'; // Remplacez avec votre ID de template EmailJS
  static const String _publicKey = 'HwkqFeJ-iru4f1Pbm'; // Remplacez avec votre clé publique EmailJS
  static const String _baseUrl = 'https://api.emailjs.com/api/v1.0/email/send';

  // Envoyer un email de réactivation avec EmailJS
  Future<bool> sendReactivationEmail({
    required String userEmail,
    required String userName,
    required String reactivationToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost:3000', // Remplacez avec votre domaine
        },
        body: jsonEncode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey,
          'template_params': {
            'to_email': userEmail,
            'user_name': userName,
            'reactivation_link': 'https://yourapp.com/reactivate?token=$reactivationToken',
            'expiry_days': '30',
          }
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Email de réactivation envoyé avec EmailJS');
        return true;
      } else {
        print('❌ Erreur EmailJS: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Erreur lors de l\'envoi avec EmailJS: $e');
      return false;
    }
  }

  // Vérifier si EmailJS est configuré
  bool get isConfigured {
    return _serviceId != 'service_your_service_id' &&
           _templateId != 'template_your_template_id' &&
           _publicKey != 'your_public_key';
  }
}

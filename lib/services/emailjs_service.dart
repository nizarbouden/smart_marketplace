import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailJSService {
  static final EmailJSService _instance = EmailJSService._internal();
  factory EmailJSService() => _instance;
  EmailJSService._internal();

  static const String _serviceId         = 'service_ji6jhpj';
  static const String _templateId        = 'template_ec6j7wn';
  static const String _supportTemplateId = 'template_k1lro7i';
  static const String _publicKey         = 'HwkqFeJ-iru4f1Pbm';
  // ✅ Private Key — dashboard.emailjs.com/admin/account/security
  static const String _privateKey        = 'VUF3ISEQgUopatX4gM3Fc';
  static const String _baseUrl           = 'https://api.emailjs.com/api/v1.0/email/send';

  Future<bool> sendReactivationEmail({
    required String userEmail,
    required String userName,
    required String reactivationToken,
  }) async {
    try {
      // ✅ Lien deep link intercepté par l'app Android via AndroidManifest
      //    Format : winzy://reactivate?token=XXXX
      final deepLink = 'winzy://reactivate?token=$reactivationToken';

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id':  _serviceId,
          'template_id': _templateId,
          'user_id':     _publicKey,
          'accessToken': _privateKey, // ✅ strict mode
          'template_params': {
            'to_email':         userEmail,
            'user_name':        userName,
            'expiry_days':      '30',
          },
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Email de réactivation envoyé à $userEmail');
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

  Future<bool> sendSupportEmail({
    required String userName,
    required String userEmail,
    required String issueDescription,
    String? userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id':  _serviceId,
          'template_id': _supportTemplateId,
          'user_id':     _publicKey,
          'accessToken': _privateKey, // ✅ strict mode
          'template_params': {
            'to_email':          'nizarbouden234@gmail.com',
            'from_name':         userName,
            'from_email':        userEmail,
            'user_id':           userId ?? 'Non connecté',
            'issue_description': issueDescription,
            'subject':           'Demande de support Winzy',
            'date':              DateTime.now().toString().split('.')[0],
          },
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Email de support envoyé');
        return true;
      } else {
        print('❌ Erreur EmailJS support: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Erreur lors de l\'envoi de l\'email de support: $e');
      return false;
    }
  }

  bool get isConfigured =>
      _serviceId.isNotEmpty  && !_serviceId.contains('your')  &&
          _templateId.isNotEmpty && !_templateId.contains('your') &&
          _publicKey.isNotEmpty  && !_publicKey.contains('your');
}
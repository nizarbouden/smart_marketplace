import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'emailjs_service.dart';

class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  final EmailJSService _emailJSService = EmailJSService();

  // Envoyer un email de réactivation de compte
  Future<void> sendAccountReactivationEmail({
    required String userEmail,
    required String userId,
    required String userName,
  }) async {
    try {
      final reactivationToken = _generateReactivationToken();

      // 1. Enregistrer dans Firestore pour suivi
      final docRef = await FirebaseFirestore.instance.collection('reactivation_emails').add({
        'userId': userId,
        'userEmail': userEmail,
        'userName': userName,
        'reactivationToken': reactivationToken,
        'createdAt': Timestamp.now(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        'status': 'pending',
        'emailType': 'account_reactivation',
        'processed': false,
      });

      // 2. Essayer d'envoyer l'email avec EmailJS si configuré
      if (_emailJSService.isConfigured) {
        final emailSent = await _emailJSService.sendReactivationEmail(
          userEmail: userEmail,
          userName: userName,
          reactivationToken: reactivationToken,
        );

        if (emailSent) {
          await docRef.update({'processed': true});
          print('✅ Email de réactivation envoyé avec EmailJS');
          return;
        } else {
          print('⚠️ Échec de l\'envoi EmailJS, email en attente');
        }
      } else {
        print('⚠️ EmailJS non configuré - Configurez EmailJS ou Firebase Functions');
        print('📧 Instructions EmailJS:');
        print('1. Créez un compte sur https://www.emailjs.com/');
        print('2. Créez un service email et un template');
        print('3. Mettez à jour les constantes dans emailjs_service.dart');
      }

      print('✅ Demande de réactivation enregistrée dans Firestore');
      print('📧 Document ID: ${docRef.id}');
      print('🔑 Token: $reactivationToken');
      
    } catch (e) {
      print('❌ Erreur lors de l\'envoi de l\'email de réactivation: $e');
      throw Exception('Failed to send reactivation email: $e');
    }
  }

  // Envoyer un email de support automatiquement
  Future<bool> sendSupportEmail({
    required String issueDescription,
    String? userName,
    String? userEmail,
  }) async {
    try {
      // Récupérer les informations de l'utilisateur connecté si non fournies
      final user = FirebaseAuth.instance.currentUser;
      
      final finalUserName = userName ?? user?.displayName ?? 'Utilisateur Winzy';
      final finalUserEmail = userEmail ?? user?.email ?? 'non_fourni@winzy.com';
      final userId = user?.uid;

      // 1. Enregistrer la demande dans Firestore pour suivi
      final docRef = await FirebaseFirestore.instance.collection('support_requests').add({
        'userId': userId,
        'userName': finalUserName,
        'userEmail': finalUserEmail,
        'issueDescription': issueDescription,
        'status': 'pending',
        'createdAt': Timestamp.now(),
        'emailType': 'support_request',
        'processed': false,
      });

      // 2. Essayer d'envoyer l'email avec EmailJS si configuré
      if (_emailJSService.isConfigured) {
        final emailSent = await _emailJSService.sendSupportEmail(
          userName: finalUserName,
          userEmail: finalUserEmail,
          issueDescription: issueDescription,
          userId: userId,
        );

        if (emailSent) {
          await docRef.update({'processed': true});
          print('✅ Email de support envoyé avec EmailJS');
          return true;
        } else {
          print('⚠️ Échec de l\'envoi EmailJS, demande enregistrée dans Firestore');
          return false;
        }
      } else {
        print('⚠️ EmailJS non configuré - La demande est enregistrée dans Firestore');
        print('📧 Instructions EmailJS:');
        print('1. Créez un compte sur https://www.emailjs.com/');
        print('2. Créez un service email et un template pour le support');
        print('3. Mettez à jour les constantes dans emailjs_service.dart');
        return false;
      }
      
    } catch (e) {
      print('❌ Erreur lors de l\'envoi de l\'email de support: $e');
      throw Exception('Failed to send support email: $e');
    }
  }

  // Générer un token de réactivation unique
  String _generateReactivationToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().hashCode;
    return 'react_${timestamp}_$random';
  }

  // Vérifier si un token de réactivation est valide
  Future<bool> isReactivationTokenValid(String token) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('reactivation_emails')
          .where('reactivationToken', isEqualTo: token)
          .where('status', isEqualTo: 'pending')
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('❌ Erreur lors de la vérification du token: $e');
      return false;
    }
  }

  // Réactiver un compte avec un token
  Future<bool> reactivateAccount(String token) async {
    try {
      // Trouver le document du token
      final query = await FirebaseFirestore.instance
          .collection('reactivation_emails')
          .where('reactivationToken', isEqualTo: token)
          .where('status', isEqualTo: 'pending')
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return false;
      }

      final emailDoc = query.docs.first;
      final userId = emailDoc['userId'] as String;

      // Mettre à jour le statut de l'utilisateur
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'status': 'active',
        'reactivatedAt': Timestamp.now(),
        'deletionRequestedAt': null,
        'scheduledDeletionAt': null,
      });

      // Marquer le token comme utilisé
      await emailDoc.reference.update({
        'status': 'used',
        'usedAt': Timestamp.now(),
      });

      print('✅ Compte réactivé avec succès pour l\'utilisateur: $userId');
      return true;
    } catch (e) {
      print('❌ Erreur lors de la réactivation du compte: $e');
      return false;
    }
  }
}

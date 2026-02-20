import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  // Clé de chiffrement simple (en production, utilisez une clé plus sécurisée)
  static const String _encryptionKey = 'SmartMarketplace2024SecureKey!';
  
  /// Chiffrer une chaîne de caractères
  String encrypt(String plainText) {
    try {
      if (plainText.isEmpty) return '';
      
      // Convertir la clé en bytes
      final keyBytes = utf8.encode(_encryptionKey);
      
      // Convertir le texte en bytes
      final textBytes = utf8.encode(plainText);
      
      // Créer un HMAC pour le chiffrement
      final hmac = Hmac(sha256, keyBytes);
      final digest = hmac.convert(textBytes);
      
      // Combiner le texte et le HMAC
      final combined = textBytes + digest.bytes;
      
      // Encoder en base64
      return base64.encode(combined);
    } catch (e) {
      print('❌ Erreur lors du chiffrement: $e');
      return '';
    }
  }

  /// Déchiffrer une chaîne de caractères
  String decrypt(String encryptedText) {
    try {
      if (encryptedText.isEmpty) return '';
      
      // Décoder depuis base64
      final combined = base64.decode(encryptedText);
      
      // Séparer le texte et le HMAC
      final textBytes = combined.sublist(0, combined.length - 32);
      final hmacBytes = combined.sublist(combined.length - 32);
      
      // Vérifier le HMAC
      final keyBytes = utf8.encode(_encryptionKey);
      final hmac = Hmac(sha256, keyBytes);
      final digest = hmac.convert(textBytes);
      
      if (!_bytesEqual(digest.bytes, hmacBytes)) {
        print('❌ Erreur: HMAC invalide');
        return '';
      }
      
      // Décoder le texte
      return utf8.decode(textBytes);
    } catch (e) {
      print('❌ Erreur lors du déchiffrement: $e');
      return '';
    }
  }

  /// Comparer deux listes de bytes en toute sécurité
  bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Générer un token aléatoire pour PayPal
  String generateRandomToken() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    final randomBytes = utf8.encode(random);
    final digest = sha256.convert(randomBytes);
    return digest.toString();
  }

  /// Valider un numéro de carte bancaire (algorithme de Luhn)
  bool isValidCardNumber(String cardNumber) {
    // Supprimer les espaces et les tirets
    String cleanNumber = cardNumber.replaceAll(RegExp(r'[\s-]'), '');
    
    // Vérifier que c'est bien des chiffres
    if (!RegExp(r'^[0-9]+$').hasMatch(cleanNumber)) {
      return false;
    }
    
    // Vérifier la longueur (13-19 chiffres)
    if (cleanNumber.length < 13 || cleanNumber.length > 19) {
      return false;
    }
    
    // Algorithme de Luhn
    int sum = 0;
    bool isSecond = false;
    
    for (int i = cleanNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cleanNumber[i]);
      
      if (isSecond) {
        digit *= 2;
        if (digit > 9) {
          digit = (digit % 10) + 1;
        }
      }
      
      sum += digit;
      isSecond = !isSecond;
    }
    
    return sum % 10 == 0;
  }

  /// Détecter le type de carte bancaire
  String detectCardType(String cardNumber) {
    String cleanNumber = cardNumber.replaceAll(RegExp(r'[\s-]'), '');
    
    // Visa
    if (RegExp(r'^4').hasMatch(cleanNumber)) {
      return 'visa';
    }
    
    // Mastercard
    if (RegExp(r'^5[1-5]').hasMatch(cleanNumber)) {
      return 'mastercard';
    }
    
    // American Express
    if (RegExp(r'^3[47]').hasMatch(cleanNumber)) {
      return 'amex';
    }
    
    // Discover
    if (RegExp(r'^6(?:011|5[0-9]{2})').hasMatch(cleanNumber)) {
      return 'discover';
    }
    
    return 'unknown';
  }

  /// Valider une date d'expiration
  bool isValidExpiry(String month, String year) {
    try {
      int monthInt = int.parse(month);
      int yearInt = int.parse(year);
      
      // Vérifier le mois
      if (monthInt < 1 || monthInt > 12) {
        return false;
      }
      
      // Vérifier que la date n'est pas expirée
      DateTime now = DateTime.now();
      DateTime expiryDate = DateTime(yearInt, monthInt + 1, 0); // Dernier jour du mois
      
      return expiryDate.isAfter(now);
    } catch (e) {
      return false;
    }
  }

  /// Valider un CVV
  bool isValidCvv(String cvv, String cardType) {
    // CVV à 3 chiffres pour la plupart des cartes
    if (cvv.length != 3 || !RegExp(r'^[0-9]{3}$').hasMatch(cvv)) {
      // American Express utilise 4 chiffres
      if (cardType == 'amex' && cvv.length == 4 && RegExp(r'^[0-9]{4}$').hasMatch(cvv)) {
        return true;
      }
      return false;
    }
    return true;
  }

  /// Valider un email PayPal
  bool isValidPayPalEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }
}

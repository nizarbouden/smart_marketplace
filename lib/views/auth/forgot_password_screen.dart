import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  String _errorMessage = '';
  String _generatedOtp = '';

  // Générer un code OTP de 6 chiffres
  String _generateOtpCode() {
    final Random random = Random();
    final String otpCode = (100000 + random.nextInt(900000)).toString();
    print('🔐 OTP généré: $otpCode');
    return otpCode;
  }

  // Envoyer un email avec OTP via EmailJS
  Future<bool> _sendOtpEmail(String email, String otpCode) async {
    try {
      const String serviceId = 'service_o6jt1gj';
      const String templateId = 'template_ufme16q';
      const String userId = 'HwkqFeJ-iru4f1Pbm';

      final Map<String, String> templateParams = {
        'to_email': email,
        'otp_code': otpCode,
        'app_name': 'Winzy',
        'expiry_minutes': '15',
      };

      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: jsonEncode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': userId,
          'template_params': templateParams,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Email OTP envoyé à $email');
        return true;
      } else {
        print('❌ Erreur envoi email: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Erreur EmailJS: $e');
      return false;
    }
  }

  // Stocker l'OTP dans Firestore
  Future<void> _storeOtpInFirestore(String email, String otpCode) async {
    try {
      await FirebaseFirestore.instance.collection('otps').doc(email).set({
        'otp': otpCode,
        'email': email,
        'timestamp': Timestamp.now(),
        'verified': false,
        'attempts': 0,
      });
      print('✅ OTP stocké dans Firestore pour $email');
    } catch (e) {
      print('❌ Erreur stockage OTP: $e');
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final String email = _emailController.text.trim();
      
      // Vérifier si l'email existe dans Firebase Auth
      List<String> signInMethods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      
      if (signInMethods.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Aucun compte trouvé avec cet email';
        });
        return;
      }

      // Générer et stocker l'OTP
      final String otpCode = _generateOtpCode();
      _generatedOtp = otpCode;
      
      // Stocker dans Firestore
      await _storeOtpInFirestore(email, otpCode);
      
      // Envoyer l'email avec OTP
      bool emailSent = await _sendOtpEmail(email, otpCode);
      
      if (emailSent) {
        setState(() {
          _isLoading = false;
          _emailSent = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code OTP envoyé à $email'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur lors de l\'envoi de l\'email';
        });
      }
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Une erreur est survenue';
      });
      print('❌ Erreur générale: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6366F1),
              Color(0xFF8B5CF6),
              Color(0xFFA855F7),
            ],
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: screenHeight),
          child: IntrinsicHeight(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Card(
                  margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  color: Colors.white.withOpacity(0.95),
                  elevation: 15,
                  child: Padding(
                    padding: EdgeInsets.all(screenWidth * 0.08),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_emailSent) ...[
                            // Logo
                            Center(
                              child: SizedBox(
                                width: screenWidth * 0.3,
                                height: screenHeight * 0.12,
                                child: Image.asset('assets/images/logoApp.png'),
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.03),

                            // Titre
                            Text(
                              'ENVOYER L\'EMAIL DE RÉINITIALISATION',
                              style: TextStyle(
                                color: const Color(0xFF8700FF),
                                fontSize: screenWidth * 0.06, // Responsive
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.02),

                            // Description
                            Text(
                              'Entrez votre adresse email pour recevoir\nun lien de réinitialisation de mot de passe',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF718096),
                                fontSize: screenWidth * 0.04, // Responsive
                                height: 1.4,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.03),

                            // Champ email
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: 'votre.email@example.com',
                                hintStyle: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: screenWidth * 0.04, // Responsive
                                ),
                                prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF8700FF), size: screenWidth * 0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Color(0xFF8700FF), width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.02),
                              ),
                              style: TextStyle(
                                fontSize: screenWidth * 0.04, // Responsive
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Veuillez entrer votre adresse email';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                  return 'Veuillez entrer une adresse email valide';
                                }
                                return null;
                              },
                            ),

                            SizedBox(height: screenHeight * 0.03),

                            // Message d'erreur
                            if (_errorMessage.isNotEmpty) ...[
                              Container(
                                padding: EdgeInsets.all(screenWidth * 0.03),
                                decoration: BoxDecoration(
                                  color: Color(0xFFFFF5F5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Color(0xFFFA5450), width: 1),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning_amber_outlined, color: Color(0xFFFA5450), size: screenWidth * 0.05),
                                    SizedBox(width: screenWidth * 0.02),
                                    Expanded(
                                      child: Text(
                                        _errorMessage,
                                        style: TextStyle(color: Color(0xFFFA5450), fontSize: screenWidth * 0.035),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.02),
                            ],

                            // Envoyer Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8700FF),
                                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02), // Responsive
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: _isLoading ? null : _sendPasswordResetEmail,
                                child: _isLoading
                                    ? const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Envoi en cours...',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.email_outlined,
                                      color: Colors.white,
                                      size: screenWidth * 0.05, // Responsive
                                    ),
                                    SizedBox(width: screenWidth * 0.02), // Responsive
                                    Text(
                                      'Envoyer l\'email',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: screenWidth * 0.04, // Responsive
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: screenHeight * 0.02),

                            // Lien retour
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Retourner à la ",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: screenWidth * 0.035, // Responsive
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacementNamed(context, '/login');
                                  },
                                  child: Text(
                                    'page de connexion',
                                    style: TextStyle(
                                      color: Color(0xFF8700FF),
                                      fontSize: screenWidth * 0.035, // Responsive
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Section de confirmation après envoi
                          if (_emailSent) ...[
                            Container(
                              margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
                              padding: EdgeInsets.all(screenWidth * 0.06),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF10B981),
                                    size: screenWidth * 0.15, // Responsive
                                  ),
                                  SizedBox(height: screenHeight * 0.025),
                                  Text(
                                    'Email envoyé !',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.05, // Responsive
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                  SizedBox(height: screenHeight * 0.015),
                                  Text(
                                    'Un lien de réinitialisation a été envoyé à ${_emailController.text}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.035, // Responsive
                                      color: Color(0xFF718096),
                                    ),
                                  ),
                                  SizedBox(height: screenHeight * 0.025),
                                  Text(
                                    'Vérifiez votre boîte de réception et cliquez sur le lien pour réinitialiser votre mot de passe',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.035, // Responsive
                                      color: Color(0xFF718096),
                                    ),
                                  ),
                                  SizedBox(height: screenHeight * 0.04),
                                  SizedBox(
                                    width: double.infinity,
                                    height: screenHeight * 0.07, // Responsive
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.pushReplacementNamed(context, '/login');
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF5689FF),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 3,
                                        shadowColor: const Color(0xFF5689FF).withOpacity(0.3),
                                      ),
                                      child: Text(
                                        'Continuer',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.04, // Responsive
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
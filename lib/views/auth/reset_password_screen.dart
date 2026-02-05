import 'package:flutter/material.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String _password = '';
  String _confirmPassword = '';
  String? passwordError;
  String? confirmPasswordError;

  // Méthodes de validation
  bool _hasMinLength(String password) => password.length >= 8;
  bool _hasLowerCase(String password) => password.contains(RegExp(r'[a-z]'));
  bool _hasUpperCase(String password) => password.contains(RegExp(r'[A-Z]'));
  bool _isPasswordValid(String password) => 
      _hasMinLength(password) && _hasLowerCase(password) && _hasUpperCase(password);

  void validateFields() {
    setState(() {
      passwordError = null;
      confirmPasswordError = null;

      if (_password.isEmpty) {
        passwordError = 'Veuillez entrer votre mot de passe';
      } else if (!_isPasswordValid(_password)) {
        passwordError = 'Le mot de passe ne respecte pas les critères';
      }

      if (_confirmPassword.isEmpty) {
        confirmPasswordError = 'Veuillez confirmer votre mot de passe';
      } else if (_confirmPassword.length < 8) {
        confirmPasswordError = 'Le mot de passe doit contenir au moins 8 caractères';
      } else if (_password != _confirmPassword) {
        confirmPasswordError = 'Les mots de passe ne correspondent pas';
      }
    });
  }

  Widget errorWithIcon(String errorMessage) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_outlined, color: Color(0xFFFA5450), size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Color(0xFFFA5450), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationIndicator(String text, bool isValid) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isValid ? Colors.green : Colors.grey[300],
            border: isValid ? Border.all(color: Colors.green, width: 2) : null,
          ),
          child: isValid
              ? const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 12,
                )
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: isValid ? Colors.green : Colors.grey[600],
            fontWeight: isValid ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
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
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(height: screenHeight * 0.15),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: SizedBox(
                              width: screenWidth * 0.3,
                              height: screenHeight * 0.12,
                              child: Image.asset('assets/images/logoApp.png'),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          const Center(
                            child: Text(
                              'RÉINITIALISER LE MOT DE PASSE',
                              style: TextStyle(
                                color: Color(0xFF8700FF),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.03),

                          // New Password Field
                          TextFormField(
                            obscureText: !_isPasswordVisible,
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[50],
                              hintText: 'Nouveau mot de passe',
                              prefixIcon: const Icon(Icons.lock, color: Color(0xFF8700FF)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                  color: const Color(0xFF8700FF),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF8700FF), width: 2),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _password = value;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer votre mot de passe';
                              }
                              
                              if (!_isPasswordValid(value)) {
                                return '';
                              }
                              
                              return null;
                            },
                          ),
                          
                          // Indicateurs de validation du mot de passe
                          if (_password.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _isPasswordValid(_password) 
                                      ? Colors.green.withOpacity(0.3) 
                                      : Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildValidationIndicator(
                                    '8 caractères minimum',
                                    _hasMinLength(_password),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildValidationIndicator(
                                    '1 lettre minuscule',
                                    _hasLowerCase(_password),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildValidationIndicator(
                                    '1 lettre majuscule',
                                    _hasUpperCase(_password),
                                  ),
                                ],
                              ),
                            ),

                          if (passwordError != null) ...[
                            const SizedBox(height: 8),
                            errorWithIcon(passwordError!),
                          ],

                          SizedBox(height: screenHeight * 0.02),

                          // Confirm New Password Field
                          TextFormField(
                            obscureText: !_isConfirmPasswordVisible,
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[50],
                              hintText: 'Confirmer le mot de passe',
                              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF8700FF)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isConfirmPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: const Color(0xFF8700FF),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF8700FF), width: 2),
                              ),
                            ),
                            onChanged: (value) {
                              _confirmPassword = value;
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez confirmer votre mot de passe';
                              }
                              if (value != _password) {
                                return 'Les mots de passe ne correspondent pas';
                              }
                              return null;
                            },
                          ),
                          if (confirmPasswordError != null) ...[
                            const SizedBox(height: 8),
                            errorWithIcon(confirmPasswordError!),
                          ],

                          SizedBox(height: screenHeight * 0.03),

                          // Reset Password Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8700FF),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              onPressed: () {
                                validateFields();
                                if (passwordError == null && confirmPasswordError == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Mot de passe réinitialisé avec succès!"),
                                      backgroundColor: Color(0xFF8700FF),
                                    ),
                                  );
                                  Navigator.pushReplacementNamed(context, '/login');
                                }
                              },
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Réinitialiser le mot de passe',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.refresh, color: Colors.white),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Back to Login
                          Center(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pushReplacementNamed(context, '/login');
                              },
                              child: const Text(
                                "Retour à la connexion",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8700FF),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: screenHeight * 0.03),
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

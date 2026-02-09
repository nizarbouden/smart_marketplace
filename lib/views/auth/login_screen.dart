import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _rememberMe = false;
  bool _isPasswordVisible = false;
  String _email = '';
  String _password = '';
  bool _isLoading = false;

  // Méthodes de validation
  bool _hasMinLength(String password) => password.length >= 8;
  bool _hasLowerCase(String password) => password.contains(RegExp(r'[a-z]'));
  bool _hasUpperCase(String password) => password.contains(RegExp(r'[A-Z]'));
  bool _isPasswordValid(String password) => 
      _hasMinLength(password) && _hasLowerCase(password) && _hasUpperCase(password);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF6366F1),
              const Color(0xFF8B5CF6),
              const Color(0xFFA855F7),
            ],
          ),
        ),
        child: SizedBox(
          height: screenHeight,
          width: screenWidth,
          child: Center(
            child: SingleChildScrollView(
              child: Card(
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
                        SizedBox(
                          width: screenWidth * 0.3,
                          height: screenHeight * 0.12,
                          child: Image.asset('assets/images/logoApp.png'),
                        ),
                        const SizedBox(height: 20),
                        
                        const Text(
                          'Connexion',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8700FF),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Email Field
                        TextFormField(
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[50],
                            hintText: 'Email',
                            prefixIcon: const Icon(Icons.email, color: Color(0xFF8700FF)),
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
                          onChanged: (value) => _email = value,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer votre email';
                            }
                            final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegex.hasMatch(value)) {
                              return 'Veuillez entrer un email valide';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Password Field
                        TextFormField(
                          obscureText: !_isPasswordVisible,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[50],
                            hintText: 'Mot de passe',
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

                        const SizedBox(height: 15),

                        // Remember me
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value!;
                                });
                              },
                              activeColor: const Color(0xFF8700FF),
                            ),
                            const Text(
                              'Se souvenir de moi',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 10),
                        
                        // Forgot password
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, '/forget-Password');
                              },
                              child: const Text(
                                'Mot de passe oublié?',
                                style: TextStyle(
                                  color: Color(0xFF8700FF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),

                        // Message d'erreur
                        if (authProvider.errorMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              border: Border.all(color: Colors.red[200]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error, color: Colors.red[600], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    authProvider.errorMessage!,
                                    style: TextStyle(color: Colors.red[600], fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Login Button
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
                            onPressed: (authProvider.isLoading || _isLoading) ? null : _handleLogin,
                            child: (authProvider.isLoading || _isLoading)
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
                                      Text('Connexion en cours...'),
                                    ],
                                  )
                                : const Text(
                                    'Se connecter',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Bouton Google
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(color: Colors.grey),
                            ),
                            onPressed: (authProvider.isLoading || _isLoading) ? null : _handleGoogleSignIn,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/google_logo.png',
                                  height: 24,
                                  width: 24,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.account_circle, size: 24);
                                  },
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Continuer avec Google',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Pas de compte? ",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacementNamed(context, '/signup');
                              },
                              child: const Text(
                                "S'inscrire",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8700FF),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
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

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    setState(() {
      _isLoading = true;
    });

    bool success = await authProvider.signIn(
      email: _email.trim(),
      password: _password,
    );

    setState(() {
      _isLoading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connexion réussie !'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    setState(() {
      _isLoading = true;
    });

    bool success = await authProvider.signInWithGoogle();

    setState(() {
      _isLoading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connexion Google réussie !'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacementNamed(context, '/home');
    }
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  bool _isLoading = false;
  bool _agreeToTerms = false;

  // Méthodes de validation
  bool _hasMinLength(String password) => password.length >= 6;
  bool _isPasswordValid(String password) => _hasMinLength(password);

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
                          'Créer un compte',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8700FF),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Email
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
                            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegex.hasMatch(value)) {
                              return 'Veuillez entrer un email valide';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Password
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
                          onChanged: (value) => _password = value,
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
                        const SizedBox(height: 20),

                        // Confirm Password
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
                                _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
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
                          onChanged: (value) => _confirmPassword = value,
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

                        // Password
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
                        
                        const SizedBox(height: 20),

                        // Confirm Password
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
                          onChanged: (value) => _confirmPassword = value,
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
                        const SizedBox(height: 20),
                        
                        // Message d'information
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue[700], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Les autres informations (nom, prénom, etc.) seront à compléter dans votre profil.',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Checkbox conditions générales
                        Row(
                          children: [
                            Checkbox(
                              value: _agreeToTerms,
                              onChanged: (value) {
                                setState(() {
                                  _agreeToTerms = value ?? false;
                                });
                              },
                              activeColor: const Color(0xFF8700FF),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  _showTermsAndConditions();
                                },
                                child: const Text(
                                  'J\'accepte les conditions générales d\'utilisation',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF8700FF),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

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
                            onPressed: (authProvider.isLoading || _isLoading) ? null : _handleSignUp,
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
                                      Text('Inscription en cours...'),
                                    ],
                                  )
                                : const Text(
                                    'S\'inscrire',
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
                                  'assets/icons/google-icon.png',
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
                              "Déjà un compte? ",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacementNamed(context, '/login');
                              },
                              child: const Text(
                                "Se connecter",
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

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez accepter les conditions générales d\'utilisation'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    setState(() {
      _isLoading = true;
    });

    bool success = await authProvider.signUp(
      email: _email.trim(),
      password: _password,
    );

    setState(() {
      _isLoading = false;
    });

    if (success) {
      print('✅ SignUpScreen: Compte créé avec succès, navigation vers /home');
      Navigator.pushReplacementNamed(context, '/home');
      print('✅ SignUpScreen: Navigation vers /home effectuée');
    } else {
      print('❌ SignUpScreen: Échec de la création du compte');
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
      print('✅ SignUpScreen: Connexion Google réussie, navigation vers /home');
      Navigator.pushReplacementNamed(context, '/home');
      print('✅ SignUpScreen: Navigation vers /home effectuée');
    } else {
      print('❌ SignUpScreen: Échec de la connexion Google');
    }
  }

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Conditions Générales d\'Utilisation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8700FF),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Bienvenue sur Winzy !\n\n',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Text(
                  '1. Acceptation des Conditions\n',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'En utilisant notre application, vous acceptez de respecter et de vous conformer aux conditions suivantes.\n\n',
                  style: TextStyle(fontSize: 13),
                ),
                const Text(
                  '2. Utilisation de la Plateforme\n',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Text(
                  '• Winzy est une plateforme de mise en relation entre acheteurs et vendeurs.\n'
                  '• Vous devez fournir des informations exactes et véridiques.\n'
                  '• Vous êtes responsable de la sécurité de votre compte.\n'
                  '• Toute activité frauduleuse entraînera la suspension immédiate de votre compte.\n\n',
                  style: TextStyle(fontSize: 13),
                ),
                const Text(
                  '3. Responsabilités des Vendeurs\n',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Text(
                  '• Les vendeurs doivent décrire précisément leurs produits.\n'
                  '• Les prix affichés doivent être fermes et non négociables sur la plateforme.\n'
                  '• Les vendeurs sont responsables de la livraison des produits vendus.\n'
                  '• Winzy n\'est pas responsable des transactions entre vendeurs et acheteurs.\n\n',
                  style: TextStyle(fontSize: 13),
                ),
                const Text(
                  '4. Responsabilités des Acheteurs\n',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Text(
                  '• Les acheteurs s\'engagent à payer les produits commandés.\n'
                  '• Les retours doivent respecter la politique de retour du vendeur.\n'
                  '• Les acheteurs doivent vérifier les produits avant confirmation de réception.\n\n',
                  style: TextStyle(fontSize: 13),
                ),
                const Text(
                  '5. Propriété Intellectuelle\n',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Text(
                  '• Tout contenu publié sur la plateforme reste la propriété de son auteur.\n'
                  '• Winzy dispose d\'une licence d\'utilisation pour afficher ce contenu.\n'
                  '• Toute copie ou utilisation non autorisée est strictement interdite.\n\n',
                  style: TextStyle(fontSize: 13),
                ),
                const Text(
                  '6. Confidentialité et Données\n',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Text(
                  '• Nous respectons votre vie privée et protégeons vos données personnelles.\n'
                  '• Vos informations sont utilisées uniquement pour améliorer nos services.\n'
                  '• Nous ne partageons jamais vos données sans votre consentement.\n\n',
                  style: TextStyle(fontSize: 13),
                ),
                const Text(
                  '7. Modification des Conditions\n',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Text(
                  '• Winzy se réserve le droit de modifier ces conditions à tout moment.\n'
                  '• Les modifications seront notifiées aux utilisateurs par email ou via l\'application.\n'
                  '• La poursuite de l\'utilisation de l\'application vaut acceptation des nouvelles conditions.\n\n',
                  style: TextStyle(fontSize: 13),
                ),
                const Text(
                  '8. Résolution des Litiges\n',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Text(
                  '• En cas de litige, nous encourageons une résolution amiable entre les parties.\n'
                  '• Si nécessaire, notre service client pourra intervenir pour médiation.\n'
                  '• Les litiges seront soumis à la législation en vigueur dans votre pays.\n\n',
                  style: TextStyle(fontSize: 13),
                ),
                const Text(
                  '9. Limitation de Responsabilité\n',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Text(
                  '• Winzy agit comme intermédiaire et ne peut être tenue responsable des dommages directs ou indirects.\n'
                  '• Notre responsabilité est limitée au montant des commissions perçues.\n'
                  '• Nous ne garantissons pas la qualité des produits vendus par les tiers.\n\n',
                  style: TextStyle(fontSize: 13),
                ),
                const Text(
                  '10. Contact et Support\n',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Dernière mise à jour : ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Fermer',
                style: TextStyle(
                  color: Color(0xFF8700FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _agreeToTerms = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8700FF),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'J\'accepte',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
}

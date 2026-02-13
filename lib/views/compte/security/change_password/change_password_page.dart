import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../services/firebase_auth_service.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;
  
  // Firebase Auth
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseAuthService _authService = FirebaseAuthService();

  // Méthode pour ouvrir la page de sécurité Google
  Future<void> _launchGoogleSecurity() async {
    const url = 'https://myaccount.google.com/security';
    final uri = Uri.parse(url);
    
    print('🔍 DEBUG: Tentative d\'ouverture de l\'URL: $url');
    
    // Méthode alternative simple
    try {
      // Essayer d'abord avec url_launcher
      if (await canLaunchUrl(uri)) {
        print('✅ DEBUG: canLaunchUrl() retourne true');
        
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        print('🚀 DEBUG: launchUrl() retourne: $launched');
        
        if (launched) {
          print('✅ DEBUG: URL lancée avec succès!');
          return;
        }
      }
      
      print('⚠️ DEBUG: url_launcher échoué, essai de la méthode alternative');
      
      // Méthode alternative: copier l'URL dans le presse-papiers et afficher un message
      await _copyUrlAndShowMessage(url);
      
    } catch (e) {
      print('� DEBUG: Exception capturée: ${e.toString()}');
      print('🔥 DEBUG: Type d\'exception: ${e.runtimeType}');
      
      // En cas d'erreur, utiliser la méthode alternative
      await _copyUrlAndShowMessage(url);
    }
  }

  // Méthode alternative: copier l'URL et afficher un message
  Future<void> _copyUrlAndShowMessage(String url) async {
    // Importer flutter/services pour le presse-papiers
    const url = 'https://myaccount.google.com/security';
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ouvrir la sécurité Google'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pour changer votre mot de passe Google, veuillez:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text('1. Copier le lien ci-dessous'),
              const Text('2. Ouvrir votre navigateur'),
              const Text('3. Coller le lien et accéder à la page'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        url,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        try {
                          await Clipboard.setData(ClipboardData(text: url));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Lien copié dans le presse-papiers!'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur lors de la copie: $e'),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Validation du mot de passe
  bool _isPasswordValid(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false; // Au moins une majuscule
    if (!password.contains(RegExp(r'[a-z]'))) return false; // Au moins une minuscule
    return true;
  }

  // Obtenir la liste des erreurs de validation
  List<String> _getPasswordErrors(String password) {
    List<String> errors = [];
    
    if (password.length < 8) {
      errors.add('Au moins 8 caractères');
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      errors.add('Au moins une lettre majuscule');
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      errors.add('Au moins une lettre minuscule');
    }
    
    return errors;
  }

  // Méthode pour changer le mot de passe
  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // Validation
    if (currentPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer votre mot de passe actuel'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un nouveau mot de passe'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_isPasswordValid(newPassword)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le nouveau mot de passe ne respecte pas les conditions requises'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez confirmer votre nouveau mot de passe'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les mots de passe ne correspondent pas'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (currentPassword == newPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le nouveau mot de passe doit être différent de l\'ancien'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Créer les credentials pour la réauthentification
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      // Réauthentifier l'utilisateur
      await user.reauthenticateWithCredential(credential);

      // Changer le mot de passe
      await user.updatePassword(newPassword);

      // Créer une notification de succès
      await _authService.createNotification(
        userId: user.uid,
        title: 'Mot de passe modifié',
        body: 'Votre mot de passe a été changé avec succès',
        type: 'profile',
      );

      // Afficher un message de succès
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mot de passe changé avec succès!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      );

      // Retourner à la page précédente
      Navigator.of(context).pop();
    } catch (e) {
      String errorMessage = 'Erreur lors du changement de mot de passe';
      
      if (e.toString().contains('wrong-password') || 
          e.toString().contains('invalid-credential')) {
        errorMessage = 'Le mot de passe actuel est incorrect';
      } else if (e.toString().contains('too-many-requests')) {
        errorMessage = 'Trop de tentatives. Veuillez réessayer plus tard';
      } else if (e.toString().contains('network-request-failed')) {
        errorMessage = 'Erreur de connexion. Vérifiez votre internet';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    // Vérifier le provider de l'utilisateur
    final user = _auth.currentUser;
    final isGoogleUser = user?.providerData.any((provider) => provider.providerId == 'google.com') ?? false;
    final isEmailUser = user?.providerData.any((provider) => provider.providerId == 'password') ?? false;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back,
            color: Colors.black87,
            size: isDesktop ? 28 : isTablet ? 24 : 20,
          ),
        ),
        title: Text(
          'Changer le mot de passe',
          style: TextStyle(
            color: Colors.black87,
            fontSize: isDesktop ? 24 : isTablet ? 22 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 24 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isMobile ? 24 : 32),
              decoration: BoxDecoration(
                color: isGoogleUser 
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    isGoogleUser 
                        ? Icons.security
                        : Icons.lock_reset,
                    size: isMobile ? 60 : 80,
                    color: isGoogleUser 
                        ? Colors.blue
                        : Colors.deepPurple,
                  ),
                  SizedBox(height: isMobile ? 16 : 20),
                  Text(
                    'Sécurité',
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: isGoogleUser 
                          ? Colors.blue
                          : Colors.deepPurple,
                    ),
                  ),
                  SizedBox(height: isMobile ? 8 : 12),
                  Text(
                    isGoogleUser 
                        ? 'Gérez la sécurité de votre compte Google'
                        : 'Modifiez votre mot de passe pour protéger votre compte',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: isMobile ? 32 : 40),

            // Contenu selon le provider
            if (isGoogleUser) ...[
              // Message pour les utilisateurs Google
              Container(
                padding: EdgeInsets.all(isMobile ? 24 : 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isMobile ? 12 : 16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.info_outline,
                            size: isMobile ? 24 : 28,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(width: isMobile ? 16 : 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Compte Google',
                                style: TextStyle(
                                  fontSize: isMobile ? 18 : 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: isMobile ? 4 : 6),
                              Text(
                                'Votre compte est connecté via Google',
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: isMobile ? 24 : 32),
                    
                    Container(
                      padding: EdgeInsets.all(isMobile ? 16 : 20),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Comment changer votre mot de passe ?',
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                          SizedBox(height: isMobile ? 12 : 16),
                          ...[
                            '1. Allez dans votre compte Google',
                            '2. Cliquez sur "Sécurité"',
                            '3. Sous "Connexion à Google", cliquez sur "Mot de passe"',
                            '4. Suivez les instructions pour changer votre mot de passe',
                          ].map((instruction) => Padding(
                            padding: EdgeInsets.only(bottom: isMobile ? 8 : 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: isMobile ? 20 : 24,
                                  height: isMobile ? 20 : 24,
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      instruction.split('.')[0],
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isMobile ? 10 : 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: isMobile ? 12 : 16),
                                Expanded(
                                  child: Text(
                                    instruction.substring(instruction.indexOf('.') + 2),
                                    style: TextStyle(
                                      fontSize: isMobile ? 14 : 16,
                                      color: Colors.grey[700],
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                          
                          SizedBox(height: isMobile ? 16 : 20),
                          
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isMobile ? 12 : 16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber,
                                  color: Colors.orange,
                                  size: isMobile ? 20 : 24,
                                ),
                                SizedBox(width: isMobile ? 12 : 16),
                                Expanded(
                                  child: Text(
                                    'Le changement de mot de passe doit être effectué directement sur Google pour des raisons de sécurité.',
                                    style: TextStyle(
                                      fontSize: isMobile ? 12 : 14,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: isMobile ? 24 : 32),
                    
                    // Bouton pour aller sur Google
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _launchGoogleSecurity,
                        icon: const Icon(Icons.open_in_browser),
                        label: Text(
                          'Ouvrir la sécurité Google',
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: Colors.blue),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (isEmailUser) ...[
              // Formulaire de changement de mot de passe pour utilisateurs email
              Container(
                padding: EdgeInsets.all(isMobile ? 24 : 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mot de passe actuel
                    Text(
                      'Mot de passe actuel',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: isMobile ? 8 : 12),
                    TextField(
                      controller: _currentPasswordController,
                      obscureText: !_showCurrentPassword,
                      decoration: InputDecoration(
                        hintText: 'Entrez votre mot de passe actuel',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showCurrentPassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _showCurrentPassword = !_showCurrentPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.deepPurple),
                        ),
                      ),
                    ),

                    SizedBox(height: isMobile ? 24 : 32),

                    // Nouveau mot de passe
                    Text(
                      'Nouveau mot de passe',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: isMobile ? 8 : 12),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: !_showNewPassword,
                      decoration: InputDecoration(
                        hintText: 'Entrez votre nouveau mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showNewPassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _showNewPassword = !_showNewPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.deepPurple),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {}); // Pour mettre à jour l'affichage des erreurs
                      },
                    ),

                    // Messages d'erreur pour le nouveau mot de passe
                    if (_newPasswordController.text.isNotEmpty && !_isPasswordValid(_newPasswordController.text))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Le mot de passe doit contenir:',
                                style: TextStyle(
                                  fontSize: isMobile ? 12 : 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              ..._getPasswordErrors(_newPasswordController.text).map((error) => Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 14,
                                      color: Colors.red[600],
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        error,
                                        style: TextStyle(
                                          fontSize: isMobile ? 11 : 12,
                                          color: Colors.red[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                      ),

                    SizedBox(height: isMobile ? 24 : 32),

                    // Confirmation du nouveau mot de passe
                    Text(
                      'Confirmer le nouveau mot de passe',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: isMobile ? 8 : 12),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: !_showConfirmPassword,
                      decoration: InputDecoration(
                        hintText: 'Confirmez votre nouveau mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _showConfirmPassword = !_showConfirmPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.deepPurple),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {}); // Pour mettre à jour l'affichage des erreurs
                      },
                    ),

                    // Message d'erreur pour la confirmation
                    if (_confirmPasswordController.text.isNotEmpty && 
                        _confirmPasswordController.text != _newPasswordController.text)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 16,
                                color: Colors.red[600],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Les mots de passe ne correspondent pas',
                                  style: TextStyle(
                                    fontSize: isMobile ? 11 : 12,
                                    color: Colors.red[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    SizedBox(height: isMobile ? 32 : 40),

                    // Bouton de changement
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Changer le mot de passe',
                                style: TextStyle(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Message pour les autres providers
              Container(
                padding: EdgeInsets.all(isMobile ? 24 : 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info,
                      size: isMobile ? 60 : 80,
                      color: Colors.grey,
                    ),
                    SizedBox(height: isMobile ? 16 : 20),
                    Text(
                      'Méthode de connexion non supportée',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: isMobile ? 8 : 12),
                    Text(
                      'Votre méthode de connexion actuelle ne permet pas de changer le mot de passe depuis cette application.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

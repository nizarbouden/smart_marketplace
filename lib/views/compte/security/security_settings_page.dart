import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../services/auto_logout_service.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../widgets/auto_logout_warning_dialog.dart';
import 'change_password/change_password_page.dart';

class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  bool _twoFactorAuth = false;
  bool _biometricAuth = true;
  bool _loginNotifications = true;
  bool _sessionTimeout = true;
  String _sessionTimeoutValue = '30 minutes';

  // ✅ Variable pour tracker si le service est prêt
  bool _isServiceReady = false;

  // ✅ Variable pour tracker si le dialog est affiché
  bool _dialogShown = false;

  // Firebase Auth
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseAuthService _authService = FirebaseAuthService();
  final AutoLogoutService _autoLogoutService = AutoLogoutService();

  @override
  void initState() {
    super.initState();
    _initializeService();
    _setupAutoLogout();
  }

  // ✅ Initialiser le service correctement
  Future<void> _initializeService() async {
    try {
      // ✅ Initialiser le service
      await _autoLogoutService.init();

      final settings = await _autoLogoutService.loadAutoLogoutSettings();

      if (mounted) {
        setState(() {
          _sessionTimeout = settings['enabled'] ?? false;
          _sessionTimeoutValue = settings['duration'] ?? '30 minutes';
          _isServiceReady = true;
        });
      }

      print('✅ SecuritySettingsPage: Service prêt');
      print('   Statut: enabled=${_sessionTimeout}, duration=${_sessionTimeoutValue}');

      // ✅ Si auto-logout est activé, démarrer le timer
      if (_sessionTimeout) {
        _autoLogoutService.startAutoLogout(_sessionTimeoutValue);
        print('🚀 SecuritySettingsPage: Auto-logout démarré');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation du service: $e');
    }
  }

  // ✅ Configurer les callbacks
  void _setupAutoLogout() {
    _autoLogoutService.setOnLogoutCallback(() {
      print('📌 SecuritySettingsPage: Callback logout reçu');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏱️ Déconnexion automatique - Inactivité détectée'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );

        // ✅ Arrêter le service avant de naviguer
        _autoLogoutService.stopAutoLogout();

        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
              (route) => false,
        );
      }
    });

    _autoLogoutService.setOnWarningCallback((remainingSeconds) {
      print('📌 SecuritySettingsPage: Callback warning reçu: ${remainingSeconds}s');
      if (mounted) {
        // ✅ Appeler directement SANS vérifier canPop()
        _showAutoLogoutWarning(remainingSeconds);
      }
    });
  }

  // ✅ Afficher le dialog d'avertissement (CORRIGÉ)
  void _showAutoLogoutWarning(int remainingSeconds) {
    print('🔔 SecuritySettingsPage: Affichage du dialog d\'avertissement (${remainingSeconds}s)');

    // ✅ Vérifier que le dialog n'est pas déjà affiché
    if (_dialogShown) {
      print('⚠️  SecuritySettingsPage: Dialog déjà affiché, ignoré');
      return;
    }

    // ✅ Marquer le dialog comme affiché
    _dialogShown = true;

    // ✅ Afficher le dialog SANS vérifier canPop()
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AutoLogoutWarningDialog(
        remainingSeconds: remainingSeconds,
        onStayLoggedIn: () {
          print('✅ SecuritySettingsPage: User a cliqué "Rester connecté"');
          _dialogShown = false;

          // ✅ Fermer le dialog
          if (mounted && Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }

          // ✅ Réinitialiser le timer
          _autoLogoutService.recordActivity();
        },
        onLogout: () {
          print('❌ SecuritySettingsPage: User a cliqué "Se déconnecter"');
          _dialogShown = false;

          // ✅ Fermer le dialog
          if (mounted && Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }

          // ✅ Arrêter le service
          _autoLogoutService.stopAutoLogout();

          // ✅ Déconnecter
          _auth.signOut();

          // ✅ Rediriger vers login
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
                  (route) => false,
            );
          }
        },
      ),
    ).then((_) {
      print('🔌 SecuritySettingsPage: Dialog fermé');
      _dialogShown = false;
    });
  }

  @override
  void dispose() {
    // ✅ Ne pas arrêter le service ici, il continue en arrière-plan
    print('🔌 SecuritySettingsPage: dispose() - Service continue');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    // ✅ Afficher un loading spinner pendant l'initialisation
    if (!_isServiceReady) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Sécurité'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(context, isDesktop, isTablet, isMobile),
      body: _buildBody(context, isDesktop, isTablet, isMobile),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDesktop, bool isTablet, bool isMobile) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () {
          print('👈 Retour arrière depuis SecuritySettingsPage');
          Navigator.of(context).pop();
        },
        icon: Icon(
          Icons.arrow_back,
          color: Colors.black87,
          size: isDesktop ? 28 : isTablet ? 24 : 20,
        ),
      ),
      title: Text(
        'Sécurité',
        style: TextStyle(
          color: Colors.black87,
          fontSize: isDesktop ? 24 : isTablet ? 22 : 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: IconButton(
            onPressed: _saveSettings,
            icon: Icon(
              Icons.save,
              color: Colors.deepPurple,
              size: isDesktop ? 24 : isTablet ? 22 : 20,
            ),
            tooltip: 'Enregistrer les paramètres',
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, bool isDesktop, bool isTablet, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 24 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Authentification
          _buildSectionCard(
            title: 'Authentification',
            icon: Icons.lock,
            children: [
              _buildSwitchTile(
                title: 'Authentification à deux facteurs',
                subtitle: 'Ajoute une couche de sécurité supplémentaire',
                value: _twoFactorAuth,
                onChanged: (value) {
                  print('🔒 2FA: $value');
                  setState(() => _twoFactorAuth = value);
                },
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              _buildSwitchTile(
                title: 'Authentification biométrique',
                subtitle: 'Utilisez votre empreinte ou visage',
                value: _biometricAuth,
                onChanged: (value) {
                  print('👆 Biométrie: $value');
                  setState(() => _biometricAuth = value);
                },
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              _buildActionTile(
                title: 'Changer le mot de passe',
                subtitle: 'Mettez à jour votre mot de passe',
                icon: Icons.password,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ChangePasswordPage(),
                    ),
                  );
                },
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
            ],
            isDesktop: isDesktop,
            isTablet: isTablet,
            isMobile: isMobile,
          ),

          SizedBox(height: isMobile ? 20 : isTablet ? 24 : 28),

          // Session
          _buildSectionCard(
            title: 'Session',
            icon: Icons.timer,
            children: [
              _buildSwitchTile(
                title: 'Déconnexion automatique',
                subtitle: 'Déconnexion après inactivité',
                value: _sessionTimeout,
                onChanged: (value) async {
                  print('⏱️  Déconnexion auto: $value');
                  setState(() => _sessionTimeout = value);

                  if (value) {
                    print('🟢 ACTIVATION auto-logout');
                    // ✅ Redémarrer le timer avec la nouvelle durée
                    _autoLogoutService.startAutoLogout(_sessionTimeoutValue);

                    await _autoLogoutService.saveAutoLogoutSettings(
                      enabled: true,
                      duration: _sessionTimeoutValue,
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Déconnexion automatique activée ($_sessionTimeoutValue)'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  } else {
                    print('🔴 DÉSACTIVATION auto-logout');
                    // ✅ Arrêter le timer
                    _autoLogoutService.stopAutoLogout();

                    await _autoLogoutService.saveAutoLogoutSettings(
                      enabled: false,
                      duration: _sessionTimeoutValue,
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❌ Déconnexion automatique désactivée'),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              if (_sessionTimeout)
                _buildDropdownTile(
                  title: 'Délai d\'inactivité',
                  subtitle: 'Temps avant déconnexion automatique',
                  value: _sessionTimeoutValue,
                  items: ['5 secondes', '15 minutes', '30 minutes', '1 heure', '2 heures'],
                  onChanged: (value) async {
                    print('⏳ Changement durée: $value');
                    setState(() => _sessionTimeoutValue = value);

                    // ✅ IMPORTANT: Redémarrer le timer avec la nouvelle durée
                    print('🔄 Redémarrage du timer avec la nouvelle durée');
                    _autoLogoutService.startAutoLogout(value);

                    await _autoLogoutService.saveAutoLogoutSettings(
                      enabled: true,
                      duration: value,
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Délai d\'inactivité changé à $value'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                  isMobile: isMobile,
                ),
              _buildActionTile(
                title: 'Sessions actives',
                subtitle: 'Gérez vos connexions actives',
                icon: Icons.devices,
                onTap: _showActiveSessions,
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
            ],
            isDesktop: isDesktop,
            isTablet: isTablet,
            isMobile: isMobile,
          ),

          SizedBox(height: isMobile ? 20 : isTablet ? 24 : 28),

          // Confidentialité
          _buildSectionCard(
            title: 'Confidentialité',
            icon: Icons.privacy_tip,
            children: [
              _buildSwitchTile(
                title: 'Notifications de connexion',
                subtitle: 'Soyez notifié des nouvelles connexions',
                value: _loginNotifications,
                onChanged: (value) => setState(() => _loginNotifications = value),
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              _buildActionTile(
                title: 'Télécharger vos données',
                subtitle: 'Exportez vos informations personnelles',
                icon: Icons.download,
                onTap: _downloadData,
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              _buildActionTile(
                title: 'Supprimer le compte',
                subtitle: 'Supprimez définitivement votre compte',
                icon: Icons.delete_forever,
                isDanger: true,
                onTap: _showDeleteAccountDialog,
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
            ],
            isDesktop: isDesktop,
            isTablet: isTablet,
            isMobile: isMobile,
          ),

          SizedBox(height: isMobile ? 32 : isTablet ? 40 : 48),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    return Container(
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
          // Header de la section
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 8 : isTablet ? 10 : 12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.deepPurple,
                    size: isDesktop ? 24 : isTablet ? 22 : 20,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isDesktop ? 18 : isTablet ? 17 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // Contenu de la section
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : isTablet ? 20 : 24,
            vertical: isMobile ? 12 : isTablet ? 14 : 16,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: isMobile ? 2 : 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.deepPurple,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          color: Colors.grey[200],
          indent: isMobile ? 16 : isTablet ? 20 : 24,
          endIndent: isMobile ? 16 : isTablet ? 20 : 24,
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isDanger = false,
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : isTablet ? 20 : 24,
              vertical: isMobile ? 12 : isTablet ? 14 : 16,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 8 : isTablet ? 10 : 12),
                  decoration: BoxDecoration(
                    color: isDanger
                        ? Colors.red.withOpacity(0.1)
                        : Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isDanger ? Colors.red : Colors.deepPurple,
                    size: isDesktop ? 20 : isTablet ? 18 : 16,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
                          fontWeight: FontWeight.w600,
                          color: isDanger ? Colors.red : Colors.black87,
                        ),
                      ),
                      SizedBox(height: isMobile ? 2 : 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: isDesktop ? 20 : isTablet ? 18 : 16,
                ),
              ],
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          color: Colors.grey[200],
          indent: isMobile ? 16 : isTablet ? 20 : 24,
          endIndent: isMobile ? 16 : isTablet ? 20 : 24,
        ),
      ],
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required Function(String) onChanged,
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : isTablet ? 20 : 24,
            vertical: isMobile ? 12 : isTablet ? 14 : 16,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: isMobile ? 2 : 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : isTablet ? 16 : 20,
                  vertical: isMobile ? 8 : isTablet ? 10 : 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: value,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      onChanged(newValue);
                    }
                  },
                  items: items.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                        ),
                      ),
                    );
                  }).toList(),
                  underline: const SizedBox(),
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.deepPurple,
                    size: isDesktop ? 20 : isTablet ? 18 : 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          color: Colors.grey[200],
          indent: isMobile ? 16 : isTablet ? 20 : 24,
          endIndent: isMobile ? 16 : isTablet ? 20 : 24,
        ),
      ],
    );
  }

  void _saveSettings() async {
    print('💾 Sauvegarde des paramètres');
    if (_sessionTimeout) {
      // ✅ Redémarrer le timer avec les nouveaux paramètres
      _autoLogoutService.startAutoLogout(_sessionTimeoutValue);

      await _autoLogoutService.saveAutoLogoutSettings(
        enabled: true,
        duration: _sessionTimeoutValue,
      );
    } else {
      // ✅ Arrêter le timer
      _autoLogoutService.stopAutoLogout();

      await _autoLogoutService.saveAutoLogoutSettings(
        enabled: false,
        duration: _sessionTimeoutValue,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✅ Paramètres de sécurité enregistrés!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  void _showActiveSessions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sessions actives'),
        content: const Text('Gestion des sessions actives à implémenter.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _downloadData() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Utilisateur non connecté'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Afficher un dialogue de confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Télécharger vos données'),
        content: const Text(
          'Voulez-vous télécharger toutes vos informations personnelles ?\n\n'
              'Ceci inclut :\n'
              '• Votre profil\n'
              '• Vos adresses\n'
              '• Vos préférences\n'
              '• L\'historique des notifications',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Télécharger'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Préparation du téléchargement...'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final userData = await _getUserCompleteData(user.uid);

      final exportData = {
        'export_info': {
          'date': DateTime.now().toIso8601String(),
          'version': '1.0.0',
          'user_id': user.uid,
          'app_name': 'Winzy Marketplace',
        },
        'profile': {
          'email': user.email,
          'display_name': user.displayName,
          'photo_url': user.photoURL,
          'email_verified': user.emailVerified,
          'creation_time': user.metadata.creationTime?.toIso8601String(),
          'last_sign_in': user.metadata.lastSignInTime?.toIso8601String(),
        },
        'addresses': userData['addresses'] ?? [],
        'preferences': userData['preferences'] ?? {},
        'notifications_count': userData['notifications_count'] ?? 0,
      };

      final jsonString = jsonEncode(exportData);

      final readableContent = '''========================================
     MES DONNÉES PERSONNELLES - WINZY MARKETPLACE
========================================

Date d'export: ${DateTime.now().toString().split('.')[0]}
Version: 1.0.0
Application: Winzy Marketplace

Ce fichier contient toutes vos informations personnelles
exportées depuis votre compte Winzy Marketplace.

========================================
        DONNÉES AU FORMAT JSON
========================================

$jsonString

========================================
           INSTRUCTIONS
========================================

1. Ce fichier peut être ouvert avec n'importe quel éditeur de texte
2. Vous pouvez copier-coller les données JSON dans un validateur en ligne
3. Pour importer vos données dans une autre application, utilisez la section JSON ci-dessus
4. Conservez ce fichier dans un endroit sécurisé

Pour plus d'informations, contactez le support Winzy Marketplace.
========================================''';

      final bytes = utf8.encode(readableContent);

      Directory directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final fileName = 'winzy_donnees_personnelles_${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File('${directory.path}/$fileName');

      print('🔍 DEBUG: Répertoire de sauvegarde: ${directory.path}');
      print('🔍 DEBUG: Chemin complet du fichier: ${file.path}');

      await file.writeAsBytes(bytes);

      final fileExists = await file.exists();
      print('🔍 DEBUG: Fichier créé avec succès? $fileExists');

      if (!fileExists) {
        throw Exception('Impossible de créer le fichier dans: ${file.path}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Données exportées avec succès !\nFichier: ${file.path}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Partager',
              textColor: Colors.white,
              onPressed: () async {
                try {
                  await Share.share(
                    readableContent,
                    subject: 'Mes données personnelles Winzy',
                    sharePositionOrigin: null,
                  );
                } catch (e) {
                  print('Erreur partage: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Erreur lors du partage: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur lors du téléchargement: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _getUserCompleteData(String userId) async {
    try {
      final addresses = await _authService.getUserAddresses();
      final notifications = await _authService.getUserNotifications();

      final preferences = {
        'theme': 'light',
        'language': 'fr',
        'notifications_enabled': true,
      };

      return {
        'addresses': addresses.map((addr) => {
          'id': addr['id'],
          'title': addr['title'],
          'street': addr['street'],
          'city': addr['city'],
          'postal_code': addr['postalCode'],
          'country': addr['country'],
          'is_default': addr['isDefault'],
        }).toList(),
        'preferences': preferences,
        'notifications_count': notifications.length,
      };
    } catch (e) {
      print('Erreur lors de la récupération des données: $e');
      return {
        'addresses': <Map<String, dynamic>>[],
        'preferences': {},
        'notifications_count': 0,
      };
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Supprimer le compte',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer votre compte ? Cette action est irréversible et toutes vos données seront perdues.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Suppression du compte à implémenter.'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/firebase_auth_service.dart';
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

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
        onPressed: () => Navigator.of(context).pop(),
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
                onChanged: (value) => setState(() => _twoFactorAuth = value),
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              _buildSwitchTile(
                title: 'Authentification biométrique',
                subtitle: 'Utilisez votre empreinte ou visage',
                value: _biometricAuth,
                onChanged: (value) => setState(() => _biometricAuth = value),
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
                onChanged: (value) => setState(() => _sessionTimeout = value),
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              if (_sessionTimeout)
                _buildDropdownTile(
                  title: 'Délai d\'inactivité',
                  subtitle: 'Temps avant déconnexion automatique',
                  value: _sessionTimeoutValue,
                  items: ['15 minutes', '30 minutes', '1 heure', '2 heures'],
                  onChanged: (value) => setState(() => _sessionTimeoutValue = value),
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

  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Paramètres de sécurité enregistrés!'),
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

  void _downloadData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Téléchargement de vos données en cours...'),
        backgroundColor: Colors.blue,
      ),
    );
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

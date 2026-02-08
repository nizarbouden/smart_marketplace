import 'package:flutter/material.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  // États des notifications
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _orderUpdates = true;
  bool _promotionalOffers = false;
  bool _newProducts = true;
  bool _priceDrops = true;
  bool _newsletter = false;
  bool _accountUpdates = true;
  bool _securityAlerts = true;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(context, isDesktop, isTablet, isMobile),
      body: _buildBody(context, isDesktop, isTablet, isMobile),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDesktop,
      bool isTablet, bool isMobile) {
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
        'Paramètres de notification',
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

  Widget _buildBody(BuildContext context, bool isDesktop, bool isTablet,
      bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 24 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Notifications générales
          _buildSectionCard(
            title: 'Notifications générales',
            icon: Icons.notifications_active,
            children: [
              _buildSwitchTile(
                title: 'Notifications push',
                subtitle: 'Recevoir des notifications sur votre appareil',
                value: _pushNotifications,
                onChanged: (value) =>
                    setState(() => _pushNotifications = value),
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              _buildSwitchTile(
                title: 'Notifications par email',
                subtitle: 'Recevoir des notifications par email',
                value: _emailNotifications,
                onChanged: (value) =>
                    setState(() => _emailNotifications = value),
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

          // Section Commandes
          _buildSectionCard(
            title: 'Commandes et livraisons',
            icon: Icons.shopping_cart,
            children: [
              _buildSwitchTile(
                title: 'Mises à jour de commande',
                subtitle: 'Suivi de votre commande et livraison',
                value: _orderUpdates,
                onChanged: (value) => setState(() => _orderUpdates = value),
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

          // Section Marketing
          _buildSectionCard(
            title: 'Marketing et promotions',
            icon: Icons.campaign,
            children: [
              _buildSwitchTile(
                title: 'Offres promotionnelles',
                subtitle: 'Réductions et offres spéciales',
                value: _promotionalOffers,
                onChanged: (value) =>
                    setState(() => _promotionalOffers = value),
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              _buildSwitchTile(
                title: 'Nouveaux produits',
                subtitle: 'Découvrez les nouveaux arrivages',
                value: _newProducts,
                onChanged: (value) => setState(() => _newProducts = value),
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              _buildSwitchTile(
                title: 'Baisse de prix',
                subtitle: 'Alertes lorsque les prix baissent',
                value: _priceDrops,
                onChanged: (value) => setState(() => _priceDrops = value),
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              _buildSwitchTile(
                title: 'Newsletter',
                subtitle: 'Actualités et conseils hebdomadaires',
                value: _newsletter,
                onChanged: (value) => setState(() => _newsletter = value),
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

          // Section Compte
          _buildSectionCard(
            title: 'Compte et sécurité',
            icon: Icons.account_circle,
            children: [
              _buildSwitchTile(
                title: 'Mises à jour du compte',
                subtitle: 'Changements importants sur votre compte',
                value: _accountUpdates,
                onChanged: (value) => setState(() => _accountUpdates = value),
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              _buildSwitchTile(
                title: 'Alertes de sécurité',
                subtitle: 'Activités suspectes et connexions',
                value: _securityAlerts,
                onChanged: (value) => setState(() => _securityAlerts = value),
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
            ],
            isDesktop: isDesktop,
            isTablet: isTablet,
            isMobile: isMobile,
          ),
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
        if (title !=
            'Alertes de sécurité') // Ne pas ajouter de diviseur après le dernier élément
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
    // Simuler la sauvegarde des paramètres
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Paramètres enregistrés avec succès!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
    Navigator.of(context).pop();
  }

}

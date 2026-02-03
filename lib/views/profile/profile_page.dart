import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 1200;
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        child: Column(
          children: [
            SizedBox(height: isTablet ? 30 : 20),
            
            // Profile Header
            Container(
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: isTablet ? 60 : 50,
                        backgroundColor: Colors.deepPurple[100],
                        child: Icon(
                          Icons.person,
                          size: isTablet ? 60 : 50,
                          color: Colors.deepPurple,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: isTablet ? 32 : 24,
                          height: isTablet ? 32 : 24,
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: isTablet ? 18 : 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: isTablet ? 20 : 16),
                  
                  // Nom et email
                  Text(
                    'Jean Dupont',
                    style: TextStyle(
                      fontSize: isTablet ? 24 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: isTablet ? 8 : 4),
                  Text(
                    'jean.dupont@email.com',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: isTablet ? 16 : 14,
                    ),
                  ),
                  
                  SizedBox(height: isTablet ? 24 : 16),
                  
                  // Statistiques
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statItem('Commandes', '24', isTablet),
                      _statItem('Favoris', '18', isTablet),
                      _statItem('Avis', '12', isTablet),
                    ],
                  ),
                ],
              ),
            ),
            
            SizedBox(height: isTablet ? 30 : 20),
            
            // Menu Options
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _menuTile(
                    icon: Icons.person_outline,
                    title: 'Informations personnelles',
                    onTap: () {},
                    isTablet: isTablet,
                  ),
                  _menuTile(
                    icon: Icons.location_on_outlined,
                    title: 'Adresses de livraison',
                    onTap: () {},
                    isTablet: isTablet,
                  ),
                  _menuTile(
                    icon: Icons.payment_outlined,
                    title: 'Moyens de paiement',
                    onTap: () {},
                    isTablet: isTablet,
                  ),
                  _menuTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    onTap: () {},
                    isTablet: isTablet,
                  ),
                  _menuTile(
                    icon: Icons.security_outlined,
                    title: 'Sécurité',
                    onTap: () {},
                    isTablet: isTablet,
                  ),
                  _menuTile(
                    icon: Icons.help_outline,
                    title: 'Aide et support',
                    onTap: () {},
                    isTablet: isTablet,
                  ),
                  _menuTile(
                    icon: Icons.info_outline,
                    title: 'À propos',
                    onTap: () {},
                    isTablet: isTablet,
                  ),
                  _menuTile(
                    icon: Icons.logout,
                    title: 'Déconnexion',
                    onTap: () {},
                    isLast: true,
                    textColor: Colors.red,
                    isTablet: isTablet,
                  ),
                ],
              ),
            ),
            
            SizedBox(height: isTablet ? 30 : 20),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, bool isTablet) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: isTablet ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        SizedBox(height: isTablet ? 6 : 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: isTablet ? 14 : 12,
          ),
        ),
      ],
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLast = false,
    Color textColor = Colors.black,
    required bool isTablet,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24 : 16,
            vertical: isTablet ? 4 : 0,
          ),
          leading: Icon(
            icon,
            color: textColor == Colors.red ? Colors.red : Colors.grey[700],
            size: isTablet ? 24 : 20,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w500,
              fontSize: isTablet ? 16 : 14,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: isTablet ? 18 : 16,
            color: textColor == Colors.red ? Colors.red : Colors.grey[400],
          ),
          onTap: onTap,
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }
}

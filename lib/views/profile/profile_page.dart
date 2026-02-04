import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 32 : isTablet ? 24 : 16),
        child: Column(
          children: [
            SizedBox(height: isDesktop ? 40 : isTablet ? 30 : 20),
            
            // Profile Header
            Container(
              padding: EdgeInsets.all(isDesktop ? 32 : isTablet ? 24 : 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isDesktop ? 20 : 12),
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
                        radius: isDesktop ? 80 : isTablet ? 60 : 50,
                        backgroundColor: Colors.deepPurple[100],
                        child: Icon(
                          Icons.person,
                          size: isDesktop ? 80 : isTablet ? 60 : 50,
                          color: Colors.deepPurple,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: isDesktop ? 40 : isTablet ? 32 : 24,
                          height: isDesktop ? 40 : isTablet ? 32 : 24,
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: isDesktop ? 20 : isTablet ? 16 : 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: isDesktop ? 24 : isTablet ? 20 : 16),
                  
                  // Nom et email
                  Text(
                    'Jean Dupont',
                    style: TextStyle(
                      fontSize: isDesktop ? 28 : isTablet ? 24 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: isDesktop ? 8 : isTablet ? 6 : 4),
                  Text(
                    'jean.dupont@email.com',
                    style: TextStyle(
                      fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  
                  SizedBox(height: isDesktop ? 32 : isTablet ? 24 : 20),
                  
                  // Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statItem('Commandes', '25', isDesktop, isTablet),
                      _statItem('Favoris', '12', isDesktop, isTablet),
                      _statItem('Points', '850', isDesktop, isTablet),
                    ],
                  ),
                ],
              ),
            ),
            
            SizedBox(height: isDesktop ? 32 : isTablet ? 24 : 20),
            
            // Menu Options
            Container(
              padding: EdgeInsets.all(isDesktop ? 24 : isTablet ? 20 : 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isDesktop ? 20 : 12),
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
                  _menuTile('Informations personnelles', Icons.person, isDesktop, isTablet),
                  _menuTile('Adresses', Icons.location_on, isDesktop, isTablet),
                  _menuTile('Moyens de paiement', Icons.credit_card, isDesktop, isTablet),
                  _menuTile('Notifications', Icons.notifications, isDesktop, isTablet),
                  _menuTile('Sécurité', Icons.security, isDesktop, isTablet),
                  _menuTile('Aide', Icons.help, isDesktop, isTablet),
                  _menuTile('Déconnexion', Icons.logout, isDesktop, isTablet, isLast: true),
                ],
              ),
            ),
            
            SizedBox(height: isTablet ? 30 : 20),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, bool isDesktop, bool isTablet) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: isDesktop ? 32 : isTablet ? 28 : 24,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        SizedBox(height: isDesktop ? 8 : isTablet ? 6 : 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isDesktop ? 16 : isTablet ? 14 : 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _menuTile(String title, IconData icon, bool isDesktop, bool isTablet, {bool isLast = false}) {
    return Column(
      children: [
        ListTile(
          leading: Icon(
            icon,
            color: isLast ? Colors.red : Colors.deepPurple,
            size: isDesktop ? 28 : isTablet ? 24 : 20,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
              fontWeight: FontWeight.w500,
              color: isLast ? Colors.red : Colors.black,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: Colors.grey[400],
            size: isDesktop ? 20 : isTablet ? 16 : 12,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 8 : isTablet ? 4 : 0,
            vertical: isDesktop ? 4 : isTablet ? 2 : 0,
          ),
          onTap: () {
            // TODO: Navigation
          },
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 0.5,
            color: Colors.grey[300],
            indent: isDesktop ? 68 : isTablet ? 64 : 60,
            endIndent: isDesktop ? 20 : isTablet ? 16 : 12,
          ),
      ],
    );
  }
}

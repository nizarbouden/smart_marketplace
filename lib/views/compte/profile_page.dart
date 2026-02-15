import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../services/auto_logout_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../widgets/auto_logout_warning_dialog.dart';
import 'profile/edit_profile_page.dart';
import 'adress/address_page.dart';
import 'notifications/notification_settings_page.dart';
import 'security/security_settings_page.dart';
import 'help/help_page.dart';
import 'payment/payment_methods_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final AutoLogoutService _autoLogoutService = AutoLogoutService();

  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    print('📱 ProfilePage: initState()');
    _syncEmailIfNeeded();

    // ✅ NOUVEAU: Ajouter des listeners au lieu de configurer les callbacks
    _setupListeners();
  }

  // ✅ NOUVEAU: Utiliser les listeners
  void _setupListeners() {
    print('👂 ProfilePage: Ajout des listeners');

    // ✅ Listener pour l'avertissement
    _autoLogoutService.addWarningListener((event) {
      print('📌 ProfilePage: Warning listener APPELÉ! ${event.remainingSeconds}s');
      if (mounted) {
        print('✅ ProfilePage: mounted=true, affichage dialog');
        _showAutoLogoutWarning(event.remainingSeconds);
      } else {
        print('❌ ProfilePage: mounted=false!');
      }
    });

    // ✅ Listener pour la déconnexion
    _autoLogoutService.addLogoutListener((event) {
      print('📌 ProfilePage: Logout listener APPELÉ!');
      if (mounted) {
        print('✅ ProfilePage: mounted=true, déconnexion');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏱️ Déconnexion automatique - Inactivité détectée'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );

        _autoLogoutService.stopAutoLogout();

        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
              (route) => false,
        );
      } else {
        print('❌ ProfilePage: mounted=false!');
      }
    });
  }

  void _showAutoLogoutWarning(int remainingSeconds) {
    print('🔔 ProfilePage: _showAutoLogoutWarning() appelée avec ${remainingSeconds}s');

    if (_dialogShown) {
      print('⚠️  Dialog déjà affiché, ignoré');
      return;
    }

    _dialogShown = true;
    print('📢 ProfilePage: Affichage du dialog');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        print('📢 ProfilePage: Builder du dialog appelé');
        return AutoLogoutWarningDialog(
          remainingSeconds: remainingSeconds,
          onStayLoggedIn: () {
            print('✅ ProfilePage: User a cliqué "Rester connecté"');
            _dialogShown = false;

            if (mounted && Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }

            _autoLogoutService.recordActivity();
          },
          onLogout: () {
            print('❌ ProfilePage: User a cliqué "Se déconnecter"');
            _dialogShown = false;

            if (mounted && Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }

            _autoLogoutService.stopAutoLogout();
            FirebaseAuth.instance.signOut();

            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                    (route) => false,
              );
            }
          },
        );
      },
    ).then((_) {
      print('🔌 ProfilePage: Dialog fermé');
      _dialogShown = false;
    });
  }

  Future<void> _syncEmailIfNeeded() async {
    try {
      String? authEmail = _authService.getCurrentEmail();
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);

      if (authEmail != null && authEmail != authProvider.user?.email) {
        print('🔄 ProfilePage: Synchronisation email');
        await _authService.syncEmailFromAuth();

        if (mounted) {
          print('✅ ProfilePage: Email synchronisé');
        }
      }
    } catch (e) {
      print('❌ ProfilePage: Erreur sync email: $e');
    }
  }

  String _getCorrectEmail() {
    String? authEmail = _authService.getCurrentEmail();
    final authProvider = Provider.of<app_auth.AuthProvider>(context);

    String correctEmail = authEmail ?? authProvider.user?.email ?? 'email@example.com';

    return correctEmail;
  }

  @override
  void dispose() {
    print('🔌 ProfilePage: dispose()');
    // ✅ IMPORTANT: Supprimer les listeners quand on quitte
    // Les listeners resteront actifs s'il y a d'autres pages qui les utilisent
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    final authProvider = Provider.of<app_auth.AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 32 : isTablet ? 24 : 16),
        child: Column(
          children: [
            SizedBox(height: isDesktop ? 40 : isTablet ? 30 : 20),

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
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: isDesktop ? 80 : isTablet ? 60 : 50,
                        backgroundColor: Colors.deepPurple[100],
                        backgroundImage: authProvider.user?.photoUrl != null
                            ? NetworkImage(authProvider.user!.photoUrl!)
                            : null,
                        child: authProvider.user?.photoUrl == null
                            ? Icon(
                          Icons.person,
                          size: isDesktop ? 80 : isTablet ? 60 : 50,
                          color: Colors.deepPurple,
                        )
                            : null,
                      ),
                    ],
                  ),

                  SizedBox(height: isDesktop ? 24 : isTablet ? 20 : 16),

                  Text(
                    authProvider.fullName ?? 'Utilisateur',
                    style: TextStyle(
                      fontSize: isDesktop ? 28 : isTablet ? 24 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: isDesktop ? 8 : isTablet ? 6 : 4),
                  Text(
                    _getCorrectEmail(),
                    style: TextStyle(
                      fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                      color: Colors.grey[600],
                    ),
                  ),

                  SizedBox(height: isDesktop ? 32 : isTablet ? 24 : 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statItem('Commandes', '${authProvider.orders.length}', isDesktop, isTablet),
                      _statItem('Favoris', '${authProvider.favorites.length}', isDesktop, isTablet),
                      _statItem('Points', '${authProvider.points}', isDesktop, isTablet),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: isDesktop ? 32 : isTablet ? 24 : 20),

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
                  _menuTile('Paramètres de notifications', Icons.notifications, isDesktop, isTablet),
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
            if (title == 'Déconnexion') {
              _showLogoutDialog();
            } else if (title == 'Informations personnelles') {
              final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfilePage(
                    user: authProvider.user,
                  ),
                ),
              );
            } else if (title == 'Adresses') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddressPage()),
              );
            } else if (title == 'Paramètres de notifications') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationSettingsPage()),
              );
            } else if (title == 'Sécurité') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SecuritySettingsPage()),
              );
            } else if (title == 'Aide') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpPage()),
              );
            } else if (title == 'Moyens de paiement') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PaymentMethodsPage()),
              );
            }
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

  void _showLogoutDialog() {
    print('🔴 ProfilePage: Affichage du dialog de déconnexion');
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 20,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF6366F1),
                  const Color(0xFF8B5CF6),
                  const Color(0xFFA855F7),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Déconnexion',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8700FF),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Êtes-vous sûr de vouloir\nvous déconnecter?',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFF6366F1),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  backgroundColor: Colors.transparent,
                                ),
                                child: const Text(
                                  'Annuler',
                                  style: TextStyle(
                                    color: Color(0xFF6366F1),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () async {
                                  try {
                                    print('🔴 ProfilePage: Logout button - Arrêt du service');
                                    _autoLogoutService.stopAutoLogout();

                                    print('🔴 ProfilePage: Logout button - SignOut Firebase');
                                    await FirebaseAuth.instance.signOut();
                                    print('✅ ProfilePage: Déconnexion réussie');

                                    print('🔴 ProfilePage: Logout button - Navigation /login');
                                    Navigator.of(context).pop();
                                    Navigator.pushReplacementNamed(context, '/login');
                                  } catch (e) {
                                    print('⚠️ ProfilePage: Erreur logout: $e');
                                    Navigator.of(context).pop();
                                    Navigator.pushReplacementNamed(context, '/login');
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1),
                                  foregroundColor: Colors.white,
                                  shadowColor: const Color(0xFF6366F1).withOpacity(0.3),
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const FittedBox(
                                  child: Text(
                                    'Se déconnecter',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
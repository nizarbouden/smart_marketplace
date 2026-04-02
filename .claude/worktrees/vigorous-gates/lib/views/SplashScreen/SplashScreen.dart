import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../localization/app_localizations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _loadingController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeInOut),
    );

    _mainController.forward();
    _loadingController.forward();

    _checkAuthAfterDelay();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  //  ENTRÉE PRINCIPALE
  // ─────────────────────────────────────────────────────────────

  Future<void> _checkAuthAfterDelay() async {
    print('🔄 SplashScreen: Démarrage de la vérification de connexion...');
    await Future.delayed(const Duration(seconds: 5));
    if (mounted) await _forceAuthCheck();
  }

  // ─────────────────────────────────────────────────────────────
  //  VÉRIFICATION AUTH
  //  Ordre garanti :
  //  1. Lire rememberMe (clé identique à AuthProvider : 'rememberMe')
  //  2. Si false → signOut() maintenant → /login
  //  3. Si true  → valider token → naviguer par rôle
  // ─────────────────────────────────────────────────────────────

  Future<void> _forceAuthCheck() async {
    final auth = FirebaseAuth.instance;

    try {
      // Reload Firebase avant tout
      await auth.currentUser?.reload();
      await Future.delayed(const Duration(milliseconds: 300));

      final user = auth.currentUser;
      print('🔄 SplashScreen: Utilisateur: ${user?.email ?? 'null'}');

      if (user == null) {
        print('❌ SplashScreen: Aucun utilisateur → /login');
        _goTo('/login');
        return;
      }

      // ✅ Clé identique à AuthProvider : 'rememberMe'
      final prefs      = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('rememberMe') ?? false;
      print('🔄 SplashScreen: rememberMe = $rememberMe');

      if (!rememberMe) {
        // ✅ FIX CORE : déconnecter ICI avant toute navigation
        // L'AuthProvider ne doit plus faire de signOut au démarrage
        print('🔄 SplashScreen: rememberMe=false → signOut + /login');
        await auth.signOut();
        await prefs.remove('rememberMe');
        await prefs.remove('lastEmail');
        _goTo('/login');
        return;
      }

      // rememberMe = true → valider le token
      try {
        final idToken = await user.getIdToken();
        if (idToken == null || idToken.isEmpty) {
          print('⚠️ SplashScreen: Token vide → signOut + /login');
          await auth.signOut();
          _goTo('/login');
          return;
        }
        print('✅ SplashScreen: Token valide');
      } catch (e) {
        print('⚠️ SplashScreen: Erreur token: $e → signOut + /login');
        await auth.signOut();
        _goTo('/login');
        return;
      }

      // Token OK → naviguer selon rôle
      print('✅ SplashScreen: Utilisateur connecté avec token valide');
      if (mounted) await _navigateByRole(user);

    } catch (e) {
      print('⚠️ SplashScreen: Erreur reload: $e');
      // Erreur réseau : si rememberMe actif on tente quand même
      final prefs      = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('rememberMe') ?? false;
      final user       = auth.currentUser;

      if (rememberMe && user != null) {
        print('⚠️ SplashScreen: Erreur réseau + rememberMe actif → continuer');
        if (mounted) await _navigateByRole(user);
      } else {
        await auth.signOut();
        _goTo('/login');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  NAVIGATION PAR RÔLE
  // ─────────────────────────────────────────────────────────────

  Future<void> _navigateByRole(User user) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        print('❌ SplashScreen: Document utilisateur non trouvé → /login');
        _goTo('/login');
        return;
      }

      final data = userDoc.data() as Map<String, dynamic>;
      final role = data['role'] as String? ?? '';
      print('🔍 SplashScreen: Rôle trouvé pour ${user.email}: $role');

      if (role == 'seller') {
        print('✅ SplashScreen: Redirection → /seller-home');
        _goTo('/seller-home');
      } else if (role.isNotEmpty && role != 'null') {
        print('✅ SplashScreen: Redirection → /home');
        _goTo('/home');
      } else {
        print('🔄 SplashScreen: Pas de rôle → /login');
        _goTo('/login');
      }
    } catch (e) {
      print('❌ SplashScreen: Erreur rôle: $e → /login');
      _goTo('/login');
    }
  }

  void _goTo(String route) {
    if (mounted) Navigator.of(context).pushReplacementNamed(route);
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD (identique à l'original)
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6C5CE7), Color(0xFF4A3BB4)],
          ),
        ),
        child: Stack(children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _logoOpacity,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Container(
                      width: 140, height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 25, spreadRadius: 8,
                          offset: const Offset(0, 12),
                        )],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Image.asset('assets/images/logo.png',
                          fit: BoxFit.contain),
                    ),
                  ),
                ),
                const SizedBox(height: 50),
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: Column(children: [
                      Text(
                        AppLocalizations.get('splash_loading'),
                        style: const TextStyle(
                          color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.w500, letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildProgressBar(),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 35, left: 0, right: 0,
            child: FadeTransition(
              opacity: _textOpacity,
              child: Column(children: [
                Text(AppLocalizations.get('splash_version'),
                    style: const TextStyle(color: Colors.white70,
                        fontSize: 16, fontWeight: FontWeight.w400)),
                const SizedBox(height: 6),
                Text(AppLocalizations.get('splash_copyright'),
                    style: const TextStyle(color: Colors.white54,
                        fontSize: 14, fontWeight: FontWeight.w300)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Column(children: [
          Container(
            width: 220, height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Stack(children: [
              Container(
                width: 220 * _progressAnimation.value, height: 6,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFC7D2FE)]),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [BoxShadow(
                    color: Colors.white.withOpacity(0.6),
                    blurRadius: 10, spreadRadius: 1,
                  )],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Text(
            '${(_progressAnimation.value * 100).toStringAsFixed(0)}%',
            style: const TextStyle(color: Colors.white70, fontSize: 13,
                fontWeight: FontWeight.w400, letterSpacing: 0.5),
          ),
        ]);
      },
    );
  }
}
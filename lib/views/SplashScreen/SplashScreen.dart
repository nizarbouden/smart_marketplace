import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
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

    // Contrôleur principal pour les animations d'introduction
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Contrôleur pour la barre de progression
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    // Animation du logo : apparition avec zoom subtil
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

    // Animation du texte : déplacement fluide vers le haut avec apparition
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

    // Animation de la barre de progression
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingController,
        curve: Curves.easeInOut,
      ),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          _checkAuthAndRedirect();
        }
      }
    });

    // Démarrer les animations
    _mainController.forward();
    _loadingController.forward();
    
    // Vérifier l'état de connexion après un court délai
    _checkAuthAfterDelay();
  }
  
  // Vérifier la connexion après un délai
  void _checkAuthAfterDelay() async {
    print('🔄 SplashScreen: Démarrage de la vérification de connexion...');
    
    // Attendre que Firebase soit initialisé
    await Future.delayed(const Duration(seconds: 2));
    
    // Forcer la vérification de l'état actuel
    if (mounted) {
      await _forceAuthCheck();
    }
  }
  
  // Forcer la vérification de l'état d'authentification
  Future<void> _forceAuthCheck() async {
    final FirebaseAuth auth = FirebaseAuth.instance;
    
    try {
      // Forcer le rechargement de l'utilisateur
      await auth.currentUser?.reload();
      
      // Attendre un peu pour que Firebase se stabilise
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Vérifier à nouveau
      final user = auth.currentUser;
      print('🔄 SplashScreen: Vérification après reload - Utilisateur: ${user?.email ?? 'null'}');
      
      // Vérification supplémentaire avec getIdToken
      if (user != null) {
        try {
          final idToken = await user.getIdToken();
          print('🔄 SplashScreen: Token valide: ${idToken?.isNotEmpty ?? false}');
          
          if (idToken != null && idToken.isNotEmpty) {
            print('✅ SplashScreen: Utilisateur connecté avec token valide, redirection vers /home');
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/home');
            }
            return;
          } else {
            print('⚠️ SplashScreen: Token vide ou null, utilisateur invalide');
          }
        } catch (e) {
          print('⚠️ SplashScreen: Erreur token: $e');
        }
      }
      
      // Si on arrive ici, l'utilisateur n'est pas valide
      print('❌ SplashScreen: Utilisateur non valide ou déconnecté, redirection vers /login');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
      
    } catch (e) {
      print('⚠️ SplashScreen: Erreur lors du reload: $e');
      // En cas d'erreur, vérifier l'état actuel
      final user = auth.currentUser;
      if (user != null) {
        print('⚠️ SplashScreen: Utilisateur détecté malgré l''erreur, redirection vers /home');
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        print('❌ SplashScreen: Pas d''utilisateur, redirection vers /login');
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

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
            colors: [
              Color(0xFF6C5CE7),
              Color(0xFF4A3BB4),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Contenu principal
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo avec animation de zoom et opacité
                  FadeTransition(
                    opacity: _logoOpacity,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 25,
                              spreadRadius: 8,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),

                  // Texte et barre de progression
                  SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textOpacity,
                      child: Column(
                        children: [
                          const Text(
                            'Chargement en cours',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _buildProgressBar(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Footer avec version et copyright
            Positioned(
              bottom: 35,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _textOpacity,
                child: const Column(
                  children: [
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '© 2026 winzy. Tous droits réservés.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Column(
          children: [
            Container(
              width: 220,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Stack(
                children: [
                  // Barre de progression animée avec dégradé
                  Container(
                    width: 220 * _progressAnimation.value,
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFFFFF),
                          Color(0xFFC7D2FE),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.6),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${(_progressAnimation.value * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
              ),
            ),
          ],
        );
      },
    );
  }

  // Vérifier l'état de connexion et rediriger
  void _checkAuthAndRedirect() async {
    print('');
    
    final FirebaseAuth auth = FirebaseAuth.instance;
    
    // Attendre un peu plus pour que Firebase s'initialise complètement
    await Future.delayed(const Duration(seconds: 1));
    
    // Vérifier plusieurs fois pour être sûr
    int attempts = 0;
    while (attempts < 3) {
      final user = auth.currentUser;
      print('');
      
      if (user != null) {
        print('');
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
        return;
      }
      
      attempts++;
      if (attempts < 3) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    print('');
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }
}
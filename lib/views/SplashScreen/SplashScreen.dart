import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:math';

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
      duration: const Duration(seconds: 1),
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
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    });

    // Démarrer les animations
    _mainController.forward();
    _loadingController.forward();
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
}
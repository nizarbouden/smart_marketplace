import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<dynamic> pushNamed(String routeName) {
    return navigatorKey.currentState!.pushNamed(routeName);
  }

  Future<dynamic> pushReplacementNamed(String routeName) {
    return navigatorKey.currentState!.pushReplacementNamed(routeName);
  }

  Future<dynamic> pushNamedAndRemoveUntil(String routeName, RoutePredicate predicate) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil(routeName, predicate);
  }

  void pop() {
    return navigatorKey.currentState!.pop();
  }

  // Méthode spéciale pour rediriger vers login après déconnexion
  Future<void> redirectToLogin() async {
    try {
      // Attendre un peu pour s'assurer que tout est propre
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Forcer la redirection vers login
      navigatorKey.currentState!.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    } catch (e) {
      print('❌ NavigationService: Erreur lors de la redirection vers login: $e');
    }
  }
}

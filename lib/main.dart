import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:smart_marketplace/views/SplashScreen/SplashScreen.dart';
import 'package:smart_marketplace/views/auth/login_screen.dart';
import 'package:smart_marketplace/views/auth/signup_screen.dart';
import 'package:smart_marketplace/views/auth/forgot_password_screen.dart';
import 'package:smart_marketplace/views/compte/profile/edit_profile_page.dart';
import 'package:smart_marketplace/views/compte/profile_page.dart';
import 'package:smart_marketplace/views/compte/notifications/notification_settings_page.dart';
import 'package:smart_marketplace/views/compte/adress/address_page.dart';
import 'package:smart_marketplace/views/compte/payment/payment_methods_page.dart';
import 'package:smart_marketplace/views/payment/checkout_page.dart';
import 'package:smart_marketplace/views/layout/main_layout.dart';
import 'package:smart_marketplace/views/cart/cart_page.dart';
import 'package:smart_marketplace/views/history/history_page.dart';
import 'package:smart_marketplace/views/notifications/notifications_page.dart';
import 'package:smart_marketplace/config/firebase_config.dart';
import 'package:smart_marketplace/providers/auth_provider.dart';
import 'package:smart_marketplace/services/firebase_auth_service.dart';
import 'package:smart_marketplace/views/compte/security/security_settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 === DÉMARRAGE DE L\'APPLICATION ===');

  // Initialiser Firebase
  print('📱 Initialisation Firebase...');
  await FirebaseConfig.initializeFirebase();
  print('✅ Firebase initialisé');

  // Nettoyer le cache Firestore
  print('🧹 Nettoyage du cache Firestore...');
  await FirebaseAuthService().clearFirestoreCache();
  print('✅ Cache nettoyé');

  print('🎯 === LANCEMENT DE L\'APPLICATION ===\n');

  // ✅ NE PAS initialiser AutoLogoutService ici
  // Le service sera initialisé SEULEMENT dans MainLayout après connexion

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Winzy',

        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
          ),
          useMaterial3: true,
        ),

        // ✅ SplashScreen en premier
        initialRoute: '/',

        routes: {
          '/': (context) => const SplashScreen(),
          '/home': (context) => const MainLayout(),
          '/panier': (context) => const CartPage(),
          '/paiement': (context) => const CheckoutPage(),
          '/historique': (context) => const HistoryPage(),
          '/profil': (context) => const ProfilePage(),
          '/edit-profile': (context) => const EditProfilePage(),
          '/notifications': (context) => const NotificationsPage(),
          '/notification-settings': (context) => const NotificationSettingsPage(),
          '/addresses': (context) => const AddressPage(),
          '/payment-methods': (context) => const PaymentMethodsPage(),
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignUpScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          // ✅ Route pour la sécurité
          '/security-settings': (context) => const SecuritySettingsPage(),
        },
      ),
    );
  }
}
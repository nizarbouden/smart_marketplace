import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:smart_marketplace/providers/cart_provider.dart';
import 'package:smart_marketplace/views/SplashScreen/SplashScreen.dart';
import 'package:smart_marketplace/views/auth/login_screen.dart';
import 'package:smart_marketplace/views/auth/signup_screen.dart';
import 'package:smart_marketplace/views/auth/forgot_password_screen.dart';
import 'package:smart_marketplace/views/compte/help/help_page.dart';
import 'package:smart_marketplace/views/compte/profile/edit_profile_page.dart';
import 'package:smart_marketplace/views/compte/profile_page.dart';
import 'package:smart_marketplace/views/compte/notifications/notification_settings_page.dart';
import 'package:smart_marketplace/views/compte/adress/address_page.dart';
import 'package:smart_marketplace/views/compte/payment/payment_methods_page.dart';
import 'package:smart_marketplace/views/layout/seller_main_layout.dart';
import 'package:smart_marketplace/views/payment/checkout_page.dart';
import 'package:smart_marketplace/views/layout/main_layout.dart';
import 'package:smart_marketplace/views/cart/cart_page.dart';
import 'package:smart_marketplace/views/history/history_page.dart';
import 'package:smart_marketplace/views/notifications/notifications_page.dart';
import 'package:smart_marketplace/config/firebase_config.dart';
import 'package:smart_marketplace/providers/auth_provider.dart';
import 'package:smart_marketplace/providers/language_provider.dart';
import 'package:smart_marketplace/services/firebase_auth_service.dart';
import 'package:smart_marketplace/views/compte/security/security_settings_page.dart';
import 'package:smart_marketplace/widgets/activity_recorder_wrapper.dart';
import 'package:smart_marketplace/views/compte/security/change_password/change_password_page.dart';
import 'package:smart_marketplace/services/navigation_service.dart';

// ✅ RouteObserver global — accessible depuis cart_page.dart
final RouteObserver<ModalRoute<void>> routeObserver =
RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Status bar noire pour toute l'application
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  print('=== DÉMARRAGE DE L\'APPLICATION ===');

  print('📱 Initialisation Firebase...');
  await FirebaseConfig.initializeFirebase();
  print('✅ Firebase initialisé');

  print('🧹 Nettoyage du cache Firestore...');
  await FirebaseAuthService().clearFirestoreCache();
  print('✅ Cache nettoyé');

  // ✅ Initialisation Stripe — clé PUBLIQUE uniquement (pk_test_...)
  print('💳 Initialisation Stripe...');
  Stripe.publishableKey = 'pk_test_51T5rs4Q3Ez5ClbruC5VNxyihMhvo9dVbMRJYiWE8gD1eLWpbiRd4Ztf2RAH5eLiSP1VcCfZOrMa6Ww76pfmoCkX800GJUPNsox'; // ← remplace par ta clé publique
  await Stripe.instance.applySettings();
  print('✅ Stripe initialisé');

  print('🎯 === LANCEMENT DE L\'APPLICATION ===\n');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final navigationService = NavigationService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => LanguageProvider()),
        ChangeNotifierProvider(create: (context) => CartProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) {
          return MaterialApp(
            navigatorKey: navigationService.navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'Winzy',

            // ✅ RouteObserver enregistré ici
            navigatorObservers: [routeObserver],

            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                  statusBarBrightness: Brightness.light,
                ),
              ),
            ),

            initialRoute: '/',

            routes: {
              '/': (context) => const SplashScreen(),

              '/home': (context) => ActivityRecorderWrapper(
                child: MainLayout(key: mainLayoutKey),
              ),

              '/seller-home': (context) => ActivityRecorderWrapper(
                child: const SellerMainLayout(),
              ),

              '/panier': (context) => ActivityRecorderWrapper(
                child: const CartPage(),
              ),
              '/paiement': (context) => ActivityRecorderWrapper(
                child: const CheckoutPage(),
              ),
              '/historique': (context) => ActivityRecorderWrapper(
                child: const HistoryPage(),
              ),
              '/profil': (context) => ActivityRecorderWrapper(
                child: const ProfilePage(),
              ),
              '/edit-profile': (context) => ActivityRecorderWrapper(
                child: const EditProfilePage(),
              ),
              '/notifications': (context) => ActivityRecorderWrapper(
                child: const NotificationsPage(),
              ),
              '/notification-settings': (context) => ActivityRecorderWrapper(
                child: const NotificationSettingsPage(),
              ),
              '/addresses': (context) => ActivityRecorderWrapper(
                child: const AddressPage(),
              ),
              '/payment-methods': (context) => ActivityRecorderWrapper(
                child: const PaymentMethodsPage(),
              ),

              '/login': (context) => const LoginScreen(),
              '/signup': (context) => const SignUpScreen(),
              '/forgot-password': (context) => const ForgotPasswordScreen(),

              '/security-settings': (context) => ActivityRecorderWrapper(
                child: const SecuritySettingsPage(),
              ),
              '/change-password': (context) => ActivityRecorderWrapper(
                child: const ChangePasswordPage(),
              ),

              '/help': (context) => ActivityRecorderWrapper(
                child: const HelpPage(),
              ),
            },

            locale: Locale(languageProvider.currentLanguageCode),
          );
        },
      ),
    );
  }
}
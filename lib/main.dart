import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import 'package:smart_marketplace/providers/cart_provider.dart';
import 'package:smart_marketplace/providers/currency_provider.dart';
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

final RouteObserver<ModalRoute<void>> routeObserver =
RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  print('💳 Initialisation Stripe...');
  Stripe.publishableKey =
  'pk_test_51T5rs4Q3Ez5ClbruC5VNxyihMhvo9dVbMRJYiWE8gD1eLWpbiRd4Ztf2RAH5eLiSP1VcCfZOrMa6Ww76pfmoCkX800GJUPNsox';
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
        // ✅ CurrencyProvider initialisé SANS uid ici —
        //    l'uid sera injecté dans _AppRoot dès que Firebase
        //    confirme quel utilisateur est connecté.
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) {
          return MaterialApp(
            navigatorKey: navigationService.navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'Winzy',
            navigatorObservers: [routeObserver],
            theme: ThemeData(
              colorScheme:
              ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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
            // ✅ Toutes les routes sont wrappées dans _AppRoot
            //    qui gère l'écoute authStateChanges une seule fois.
            builder: (context, child) => _AppRoot(child: child!),
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
              '/notification-settings': (context) =>
                  ActivityRecorderWrapper(
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
              '/forgot-password': (context) =>
              const ForgotPasswordScreen(),
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

// ─────────────────────────────────────────────────────────────────
//  _AppRoot — écoute authStateChanges UNE SEULE FOIS pour toute
//  l'app et met à jour le CurrencyProvider avec l'UID du compte
//  connecté. Chaque compte a sa propre devise sauvegardée.
// ─────────────────────────────────────────────────────────────────

class _AppRoot extends StatefulWidget {
  final Widget child;
  const _AppRoot({required this.child});

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  // ✅ uid actuellement chargé dans le provider
  String _loadedUid  = '';
  bool   _initDone   = false;

  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialisation au démarrage avec l'utilisateur déjà connecté
      final currentUser = FirebaseAuth.instance.currentUser;
      await _initCurrency(currentUser?.uid ?? '');

      // ✅ On démarre l'écoute APRÈS le premier init pour éviter
      // la double exécution (initState + authStateChanges)
      _authSub = FirebaseAuth.instance
          .authStateChanges()
          .listen(_onAuthChanged);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  // ── Appelé à chaque changement de compte ─────────────────────

  void _onAuthChanged(User? user) {
    if (!mounted) return;
    final newUid = user?.uid ?? '';
    // ✅ Ne rien faire si c'est le même utilisateur
    // (évite de reset la devise quand l'app rebuild)
    if (newUid == _loadedUid) return;
    _initCurrency(newUid);
  }

  // ── Initialise / change la devise selon l'UID ────────────────
  //
  //  • Premier appel → init() : charge taux API + devise de cet UID
  //  • Changement de compte → switchUser() : charge devise du nouvel UID
  //    sans re-fetcher les taux (cache commun)
  //
  //  La clé : chaque UID a sa propre clé SharedPreferences
  //  → "selected_currency_<uid>"

  Future<void> _initCurrency(String uid) async {
    if (!mounted) return;
    final cp = Provider.of<CurrencyProvider>(context, listen: false);

    if (!_initDone) {
      // Premier lancement : init complet (taux + devise)
      _initDone  = true;
      _loadedUid = uid;
      await cp.init(uid: uid);
    } else if (uid != _loadedUid) {
      // Changement de compte : charger juste la devise du nouvel UID
      _loadedUid = uid;
      await cp.switchUser(uid);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
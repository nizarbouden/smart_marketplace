import 'package:flutter/material.dart';
import 'package:smart_marketplace/views/SplashScreen/SplashScreen.dart';
import 'package:smart_marketplace/views/auth/login_screen.dart';
import 'package:smart_marketplace/views/auth/signup_screen.dart';
import 'package:smart_marketplace/views/auth/reset_password_screen.dart';
import 'package:smart_marketplace/views/auth/forget_password_otp_screen.dart';
import 'views/layout/main_layout.dart';
import 'views/cart/cart_page_stateful.dart';
import 'views/history/history_page.dart';
import 'views/profile/profile_page.dart';
import 'views/profile/edit_profile_page.dart';
import 'views/notifications/notifications_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'smart_marketplace',

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
        '/panier': (context) => const CartPageStateful(),
        '/historique': (context) => const HistoryPage(),
        '/profil': (context) => const ProfilePage(),
        '/edit-profile': (context) => const EditProfilePage(),
        '/notifications': (context) => const NotificationsPage(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/forget-Password': (context) => const ForgetPasswordOtpScreen(),
      },
    );
  }
}

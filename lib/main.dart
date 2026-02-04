import 'package:flutter/material.dart';
import 'package:smart_marketplace/views/SplashScreen/SplashScreen.dart';
import 'views/layout/main_layout.dart';
import 'views/cart/cart_page_stateful.dart';
import 'views/history/history_page.dart';
import 'views/profile/profile_page.dart';
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
        '/notifications': (context) => const NotificationsPage(),
      },
    );
  }
}

import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 1200;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: isTablet ? 30 : 20),

            // Header avec options
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: isTablet ? 28 : 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: marquer toutes comme lues
                  },
                  child: Text(
                    'Tout marquer comme lu',
                    style: TextStyle(
                      color: Colors.deepPurple,
                      fontSize: isTablet ? 14 : 12,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: isTablet ? 30 : 20),

            // Liste des notifications
            Expanded(
              child: ListView.builder(
                itemCount: 8,
                itemBuilder: (context, index) {
                  return _notificationCard(index, isTablet);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationCard(int index, bool isTablet) {
    final isUnread = index < 3; // Premières 3 notifications non lues
    final notifications = [
      {
        'title': 'Commande livrée',
        'message': 'Votre commande #12345 a été livrée avec succès',
        'time': 'Il y a 2 heures',
        'icon': Icons.check_circle,
        'color': Colors.green,
      },
      {
        'title': 'Promotion spéciale',
        'message': 'Profitez de -20% sur tous les produits électroniques',
        'time': 'Il y a 5 heures',
        'icon': Icons.local_offer,
        'color': Colors.orange,
      },
      {
        'title': 'Nouveau produit',
        'message': 'Découvrez les nouveaux arrivages dans votre catégorie préférée',
        'time': 'Hier',
        'icon': Icons.new_releases,
        'color': Colors.blue,
      },
      {
        'title': 'Paiement confirmé',
        'message': 'Votre paiement de 167,47 € a été confirmé',
        'time': 'Hier',
        'icon': Icons.payment,
        'color': Colors.purple,
      },
      {
        'title': 'Mise à jour de livraison',
        'message': 'Votre commande est en route',
        'time': 'Il y a 2 jours',
        'icon': Icons.local_shipping,
        'color': Colors.indigo,
      },
      {
        'title': 'Avis reçu',
        'message': 'Un client a laissé un avis sur votre produit',
        'time': 'Il y a 3 jours',
        'icon': Icons.star,
        'color': Colors.amber,
      },
      {
        'title': 'Rappel de panier',
        'message': 'Vous avez des articles dans votre panier',
        'time': 'Il y a 4 jours',
        'icon': Icons.shopping_cart,
        'color': Colors.red,
      },
      {
        'title': 'Mise à jour de l\'app',
        'message': 'Nouvelles fonctionnalités disponibles',
        'time': 'Il y a 1 semaine',
        'icon': Icons.system_update,
        'color': Colors.grey,
      },
    ];

    final notification = notifications[index % notifications.length];

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: isUnread
            ? Border.all(color: Colors.deepPurple.withOpacity(0.3), width: 2)
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône de notification
            Container(
              width: isTablet ? 48 : 40,
              height: isTablet ? 48 : 40,
              decoration: BoxDecoration(
                color: (notification['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                notification['icon'] as IconData,
                color: notification['color'] as Color,
                size: isTablet ? 24 : 20,
              ),
            ),

            SizedBox(width: isTablet ? 16 : 12),

            // Contenu de la notification
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification['title'] as String,
                          style: TextStyle(
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                            fontSize: isTablet ? 18 : 16,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: isTablet ? 10 : 8,
                          height: isTablet ? 10 : 8,
                          decoration: const BoxDecoration(
                            color: Colors.deepPurple,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: isTablet ? 8 : 4),
                  Text(
                    notification['message'] as String,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: isTablet ? 16 : 14,
                    ),
                  ),
                  SizedBox(height: isTablet ? 12 : 8),
                  Text(
                    notification['time'] as String,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: isTablet ? 14 : 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> notifications = [
    {
      'id': 1,
      'title': 'Commande livrée',
      'message': 'Votre commande #12345 a été livrée avec succès',
      'time': 'Il y a 2 heures',
      'icon': Icons.check_circle,
      'color': Colors.green,
      'isRead': false,
    },
    {
      'id': 2,
      'title': 'Promotion spéciale',
      'message': 'Profitez de -20% sur tous les produits électroniques',
      'time': 'Il y a 5 heures',
      'icon': Icons.local_offer,
      'color': Colors.orange,
      'isRead': false,
    },
    {
      'id': 3,
      'title': 'Nouveau produit',
      'message': 'Découvrez les nouveaux arrivages dans votre catégorie préférée',
      'time': 'Hier',
      'icon': Icons.new_releases,
      'color': Colors.blue,
      'isRead': false,
    },
    {
      'id': 4,
      'title': 'Paiement confirmé',
      'message': 'Votre paiement de 167,47 € a été confirmé',
      'time': 'Hier',
      'icon': Icons.payment,
      'color': Colors.purple,
      'isRead': true,
    },
    {
      'id': 5,
      'title': 'Mise à jour de livraison',
      'message': 'Votre commande est en route',
      'time': 'Il y a 2 jours',
      'icon': Icons.local_shipping,
      'color': Colors.indigo,
      'isRead': true,
    },
    {
      'id': 6,
      'title': 'Avis reçu',
      'message': 'Un client a laissé un avis sur votre produit',
      'time': 'Il y a 3 jours',
      'icon': Icons.star,
      'color': Colors.amber,
      'isRead': true,
    },
    {
      'id': 7,
      'title': 'Rappel de panier',
      'message': 'Vous avez des articles dans votre panier',
      'time': 'Il y a 4 jours',
      'icon': Icons.shopping_cart,
      'color': Colors.red,
      'isRead': true,
    },
    {
      'id': 8,
      'title': 'Mise à jour de l\'app',
      'message': 'Nouvelles fonctionnalités disponibles',
      'time': 'Il y a 1 semaine',
      'icon': Icons.system_update,
      'color': Colors.grey,
      'isRead': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    // Responsive padding
    final horizontalPadding = isMobile ? 16.0 : (isTablet ? 24.0 : 32.0);
    final verticalPadding = isMobile ? 16.0 : (isTablet ? 24.0 : 32.0);
    final topSpacing = isMobile ? 16.0 : (isTablet ? 24.0 : 32.0);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: topSpacing),

              // Header avec titre et options
              _buildHeader(isMobile, isTablet),

              SizedBox(height: isDesktop ? 32 : (isTablet ? 28 : 20)),

              // Liste des notifications
              Expanded(
                child: notifications.isEmpty
                    ? _buildEmptyState(isMobile, isTablet)
                    : _buildNotificationsList(isMobile, isTablet, isDesktop),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Boutons - Layout responsive
        if (isMobile)
          _buildButtonsMobile()
        else
          _buildButtonsDesktop(isTablet),
      ],
    );
  }

  Widget _buildButtonsMobile() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () {
              _markAllAsRead();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Tout marquer comme lu',
              style: TextStyle(
                color: Colors.deepPurple,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              _clearAllNotifications();
            },
            icon: const Icon(Icons.delete_sweep, size: 15),
            label: const Text(
              'Tout supprimer',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButtonsDesktop(bool isTablet) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Gauche: Tout marquer comme lu
        TextButton(
          onPressed: () {
            _markAllAsRead();
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(
              vertical: 12,
              horizontal: isTablet ? 16 : 20,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Tout marquer comme lu',
            style: TextStyle(
              color: Colors.deepPurple,
              fontSize: isTablet ? 13 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // Droite: Tout supprimer
        ElevatedButton.icon(
          onPressed: () {
            _clearAllNotifications();
          },
          icon: Icon(Icons.delete_sweep, size: isTablet ? 16 : 18),
          label: Text(
            'Tout supprimer',
            style: TextStyle(
              fontSize: isTablet ? 13 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 12 : 16,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isMobile, bool isTablet) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: isMobile ? 60 : (isTablet ? 80 : 100),
            color: Colors.grey[400],
          ),
          SizedBox(height: isMobile ? 16 : (isTablet ? 20 : 24)),
          Text(
            'Aucune notification',
            style: TextStyle(
              fontSize: isMobile ? 18 : (isTablet ? 22 : 26),
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isMobile ? 8 : (isTablet ? 12 : 16)),
          Text(
            'Vous n\'avez aucune nouvelle notification',
            style: TextStyle(
              fontSize: isMobile ? 14 : (isTablet ? 16 : 18),
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(bool isMobile, bool isTablet, bool isDesktop) {
    return ListView.builder(
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        return _dismissibleNotificationCard(index, isMobile, isTablet, isDesktop);
      },
    );
  }

  Widget _dismissibleNotificationCard(
      int index,
      bool isMobile,
      bool isTablet,
      bool isDesktop,
      ) {
    final notification = notifications[index];
    final isUnread = !notification['isRead'] as bool;

    // Responsive spacing
    final cardMarginBottom = isMobile ? 12.0 : (isTablet ? 16.0 : 18.0);
    final iconSize = isMobile ? 40 : (isTablet ? 48 : 56);
    final iconInnerSize = isMobile ? 20 : (isTablet ? 24 : 28);
    final titleFontSize = isMobile ? 15 : (isTablet ? 17 : 18);
    final messageFontSize = isMobile ? 13 : (isTablet ? 15 : 16);
    final timeFontSize = isMobile ? 11 : (isTablet ? 13 : 14);
    final cardPadding = isMobile ? 12.0 : (isTablet ? 18.0 : 20.0);
    final iconSpacing = isMobile ? 10.0 : (isTablet ? 14.0 : 16.0);

    return Dismissible(
      key: Key(notification['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: cardPadding),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete,
              color: Colors.white,
              size: isMobile ? 24 : (isTablet ? 28 : 32),
            ),
            SizedBox(height: isMobile ? 2 : 4),
            Text(
              'Supprimer',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 10 : (isTablet ? 12 : 14),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (direction) {
        _deleteNotification(index);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: cardMarginBottom),
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
              ? Border.all(
            color: Colors.deepPurple.withOpacity(0.3),
            width: 2,
          )
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icône de notification
              Container(
                width: iconSize.toDouble(),
                height: iconSize.toDouble(),
                decoration: BoxDecoration(
                  color: (notification['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  notification['icon'] as IconData,
                  color: notification['color'] as Color,
                  size: iconInnerSize.toDouble(),
                ),
              ),

              SizedBox(width: iconSpacing),

              // Contenu de la notification
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre + Indicateur de non-lu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification['title'] as String,
                            style: TextStyle(
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: titleFontSize.toDouble(),
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Padding(
                            padding: EdgeInsets.only(
                              left: isMobile ? 4 : 8,
                              top: isMobile ? 2 : 4,
                            ),
                            child: Container(
                              width: isMobile ? 6 : (isTablet ? 8 : 10),
                              height: isMobile ? 6 : (isTablet ? 8 : 10),
                              decoration: const BoxDecoration(
                                color: Colors.deepPurple,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),

                    SizedBox(height: isMobile ? 4 : (isTablet ? 6 : 8)),

                    // Message
                    Text(
                      notification['message'] as String,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: messageFontSize.toDouble(),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: isMobile ? 6 : (isTablet ? 10 : 12)),

                    // Heure
                    Text(
                      notification['time'] as String,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: timeFontSize.toDouble(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteNotification(int index) {
    setState(() {
      notifications.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification supprimée'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () {
            // TODO: Implémenter la fonctionnalité d'annulation
          },
        ),
      ),
    );
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in notifications) {
        notification['isRead'] = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Toutes les notifications marquées comme lues'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearAllNotifications() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 20,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFEF4444),
                  const Color(0xFFF87171),
                  const Color(0xFFFCA5A5),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header avec icône animée
                Container(
                  padding: const EdgeInsets.all(28),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.delete_sweep,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),

                // Contenu blanc
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Supprimer les notifications',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Êtes-vous sûr de vouloir\nsupprimer toutes les notifications?',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // Boutons modernes
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFEF4444),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  backgroundColor: Colors.transparent,
                                ),
                                child: const Text(
                                  'Annuler',
                                  style: TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  setState(() {
                                    notifications.clear();
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Toutes les notifications ont été supprimées',
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  foregroundColor: Colors.white,
                                  shadowColor: const Color(0xFFEF4444)
                                      .withOpacity(0.3),
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Supprimer',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
import 'package:flutter/material.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

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
            
            // Filtres
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20 : 16,
                      vertical: isTablet ? 12 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.filter_list, color: Colors.grey, size: isTablet ? 20 : 16),
                        SizedBox(width: isTablet ? 12 : 8),
                        Text(
                          'Toutes les commandes',
                          style: TextStyle(fontSize: isTablet ? 14 : 12),
                        ),
                        Icon(Icons.arrow_drop_down, size: isTablet ? 20 : 16),
                      ],
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20 : 16,
                      vertical: isTablet ? 12 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, color: Colors.grey, size: isTablet ? 18 : 16),
                        SizedBox(width: isTablet ? 12 : 8),
                        Text(
                          'Date',
                          style: TextStyle(fontSize: isTablet ? 14 : 12),
                        ),
                        Icon(Icons.arrow_drop_down, size: isTablet ? 20 : 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: isTablet ? 30 : 20),
            
            // Liste des commandes
            Expanded(
              child: ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) {
                  return _orderCard(isTablet);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(bool isTablet) {
    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 20 : 16),
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
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête de la commande
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Commande #12345',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isTablet ? 18 : 16,
                        ),
                      ),
                      SizedBox(height: isTablet ? 6 : 4),
                      Text(
                        '15 Janvier 2024',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isTablet ? 14 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 16 : 12,
                    vertical: isTablet ? 8 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Livrée',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: isTablet ? 14 : 12,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: isTablet ? 16 : 12),
            
            // Produits de la commande
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: isTablet ? 80 : 60,
                    height: isTablet ? 80 : 60,
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.image,
                      color: Colors.grey,
                      size: isTablet ? 30 : 20,
                    ),
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Produit 1',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: isTablet ? 16 : 14,
                        ),
                      ),
                      SizedBox(height: isTablet ? 8 : 4),
                      Text(
                        'Quantité: 2',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isTablet ? 14 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '99,98 €',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                    fontSize: isTablet ? 18 : 16,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: isTablet ? 16 : 12),
            const Divider(),
            
            // Actions
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: 167,47 €',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 18 : 16,
                      ),
                    ),
                    if (!isTablet)
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              // TODO: voir les détails
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.deepPurple),
                              foregroundColor: Colors.deepPurple,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: const Text('Détails', style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              // TODO: commander à nouveau
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: const Text('Recommander', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                  ),
                  ],
                ),
                if (isTablet)
                  SizedBox(height: isTablet ? 12 : 8),
                if (isTablet)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          // TODO: voir les détails
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.deepPurple),
                          foregroundColor: Colors.deepPurple,
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 20 : 16,
                            vertical: isTablet ? 12 : 8,
                          ),
                        ),
                        child: Text(
                          'Détails',
                          style: TextStyle(fontSize: isTablet ? 14 : 12),
                        ),
                      ),
                      SizedBox(width: isTablet ? 12 : 8),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: commander à nouveau
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 20 : 16,
                            vertical: isTablet ? 12 : 8,
                          ),
                        ),
                        child: Text(
                          'Recommander',
                          style: TextStyle(fontSize: isTablet ? 14 : 12),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

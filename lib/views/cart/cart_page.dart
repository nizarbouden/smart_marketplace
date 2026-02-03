import 'package:flutter/material.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

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
            
            // Liste des articles dans le panier
            Expanded(
              child: ListView.builder(
                itemCount: 3,
                itemBuilder: (context, index) {
                  return _cartItemCard(isTablet);
                },
              ),
            ),
            
            // Résumé du panier
            Container(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
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
              child: Column(
                children: [
                  _summaryRow('Sous-total', '149,97 €', isTablet),
                  _summaryRow('Livraison', '5,00 €', isTablet),
                  _summaryRow('TVA', '12,50 €', isTablet),
                  const Divider(),
                  _summaryRow('Total', '167,47 €', isTablet, isTotal: true),
                  SizedBox(height: isTablet ? 20 : 16),
                  SizedBox(
                    width: double.infinity,
                    height: isTablet ? 56 : 48,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: procéder au paiement
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Procéder au paiement',
                        style: TextStyle(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  Widget _cartItemCard(bool isTablet) {
    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
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
      child: Row(
        children: [
          // Image du produit
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: isTablet ? 100 : 80,
              height: isTablet ? 100 : 80,
              color: Colors.grey[200],
              child: Icon(
                Icons.image,
                color: Colors.grey,
                size: isTablet ? 40 : 30,
              ),
            ),
          ),
          
          SizedBox(width: isTablet ? 16 : 12),
          
          // Détails du produit
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nom du produit',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isTablet ? 18 : 16,
                  ),
                ),
                SizedBox(height: isTablet ? 8 : 4),
                Text(
                  '49,99 €',
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
                SizedBox(height: isTablet ? 16 : 8),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove, size: isTablet ? 20 : 16),
                            onPressed: () {},
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: isTablet ? 12 : 8),
                            child: Text(
                              '1',
                              style: TextStyle(fontSize: isTablet ? 16 : 14),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add, size: isTablet ? 20 : 16),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red, size: isTablet ? 24 : 20),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, bool isTablet, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTablet ? 6 : 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? (isTablet ? 18 : 16) : (isTablet ? 16 : 14),
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? (isTablet ? 18 : 16) : (isTablet ? 16 : 14),
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.deepPurple : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final crossAxisCount = isTablet ? 3 : 2;
    final childAspectRatio = isTablet ? 0.8 : 0.75;
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: isTablet ? 30 : 20),

            // 🔍 Barre de recherche
            TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher des produits...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 16 : 12,
                ),
              ),
            ),

            SizedBox(height: isTablet ? 30 : 20),

            // 🏷 Catégories
            Text(
              'Catégories',
              style: TextStyle(
                fontSize: isTablet ? 22 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: isTablet ? 15 : 10),

            SizedBox(
              height: isTablet ? 60 : 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _categoryItem('Tous', isTablet),
                  _categoryItem('Électronique', isTablet),
                  _categoryItem('Mode', isTablet),
                  _categoryItem('Chaussures', isTablet),
                  _categoryItem('Accessoires', isTablet),
                ],
              ),
            ),

            SizedBox(height: isTablet ? 30 : 20),

            // 🛍 Produits
            Text(
              'Produits Populaires',
              style: TextStyle(
                fontSize: isTablet ? 22 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: isTablet ? 15 : 10),

            LayoutBuilder(
              builder: (context, constraints) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 6,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: isTablet ? 16 : 12,
                    crossAxisSpacing: isTablet ? 16 : 12,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemBuilder: (context, index) {
                    return _productCard(isTablet);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 🟣 Widget catégorie
  Widget _categoryItem(String title, bool isTablet) {
    return Container(
      margin: EdgeInsets.only(right: isTablet ? 15 : 10),
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 20,
        vertical: isTablet ? 12 : 8,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.deepPurple,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: isTablet ? 14 : 12,
        ),
      ),
    );
  }

  // 🟣 Carte produit
  Widget _productCard(bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: Container(
                color: Colors.grey[200],
                child: Icon(
                  Icons.image,
                  size: isTablet ? 60 : 40,
                  color: Colors.grey[400],
                ),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.all(isTablet ? 12 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nom du produit',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
                SizedBox(height: isTablet ? 8 : 5),
                Text(
                  '49,99 €',
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

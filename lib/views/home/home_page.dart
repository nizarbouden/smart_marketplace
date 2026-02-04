import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;
    
    // Responsive grid settings
    int crossAxisCount;
    double childAspectRatio;
    double padding;
    
    if (isDesktop) {
      crossAxisCount = 4;
      childAspectRatio = 0.9;
      padding = 32;
    } else if (isTablet) {
      crossAxisCount = 3;
      childAspectRatio = 0.8;
      padding = 24;
    } else {
      crossAxisCount = 2;
      childAspectRatio = 0.75;
      padding = 16;
    }
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: isDesktop ? 40 : isTablet ? 30 : 20),

            // 🔍 Barre de recherche
            TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher des produits...',
                prefixIcon: Icon(Icons.search, size: isDesktop ? 28 : isTablet ? 24 : 20),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24 : isTablet ? 20 : 16,
                  vertical: isDesktop ? 20 : isTablet ? 16 : 12,
                ),
                hintStyle: TextStyle(
                  fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                ),
              ),
            ),

            SizedBox(height: isDesktop ? 40 : isTablet ? 30 : 20),

            // 🏷 Catégories
            Text(
              'Catégories',
              style: TextStyle(
                fontSize: isDesktop ? 28 : isTablet ? 22 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: isDesktop ? 20 : isTablet ? 15 : 10),

            SizedBox(
              height: isDesktop ? 80 : isTablet ? 60 : 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _categoryCard('Électronique', Icons.computer, isDesktop, isTablet),
                  _categoryCard('Mode', Icons.checkroom, isDesktop, isTablet),
                  _categoryCard('Maison', Icons.home, isDesktop, isTablet),
                  _categoryCard('Sports', Icons.sports_soccer, isDesktop, isTablet),
                  _categoryCard('Livres', Icons.book, isDesktop, isTablet),
                ],
              ),
            ),

            SizedBox(height: isDesktop ? 40 : isTablet ? 30 : 20),

            // 🛍️ Produits populaires
            Text(
              'Produits populaires',
              style: TextStyle(
                fontSize: isDesktop ? 28 : isTablet ? 22 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: isDesktop ? 20 : isTablet ? 15 : 10),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: isDesktop ? 20 : isTablet ? 16 : 12,
                mainAxisSpacing: isDesktop ? 20 : isTablet ? 16 : 12,
              ),
              itemCount: 8,
              itemBuilder: (context, index) {
                return _productCard('Produit ${index + 1}', '${(index + 1) * 15.99} €', isDesktop, isTablet);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 🟣 Widget catégorie
  Widget _categoryCard(String title, IconData icon, bool isDesktop, bool isTablet) {
    return Container(
      margin: EdgeInsets.only(right: isDesktop ? 20 : isTablet ? 15 : 10),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : isTablet ? 24 : 20,
        vertical: isDesktop ? 16 : isTablet ? 12 : 8,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.deepPurple,
        borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: isDesktop ? 24 : isTablet ? 20 : 16,
          ),
          SizedBox(width: isDesktop ? 12 : isTablet ? 8 : 6),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: isDesktop ? 16 : isTablet ? 14 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // 🟣 Carte produit
  Widget _productCard(String name, String price, bool isDesktop, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 15),
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(isDesktop ? 20 : 15)),
              child: Container(
                color: Colors.grey[200],
                child: Icon(
                  Icons.image,
                  size: isDesktop ? 80 : isTablet ? 60 : 40,
                  color: Colors.grey[400],
                ),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.all(isDesktop ? 16 : isTablet ? 12 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isDesktop ? 12 : isTablet ? 8 : 5),
                Text(
                  price,
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
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

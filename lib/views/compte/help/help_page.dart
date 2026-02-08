import 'package:flutter/material.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredArticles = [];
  
  final List<Map<String, dynamic>> _helpArticles = [
    {
      'id': 1,
      'category': 'Commandes',
      'title': 'Comment suivre ma commande ?',
      'content': 'Vous pouvez suivre votre commande depuis la section "Historique" de votre profil. Vous y trouverez le statut en temps réel de toutes vos commandes.',
      'icon': Icons.local_shipping,
      'color': Colors.blue,
    },
    {
      'id': 2,
      'category': 'Commandes',
      'title': 'Comment annuler une commande ?',
      'content': 'Pour annuler une commande, allez dans l\'historique des commandes, sélectionnez la commande concernée et cliquez sur "Annuler". Vous avez 30 minutes après la validation pour annuler.',
      'icon': Icons.cancel,
      'color': Colors.orange,
    },
    {
      'id': 3,
      'category': 'Paiement',
      'title': 'Quels sont les moyens de paiement acceptés ?',
      'content': 'Nous acceptons les cartes bancaires, les portefeuilles électroniques et le paiement à la livraison. Toutes les transactions sont sécurisées.',
      'icon': Icons.payment,
      'color': Colors.green,
    },
    {
      'id': 4,
      'category': 'Compte',
      'title': 'Comment modifier mes informations personnelles ?',
      'content': 'Allez dans votre profil, puis "Informations personnelles" pour modifier votre nom, email et numéro de téléphone.',
      'icon': Icons.person,
      'color': Colors.purple,
    },
    {
      'id': 5,
      'category': 'Livraison',
      'title': 'Quels sont les délais de livraison ?',
      'content': 'Les délais de livraison varient selon votre localisation : Grand Tunis : 24-48h, Autres gouvernorats : 2-5 jours ouvrés.',
      'icon': Icons.delivery_dining,
      'color': Colors.red,
    },
    {
      'id': 6,
      'category': 'Retours',
      'title': 'Comment retourner un produit ?',
      'content': 'Vous avez 14 jours pour retourner un produit. Contactez notre service client via le chat ou par email pour initier un retour.',
      'icon': Icons.assignment_return,
      'color': Colors.teal,
    },
    {
      'id': 7,
      'category': 'Sécurité',
      'title': 'Comment sécuriser mon compte ?',
      'content': 'Activez l\'authentification à deux facteurs et utilisez un mot de passe robuste. Évitez de partager vos identifiants.',
      'icon': Icons.security,
      'color': Colors.indigo,
    },
    {
      'id': 8,
      'category': 'Application',
      'title': 'Comment mettre à jour l\'application ?',
      'content': 'Vérifiez régulièrement le Play Store ou App Store pour les mises à jour. Activez les mises à jour automatiques pour ne rien manquer.',
      'icon': Icons.system_update,
      'color': Colors.cyan,
    },
  ];

  @override
  void initState() {
    super.initState();
    _filteredArticles = _helpArticles;
    _searchController.addListener(_filterArticles);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(context, isDesktop, isTablet, isMobile),
      body: _buildBody(context, isDesktop, isTablet, isMobile),
      floatingActionButton: _buildFloatingActionButton(isDesktop, isTablet, isMobile),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDesktop, bool isTablet, bool isMobile) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(
          Icons.arrow_back,
          color: Colors.black87,
          size: isDesktop ? 28 : isTablet ? 24 : 20,
        ),
      ),
      title: Text(
        'Centre d\'aide',
        style: TextStyle(
          color: Colors.black87,
          fontSize: isDesktop ? 24 : isTablet ? 22 : 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: false,
    );
  }

  Widget _buildBody(BuildContext context, bool isDesktop, bool isTablet, bool isMobile) {
    return Column(
      children: [
        // Barre de recherche
        Container(
          margin: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher une aide...',
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.grey[600],
                size: isDesktop ? 24 : isTablet ? 22 : 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : isTablet ? 20 : 24,
                vertical: isMobile ? 14 : isTablet ? 16 : 18,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),

        // Catégories rapides
        Container(
          margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : isTablet ? 20 : 24),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip('Tous', Colors.deepPurple, true),
                _buildCategoryChip('Commandes', Colors.blue, false),
                _buildCategoryChip('Paiement', Colors.green, false),
                _buildCategoryChip('Compte', Colors.purple, false),
                _buildCategoryChip('Livraison', Colors.red, false),
                _buildCategoryChip('Retours', Colors.teal, false),
              ],
            ),
          ),
        ),

        SizedBox(height: isMobile ? 16 : isTablet ? 20 : 24),

        // Articles d'aide
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : isTablet ? 20 : 24),
            itemCount: _filteredArticles.length,
            itemBuilder: (context, index) {
              final article = _filteredArticles[index];
              return _buildArticleCard(article, isDesktop, isTablet, isMobile);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String label, Color color, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          // TODO: Filtrer par catégorie
        },
        backgroundColor: isSelected ? color : color.withOpacity(0.1),
        side: BorderSide(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
    );
  }

  Widget _buildArticleCard(Map<String, dynamic> article, bool isDesktop, bool isTablet, bool isMobile) {
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : isTablet ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: EdgeInsets.all(isMobile ? 8 : isTablet ? 10 : 12),
          decoration: BoxDecoration(
            color: (article['color'] as Color).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            article['icon'] as IconData,
            color: article['color'] as Color,
            size: isDesktop ? 24 : isTablet ? 22 : 20,
          ),
        ),
        title: Text(
          article['title'] as String,
          style: TextStyle(
            fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          article['category'] as String,
          style: TextStyle(
            fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
            color: article['color'] as Color,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          Icons.expand_more,
          color: Colors.grey[400],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
            child: Text(
              article['content'] as String,
              style: TextStyle(
                fontSize: isDesktop ? 15 : isTablet ? 14 : 13,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(bool isDesktop, bool isTablet, bool isMobile) {
    return FloatingActionButton.extended(
      onPressed: _showContactSupport,
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: Icon(
        Icons.support_agent,
        size: isDesktop ? 24 : isTablet ? 22 : 20,
      ),
      label: Text(
        'Support',
        style: TextStyle(
          fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _filterArticles() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredArticles = _helpArticles;
      } else {
        _filteredArticles = _helpArticles.where((article) {
          final title = (article['title'] as String).toLowerCase();
          final content = (article['content'] as String).toLowerCase();
          final category = (article['category'] as String).toLowerCase();
          return title.contains(query) || 
                 content.contains(query) || 
                 category.contains(query);
        }).toList();
      }
    });
  }

  void _showContactSupport() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Contacter le support',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            _buildContactOption(
              'Chat en direct',
              'Discutez avec un agent maintenant',
              Icons.chat,
              Colors.green,
              () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chat en direct bientôt disponible!'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
            ),
            _buildContactOption(
              'Téléphone',
              'Appelez-nous au 71 234 567',
              Icons.phone,
              Colors.blue,
              () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Appel en cours...'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
            _buildContactOption(
              'Email',
              'Envoyez-nous un email',
              Icons.email,
              Colors.orange,
              () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ouverture du client email...'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildContactOption(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: Colors.grey,
        size: 16,
      ),
      onTap: onTap,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:smart_marketplace/services/faq_service.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final TextEditingController _searchController = TextEditingController();
  final FAQService _faqService = FAQService();
  List<Map<String, dynamic>> _filteredArticles = [];
  List<Map<String, dynamic>> _allArticles = [];
  List<String> _categories = [];
  String _selectedCategory = 'Tous';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFAQs();
    _searchController.addListener(_filterArticles);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFAQs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('🔥 Début du chargement des FAQs...');
      final faqs = await _faqService.getAllFAQs();
      final categories = await _faqService.getCategories();
      
      print('📋 FAQs récupérées: ${faqs.length}');
      print('📂 Catégories récupérées: $categories');
      
      for (var faq in faqs) {
        print('📄 FAQ: ${faq['title']} - ${faq['category']}');
      }

      setState(() {
        _allArticles = faqs;
        _filteredArticles = faqs;
        _categories = ['Tous', ...categories];
        _isLoading = false;
      });
      
      print('✅ FAQs chargées avec succès!');
    } catch (e) {
      print('❌ Erreur lors du chargement des FAQs: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des FAQs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getColorFromString(String colorString) {
    if (colorString.startsWith('#')) {
      return Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
    }

    switch (colorString.toLowerCase()) {
      case 'blue': return Colors.blue;
      case 'orange': return Colors.orange;
      case 'green': return Colors.green;
      case 'purple': return Colors.purple;
      case 'red': return Colors.red;
      case 'teal': return Colors.teal;
      case 'indigo': return Colors.indigo;
      case 'cyan': return Colors.cyan;
      default: return Colors.grey;
    }
  }

  IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'local_shipping': return Icons.local_shipping;
      case 'cancel': return Icons.cancel;
      case 'payment': return Icons.payment;
      case 'person': return Icons.person;
      case 'delivery_dining': return Icons.delivery_dining;
      case 'assignment_return': return Icons.assignment_return;
      case 'security': return Icons.security;
      case 'system_update': return Icons.system_update;
      default: return Icons.help_outline;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'commandes': return Colors.blue;
      case 'paiement': return Colors.green;
      case 'compte': return Colors.purple;
      case 'livraison': return Colors.red;
      case 'retours': return Colors.teal;
      case 'sécurité': return Colors.indigo;
      case 'application': return Colors.cyan;
      default: return Colors.deepPurple;
    }
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
      body: _isLoading
          ? _buildLoadingWidget()
          : _buildBody(context, isDesktop, isTablet, isMobile),
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

  Widget _buildLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
      ),
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
              children: _categories.map((category) {
                final color = category == 'Tous' ? Colors.deepPurple : _getCategoryColor(category);
                return _buildCategoryChip(category, color, category == _selectedCategory);
              }).toList(),
            ),
          ),
        ),

        SizedBox(height: isMobile ? 16 : isTablet ? 20 : 24),

        // Articles d'aide
        Expanded(
          child: _filteredArticles.isEmpty
              ? _buildEmptyState(context, isDesktop, isTablet, isMobile)
              : ListView.builder(
                  padding: EdgeInsets.only(
                    left: isMobile ? 16 : isTablet ? 20 : 24,
                    right: isMobile ? 16 : isTablet ? 20 : 24,
                    bottom: isMobile ? 80 : isTablet ? 90 : 100, // Espace pour le bouton flottant
                  ),
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
          setState(() {
            _selectedCategory = label;
            _filterArticles();
          });
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
    final icon = _getIconFromString(article['icon'] ?? 'help_outline');
    final color = _getColorFromString(article['color'] ?? 'blue');

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
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: isDesktop ? 24 : isTablet ? 22 : 20,
          ),
        ),
        title: Text(
          article['title'] ?? 'Question',
          style: TextStyle(
            fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          article['category'] ?? 'Catégorie',
          style: TextStyle(
            fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
            color: color,
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
              article['content'] ?? 'Contenu non disponible',
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

  Widget _buildEmptyState(BuildContext context, bool isDesktop, bool isTablet, bool isMobile) {
    return Padding(
      padding: EdgeInsets.only(
        left: isMobile ? 16 : isTablet ? 20 : 24,
        right: isMobile ? 16 : isTablet ? 20 : 24,
        bottom: isMobile ? 80 : isTablet ? 90 : 100, // Espace pour le bouton flottant
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: isDesktop ? 80 : isTablet ? 64 : 48,
              color: Colors.grey[400],
            ),
            SizedBox(height: isMobile ? 16 : isTablet ? 20 : 24),
            Text(
              'Aucune aide trouvée',
              style: TextStyle(
                fontSize: isDesktop ? 20 : isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: isMobile ? 8 : isTablet ? 10 : 12),
            Text(
              'Essayez de modifier votre recherche ou de changer de catégorie',
              style: TextStyle(
                fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
    print('🔍 Filtrage - Recherche: "$query", Catégorie: "$_selectedCategory"');
    
    setState(() {
      if (query.isEmpty && _selectedCategory == 'Tous') {
        _filteredArticles = _allArticles;
        print('📋 Affichage de toutes les FAQs: ${_filteredArticles.length}');
      } else {
        _filteredArticles = _allArticles.where((article) {
          final title = (article['title'] as String? ?? '').toLowerCase();
          final content = (article['content'] as String? ?? '').toLowerCase();
          final category = (article['category'] as String? ?? '').toLowerCase();
          
          final matchesSearch = query.isEmpty || 
                              title.contains(query) || 
                              content.contains(query) || 
                              category.contains(query);
          
          final matchesCategory = _selectedCategory == 'Tous' || 
                                 category == _selectedCategory.toLowerCase();
          
          print('📄 "${article['title']}" - Search: $matchesSearch, Category: $matchesCategory');
          
          return matchesSearch && matchesCategory;
        }).toList();
        print('📋 FAQs filtrées: ${_filteredArticles.length}');
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
              'Appelez-nous au +216 70 000 000',
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
              'Envoyez-nous un email à support@winzy.com',
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

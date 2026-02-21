import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_marketplace/services/faq_service.dart';
import 'package:smart_marketplace/services/email_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';

import 'live_chat_page.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final TextEditingController _searchController = TextEditingController();
  final FAQService _faqService = FAQService();
  final EmailService _emailService = EmailService();
  final TextEditingController _issueController = TextEditingController();
  List<Map<String, dynamic>> _filteredArticles = [];
  List<Map<String, dynamic>> _allArticles = [];
  List<String> _categories = [];
  String _selectedCategory = '';   // initialisé dans initState
  bool _isLoading = true;
  bool _isSendingEmail = false;

  String _t(String key) => AppLocalizations.get(key);

  @override
  void initState() {
    super.initState();
    _selectedCategory = _t('help_category_all');
    _loadFAQs();
    _searchController.addListener(_filterArticles);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _issueController.dispose();
    super.dispose();
  }

  Future<void> _loadFAQs() async {
    setState(() => _isLoading = true);
    try {
      final faqs       = await _faqService.getAllFAQs();
      final categories = await _faqService.getCategories();
      setState(() {
        _allArticles      = faqs;
        _filteredArticles = faqs;
        _categories       = [_t('help_category_all'), ...categories];
        _selectedCategory = _t('help_category_all');
        _isLoading        = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_t('help_faq_load_error')}: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Color _getColorFromString(String colorString) {
    if (colorString.startsWith('#')) {
      return Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
    }
    switch (colorString.toLowerCase()) {
      case 'blue':   return Colors.blue;
      case 'orange': return Colors.orange;
      case 'green':  return Colors.green;
      case 'purple': return Colors.purple;
      case 'red':    return Colors.red;
      case 'teal':   return Colors.teal;
      case 'indigo': return Colors.indigo;
      case 'cyan':   return Colors.cyan;
      default:       return Colors.grey;
    }
  }

  IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'local_shipping':    return Icons.local_shipping;
      case 'cancel':            return Icons.cancel;
      case 'payment':           return Icons.payment;
      case 'person':            return Icons.person;
      case 'delivery_dining':   return Icons.delivery_dining;
      case 'assignment_return': return Icons.assignment_return;
      case 'security':          return Icons.security;
      case 'system_update':     return Icons.system_update;
      default:                  return Icons.help_outline;
    }
  }

  Color _getCategoryColor(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('command') || cat.contains('order')) return Colors.blue;
    if (cat.contains('paiem') || cat.contains('payment')) return Colors.green;
    if (cat.contains('compte') || cat.contains('account')) return Colors.purple;
    if (cat.contains('livr') || cat.contains('deliv')) return Colors.red;
    if (cat.contains('retour') || cat.contains('return')) return Colors.teal;
    if (cat.contains('sécu') || cat.contains('secur')) return Colors.indigo;
    if (cat.contains('applic') || cat.contains('app')) return Colors.cyan;
    return Colors.deepPurple;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile  = screenWidth < 600;
    final isTablet  = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    return Directionality(
      textDirection: AppLocalizations.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _buildAppBar(context, isDesktop, isTablet, isMobile),
        body: _isLoading
            ? _buildLoadingWidget()
            : _buildBody(context, isDesktop, isTablet, isMobile),
        floatingActionButton: _buildFloatingActionButton(isDesktop, isTablet, isMobile),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDesktop, bool isTablet, bool isMobile) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(
          AppLocalizations.isRtl ? Icons.arrow_forward : Icons.arrow_back,
          color: Colors.black87,
          size: isDesktop ? 28 : isTablet ? 24 : 20,
        ),
      ),
      title: Text(
        _t('help_center_title'),
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
            textDirection: AppLocalizations.isRtl ? TextDirection.rtl : TextDirection.ltr,
            decoration: InputDecoration(
              hintText: _t('help_search_hint'),
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
              ),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600],
                  size: isDesktop ? 24 : isTablet ? 22 : 20),
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

        // Filtres de catégorie
        Container(
          margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : isTablet ? 20 : 24),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((category) {
                final isAll      = category == _t('help_category_all');
                final color      = isAll ? Colors.deepPurple : _getCategoryColor(category);
                final isSelected = category == _selectedCategory;
                return _buildCategoryChip(category, color, isSelected);
              }).toList(),
            ),
          ),
        ),

        SizedBox(height: isMobile ? 16 : isTablet ? 20 : 24),

        // Liste des articles
        Expanded(
          child: _filteredArticles.isEmpty
              ? _buildEmptyState(context, isDesktop, isTablet, isMobile)
              : ListView.builder(
            padding: EdgeInsets.only(
              left:   isMobile ? 16 : isTablet ? 20 : 24,
              right:  isMobile ? 16 : isTablet ? 20 : 24,
              bottom: isMobile ? 80 : isTablet ? 90 : 100,
            ),
            itemCount: _filteredArticles.length,
            itemBuilder: (context, index) {
              return _buildArticleCard(
                  _filteredArticles[index], isDesktop, isTablet, isMobile);
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
        onSelected: (_) {
          setState(() {
            _selectedCategory = label;
            _filterArticles();
          });
        },
        backgroundColor: isSelected ? color : color.withOpacity(0.1),
        side: BorderSide(color: color.withOpacity(0.3), width: 1),
      ),
    );
  }

  Widget _buildArticleCard(Map<String, dynamic> article, bool isDesktop, bool isTablet, bool isMobile) {
    final icon  = _getIconFromString(article['icon'] ?? 'help_outline');
    final color = _getColorFromString(article['color'] ?? 'blue');

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : isTablet ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: EdgeInsets.all(isMobile ? 8 : isTablet ? 10 : 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: isDesktop ? 24 : isTablet ? 22 : 20),
        ),
        title: Text(
          article['title'] ?? _t('help_faq_content_unavailable'),
          style: TextStyle(
            fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          article['category'] ?? '',
          style: TextStyle(fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
              color: color, fontWeight: FontWeight.w500),
        ),
        trailing: Icon(Icons.expand_more, color: Colors.grey[400]),
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
            child: Text(
              article['content'] ?? _t('help_faq_content_unavailable'),
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
        left:   isMobile ? 16 : isTablet ? 20 : 24,
        right:  isMobile ? 16 : isTablet ? 20 : 24,
        bottom: isMobile ? 80 : isTablet ? 90 : 100,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: isDesktop ? 80 : isTablet ? 64 : 48, color: Colors.grey[400]),
            SizedBox(height: isMobile ? 16 : isTablet ? 20 : 24),
            Text(
              _t('help_empty_title'),
              style: TextStyle(
                fontSize: isDesktop ? 20 : isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: isMobile ? 8 : isTablet ? 10 : 12),
            Text(
              _t('help_empty_subtitle'),
              style: TextStyle(fontSize: isDesktop ? 14 : isTablet ? 13 : 12, color: Colors.grey[500]),
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
      icon: Icon(Icons.support_agent, size: isDesktop ? 24 : isTablet ? 22 : 20),
      label: Text(
        _t('help_support_fab'),
        style: TextStyle(fontSize: isDesktop ? 16 : isTablet ? 15 : 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _filterArticles() {
    final query = _searchController.text.toLowerCase();
    final allCategory = _t('help_category_all');
    setState(() {
      if (query.isEmpty && _selectedCategory == allCategory) {
        _filteredArticles = _allArticles;
      } else {
        _filteredArticles = _allArticles.where((article) {
          final title    = (article['title']    as String? ?? '').toLowerCase();
          final content  = (article['content']  as String? ?? '').toLowerCase();
          final category = (article['category'] as String? ?? '').toLowerCase();
          final matchesSearch   = query.isEmpty || title.contains(query) || content.contains(query);
          final matchesCategory = _selectedCategory == allCategory ||
              category == _selectedCategory.toLowerCase();
          return matchesSearch && matchesCategory;
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
      builder: (context) => Directionality(
        textDirection: AppLocalizations.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Text(
                _t('help_contact_title'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 20),

              // Chat
              _buildContactOption(
                _t('help_chat_title'),
                _t('help_chat_subtitle'),
                Icons.chat,
                Colors.green,
                    () {
                  Navigator.pop(context); // ferme le bottom sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LiveChatPage()),
                  );
                },
              ),

              // Téléphone
              _buildContactOption(
                _t('help_phone_title'),
                _t('help_phone_subtitle'),
                Icons.phone,
                Colors.blue,
                    () async {
                  Navigator.pop(context);
                  try {
                    final Uri phoneUri = Uri.parse('tel:21693489229');
                    if (await canLaunchUrl(phoneUri)) {
                      await launchUrl(phoneUri);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(_t('help_phone_unavailable')),
                        backgroundColor: Colors.orange,
                      ));
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${_t('error')}: $e'),
                      backgroundColor: Colors.red,
                    ));
                  }
                },
              ),

              // Email
              _buildContactOption(
                _t('help_email_title'),
                _t('help_email_subtitle'),
                Icons.email,
                Colors.orange,
                    () async {
                  Navigator.pop(context);
                  await _showSupportEmailDialog();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactOption(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      trailing: Icon(
        AppLocalizations.isRtl ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
        color: Colors.grey, size: 16,
      ),
      onTap: onTap,
    );
  }

  Future<void> _copyEmailToClipboard() async {
    try {
      await Clipboard.setData(const ClipboardData(text: 'nizarbouden234@gmail.com'));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('help_email_copied')),
        backgroundColor: Colors.blue,
        action: SnackBarAction(
          label: _t('ok'),
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('help_email_fallback')),
        backgroundColor: Colors.grey,
        duration: const Duration(seconds: 5),
      ));
    }
  }

  // Dialogue pour envoyer un email de support automatiquement
  Future<void> _showSupportEmailDialog() async {
    _issueController.clear();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: AppLocalizations.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            title: Row(
              children: [
                Icon(Icons.email, color: Colors.orange, size: 24),
                const SizedBox(width: 12),
                Text(_t('help_email_title')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('help_email_dialog_subtitle'),
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _issueController,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: _t('help_email_issue_hint'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.orange, width: 2),
                      ),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t('help_email_disclaimer'),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(_t('cancel')),
              ),
              ElevatedButton(
                onPressed: _isSendingEmail ? null : () => _sendSupportEmail(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: _isSendingEmail
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(_t('help_send_email')),
              ),
            ],
          ),
        );
      },
    );
  }

  // Envoyer l'email de support automatiquement
  Future<void> _sendSupportEmail() async {
    if (_issueController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('help_email_empty_error')),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isSendingEmail = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final sent = await _emailService.sendSupportEmail(
        issueDescription: _issueController.text.trim(),
        userName: user?.displayName,
        userEmail: user?.email,
      );

      Navigator.of(context).pop(); // Fermer le dialogue

      if (sent) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('help_email_sent_success')),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('help_email_sent_pending')),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      Navigator.of(context).pop(); // Fermer le dialogue
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_t('error')}: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() => _isSendingEmail = false);
    }
  }
}
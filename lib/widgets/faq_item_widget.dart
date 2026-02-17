import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';

class FAQItemWidget extends StatefulWidget {
  final Map<String, dynamic> faq;
  final IconData icon;
  final Color color;
  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;

  const FAQItemWidget({
    super.key,
    required this.faq,
    required this.icon,
    required this.color,
    required this.isDesktop,
    required this.isTablet,
    required this.isMobile,
  });

  @override
  State<FAQItemWidget> createState() => _FAQItemWidgetState();
}

class _FAQItemWidgetState extends State<FAQItemWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        children: [
          // Header cliquable
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.all(
                widget.isMobile ? 16 : widget.isTablet ? 20 : 24,
              ),
              child: Row(
                children: [
                  // Icône
                  Container(
                    width: widget.isMobile ? 40 : widget.isTablet ? 48 : 56,
                    height: widget.isMobile ? 40 : widget.isTablet ? 48 : 56,
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.color,
                      size: widget.isMobile ? 20 : widget.isTablet ? 24 : 28,
                    ),
                  ),
                  
                  SizedBox(width: widget.isMobile ? 12 : widget.isTablet ? 16 : 20),
                  
                  // Contenu textuel
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.faq['title'] ?? AppLocalizations.get('faq_question'),
                          style: TextStyle(
                            fontSize: widget.isDesktop ? 16 : widget.isTablet ? 15 : 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: widget.isMobile ? 4 : 6),
                        Text(
                          widget.faq['category'] ?? AppLocalizations.get('faq_category'),
                          style: TextStyle(
                            fontSize: widget.isDesktop ? 12 : widget.isTablet ? 11 : 10,
                            color: widget.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Icône d'expansion
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey[600],
                      size: widget.isMobile ? 20 : widget.isTablet ? 22 : 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Contenu développé
          if (_isExpanded)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(
                  widget.isMobile ? 16 : widget.isTablet ? 20 : 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ligne de séparation
                    Container(
                      height: 1,
                      color: Colors.grey[200],
                      margin: EdgeInsets.only(bottom: widget.isMobile ? 12 : widget.isTablet ? 16 : 20),
                    ),
                    
                    // Contenu de la réponse
                    Text(
                      widget.faq['content'] ?? AppLocalizations.get('faq_content_unavailable'),
                      style: TextStyle(
                        fontSize: widget.isDesktop ? 14 : widget.isTablet ? 13 : 12,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                    
                    SizedBox(height: widget.isMobile ? 12 : widget.isTablet ? 16 : 20),
                    
                    // Actions
                    Row(
                      children: [
                        Icon(
                          Icons.thumb_up_outlined,
                          color: Colors.grey[600],
                          size: widget.isMobile ? 16 : widget.isTablet ? 18 : 20,
                        ),
                        SizedBox(width: widget.isMobile ? 6 : 8),
                        Text(
                          AppLocalizations.get('faq_useful'),
                          style: TextStyle(
                            fontSize: widget.isDesktop ? 12 : widget.isTablet ? 11 : 10,
                            color: Colors.grey[600],
                          ),
                        ),
                        
                        SizedBox(width: widget.isMobile ? 16 : widget.isTablet ? 20 : 24),
                        
                        Icon(
                          Icons.share_outlined,
                          color: Colors.grey[600],
                          size: widget.isMobile ? 16 : widget.isTablet ? 18 : 20,
                        ),
                        SizedBox(width: widget.isMobile ? 6 : 8),
                        Text(
                          AppLocalizations.get('faq_share'),
                          style: TextStyle(
                            fontSize: widget.isDesktop ? 12 : widget.isTablet ? 11 : 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

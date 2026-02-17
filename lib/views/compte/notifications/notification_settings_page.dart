import 'package:flutter/material.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _pushNotifications  = true;
  bool _emailNotifications = true;
  bool _orderUpdates       = true;
  bool _promotionalOffers  = false;
  bool _newProducts        = true;
  bool _priceDrops         = true;
  bool _newsletter         = false;
  bool _accountUpdates     = true;
  bool _securityAlerts     = true;

  String _t(String key) => AppLocalizations.get(key);

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
        body: _buildBody(context, isDesktop, isTablet, isMobile),
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
        _t('notif_settings_title'),
        style: TextStyle(
          color: Colors.black87,
          fontSize: isDesktop ? 24 : isTablet ? 22 : 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: IconButton(
            onPressed: _saveSettings,
            icon: Icon(Icons.save, color: Colors.deepPurple,
                size: isDesktop ? 24 : isTablet ? 22 : 20),
            tooltip: _t('notif_save_tooltip'),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, bool isDesktop, bool isTablet, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 24 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Notifications générales ────────────────────────────
          _buildSectionCard(
            title: _t('notif_section_general'),
            icon: Icons.notifications_active,
            isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
            children: [
              _buildSwitchTile(
                title:    _t('notif_push_title'),
                subtitle: _t('notif_push_subtitle'),
                value:    _pushNotifications,
                isLast:   false,
                onChanged: (v) => setState(() => _pushNotifications = v),
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
              _buildSwitchTile(
                title:    _t('notif_email_title'),
                subtitle: _t('notif_email_subtitle'),
                value:    _emailNotifications,
                isLast:   true,
                onChanged: (v) => setState(() => _emailNotifications = v),
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
            ],
          ),

          SizedBox(height: isMobile ? 20 : isTablet ? 24 : 28),

          // ── Commandes et livraisons ────────────────────────────
          _buildSectionCard(
            title: _t('notif_section_orders'),
            icon: Icons.shopping_cart,
            isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
            children: [
              _buildSwitchTile(
                title:    _t('notif_orders_title'),
                subtitle: _t('notif_orders_subtitle'),
                value:    _orderUpdates,
                isLast:   true,
                onChanged: (v) => setState(() => _orderUpdates = v),
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
            ],
          ),

          SizedBox(height: isMobile ? 20 : isTablet ? 24 : 28),

          // ── Marketing et promotions ────────────────────────────
          _buildSectionCard(
            title: _t('notif_section_marketing'),
            icon: Icons.campaign,
            isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
            children: [
              _buildSwitchTile(
                title:    _t('notif_promo_title'),
                subtitle: _t('notif_promo_subtitle'),
                value:    _promotionalOffers,
                isLast:   false,
                onChanged: (v) => setState(() => _promotionalOffers = v),
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
              _buildSwitchTile(
                title:    _t('notif_new_products_title'),
                subtitle: _t('notif_new_products_subtitle'),
                value:    _newProducts,
                isLast:   false,
                onChanged: (v) => setState(() => _newProducts = v),
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
              _buildSwitchTile(
                title:    _t('notif_price_drops_title'),
                subtitle: _t('notif_price_drops_subtitle'),
                value:    _priceDrops,
                isLast:   false,
                onChanged: (v) => setState(() => _priceDrops = v),
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
              _buildSwitchTile(
                title:    _t('notif_newsletter_title'),
                subtitle: _t('notif_newsletter_subtitle'),
                value:    _newsletter,
                isLast:   true,
                onChanged: (v) => setState(() => _newsletter = v),
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
            ],
          ),

          SizedBox(height: isMobile ? 20 : isTablet ? 24 : 28),

          // ── Compte et sécurité ─────────────────────────────────
          _buildSectionCard(
            title: _t('notif_section_account'),
            icon: Icons.account_circle,
            isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
            children: [
              _buildSwitchTile(
                title:    _t('notif_account_title'),
                subtitle: _t('notif_account_subtitle'),
                value:    _accountUpdates,
                isLast:   false,
                onChanged: (v) => setState(() => _accountUpdates = v),
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
              _buildSwitchTile(
                title:    _t('notif_security_title'),
                subtitle: _t('notif_security_subtitle'),
                value:    _securityAlerts,
                isLast:   true,
                onChanged: (v) => setState(() => _securityAlerts = v),
                isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 8 : isTablet ? 10 : 12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.deepPurple,
                      size: isDesktop ? 24 : isTablet ? 22 : 20),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isDesktop ? 18 : isTablet ? 17 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required bool isLast,
    required Function(bool) onChanged,
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : isTablet ? 20 : 24,
            vertical:   isMobile ? 12 : isTablet ? 14 : 16,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                      style: TextStyle(
                        fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: isMobile ? 2 : 4),
                    Text(subtitle,
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.deepPurple,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1, thickness: 0.5, color: Colors.grey[200],
            indent:    isMobile ? 16 : isTablet ? 20 : 24,
            endIndent: isMobile ? 16 : isTablet ? 20 : 24,
          ),
      ],
    );
  }

  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_t('notif_saved_success')),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
    Navigator.of(context).pop();
  }
}
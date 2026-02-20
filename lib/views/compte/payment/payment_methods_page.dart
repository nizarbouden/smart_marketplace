import 'package:flutter/material.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';

import 'add_card_page.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 1,
      'type': 'card',
      'brand': 'visa',
      'last4': '4242',
      'expiryMonth': '12',
      'expiryYear': '24',
      'isDefault': true,
      'holderName': 'Jean Dupont',
    },
    {
      'id': 2,
      'type': 'card',
      'brand': 'mastercard',
      'last4': '5555',
      'expiryMonth': '09',
      'expiryYear': '25',
      'isDefault': false,
      'holderName': 'Jean Dupont',
    },
    {
      'id': 3,
      'type': 'cash',
      'isDefault': false,
      'icon': Icons.money,
    },
  ];

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
        _t('payment_methods_title'),
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
        // Bandeau info
        Container(
          margin: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
          padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.deepPurple,
                  size: isDesktop ? 24 : isTablet ? 22 : 20),
              SizedBox(width: isMobile ? 12 : 16),
              Expanded(
                child: Text(
                  _t('payment_manage_info'),
                  style: TextStyle(
                    color: Colors.deepPurple[800],
                    fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Liste
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : isTablet ? 20 : 24),
            itemCount: _paymentMethods.length,
            itemBuilder: (context, index) {
              return _buildPaymentMethodCard(
                  _paymentMethods[index], index, isDesktop, isTablet, isMobile);
            },
          ),
        ),

        // Section sécurité
        Container(
          margin: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
          padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
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
              Row(
                children: [
                  Icon(Icons.security, color: Colors.green,
                      size: isDesktop ? 24 : isTablet ? 22 : 20),
                  SizedBox(width: isMobile ? 8 : 12),
                  Text(
                    _t('payment_security_title'),
                    style: TextStyle(
                      fontSize: isDesktop ? 18 : isTablet ? 17 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 12 : 16),
              Text(
                _t('payment_security_desc'),
                style: TextStyle(fontSize: isDesktop ? 15 : isTablet ? 14 : 13,
                    color: Colors.grey[600], height: 1.5),
              ),
              SizedBox(height: isMobile ? 12 : 16),
              Row(
                children: [
                  Icon(Icons.verified_user, color: Colors.green,
                      size: isDesktop ? 20 : isTablet ? 18 : 16),
                  SizedBox(width: isMobile ? 8 : 12),
                  Text(
                    _t('payment_pci_certified'),
                    style: TextStyle(
                      fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: isMobile ? 100 : isTablet ? 120 : 140),
      ],
    );
  }

  Widget _buildPaymentMethodCard(
      Map<String, dynamic> method, int index, bool isDesktop, bool isTablet, bool isMobile) {
    final isCard    = method['type'] == 'card';
    final isDefault = method['isDefault'] as bool;

    // Nom et description pour le type "cash" : traduits dynamiquement
    final String cashName = _t('payment_cash_option_title');
    final String cashDesc = _t('payment_cash_description');

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : isTablet ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDefault
            ? Border.all(color: Colors.deepPurple, width: 2)
            : Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                if (isCard)
                  _buildCardIcon(method['brand'] as String, isDesktop, isTablet, isMobile)
                else
                  Container(
                    padding: EdgeInsets.all(isMobile ? 8 : isTablet ? 10 : 12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(method['icon'] as IconData, color: Colors.green,
                        size: isDesktop ? 24 : isTablet ? 22 : 20),
                  ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCard ? '${method['holderName']}' : cashName,
                        style: TextStyle(fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
                            fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      if (isDefault)
                        Container(
                          margin: EdgeInsets.only(top: isMobile ? 4 : 6),
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 8 : isTablet ? 10 : 12,
                            vertical:   isMobile ? 2 : 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _t('by_default'),
                            style: TextStyle(color: Colors.white,
                                fontSize: isDesktop ? 12 : isTablet ? 11 : 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),

                // Menu contextuel
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                  onSelected: (value) {
                    if (value == 'edit')       _editPaymentMethod(method);
                    if (value == 'delete')     _deletePaymentMethod(method, index);
                    if (value == 'setDefault') _setDefaultPaymentMethod(method, index);
                  },
                  itemBuilder: (context) => [
                    if (!isDefault)
                      PopupMenuItem(
                        value: 'setDefault',
                        child: Row(children: [
                          const Icon(Icons.star_border, size: 18),
                          const SizedBox(width: 8),
                          Text(_t('payment_set_default')),
                        ]),
                      ),
                    if (isCard)
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          const Icon(Icons.edit, size: 18),
                          const SizedBox(width: 8),
                          Text(_t('edit')),
                        ]),
                      ),
                    if (!isCard && index > 0)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          const Icon(Icons.delete, size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(_t('delete'), style: const TextStyle(color: Colors.red)),
                        ]),
                      ),
                  ],
                ),
              ],
            ),

            SizedBox(height: isMobile ? 12 : 16),

            // Détails
            if (isCard)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•••• •••• •••• ${method['last4']}',
                    style: TextStyle(
                      fontSize: isDesktop ? 18 : isTablet ? 17 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      letterSpacing: 1.0,
                    ),
                  ),
                  SizedBox(height: isMobile ? 4 : 6),
                  Text(
                    '${_t('payment_expires')} ${method['expiryMonth']}/${method['expiryYear']}',
                    style: TextStyle(fontSize: isDesktop ? 14 : isTablet ? 13 : 12, color: Colors.grey[600]),
                  ),
                ],
              )
            else
              Text(
                cashDesc,
                style: TextStyle(fontSize: isDesktop ? 15 : isTablet ? 14 : 13, color: Colors.grey[600]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardIcon(String brand, bool isDesktop, bool isTablet, bool isMobile) {
    Color color;
    switch (brand.toLowerCase()) {
      case 'visa':       color = Colors.blue; break;
      case 'mastercard': color = Colors.red;  break;
      case 'amex':       color = Colors.blue; break;
      default:           color = Colors.grey;
    }
    return Container(
      padding: EdgeInsets.all(isMobile ? 8 : isTablet ? 10 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.credit_card, color: color, size: isDesktop ? 24 : isTablet ? 22 : 20),
    );
  }

  Widget _buildFloatingActionButton(bool isDesktop, bool isTablet, bool isMobile) {
    return FloatingActionButton.extended(
      onPressed: _showAddPaymentMethod,
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: Icon(Icons.add, size: isDesktop ? 24 : isTablet ? 22 : 20),
      label: Text(
        _t('payment_add_fab'),
        style: TextStyle(fontSize: isDesktop ? 16 : isTablet ? 15 : 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showAddPaymentMethod() {
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
                _t('payment_add_sheet_title'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 20),
              _buildAddOption(
                _t('payment_card_option_title'),
                _t('payment_card_option_subtitle'),
                Icons.credit_card, Colors.blue,
                    () { Navigator.pop(context); _showAddCardDialog(); },
              ),
              _buildAddOption(
                _t('payment_paypal_option_title'),
                _t('payment_paypal_option_subtitle'),
                Icons.account_balance_wallet, Colors.indigo,
                    () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(_t('payment_coming_soon')),
                    backgroundColor: Colors.indigo,
                    behavior: SnackBarBehavior.floating,
                  ));
                },
              ),
              _buildAddOption(
                _t('payment_applepay_option_title'),
                _t('payment_applepay_option_subtitle'),
                Icons.phone_iphone, Colors.black87,
                    () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(_t('payment_coming_soon')),
                    backgroundColor: Colors.black87,
                    behavior: SnackBarBehavior.floating,
                  ));
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddOption(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
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

  void _showAddCardDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddCardPage()),
    );
  }

  void _editPaymentMethod(Map<String, dynamic> method) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_t('payment_edit_coming_soon')),
      backgroundColor: Colors.orange,
    ));
  }

  void _deletePaymentMethod(Map<String, dynamic> method, int index) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppLocalizations.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Text(_t('payment_delete_title')),
          content: Text(_t('payment_delete_confirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _paymentMethods.removeAt(index));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_t('payment_deleted_success')),
                  backgroundColor: Colors.green,
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white,
              ),
              child: Text(_t('delete')),
            ),
          ],
        ),
      ),
    );
  }

  void _setDefaultPaymentMethod(Map<String, dynamic> method, int index) {
    setState(() {
      for (int i = 0; i < _paymentMethods.length; i++) {
        _paymentMethods[i]['isDefault'] = i == index;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_t('payment_set_default_success')),
      backgroundColor: Colors.green,
    ));
  }
}
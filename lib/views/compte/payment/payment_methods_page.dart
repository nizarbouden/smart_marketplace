import 'package:flutter/material.dart';

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
      'name': 'Paiement à la livraison',
      'description': 'Payer en espèces ou par carte lors de la livraison',
      'isDefault': false,
      'icon': Icons.money,
    },
  ];

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
        'Moyens de paiement',
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
        // Header info
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
              Icon(
                Icons.info_outline,
                color: Colors.deepPurple,
                size: isDesktop ? 24 : isTablet ? 22 : 20,
              ),
              SizedBox(width: isMobile ? 12 : 16),
              Expanded(
                child: Text(
                  'Gérez vos cartes et préférences de paiement',
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

        // Liste des moyens de paiement
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : isTablet ? 20 : 24),
            itemCount: _paymentMethods.length,
            itemBuilder: (context, index) {
              final method = _paymentMethods[index];
              return _buildPaymentMethodCard(method, index, isDesktop, isTablet, isMobile);
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
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.security,
                    color: Colors.green,
                    size: isDesktop ? 24 : isTablet ? 22 : 20,
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  Text(
                    'Sécurité des paiements',
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
                'Toutes vos transactions sont sécurisées avec le cryptage SSL. Vos informations bancaires ne sont jamais stockées sur nos serveurs.',
                style: TextStyle(
                  fontSize: isDesktop ? 15 : isTablet ? 14 : 13,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              SizedBox(height: isMobile ? 12 : 16),
              Row(
                children: [
                  Icon(
                    Icons.verified_user,
                    color: Colors.green,
                    size: isDesktop ? 20 : isTablet ? 18 : 16,
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  Text(
                    'Certifié PCI DSS',
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
    Map<String, dynamic> method,
    int index,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final isCard = method['type'] == 'card';
    final isDefault = method['isDefault'] as bool;

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : isTablet ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDefault 
          ? Border.all(color: Colors.deepPurple, width: 2)
          : Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec badge par défaut
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
                    child: Icon(
                      method['icon'] as IconData,
                      color: Colors.green,
                      size: isDesktop ? 24 : isTablet ? 22 : 20,
                    ),
                  ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCard 
                          ? '${method['holderName']}'
                          : method['name'] as String,
                        style: TextStyle(
                          fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (isDefault)
                        Container(
                          margin: EdgeInsets.only(top: isMobile ? 4 : 6),
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 8 : isTablet ? 10 : 12,
                            vertical: isMobile ? 2 : 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Par défaut',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isDesktop ? 12 : isTablet ? 11 : 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.grey[600],
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editPaymentMethod(method);
                    } else if (value == 'delete') {
                      _deletePaymentMethod(method, index);
                    } else if (value == 'setDefault') {
                      _setDefaultPaymentMethod(method, index);
                    }
                  },
                  itemBuilder: (context) => [
                    if (!isDefault)
                      const PopupMenuItem(
                        value: 'setDefault',
                        child: Row(
                          children: [
                            Icon(Icons.star_border, size: 18),
                            SizedBox(width: 8),
                            Text('Définir par défaut'),
                          ],
                        ),
                      ),
                    if (isCard)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Modifier'),
                          ],
                        ),
                      ),
                    if (!isCard && index > 0)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Supprimer', style: TextStyle(color: Colors.red)),
                          ],
                        ),
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
                  Row(
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
                    ],
                  ),
                  SizedBox(height: isMobile ? 4 : 6),
                  Text(
                    'Expire ${method['expiryMonth']}/${method['expiryYear']}',
                    style: TextStyle(
                      fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              )
            else
              Text(
                method['description'] as String,
                style: TextStyle(
                  fontSize: isDesktop ? 15 : isTablet ? 14 : 13,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardIcon(String brand, bool isDesktop, bool isTablet, bool isMobile) {
    IconData icon;
    Color color;

    switch (brand.toLowerCase()) {
      case 'visa':
        icon = Icons.credit_card;
        color = Colors.blue;
        break;
      case 'mastercard':
        icon = Icons.credit_card;
        color = Colors.red;
        break;
      case 'amex':
        icon = Icons.credit_card;
        color = Colors.blue;
        break;
      default:
        icon = Icons.credit_card;
        color = Colors.grey;
    }

    return Container(
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
    );
  }

  Widget _buildFloatingActionButton(bool isDesktop, bool isTablet, bool isMobile) {
    return FloatingActionButton.extended(
      onPressed: _showAddPaymentMethod,
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: Icon(
        Icons.add,
        size: isDesktop ? 24 : isTablet ? 22 : 20,
      ),
      label: Text(
        'Ajouter',
        style: TextStyle(
          fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showAddPaymentMethod() {
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
              'Ajouter un moyen de paiement',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            _buildAddOption(
              'Carte bancaire',
              'Ajouter une nouvelle carte Visa, Mastercard...',
              Icons.credit_card,
              Colors.blue,
              () {
                Navigator.pop(context);
                _showAddCardDialog();
              },
            ),
            _buildAddOption(
              'Paiement à la livraison',
              'Activer le paiement lors de la livraison',
              Icons.money,
              Colors.green,
              () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Paiement à la livraison activé!'),
                    backgroundColor: Colors.green,
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

  Widget _buildAddOption(
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

  void _showAddCardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter une carte bancaire'),
        content: const Text('Formulaire d\'ajout de carte à implémenter avec Stripe ou autre service de paiement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ajout de carte à implémenter.'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _editPaymentMethod(Map<String, dynamic> method) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Modification du moyen de paiement à implémenter.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _deletePaymentMethod(Map<String, dynamic> method, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le moyen de paiement'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce moyen de paiement ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _paymentMethods.removeAt(index);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Moyen de paiement supprimé'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _setDefaultPaymentMethod(Map<String, dynamic> method, int index) {
    setState(() {
      for (int i = 0; i < _paymentMethods.length; i++) {
        _paymentMethods[i]['isDefault'] = i == index;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Moyen de paiement défini par défaut'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_marketplace/viewmodels/profile_viewmodel.dart';
import 'package:smart_marketplace/widgets/custom_text_field.dart';

class AddressPage extends StatefulWidget {
  const AddressPage({super.key});

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  // Liste des adresses (exemple)
  List<Map<String, dynamic>> addresses = [
    {
      'id': 1,
      'name': 'Nizar Bouden',
      'phone': '+216 93489229',
      'street': 'Rue Taher Sfar Dar Chaabennabeul',
      'city': 'Nabeul',
      'region': 'Dar chaaben',
      'country': 'Tunisia',
      'postalCode': '8011',
      'isDefault': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    return ChangeNotifierProvider(
      create: (context) => ProfileViewModel(),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _buildAppBar(context, isMobile, isTablet, isDesktop),
        body: _buildBody(context, isMobile, isTablet, isDesktop),
        bottomNavigationBar: _buildAddButton(context, isMobile, isTablet, isDesktop),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isMobile, bool isTablet, bool isDesktop) {
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
        'Adresse de livraison',
        style: TextStyle(
          color: Colors.black87,
          fontSize: isDesktop ? 24 : isTablet ? 22 : 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: false,
    );
  }

  Widget _buildBody(BuildContext context, bool isMobile, bool isTablet, bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 24 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicateur de sécurité
          _buildSecurityIndicator(isMobile, isTablet, isDesktop),
          SizedBox(height: isMobile ? 24 : isTablet ? 32 : 40),

          // Liste des adresses
          addresses.isEmpty
              ? _buildEmptyState(isMobile, isTablet, isDesktop)
              : _buildAddressesList(context, isMobile, isTablet, isDesktop),

          SizedBox(height: isMobile ? 80 : isTablet ? 100 : 120),
        ],
      ),
    );
  }

  Widget _buildSecurityIndicator(bool isMobile, bool isTablet, bool isDesktop) {
    return const SizedBox.shrink();
  }

  Widget _buildAddressesList(BuildContext context, bool isMobile, bool isTablet, bool isDesktop) {
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: addresses.length,
          itemBuilder: (context, index) {
            return _buildAddressCard(
              context,
              addresses[index],
              index,
              isMobile,
              isTablet,
              isDesktop,
            );
          },
        ),
      ],
    );
  }

  Widget _buildAddressCard(
      BuildContext context,
      Map<String, dynamic> address,
      int index,
      bool isMobile,
      bool isTablet,
      bool isDesktop,
      ) {
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 16 : isTablet ? 20 : 24),
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
          // Header avec nom et téléphone
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address['name'] as String,
                  style: TextStyle(
                    fontSize: isDesktop ? 18 : isTablet ? 17 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: isMobile ? 4 : 8),
                Text(
                  address['phone'] as String,
                  style: TextStyle(
                    fontSize: isDesktop ? 15 : isTablet ? 14 : 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Adresse
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : isTablet ? 20 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address['street'] as String,
                  style: TextStyle(
                    fontSize: isDesktop ? 15 : isTablet ? 14 : 13,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: isMobile ? 4 : 8),
                Text(
                  '${address['city']}, ${address['region']}, ${address['country']}, ${address['postalCode']}',
                  style: TextStyle(
                    fontSize: isDesktop ? 15 : isTablet ? 14 : 13,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: isMobile ? 16 : isTablet ? 20 : 24),

          // Footer avec checkbox et icônes
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
            child: Row(
              children: [
                // Checkbox Par défaut
                GestureDetector(
                  onTap: () {
                    setState(() {
                      // Déselectionner tous les autres
                      for (int i = 0; i < addresses.length; i++) {
                        addresses[i]['isDefault'] = i == index;
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: isMobile ? 24 : 28,
                    height: isMobile ? 24 : 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: address['isDefault'] == true ? Colors.black : Colors.transparent,
                      border: Border.all(
                        color: address['isDefault'] == true ? Colors.black : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: address['isDefault'] == true
                        ? Icon(
                      Icons.check,
                      color: Colors.white,
                      size: isMobile ? 14 : 16,
                    )
                        : null,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Text(
                  'Par défaut',
                  style: TextStyle(
                    fontSize: isDesktop ? 15 : isTablet ? 14 : 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // Icônes à droite
                Row(
                  children: [
                    // Icône supprimer avec animation
                    GestureDetector(
                      onTap: () => _showDeleteConfirmation(context, index, isMobile, isTablet, isDesktop),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        transform: Matrix4.identity()..scale(1.0),
                        child: Icon(
                          Icons.delete_outline,
                          color: Colors.grey[400],
                          size: isDesktop ? 24 : isTablet ? 22 : 20,
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    // Icône éditer avec animation
                    GestureDetector(
                      onTap: () => Navigator.of(context).pushNamed('/edit-address', arguments: index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        transform: Matrix4.identity()..scale(1.0),
                        child: Icon(
                          Icons.edit_outlined,
                          color: Colors.grey[400],
                          size: isDesktop ? 24 : isTablet ? 22 : 20,
                        ),
                      ),
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

  Widget _buildEmptyState(bool isMobile, bool isTablet, bool isDesktop) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off_outlined,
            size: isMobile ? 60 : isTablet ? 80 : 100,
            color: Colors.grey[300],
          ),
          SizedBox(height: isMobile ? 16 : isTablet ? 24 : 32),
          Text(
            'Aucune adresse',
            style: TextStyle(
              fontSize: isDesktop ? 20 : isTablet ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Text(
            'Ajoutez votre première adresse de livraison',
            style: TextStyle(
              fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, bool isMobile, bool isTablet, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 24 : 32),
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        height: isMobile ? 52 : isTablet ? 56 : 60,
        child: AnimatedButton(
          onPressed: () => Navigator.of(context).pushNamed('/add-address'),
          text: 'Ajouter une nouvelle adresse',
          fontSize: isDesktop ? 18 : isTablet ? 16 : 15,
        ),
      ),
    );
  }





  void _showDeleteConfirmation(BuildContext context, int index, bool isMobile, bool isTablet, bool isDesktop) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext context) {
        return Dialog(
            insetPadding: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 20,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFEF4444),
                    const Color(0xFFF87171),
                    const Color(0xFFFCA5A5),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header avec icône
                  Container(
                    padding: const EdgeInsets.all(28),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.delete_sweep,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),

                  // Contenu blanc
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Supprimer l\'adresse',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Êtes-vous sûr de vouloir\nsupprimer cette adresse?',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),

                        // Boutons modernes
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFFEF4444),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    backgroundColor: Colors.transparent,
                                  ),
                                  child: const Text(
                                    'Annuler',
                                    style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      addresses.removeAt(index);
                                    });
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Adresse supprimée'),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444),
                                    foregroundColor: Colors.white,
                                    shadowColor: const Color(0xFFEF4444).withOpacity(0.3),
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Supprimer',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        );
      },
    );
  }
}

// Widget bouton animé réutilisable
class AnimatedButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;
  final double fontSize;

  const AnimatedButton({
    required this.onPressed,
    required this.text,
    required this.fontSize,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onPressed();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 2,
          ),
          child: Text(
            widget.text,
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
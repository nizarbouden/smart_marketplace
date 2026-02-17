import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_marketplace/viewmodels/profile_viewmodel.dart';
import 'package:smart_marketplace/services/firebase_auth_service.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';
import 'add_address_page.dart';
import 'edit_address_page.dart';

class AddressPage extends StatefulWidget {
  const AddressPage({super.key});

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  List<Map<String, dynamic>> addresses = [];
  bool isLoading = true;
  String? _previousDefaultAddressId;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final FirebaseAuthService _authService = FirebaseAuthService();

  // Helper traduction
  String _t(String key) => AppLocalizations.get(key);

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() { isLoading = true; });

    try {
      List<Map<String, dynamic>> userAddresses = await _authService.getUserAddresses();

      String? currentDefaultId;
      for (var address in userAddresses) {
        if (address['isDefault'] == true) {
          currentDefaultId = address['id'];
          break;
        }
      }

      setState(() {
        addresses = userAddresses;
        _previousDefaultAddressId = currentDefaultId;
        isLoading = false;
      });
    } catch (e) {
      setState(() { isLoading = false; });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_t('address_load_error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _setDefaultAddress(String addressId) async {
    try {
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;
      final isTablet = screenWidth >= 600 && screenWidth < 1200;
      final isDesktop = screenWidth >= 1200;

      int currentIndex = -1;
      Map<String, dynamic>? targetAddress;

      for (int i = 0; i < addresses.length; i++) {
        if (addresses[i]['id'] == addressId) {
          currentIndex = i;
          targetAddress = addresses[i];
          break;
        }
      }

      if (targetAddress == null || currentIndex == -1) return;

      await _authService.setDefaultAddress(
        FirebaseAuthService().currentUser?.uid ?? '',
        addressId,
      );

      if (_listKey.currentState != null && currentIndex > 0) {
        _listKey.currentState!.removeItem(
          currentIndex,
              (context, animation) => _buildAnimatedAddressCard(
            context,
            targetAddress!,
            currentIndex,
            animation,
            false,
            isMobile,
            isTablet,
            isDesktop,
          ),
          duration: const Duration(milliseconds: 300),
        );
        await Future.delayed(const Duration(milliseconds: 300));
      }

      await FirebaseAuthService().createNotification(
        userId: FirebaseAuthService().currentUser?.uid ?? '',
        title: _t('address_default_title'),
        body: _t('address_default_updated'),
        type: 'address',
      );

      await _loadAddresses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_t('error')}: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _deleteAddress(String addressId) async {
    try {
      await _authService.deleteAddress(
        FirebaseAuthService().currentUser?.uid ?? '',
        addressId,
      );
      await _loadAddresses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_t('error')}: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;
    final isRtl = AppLocalizations.isRtl;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: ChangeNotifierProvider(
        create: (context) => ProfileViewModel(),
        child: Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: _buildAppBar(context, isMobile, isTablet, isDesktop),
          body: _buildBody(context, isMobile, isTablet, isDesktop),
          bottomNavigationBar: _buildAddButton(context, isMobile, isTablet, isDesktop),
        ),
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
          AppLocalizations.isRtl ? Icons.arrow_forward : Icons.arrow_back,
          color: Colors.black87,
          size: isDesktop ? 28 : isTablet ? 24 : 20,
        ),
      ),
      title: Text(
        _t('delivery_address_title'),
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
          SizedBox(height: isMobile ? 8 : isTablet ? 12 : 16),

          isLoading
              ? _buildLoadingState(isMobile, isTablet, isDesktop)
              : addresses.isEmpty
              ? _buildEmptyState(isMobile, isTablet, isDesktop)
              : _buildAddressesList(context, isMobile, isTablet, isDesktop),

          SizedBox(height: isMobile ? 80 : isTablet ? 100 : 120),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isMobile, bool isTablet, bool isDesktop) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              _t('loading_addresses'),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressesList(BuildContext context, bool isMobile, bool isTablet, bool isDesktop) {
    return Column(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: AnimatedList(
            key: _listKey,
            initialItemCount: addresses.length,
            shrinkWrap: true,
            physics: const AlwaysScrollableScrollPhysics(),
            itemBuilder: (context, index, animation) {
              return _buildAnimatedAddressCard(
                context,
                addresses[index],
                index,
                animation,
                false,
                isMobile,
                isTablet,
                isDesktop,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedAddressCard(
      BuildContext context,
      Map<String, dynamic> address,
      int index,
      Animation<double> animation,
      bool isRemoving,
      bool isMobile,
      bool isTablet,
      bool isDesktop,
      ) {
    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(isRemoving ? 0.0 : -1.0, 0.0),
            end: Offset(isRemoving ? 1.0 : 0.0, 0.0),
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          )),
          child: _buildAddressCard(context, address, index, isMobile, isTablet, isDesktop),
        ),
      ),
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
    final isDefault = address['isDefault'] == true;
    final isNewDefault = isDefault && address['id'] != _previousDefaultAddressId;

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 16 : isTablet ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDefault
            ? Border.all(color: Colors.deepPurple, width: 2)
            : Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: isDefault
                ? Colors.deepPurple.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: isDefault ? 15 : 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge "Par défaut"
          if (isDefault)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : isTablet ? 20 : 24,
                vertical: isMobile ? 8 : isTablet ? 10 : 12,
              ),
              decoration: BoxDecoration(
                color: isNewDefault
                    ? Colors.deepPurple.withOpacity(0.2)
                    : Colors.deepPurple.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.star, color: Colors.deepPurple, size: isMobile ? 16 : isTablet ? 18 : 20),
                  const SizedBox(width: 8),
                  Text(
                    _t('default_address'),
                    style: TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 12 : isTablet ? 13 : 14,
                    ),
                  ),
                  const Spacer(),
                  if (isNewDefault)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.bounceOut,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _t('new_badge'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Nom & téléphone
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address['contactName'] as String,
                  style: TextStyle(
                    fontSize: isDesktop ? 18 : isTablet ? 17 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: isMobile ? 4 : 8),
                Text(
                  '${address['countryCode']} ${address['phone'] as String}',
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
                if (address['complement'] != null && address['complement'].toString().isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: isMobile ? 4 : 8),
                    child: Text(
                      address['complement'] as String,
                      style: TextStyle(
                        fontSize: isDesktop ? 15 : isTablet ? 14 : 13,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ),
                SizedBox(height: isMobile ? 4 : 8),
                Text(
                  '${address['city']}, ${address['province']}, ${address['countryName']}, ${address['postalCode']}',
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

          // Footer: checkbox + actions
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
            child: Row(
              children: [
                // Checkbox par défaut
                GestureDetector(
                  onTap: () async {
                    if (!isDefault) {
                      await _setDefaultAddress(address['id'] as String);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: isMobile ? 24 : 28,
                    height: isMobile ? 24 : 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDefault ? Colors.deepPurple : Colors.transparent,
                      border: Border.all(
                        color: isDefault ? Colors.deepPurple : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: isDefault
                        ? Icon(Icons.check, color: Colors.white, size: isMobile ? 14 : 16)
                        : null,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Text(
                  _t('set_as_default'),
                  style: TextStyle(
                    fontSize: isDesktop ? 15 : isTablet ? 14 : 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // Actions
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showDeleteConfirmation(context, index, isMobile, isTablet, isDesktop),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.delete_outline,
                          color: Colors.red[400],
                          size: isDesktop ? 24 : isTablet ? 22 : 20,
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => EditAddressPage(addressData: addresses[index]),
                          ),
                        ).then((_) => _loadAddresses());
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.edit_outlined,
                          color: Colors.deepPurple,
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
            _t('no_addresses'),
            style: TextStyle(
              fontSize: isDesktop ? 20 : isTablet ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Text(
            _t('add_first_address'),
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
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddAddressPage()),
            ).then((_) => _loadAddresses());
          },
          text: _t('add_new_address'),
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
        return Directionality(
          textDirection: AppLocalizations.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Dialog(
            insetPadding: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 20,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFEF4444),
                    Color(0xFFF87171),
                    Color(0xFFFCA5A5),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icône header
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
                      child: const Icon(Icons.delete_sweep, color: Colors.white, size: 32),
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
                        Text(
                          _t('delete_address'),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _t('confirm_delete_address'),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),

                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: Text(
                                    _t('cancel'),
                                    style: const TextStyle(
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
                                    Navigator.pop(context);
                                    _deleteAddress(addresses[index]['id'] as String);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444),
                                    foregroundColor: Colors.white,
                                    shadowColor: const Color(0xFFEF4444).withOpacity(0.3),
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: Text(
                                    _t('delete'),
                                    style: const TextStyle(
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
    super.key,
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

  void _onTapDown(TapDownDetails details) => _controller.forward();
  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onPressed();
  }
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: ElevatedButton(
          onPressed: widget.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
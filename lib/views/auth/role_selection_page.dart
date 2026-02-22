import 'package:flutter/material.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';
import 'package:smart_marketplace/models/user_model.dart';

class RoleSelectionPage extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String? countryCode;
  final String? genre;
  final String? photoUrl;
  final bool isGoogleUser;
  final bool isEmailVerified;

  const RoleSelectionPage({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    this.countryCode,
    this.genre,
    this.photoUrl,
    this.isGoogleUser = false,
    this.isEmailVerified = false,
  });

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  UserRole _selectedRole = UserRole.buyer;

  String _t(String key) => AppLocalizations.get(key);

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final isTablet = MediaQuery.of(context).size.width >= 768 &&
        MediaQuery.of(context).size.width < 1024;

    return Directionality(
      textDirection:
      AppLocalizations.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              AppLocalizations.isRtl
                  ? Icons.arrow_forward_ios
                  : Icons.arrow_back_ios,
              color: Colors.black87,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            _t('role_page_title'),
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                isDesktop ? 600 : (isTablet ? 500 : double.infinity),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : (isTablet ? 24 : 20),
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center, // ✅ centré
                  children: [
                    const SizedBox(height: 20),

                    // ── Header centré ──
                    _buildHeader(isDesktop),
                    const SizedBox(height: 24),

                    // Subtitle
                    Text(
                      _t('role_page_subtitle'),
                      style: TextStyle(
                        fontSize: isDesktop ? 18 : 15,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // ── Role Options (buyer + seller uniquement) ──
                    Expanded(
                      child: ListView(
                        children: [
                          _buildRoleOption(
                            role: UserRole.buyer,
                            icon: Icons.shopping_cart_outlined,
                            color: Colors.blue,
                            titleKey: 'role_buyer_title',
                            descKey: 'role_buyer_desc',
                            isDesktop: isDesktop,
                          ),
                          const SizedBox(height: 16),
                          _buildRoleOption(
                            role: UserRole.seller,
                            icon: Icons.store_outlined,
                            color: Colors.green,
                            titleKey: 'role_seller_title',
                            descKey: 'role_seller_desc',
                            isDesktop: isDesktop,
                          ),
                          // ✅ Option "both" supprimée
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    _buildBottomSection(isDesktop),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header centré ────────────────────────────────────────────
  Widget _buildHeader(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: isDesktop ? 90 : 80,
          height: isDesktop ? 90 : 80,
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person_add_outlined,
            size: isDesktop ? 44 : 38,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${_t('role_welcome')}, ${widget.firstName}',
          style: TextStyle(
            fontSize: isDesktop ? 26 : 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          widget.email,
          style: TextStyle(
            fontSize: isDesktop ? 15 : 14,
            color: Colors.grey[500],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── Carte de rôle ─────────────────────────────────────────────
  Widget _buildRoleOption({
    required UserRole role,
    required IconData icon,
    required Color color,
    required String titleKey,
    required String descKey,
    required bool isDesktop,
  }) {
    final isSelected = _selectedRole == role;

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(isDesktop ? 24 : 20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icône
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isDesktop ? 60 : 50,
              height: isDesktop ? 60 : 50,
              decoration: BoxDecoration(
                color: isSelected ? color : color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: isDesktop ? 30 : 24,
                color: isSelected ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 20),

            // Texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t(titleKey),
                    style: TextStyle(
                      fontSize: isDesktop ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t(descKey),
                    style: TextStyle(
                      fontSize: isDesktop ? 14 : 13,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            // Indicateur de sélection
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isDesktop ? 28 : 24,
              height: isDesktop ? 28 : 24,
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Bas de page ───────────────────────────────────────────────
  Widget _buildBottomSection(bool isDesktop) {
    return Column(
      children: [
        Text(
          _t('user_role_change_later'),
          style: TextStyle(
            fontSize: isDesktop ? 16 : 15,
            color: Colors.grey[500],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: isDesktop ? 56 : 50,
          child: ElevatedButton(
            onPressed: _onContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _t('role_continue'),
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  AppLocalizations.isRtl
                      ? Icons.arrow_back
                      : Icons.arrow_forward,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _onContinue() {
    final userModel = UserModel(
      uid: '',
      email: widget.email,
      nom: widget.lastName,
      prenom: widget.firstName,
      genre: widget.genre,
      phoneNumber: widget.phoneNumber,
      countryCode: widget.countryCode,
      photoUrl: widget.photoUrl,
      createdAt: DateTime.now(),
      isActive: true,
      isGoogleUser: widget.isGoogleUser,
      isEmailVerified: widget.isEmailVerified,
      role: _selectedRole,
      points: 0,
    );

    Navigator.of(context).pop(userModel);
  }
}
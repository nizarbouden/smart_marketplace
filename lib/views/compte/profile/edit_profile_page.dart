import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_marketplace/viewmodels/profile_viewmodel.dart';
import 'package:smart_marketplace/widgets/phone_field_widget.dart';
import 'package:smart_marketplace/widgets/gender_field_widget.dart';
import 'package:smart_marketplace/models/user_model.dart';
import 'package:smart_marketplace/services/firebase_auth_service.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';

class EditProfilePage extends StatefulWidget {
  final UserModel? user;
  const EditProfilePage({super.key, this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final ProfileViewModel viewModel;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // ✅ Store name controller (seller only)
  final TextEditingController _storeNameCtrl = TextEditingController();

  // Base64 image state
  String? _base64Image;
  String? _existingBase64;
  bool _isSavingImage = false;

  // ✅ Role detection
  late bool _isSeller;
  Color get _iconColor => _isSeller ? const Color(0xFF16A34A) : Colors.deepPurple;

  String _t(String key) => AppLocalizations.get(key);

  // ✅ Couleur thème selon le rôle
  Color get _themeColor =>
      _isSeller ? const Color(0xFF16A34A) : Colors.deepPurple;

  Color get _themeLightColor =>
      _isSeller ? const Color(0xFFDCFCE7) : Colors.deepPurple.shade50;

  Color get _themeAccentColor =>
      _isSeller ? const Color(0xFF15803D) : Colors.deepPurple.shade700;

  @override
  void initState() {
    super.initState();

    // ✅ Détection du rôle
    _isSeller = widget.user?.role == UserRole.seller;

    // ✅ Pré-remplissage du store name
    _storeNameCtrl.text = widget.user?.storeName ?? '';

    final String authEmail = FirebaseAuthService().getCurrentEmail() ?? '';
    final String userEmail = widget.user?.email ?? authEmail;

    viewModel = ProfileViewModel(
      firstName:   widget.user?.prenom      ?? '',
      lastName:    widget.user?.nom         ?? '',
      email:       userEmail,
      phone:       widget.user?.phoneNumber ?? '',
      countryCode: widget.user?.countryCode ?? '+216',
      genre:       widget.user?.genre,
      photoUrl:    widget.user?.photoUrl,
    );

    _loadExistingBase64();

    if (authEmail.isNotEmpty && authEmail != widget.user?.email) {
      _syncEmail();
    }
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingBase64() async {
    try {
      final uid = FirebaseAuthService().currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        final base64 = doc.data()?['photoBase64'] as String?;
        if (mounted) setState(() => _existingBase64 = base64);
      }
    } catch (_) {}
  }

  Future<void> _syncEmail() async {
    try {
      await FirebaseAuthService().syncEmailFromAuth();
    } catch (_) {}
  }

  // ── Image picking ────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source:       source,
        imageQuality: 50,
        maxWidth:     600,
      );
      if (picked == null) return;

      final bytes     = await File(picked.path).readAsBytes();
      final base64Str = base64Encode(bytes);

      final sizeKb = bytes.lengthInBytes / 1024;
      if (sizeKb > 900) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_t('edit_profile_image_too_large')),
            backgroundColor: Colors.orange,
          ));
        }
        return;
      }

      setState(() => _base64Image = base64Str);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('edit_profile_image_error')),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: _themeColor),
                title: Text(_t('edit_profile_gallery')),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: _themeColor),
                title: Text(_t('edit_profile_camera')),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_base64Image != null || _existingBase64 != null)
                ListTile(
                  leading: const Icon(Icons.delete_rounded, color: Colors.red),
                  title: Text(_t('edit_profile_remove_photo'),
                      style: const TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _base64Image    = null;
                      _existingBase64 = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: viewModel,
      child: Directionality(
        textDirection:
        AppLocalizations.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: _buildAppBar(context),
          body: _buildBody(context),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isTablet  = MediaQuery.of(context).size.width >= 600;
    final isDesktop = MediaQuery.of(context).size.width >= 1200;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(
          AppLocalizations.isRtl ? Icons.arrow_forward : Icons.arrow_back,
          color: Colors.black87,
        ),
      ),
      title: Text(
        _t('edit_profile_title'),
        style: TextStyle(
          color: Colors.black87,
          fontSize: isDesktop ? 24 : isTablet ? 22 : 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildBody(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop   = screenWidth >= 1200;
    final isTablet    = screenWidth >= 600 && screenWidth < 1200;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : isTablet ? 24 : 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Badge rôle au-dessus de l'avatar



            _buildAvatarPicker(isDesktop, isTablet),
            const SizedBox(height: 16),
            _buildRoleBadge(),
            SizedBox(height: isDesktop ? 45 : isTablet ? 37 : 31),

            _buildFormFields(context, isDesktop, isTablet),

            SizedBox(height: isDesktop ? 40 : isTablet ? 32 : 24),

            _buildSaveButton(context, isDesktop, isTablet),
          ],
        ),
      ),
    );
  }

  // ✅ Badge rôle (Vendeur / Acheteur)
  Widget _buildRoleBadge() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: _themeLightColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _themeColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isSeller ? Icons.storefront_rounded : Icons.shopping_bag_rounded,
              color: _themeColor,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              _isSeller
                  ? _t('seller_role_label')
                  : _t('buyer_role_label'),
              style: TextStyle(
                color: _themeColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Avatar picker ────────────────────────────────────────────

  Widget _buildAvatarPicker(bool isDesktop, bool isTablet) {
    final double radius = isDesktop ? 70 : isTablet ? 55 : 45;

    Widget avatarChild;
    if (_base64Image != null) {
      avatarChild = ClipOval(
        child: Image.memory(
          base64Decode(_base64Image!),
          width: radius * 2, height: radius * 2,
          fit: BoxFit.cover,
        ),
      );
    } else if (_existingBase64 != null) {
      avatarChild = ClipOval(
        child: Image.memory(
          base64Decode(_existingBase64!),
          width: radius * 2, height: radius * 2,
          fit: BoxFit.cover,
        ),
      );
    } else if (viewModel.profileImageUrl != null) {
      avatarChild = ClipOval(
        child: Image.network(
          viewModel.profileImageUrl!,
          width: radius * 2, height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.person, size: radius, color: _themeColor,
          ),
        ),
      );
    } else {
      avatarChild = Icon(Icons.person, size: radius, color: _themeColor);
    }

    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: _themeLightColor,
            child: avatarChild,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _showImageSourceSheet,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _themeColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: isDesktop ? 22 : 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Form fields ──────────────────────────────────────────────

  Widget _buildFormFields(BuildContext context, bool isDesktop, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ✅ Section store name — sellers uniquement
        if (_isSeller) ...[
          _buildSectionHeader(
            _t('seller_store_section'),
            isDesktop, isTablet,
          ),
          SizedBox(height: isDesktop ? 12 : 8),
          _buildStoreNameField(isDesktop, isTablet),
          SizedBox(height: isDesktop ? 32 : 24),
        ],

        // ── Informations personnelles ─────────────────────────
        _buildSectionHeader(
          _t('edit_profile_section_personal'),
          isDesktop, isTablet,
        ),
        SizedBox(height: isDesktop ? 12 : 8),

        Row(
          children: [
            Expanded(
              child: _buildThemedField(
                controller: viewModel.firstNameController,
                label:      _t('edit_profile_first_name'),
                icon:       Icons.person,
                isDesktop:  isDesktop,
                isTablet:   isTablet,
                validator: (v) => (v == null || v.isEmpty)
                    ? _t('edit_profile_first_name_required') : null,
              ),
            ),
            SizedBox(width: isDesktop ? 20 : isTablet ? 16 : 12),
            Expanded(
              child: _buildThemedField(
                controller: viewModel.lastNameController,
                label:      _t('edit_profile_last_name'),
                icon:       Icons.person_outline,
                isDesktop:  isDesktop,
                isTablet:   isTablet,
                validator: (v) => (v == null || v.isEmpty)
                    ? _t('edit_profile_last_name_required') : null,
              ),
            ),
          ],
        ),

        SizedBox(height: isDesktop ? 24 : isTablet ? 20 : 16),

        Consumer<ProfileViewModel>(
          builder: (context, vm, _) => GenderFieldWidget(
            selectedGender:   vm.selectedGender,
            genders:          vm.genders,
            onGenderSelected: vm.selectGender,
            isDesktop: isDesktop,
            isTablet:  isTablet,
            iconColor: _iconColor, // ✅ _iconColor est accessible ici car on est dans le State
          ),
        ),

        SizedBox(height: isDesktop ? 32 : isTablet ? 24 : 20),

        // ── Contact ───────────────────────────────────────────
        _buildSectionHeader(
          _t('edit_profile_section_contact'),
          isDesktop, isTablet,

        ),
        SizedBox(height: isDesktop ? 12 : 8),

        // Email (readonly)
        _buildThemedField(
          controller:   viewModel.emailController,
          label:        _t('edit_profile_email'),
          icon:         Icons.email,
          isDesktop:    isDesktop,
          isTablet:     isTablet,
          keyboardType: TextInputType.emailAddress,
          enabled:      false,
          readOnly:     true,
        ),

        Container(
          margin:  const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _themeColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _themeColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: _themeColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t('edit_profile_email_readonly'),
                  style: TextStyle(color: _themeColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: isDesktop ? 24 : isTablet ? 20 : 16),

        PhoneFieldWidget(
          controller:          viewModel.phoneController,
          countries:           viewModel.filteredCountries,
          selectedCountryCode: viewModel.selectedCountryCode,
          selectedCountryName: viewModel.selectedCountryName,
          selectedCountryFlag: viewModel.selectedCountryFlag,
          onCountrySelected:   viewModel.selectCountry,
          onFilterChanged:     viewModel.filterCountries,
          validator: (v) => (v == null || v.isEmpty)
              ? _t('edit_profile_phone_required') : null,
          isDesktop: isDesktop,
          isTablet:  isTablet,
          iconColor: _iconColor,
        ),
      ],
    );
  }

  // ✅ Champ store name stylisé
  Widget _buildStoreNameField(bool isDesktop, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: _storeNameCtrl,
        style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
        decoration: InputDecoration(
          hintText: _t('seller_store_name_hint'),
          hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
          prefixIcon: Icon(Icons.storefront_rounded,
              color: _themeColor, size: 20),
          filled:    true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _themeColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
        validator: (v) {
          if (_isSeller && (v == null || v.trim().isEmpty)) {
            return _t('seller_store_name_required');
          }
          return null;
        },
      ),
    );
  }

  // ✅ Champ texte thémé (remplace CustomTextField pour appliquer la couleur)
  Widget _buildThemedField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDesktop,
    required bool isTablet,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool enabled  = true,
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
        boxShadow: enabled
            ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ]
            : [],
      ),
      child: TextFormField(
        controller:   controller,
        keyboardType: keyboardType,
        enabled:      enabled,
        readOnly:     readOnly,
        validator:    validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: TextStyle(
          fontSize: 14,
          color: enabled ? const Color(0xFF1E293B) : Colors.grey[500],
        ),
        decoration: InputDecoration(
          hintText:  label,
          hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
          prefixIcon: Icon(icon,
              color: enabled ? _themeColor : Colors.grey[400], size: 20),
          filled:    true,
          fillColor: enabled ? Colors.white : Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _themeColor, width: 1.5),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
          errorStyle: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ✅ Section header avec icône colorée selon le rôle
  Widget _buildSectionHeader(
      String title,
      bool isDesktop,
      bool isTablet, {
        IconData? icon,
      }) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _themeLightColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _themeColor, size: 16),
          ),
          const SizedBox(width: 10),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize:   isDesktop ? 18 : isTablet ? 17 : 16,
            fontWeight: FontWeight.bold,
            color:      Colors.black87,
          ),
        ),
      ],
    );
  }

  // ── Save button ──────────────────────────────────────────────

  Widget _buildSaveButton(BuildContext context, bool isDesktop, bool isTablet) {
    return SizedBox(
      width:  double.infinity,
      height: isDesktop ? 56 : isTablet ? 52 : 48,
      child: ElevatedButton.icon(
        onPressed: viewModel.isLoading || _isSavingImage
            ? null
            : () async {
          if (!(_formKey.currentState?.validate() ?? false)) return;

          setState(() => _isSavingImage = true);

          try {
            bool success = await viewModel.saveProfile(context);

            if (success) {
              final uid = FirebaseAuthService().currentUser?.uid ?? '';
              if (uid.isNotEmpty) {
                final updateData = <String, dynamic>{};

                if (_base64Image != null) {
                  updateData['photoBase64'] = _base64Image;
                } else if (_existingBase64 == null) {
                  updateData['photoBase64'] = FieldValue.delete();
                }

                // ✅ Sauvegarde du store name pour les sellers
                if (_isSeller) {
                  final store = _storeNameCtrl.text.trim();
                  updateData['storeName'] =
                  store.isNotEmpty ? store : FieldValue.delete();
                }

                if (updateData.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .update(updateData);
                }
              }

              try {
                await FirebaseAuthService().createNotification(
                  userId: uid,
                  title:  _t('edit_profile_notif_title'),
                  body:   _t('edit_profile_notif_body'),
                  type:   'profile',
                );
              } catch (_) {}

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_t('edit_profile_success')),
                  backgroundColor: _themeColor,
                ));
                Future.delayed(const Duration(seconds: 1), () {
                  if (mounted) Navigator.of(context).pop();
                });
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_t('edit_profile_error')),
                  backgroundColor: Colors.red,
                ));
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(_t('edit_profile_error')),
                backgroundColor: Colors.red,
              ));
            }
          } finally {
            if (mounted) setState(() => _isSavingImage = false);
          }
        },
        icon: (viewModel.isLoading || _isSavingImage)
            ? const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : const Icon(Icons.save),
        label: Text(
          (viewModel.isLoading || _isSavingImage)
              ? _t('edit_profile_saving')
              : _t('edit_profile_save_btn'),
          style: TextStyle(
            fontSize:   isDesktop ? 18 : isTablet ? 16 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _themeColor,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: _themeColor.withOpacity(0.4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
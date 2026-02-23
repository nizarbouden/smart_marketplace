import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_marketplace/viewmodels/profile_viewmodel.dart';
import 'package:smart_marketplace/widgets/custom_text_field.dart';
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

  // Base64 image state
  String? _base64Image;      // nouvelle image choisie (en mémoire)
  String? _existingBase64;   // image déjà enregistrée dans Firestore
  bool _isSavingImage = false;

  String _t(String key) => AppLocalizations.get(key);

  @override
  void initState() {
    super.initState();

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

    // Charger l'image Base64 déjà stockée dans Firestore
    _loadExistingBase64();

    if (authEmail.isNotEmpty && authEmail != widget.user?.email) {
      _syncEmail();
    }
  }

  /// Charge l'image Base64 existante depuis Firestore
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

  // ── Sélection & conversion image ────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source:       source,
        imageQuality: 50,   // compression qualité
        maxWidth:     600,  // max largeur en px
      );
      if (picked == null) return;

      final bytes       = await File(picked.path).readAsBytes();
      final base64Str   = base64Encode(bytes);

      // Vérification taille (Firestore max 1 MB par doc)
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
                leading: const Icon(Icons.photo_library_rounded,
                    color: Colors.deepPurple),
                title: Text(_t('edit_profile_gallery')),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: Colors.deepPurple),
                title: Text(_t('edit_profile_camera')),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_base64Image != null || _existingBase64 != null)
                ListTile(
                  leading: const Icon(Icons.delete_rounded,
                      color: Colors.red),
                  title: Text(_t('edit_profile_remove_photo'),
                      style: const TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _base64Image   = null;
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
            // ── Avatar avec sélection Base64 ──────────────────
            _buildAvatarPicker(isDesktop, isTablet),

            SizedBox(height: isDesktop ? 45 : isTablet ? 37 : 31),

            _buildFormFields(context, isDesktop, isTablet),

            SizedBox(height: isDesktop ? 40 : isTablet ? 32 : 24),

            _buildSaveButton(context, isDesktop, isTablet),
          ],
        ),
      ),
    );
  }

  // ── Avatar picker ────────────────────────────────────────────

  Widget _buildAvatarPicker(bool isDesktop, bool isTablet) {
    final double radius = isDesktop ? 70 : isTablet ? 55 : 45;

    // Priorité : nouvelle image > image existante Firestore > photoUrl réseau
    Widget avatarChild;
    if (_base64Image != null) {
      avatarChild = ClipOval(
        child: Image.memory(
          base64Decode(_base64Image!),
          width:  radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
        ),
      );
    } else if (_existingBase64 != null) {
      avatarChild = ClipOval(
        child: Image.memory(
          base64Decode(_existingBase64!),
          width:  radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
        ),
      );
    } else if (viewModel.profileImageUrl != null) {
      avatarChild = ClipOval(
        child: Image.network(
          viewModel.profileImageUrl!,
          width:  radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.person,
            size: radius,
            color: Colors.deepPurple,
          ),
        ),
      );
    } else {
      avatarChild = Icon(
        Icons.person,
        size: radius,
        color: Colors.deepPurple,
      );
    }

    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: Colors.deepPurple[100],
            child: avatarChild,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _showImageSourceSheet,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.deepPurple,
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

  // ── Form fields (inchangés) ──────────────────────────────────

  Widget _buildFormFields(BuildContext context, bool isDesktop, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(_t('edit_profile_section_personal'), isDesktop, isTablet),
        SizedBox(height: isDesktop ? 12 : 8),

        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: viewModel.firstNameController,
                label:      _t('edit_profile_first_name'),
                validator:  (v) => (v == null || v.isEmpty)
                    ? _t('edit_profile_first_name_required') : null,
                isDesktop: isDesktop,
                isTablet:  isTablet,
                prefixIcon: Icons.person,
              ),
            ),
            SizedBox(width: isDesktop ? 20 : isTablet ? 16 : 12),
            Expanded(
              child: CustomTextField(
                controller: viewModel.lastNameController,
                label:      _t('edit_profile_last_name'),
                validator:  (v) => (v == null || v.isEmpty)
                    ? _t('edit_profile_last_name_required') : null,
                isDesktop: isDesktop,
                isTablet:  isTablet,
                prefixIcon: Icons.person_outline,
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
          ),
        ),

        SizedBox(height: isDesktop ? 32 : isTablet ? 24 : 20),

        _buildSectionHeader(_t('edit_profile_section_contact'), isDesktop, isTablet),
        SizedBox(height: isDesktop ? 12 : 8),

        CustomTextField(
          controller:   viewModel.emailController,
          label:        _t('edit_profile_email'),
          isDesktop:    isDesktop,
          isTablet:     isTablet,
          prefixIcon:   Icons.email,
          keyboardType: TextInputType.emailAddress,
          enabled:  false,
          readOnly: true,
        ),

        Container(
          margin:  const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t('edit_profile_email_readonly'),
                  style: const TextStyle(color: Colors.blue, fontSize: 12),
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
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isDesktop, bool isTablet) {
    return Text(
      title,
      style: TextStyle(
        fontSize:   isDesktop ? 18 : isTablet ? 17 : 16,
        fontWeight: FontWeight.bold,
        color:      Colors.black87,
      ),
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
            // 1. Sauvegarder le profil (via ViewModel existant)
            bool success = await viewModel.saveProfile(context);

            if (success) {
              // 2. Sauvegarder l'image Base64 dans Firestore
              final uid = FirebaseAuthService().currentUser?.uid ?? '';
              if (uid.isNotEmpty) {
                final updateData = <String, dynamic>{};

                if (_base64Image != null) {
                  // Nouvelle image sélectionnée
                  updateData['photoBase64'] = _base64Image;
                } else if (_existingBase64 == null) {
                  // Image supprimée par l'utilisateur
                  updateData['photoBase64'] = FieldValue.delete();
                }
                // Si _existingBase64 != null et pas de nouvelle image → rien à changer

                if (updateData.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .update(updateData);
                }
              }

              // 3. Notification
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
                  backgroundColor: Colors.green,
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
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
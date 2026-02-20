import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smart_marketplace/viewmodels/profile_viewmodel.dart';
import 'package:smart_marketplace/widgets/custom_text_field.dart';
import 'package:smart_marketplace/widgets/phone_field_widget.dart';
import 'package:smart_marketplace/widgets/gender_field_widget.dart';
import 'package:smart_marketplace/widgets/profile_image_widget.dart';
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

  String _t(String key) => AppLocalizations.get(key);

  @override
  void initState() {
    super.initState();

    final String authEmail  = FirebaseAuthService().getCurrentEmail() ?? '';
    final String userEmail  = widget.user?.email ?? authEmail;

    viewModel = ProfileViewModel(
      firstName: widget.user?.prenom      ?? '',
      lastName:  widget.user?.nom         ?? '',
      email:     userEmail,
      phone:     widget.user?.phoneNumber ?? '',
      countryCode: widget.user?.countryCode ?? '+216',
      genre:     widget.user?.genre,
      photoUrl:  widget.user?.photoUrl,
    );

    if (authEmail.isNotEmpty && authEmail != widget.user?.email) {
      _syncEmail();
    }
  }

  Future<void> _syncEmail() async {
    try {
      await FirebaseAuthService().syncEmailFromAuth();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: viewModel,
      child: Directionality(
        textDirection: AppLocalizations.isRtl ? TextDirection.rtl : TextDirection.ltr,
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
            // Photo de profil
            ProfileImageWidget(
              profileImage:    viewModel.profileImage,
              profileImageUrl: viewModel.profileImageUrl,
              onPickImage: viewModel.pickImageFromGallery,
              onTakePhoto: viewModel.takePhoto,
              isDesktop: isDesktop,
              isTablet:  isTablet,
            ),

            SizedBox(height: isDesktop ? 45 : isTablet ? 37 : 31),

            _buildFormFields(context, isDesktop, isTablet),

            SizedBox(height: isDesktop ? 40 : isTablet ? 32 : 24),

            _buildSaveButton(context, isDesktop, isTablet),
          ],
        ),
      ),
    );
  }

  Widget _buildFormFields(BuildContext context, bool isDesktop, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section Informations personnelles ──────────────────────
        _buildSectionHeader(_t('edit_profile_section_personal'), isDesktop, isTablet),
        SizedBox(height: isDesktop ? 12 : 8),

        // Prénom & Nom
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: viewModel.firstNameController,
                label:     _t('edit_profile_first_name'),
                validator: (v) => (v == null || v.isEmpty)
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
                label:     _t('edit_profile_last_name'),
                validator: (v) => (v == null || v.isEmpty)
                    ? _t('edit_profile_last_name_required') : null,
                isDesktop: isDesktop,
                isTablet:  isTablet,
                prefixIcon: Icons.person_outline,
              ),
            ),
          ],
        ),

        SizedBox(height: isDesktop ? 24 : isTablet ? 20 : 16),

        // Genre
        Consumer<ProfileViewModel>(
          builder: (context, vm, _) => GenderFieldWidget(
            selectedGender: vm.selectedGender,
            genders:        vm.genders,
            onGenderSelected: vm.selectGender,
            isDesktop: isDesktop,
            isTablet:  isTablet,
          ),
        ),

        SizedBox(height: isDesktop ? 32 : isTablet ? 24 : 20),

        // ── Section Contact ────────────────────────────────────────
        _buildSectionHeader(_t('edit_profile_section_contact'), isDesktop, isTablet),
        SizedBox(height: isDesktop ? 12 : 8),

        // Email (lecture seule)
        CustomTextField(
          controller: viewModel.emailController,
          label:      _t('edit_profile_email'),
          isDesktop:  isDesktop,
          isTablet:   isTablet,
          prefixIcon: Icons.email,
          keyboardType: TextInputType.emailAddress,
          enabled:  false,
          readOnly: true,
        ),

        // Bandeau info email non modifiable
        Container(
          margin: const EdgeInsets.only(top: 8),
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

        // Téléphone
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
        fontSize: isDesktop ? 18 : isTablet ? 17 : 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context, bool isDesktop, bool isTablet) {
    return SizedBox(
      width: double.infinity,
      height: isDesktop ? 56 : isTablet ? 52 : 48,
      child: ElevatedButton.icon(
        onPressed: viewModel.isLoading ? null : () async {
          if (_formKey.currentState?.validate() ?? false) {
            bool success = await viewModel.saveProfile(context);
            if (success) {
              try {
                await FirebaseAuthService().createNotification(
                  userId: FirebaseAuthService().currentUser?.uid ?? '',
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
          }
        },
        icon: viewModel.isLoading
            ? const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : const Icon(Icons.save),
        label: Text(
          viewModel.isLoading ? _t('edit_profile_saving') : _t('edit_profile_save_btn'),
          style: TextStyle(
            fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
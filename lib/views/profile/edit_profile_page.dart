import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smart_marketplace/viewmodels/profile_viewmodel.dart';
import 'package:smart_marketplace/widgets/custom_text_field.dart';
import 'package:smart_marketplace/widgets/phone_field_widget.dart';
import 'package:smart_marketplace/widgets/gender_field_widget.dart';
import 'package:smart_marketplace/widgets/profile_image_widget.dart';

class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ProfileViewModel(),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _buildAppBar(context),
        body: _buildBody(context),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
      ),
      title: Text(
        'Modifier le profil',
        style: TextStyle(
          color: Colors.black87,
          fontSize: MediaQuery.of(context).size.width > 600 ? 24 : 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildBody(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1200;
    final isTablet = MediaQuery.of(context).size.width > 600 && MediaQuery.of(context).size.width <= 1200;

    return Consumer<ProfileViewModel>(
      builder: (context, viewModel, child) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 32 : isTablet ? 24 : 16),
          child: Form(
            key: GlobalKey<FormState>(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo de profil
                ProfileImageWidget(
                  profileImage: viewModel.profileImage,
                  onPickImage: viewModel.pickImageFromGallery,
                  onTakePhoto: viewModel.takePhoto,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),
                
                SizedBox(height: isDesktop ? 45 : isTablet ? 37 : 31),
                
                // Champs du formulaire
                _buildFormFields(context, viewModel, isDesktop, isTablet),
                
                SizedBox(height: isDesktop ? 40 : isTablet ? 32 : 24),
                
                // Bouton de sauvegarde
                _buildSaveButton(context, viewModel, isDesktop, isTablet),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormFields(BuildContext context, ProfileViewModel viewModel, bool isDesktop, bool isTablet) {
    return Column(
      children: [
        // Nom et Prénom
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: viewModel.firstNameController,
                label: 'Prénom',
                validator: viewModel.validateFirstName,
                isDesktop: isDesktop,
                isTablet: isTablet,
                prefixIcon: Icons.person,
              ),
            ),
            SizedBox(width: isDesktop ? 20 : isTablet ? 16 : 12),
            Expanded(
              child: CustomTextField(
                controller: viewModel.lastNameController,
                label: 'Nom',
                validator: viewModel.validateLastName,
                isDesktop: isDesktop,
                isTablet: isTablet,
                prefixIcon: Icons.person_outline,
              ),
            ),
          ],
        ),
        
        SizedBox(height: isDesktop ? 24 : isTablet ? 20 : 16),
        
        // Email
        CustomTextField(
          controller: viewModel.emailController,
          label: 'Email',
          validator: viewModel.validateEmail,
          isDesktop: isDesktop,
          isTablet: isTablet,
          prefixIcon: Icons.email,
          keyboardType: TextInputType.emailAddress,
        ),
        
        SizedBox(height: isDesktop ? 24 : isTablet ? 20 : 16),
        
        // Téléphone
        PhoneFieldWidget(
          controller: viewModel.phoneController,
          countries: viewModel.filteredCountries,
          selectedCountryCode: viewModel.selectedCountryCode,
          selectedCountryName: viewModel.selectedCountryName,
          selectedCountryFlag: viewModel.selectedCountryFlag,
          onCountrySelected: viewModel.selectCountry,
          onFilterChanged: viewModel.filterCountries,
          validator: viewModel.validatePhone,
          isDesktop: isDesktop,
          isTablet: isTablet,
        ),
        
        SizedBox(height: isDesktop ? 24 : isTablet ? 20 : 16),
        
        // Genre
        GenderFieldWidget(
          selectedGender: viewModel.selectedGender,
          genders: viewModel.genders,
          onGenderSelected: viewModel.selectGender,
          isDesktop: isDesktop,
          isTablet: isTablet,
        ),
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context, ProfileViewModel viewModel, bool isDesktop, bool isTablet) {
    return SizedBox(
      width: double.infinity,
      height: isDesktop ? 56 : isTablet ? 52 : 48,
      child: ElevatedButton.icon(
        onPressed: viewModel.isLoading ? null : () async {
          final success = await viewModel.saveProfile();
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Profil mis à jour avec succès!'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur lors de la mise à jour du profil'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        icon: viewModel.isLoading
            ? SizedBox(
                width: isDesktop ? 24 : isTablet ? 20 : 16,
                height: isDesktop ? 24 : isTablet ? 20 : 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(Icons.save),
        label: Text(
          viewModel.isLoading ? 'Enregistrement...' : 'Enregistrer les modifications',
          style: TextStyle(
            fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}

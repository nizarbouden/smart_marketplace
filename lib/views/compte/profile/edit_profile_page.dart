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

class EditProfilePage extends StatefulWidget {
  final UserModel? user;
  
  const EditProfilePage({super.key, this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final ProfileViewModel viewModel;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    
    viewModel = ProfileViewModel(
      firstName: widget.user?.prenom ?? '',
      lastName: widget.user?.nom ?? '',
      email: widget.user?.email ?? '',
      phone: widget.user?.phoneNumber ?? '',
      countryCode: widget.user?.countryCode ?? '+216',
      genre: widget.user?.genre,
      photoUrl: widget.user?.photoUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1200;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;

    return ChangeNotifierProvider.value(
      value: viewModel,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _buildAppBar(context),
        body: _buildBody(context, isDesktop, isTablet),
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

  Widget _buildBody(BuildContext context, bool isDesktop, bool isTablet) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : isTablet ? 24 : 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo de profil
            ProfileImageWidget(
              profileImage: viewModel.profileImage,
              profileImageUrl: viewModel.profileImageUrl,
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
            _buildSaveButton(context, isDesktop, isTablet),
          ],
        ),
      ),
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
          enabled: widget.user?.isGoogleUser != true, // Désactiver uniquement pour les comptes Google
          readOnly: widget.user?.isGoogleUser == true, // Lecture seule uniquement pour les comptes Google
        ),
        
        // Message d'information pour les comptes Google
        if (widget.user?.isGoogleUser == true)
          Container(
            margin: EdgeInsets.only(top: 8),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Email non modifiable (compte Google)',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ],
            ),
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
        Consumer<ProfileViewModel>(
          builder: (context, viewModel, child) {
            return GenderFieldWidget(
              selectedGender: viewModel.selectedGender,
              genders: viewModel.genders,
              onGenderSelected: viewModel.selectGender,
              isDesktop: isDesktop,
              isTablet: isTablet,
            );
          },
        ),
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context, bool isDesktop, bool isTablet) {
    return SizedBox(
      width: double.infinity,
      height: isDesktop ? 56 : isTablet ? 52 : 48,
      child: ElevatedButton.icon(
        onPressed: viewModel.isLoading ? null : () async {
          // Valider le formulaire avant de sauvegarder
          if (_formKey.currentState?.validate() ?? false) {
            await viewModel.saveProfile();
            
            // Créer la notification de mise à jour du profil
            await FirebaseAuthService().createNotification(
              userId: FirebaseAuthService().currentUser?.uid ?? '',
              title: 'Profil mis à jour',
              body: 'Vos informations ont été enregistrées avec succès',
              type: 'profile',
            );
            
            // Rafraîchir les données utilisateur
            await viewModel.refreshUserData(context);
            
            // Rediriger vers la page profil après 1 seconde
            Future.delayed(const Duration(seconds: 1), () {
              Navigator.of(context).pop(); // Retour à la page profil
            });
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

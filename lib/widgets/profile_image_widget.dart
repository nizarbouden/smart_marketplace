import 'dart:io';
import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';

class ProfileImageWidget extends StatelessWidget {
  final File? profileImage;
  final String? profileImageUrl;
  final VoidCallback onPickImage;
  final VoidCallback onTakePhoto;
  final bool isDesktop;
  final bool isTablet;

  const ProfileImageWidget({
    super.key,
    this.profileImage,
    this.profileImageUrl,
    required this.onPickImage,
    required this.onTakePhoto,
    required this.isDesktop,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    print('🔍 ProfileImageWidget: profileImage = $profileImage');
    print('🔍 ProfileImageWidget: profileImageUrl = $profileImageUrl');
    
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: isDesktop ? 80 : isTablet ? 70 : 60,
                backgroundColor: Colors.deepPurple[100],
                backgroundImage: _getImageProvider(),
                child: _shouldShowDefaultIcon()
                    ? Icon(
                        Icons.person,
                        size: isDesktop ? 80 : isTablet ? 70 : 60,
                        color: Colors.deepPurple,
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _showImagePickerBottomSheet(context),
                  child: Container(
                    width: isDesktop ? 40 : isTablet ? 36 : 32,
                    height: isDesktop ? 40 : isTablet ? 36 : 32,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.get('change_photo'),
            style: TextStyle(
              fontSize: isDesktop ? 16 : 14,
              color: Colors.deepPurple,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Méthode helper pour déterminer l'image à afficher
  ImageProvider? _getImageProvider() {
    // Priorité 1: Image locale (nouvelle photo sélectionnée)
    if (profileImage != null) {
      return FileImage(profileImage!) as ImageProvider;
    }
    // Priorité 2: URL de l'image (photo existante)
    if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
      return NetworkImage(profileImageUrl!);
    }
    // Pas d'image
    return null;
  }

  // Méthode helper pour déterminer si on affiche l'icône par défaut
  bool _shouldShowDefaultIcon() {
    return profileImage == null && 
           (profileImageUrl == null || profileImageUrl!.isEmpty);
  }

  void _showImagePickerBottomSheet(BuildContext context) {
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
            Text(
              AppLocalizations.get('choose_photo'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOption(
                  icon: Icons.camera_alt,
                  label: AppLocalizations.get('camera'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onTakePhoto();
                  },
                ),
                _buildOption(
                  icon: Icons.photo_library,
                  label: AppLocalizations.get('gallery'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onPickImage();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.deepPurple,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

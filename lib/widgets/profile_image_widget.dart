import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_marketplace/viewmodels/profile_viewmodel.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';

class ProfileImageWidget extends StatelessWidget {
  final File?   profileImage;
  final String? profileImageUrl;
  final Future<void> Function() onPickImage;
  final Future<void> Function() onTakePhoto;
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

  double get _avatarRadius =>
      isDesktop ? 64 : isTablet ? 56 : 48;

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileViewModel>(
      builder: (context, vm, _) {
        return Center(
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              // ── Avatar ──────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: _avatarRadius,
                  backgroundColor: Colors.deepPurple.withOpacity(0.1),
                  backgroundImage: _resolveImage(vm),
                  child: _resolveImage(vm) == null
                      ? Icon(Icons.person,
                      size: _avatarRadius,
                      color: Colors.deepPurple.withOpacity(0.5))
                      : null,
                ),
              ),

              // ── Overlay loader pendant l'upload ─────────────────
              if (vm.isUploadingPhoto)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.45),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                ),

              // ── Bouton caméra (edit) ─────────────────────────────
              if (!vm.isUploadingPhoto)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _showPhotoOptions(context, vm),
                    child: Container(
                      width: isDesktop ? 38 : 32,
                      height: isDesktop ? 38 : 32,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: isDesktop ? 20 : 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Résoudre la source de l'image ─────────────────────────────
  ImageProvider? _resolveImage(ProfileViewModel vm) {
    if (vm.profileImage != null) return FileImage(vm.profileImage!);
    if (vm.profileImageUrl != null && vm.profileImageUrl!.isNotEmpty) {
      return NetworkImage(vm.profileImageUrl!);
    }
    return null;
  }

  // ── Bottom sheet de choix ──────────────────────────────────────
  void _showPhotoOptions(BuildContext context, ProfileViewModel vm) {
    final hasPhoto =
        vm.profileImage != null || (vm.profileImageUrl?.isNotEmpty ?? false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Text(
              AppLocalizations.get('photo_change_title'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),

            // Galerie
            _buildOption(
              context,
              icon: Icons.photo_library_rounded,
              label: AppLocalizations.get('photo_from_gallery'),
              onTap: () {
                Navigator.pop(context);
                onPickImage();
              },
            ),

            const SizedBox(height: 12),

            // Caméra
            _buildOption(
              context,
              icon: Icons.camera_alt_rounded,
              label: AppLocalizations.get('photo_from_camera'),
              onTap: () {
                Navigator.pop(context);
                onTakePhoto();
              },
            ),

            // Supprimer (seulement si photo existante)
            if (hasPhoto) ...[
              const SizedBox(height: 12),
              _buildOption(
                context,
                icon: Icons.delete_outline_rounded,
                label: AppLocalizations.get('photo_remove'),
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  vm.removePhoto();
                },
              ),
            ],

            const SizedBox(height: 8),

            // Annuler
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.get('cancel'),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
        Color color = Colors.deepPurple,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color == Colors.red ? Colors.red : Colors.black87,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }
}
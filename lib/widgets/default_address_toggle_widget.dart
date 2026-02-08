import 'package:flutter/material.dart';

class DefaultAddressToggleWidget extends StatelessWidget {
  final bool isDefault;
  final Function(bool) onChanged;
  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;

  const DefaultAddressToggleWidget({
    super.key,
    required this.isDefault,
    required this.onChanged,
    required this.isDesktop,
    required this.isTablet,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Définir comme adresse de livraison par défaut',
          style: TextStyle(
            fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Switch(
          value: isDefault,
          onChanged: onChanged,
          activeColor: Colors.deepPurple,
          inactiveThumbColor: Colors.grey[400],
          inactiveTrackColor: Colors.grey[300],
        ),
      ],
    );
  }
}

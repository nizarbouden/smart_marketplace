import 'package:flutter/material.dart';

class SaveAddressButtonWidget extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;

  const SaveAddressButtonWidget({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.isDesktop,
    required this.isTablet,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: isMobile ? 54 : isTablet ? 56 : 60,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          disabledBackgroundColor: Colors.deepPurple.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 2,
          shadowColor: Colors.deepPurple.withOpacity(0.3),
        ),
        child: isLoading
            ? SizedBox(
                width: isMobile ? 24 : 28,
                height: isMobile ? 24 : 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Enregistrer',
                style: TextStyle(
                  fontSize: isDesktop ? 18 : isTablet ? 16 : 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}

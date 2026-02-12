import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final bool isDesktop;
  final bool isTablet;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final int? maxLines;
  final bool? enabled;
  final bool? readOnly;
  final String? helperText;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    required this.isDesktop,
    required this.isTablet,
    this.prefixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.maxLines = 1,
    this.enabled,
    this.readOnly,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        obscureText: obscureText,
        maxLines: maxLines,
        enabled: enabled,
        readOnly: readOnly ?? false,
        style: TextStyle(
          fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.deepPurple) : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 20 : isTablet ? 16 : 12,
            vertical: isDesktop ? 16 : isTablet ? 14 : 12,
          ),
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: isDesktop ? 16 : isTablet ? 14 : 12,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.deepPurple, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red, width: 2),
          ),
        ),
      ),
    );
  }
}

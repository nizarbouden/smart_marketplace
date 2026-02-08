import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_marketplace/models/countries.dart';
import 'package:smart_marketplace/widgets/phone_field_widget.dart';

class AddressFormWidget extends StatefulWidget {
  // Controllers
  final TextEditingController contactNameController;
  final TextEditingController phoneController;
  final TextEditingController streetController;
  final TextEditingController complementController;
  final TextEditingController provinceController;
  final TextEditingController cityController;
  final TextEditingController postalCodeController;
  
  // Country data
  final String selectedCountryCode;
  final String selectedCountryName;
  final String selectedCountryFlag;
  final List<Map<String, String>> filteredCountries;
  
  // Callbacks
  final VoidCallback onCountryPickerTap;
  final Function(Map<String, String>) onCountrySelected;
  final Function(String) onFilterChanged;
  
  // Responsive
  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;

  const AddressFormWidget({
    super.key,
    required this.contactNameController,
    required this.phoneController,
    required this.streetController,
    required this.complementController,
    required this.provinceController,
    required this.cityController,
    required this.postalCodeController,
    required this.selectedCountryCode,
    required this.selectedCountryName,
    required this.selectedCountryFlag,
    required this.filteredCountries,
    required this.onCountryPickerTap,
    required this.onCountrySelected,
    required this.onFilterChanged,
    required this.isDesktop,
    required this.isTablet,
    required this.isMobile,
  });

  @override
  State<AddressFormWidget> createState() => _AddressFormWidgetState();
}

class _AddressFormWidgetState extends State<AddressFormWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pays/Région Section
        _buildCountrySection(),
        SizedBox(height: widget.isMobile ? 28 : widget.isTablet ? 36 : 44),

        // Informations personnelles Section
        _buildPersonalInfoSection(),
        SizedBox(height: widget.isMobile ? 28 : widget.isTablet ? 36 : 44),

        // Adresse Section
        _buildAddressSection(),
      ],
    );
  }

  Widget _buildCountrySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pays/Région',
          style: TextStyle(
            fontSize: widget.isDesktop ? 20 : widget.isTablet ? 18 : 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: widget.isMobile ? 16 : widget.isTablet ? 20 : 24),
        GestureDetector(
          onTap: widget.onCountryPickerTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isMobile ? 16 : widget.isTablet ? 20 : 24,
              vertical: widget.isMobile ? 14 : widget.isTablet ? 16 : 18,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Text(
                  widget.selectedCountryFlag,
                  style: const TextStyle(fontSize: 28),
                ),
                SizedBox(width: widget.isMobile ? 12 : 16),
                Text(
                  widget.selectedCountryName,
                  style: TextStyle(
                    fontSize: widget.isDesktop ? 16 : widget.isTablet ? 15 : 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                  size: widget.isDesktop ? 24 : widget.isTablet ? 22 : 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informations personnelles',
          style: TextStyle(
            fontSize: widget.isDesktop ? 20 : widget.isTablet ? 18 : 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: widget.isMobile ? 16 : widget.isTablet ? 20 : 24),

        // Nom du contact
        TextFormField(
          controller: widget.contactNameController,
          decoration: InputDecoration(
            hintText: 'Nom du contact*',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: widget.isDesktop ? 16 : widget.isTablet ? 15 : 14,
            ),
            prefixIcon: Icon(Icons.person, color: Colors.deepPurple),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: widget.isMobile ? 16 : widget.isTablet ? 20 : 24,
              vertical: widget.isMobile ? 14 : widget.isTablet ? 16 : 18,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez saisir un nom de contact';
            }
            return null;
          },
        ),
        SizedBox(height: 8),
        Text(
          'Veuillez saisir un nom de contact.',
          style: TextStyle(
            fontSize: widget.isDesktop ? 14 : widget.isTablet ? 13 : 12,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: widget.isMobile ? 16 : widget.isTablet ? 20 : 24),

        // Code pays + Téléphone
        Row(
          children: [
            SizedBox(
              width: widget.isMobile ? 100 : widget.isTablet ? 120 : 140,
              child: TextFormField(
                enabled: false,
                controller: TextEditingController(text: widget.selectedCountryCode),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: widget.isMobile ? 12 : widget.isTablet ? 16 : 20,
                    vertical: widget.isMobile ? 14 : widget.isTablet ? 16 : 18,
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                style: TextStyle(
                  fontSize: widget.isDesktop ? 16 : widget.isTablet ? 15 : 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(width: widget.isMobile ? 12 : 16),
            Expanded(
              child: TextFormField(
                controller: widget.phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: 'Numéro de portable*',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: widget.isDesktop ? 16 : widget.isTablet ? 15 : 14,
                  ),
                  prefixIcon: Icon(Icons.phone, color: Colors.deepPurple),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: widget.isMobile ? 16 : widget.isTablet ? 20 : 24,
                    vertical: widget.isMobile ? 14 : widget.isTablet ? 16 : 18,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Numéro requis';
                  }
                  if (value.length < 8) {
                    return 'Numéro invalide';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Adresse',
          style: TextStyle(
            fontSize: widget.isDesktop ? 20 : widget.isTablet ? 18 : 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: widget.isMobile ? 16 : widget.isTablet ? 20 : 24),

        // Rue et numéro
        TextFormField(
          controller: widget.streetController,
          decoration: InputDecoration(
            hintText: 'Rue et numéro de la rue*',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: widget.isDesktop ? 16 : widget.isTablet ? 15 : 14,
            ),
            prefixIcon: Icon(Icons.home, color: Colors.deepPurple),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: widget.isMobile ? 16 : widget.isTablet ? 20 : 24,
              vertical: widget.isMobile ? 14 : widget.isTablet ? 16 : 18,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'La rue est requise';
            }
            return null;
          },
        ),
        SizedBox(height: widget.isMobile ? 16 : widget.isTablet ? 20 : 24),

        // Complément
        TextFormField(
          controller: widget.complementController,
          decoration: InputDecoration(
            hintText: 'Appartement, suite, unité, etc. (facultatif)',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: widget.isDesktop ? 16 : widget.isTablet ? 15 : 14,
            ),
            prefixIcon: Icon(Icons.apartment, color: Colors.deepPurple),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: widget.isMobile ? 16 : widget.isTablet ? 20 : 24,
              vertical: widget.isMobile ? 14 : widget.isTablet ? 16 : 18,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        SizedBox(height: widget.isMobile ? 16 : widget.isTablet ? 20 : 24),

        // Province
        TextFormField(
          controller: widget.provinceController,
          decoration: InputDecoration(
            hintText: 'Province*',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: widget.isDesktop ? 16 : widget.isTablet ? 15 : 14,
            ),
            prefixIcon: Icon(Icons.map, color: Colors.deepPurple),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: widget.isMobile ? 16 : widget.isTablet ? 20 : 24,
              vertical: widget.isMobile ? 14 : widget.isTablet ? 16 : 18,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'La province est requise';
            }
            return null;
          },
        ),
        SizedBox(height: widget.isMobile ? 16 : widget.isTablet ? 20 : 24),

        // Ville
        TextFormField(
          controller: widget.cityController,
          decoration: InputDecoration(
            hintText: 'Ville*',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: widget.isDesktop ? 16 : widget.isTablet ? 15 : 14,
            ),
            prefixIcon: Icon(Icons.location_city, color: Colors.deepPurple),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: widget.isMobile ? 16 : widget.isTablet ? 20 : 24,
              vertical: widget.isMobile ? 14 : widget.isTablet ? 16 : 18,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'La ville est requise';
            }
            return null;
          },
        ),
        SizedBox(height: widget.isMobile ? 16 : widget.isTablet ? 20 : 24),

        // Code postal
        TextFormField(
          controller: widget.postalCodeController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: 'Code postal*',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: widget.isDesktop ? 16 : widget.isTablet ? 15 : 14,
            ),
            prefixIcon: Icon(Icons.mail, color: Colors.deepPurple),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: widget.isMobile ? 16 : widget.isTablet ? 20 : 24,
              vertical: widget.isMobile ? 14 : widget.isTablet ? 16 : 18,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Le code postal est requis';
            }
            return null;
          },
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_marketplace/models/countries.dart';
import 'package:smart_marketplace/widgets/phone_field_widget.dart';
import '../localization/app_localizations.dart';

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
  // ── Helpers ─────────────────────────────────────────────────────
  double get _fs => widget.isDesktop ? 16 : widget.isTablet ? 15 : 14;
  double get _titleFs => widget.isDesktop ? 20 : widget.isTablet ? 18 : 16;
  double get _helperFs => widget.isDesktop ? 14 : widget.isTablet ? 13 : 12;
  EdgeInsets get _fieldPadding => EdgeInsets.symmetric(
    horizontal: widget.isMobile ? 16 : widget.isTablet ? 20 : 24,
    vertical: widget.isMobile ? 14 : widget.isTablet ? 16 : 18,
  );
  double get _sectionGap => widget.isMobile ? 28 : widget.isTablet ? 36 : 44;
  double get _fieldGap => widget.isMobile ? 16 : widget.isTablet ? 20 : 24;

  InputDecoration _fieldDecoration(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey[400], fontSize: _fs),
    prefixIcon: Icon(icon, color: Colors.deepPurple),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.deepPurple, width: 2)),
    contentPadding: _fieldPadding,
    filled: true,
    fillColor: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCountrySection(),
        SizedBox(height: _sectionGap),
        _buildPersonalInfoSection(),
        SizedBox(height: _sectionGap),
        _buildAddressSection(),
      ],
    );
  }

  // ── Section Pays/Région ──────────────────────────────────────────
  Widget _buildCountrySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.get('addr_country_region'),
            style: TextStyle(fontSize: _titleFs, fontWeight: FontWeight.bold, color: Colors.black87)),
        SizedBox(height: _fieldGap),
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
                Text(widget.selectedCountryFlag, style: const TextStyle(fontSize: 28)),
                SizedBox(width: widget.isMobile ? 12 : 16),
                Text(widget.selectedCountryName,
                    style: TextStyle(fontSize: _fs, color: Colors.black87, fontWeight: FontWeight.w500)),
                const Spacer(),
                Icon(Icons.chevron_right,
                    color: Colors.grey[400], size: widget.isDesktop ? 24 : widget.isTablet ? 22 : 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Section Informations personnelles ────────────────────────────
  Widget _buildPersonalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.get('addr_personal_info_section'),
            style: TextStyle(fontSize: _titleFs, fontWeight: FontWeight.bold, color: Colors.black87)),
        SizedBox(height: _fieldGap),

        // Nom du contact
        TextFormField(
          controller: widget.contactNameController,
          decoration: _fieldDecoration(AppLocalizations.get('addr_contact_name_hint'), Icons.person),
          validator: (value) =>
          (value == null || value.isEmpty) ? AppLocalizations.get('addr_contact_name_error') : null,
        ),
        const SizedBox(height: 8),
        Text(AppLocalizations.get('addr_contact_name_helper'),
            style: TextStyle(fontSize: _helperFs, color: Colors.grey[600])),
        SizedBox(height: _fieldGap),

        // Code pays + Téléphone
        Row(
          children: [
            SizedBox(
              width: widget.isMobile ? 100 : widget.isTablet ? 120 : 140,
              child: TextFormField(
                enabled: false,
                controller: TextEditingController(text: widget.selectedCountryCode),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: widget.isMobile ? 12 : widget.isTablet ? 16 : 20,
                    vertical: widget.isMobile ? 14 : widget.isTablet ? 16 : 18,
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                style: TextStyle(fontSize: _fs, color: Colors.black87, fontWeight: FontWeight.w500),
              ),
            ),
            SizedBox(width: widget.isMobile ? 12 : 16),
            Expanded(
              child: TextFormField(
                controller: widget.phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _fieldDecoration(AppLocalizations.get('addr_phone_hint'), Icons.phone),
                validator: (value) {
                  if (value == null || value.isEmpty) return AppLocalizations.get('addr_phone_error_required');
                  if (value.length < 8) return AppLocalizations.get('addr_phone_error_invalid');
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Section Adresse ──────────────────────────────────────────────
  Widget _buildAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.get('addr_address_section'),
            style: TextStyle(fontSize: _titleFs, fontWeight: FontWeight.bold, color: Colors.black87)),
        SizedBox(height: _fieldGap),

        // Rue et numéro
        TextFormField(
          controller: widget.streetController,
          decoration: _fieldDecoration(AppLocalizations.get('addr_street_hint'), Icons.home),
          validator: (value) =>
          (value == null || value.isEmpty) ? AppLocalizations.get('addr_street_error') : null,
        ),
        SizedBox(height: _fieldGap),

        // Complément
        TextFormField(
          controller: widget.complementController,
          decoration: _fieldDecoration(AppLocalizations.get('addr_complement_hint'), Icons.apartment),
        ),
        SizedBox(height: _fieldGap),

        // Province
        TextFormField(
          controller: widget.provinceController,
          decoration: _fieldDecoration(AppLocalizations.get('addr_province_hint'), Icons.map),
          validator: (value) =>
          (value == null || value.isEmpty) ? AppLocalizations.get('addr_province_error') : null,
        ),
        SizedBox(height: _fieldGap),

        // Ville
        TextFormField(
          controller: widget.cityController,
          decoration: _fieldDecoration(AppLocalizations.get('addr_city_hint'), Icons.location_city),
          validator: (value) =>
          (value == null || value.isEmpty) ? AppLocalizations.get('addr_city_error') : null,
        ),
        SizedBox(height: _fieldGap),

        // Code postal
        TextFormField(
          controller: widget.postalCodeController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _fieldDecoration(AppLocalizations.get('addr_postal_hint'), Icons.mail),
          validator: (value) =>
          (value == null || value.isEmpty) ? AppLocalizations.get('addr_postal_error') : null,
        ),
      ],
    );
  }
}
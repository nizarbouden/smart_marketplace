import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../localization/app_localizations.dart';

class PhoneFieldWidget extends StatelessWidget {
  final TextEditingController controller;
  final List<Map<String, String>> countries;
  final String selectedCountryCode;
  final String selectedCountryName;
  final String selectedCountryFlag;
  final Function(Map<String, String>) onCountrySelected;
  final Function(String) onFilterChanged;
  final String? Function(String?)? validator;
  final bool isDesktop;
  final bool isTablet;

  const PhoneFieldWidget({
    super.key,
    required this.controller,
    required this.countries,
    required this.selectedCountryCode,
    required this.selectedCountryName,
    required this.selectedCountryFlag,
    required this.onCountrySelected,
    required this.onFilterChanged,
    this.validator,
    required this.isDesktop,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // ── Sélecteur de pays ──────────────────────────────────
          GestureDetector(
            onTap: () => _showCountryDialog(context),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 12 : isTablet ? 10 : 8,
                vertical: isDesktop ? 16 : isTablet ? 14 : 12,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                border: Border(right: BorderSide(color: Colors.grey[300]!, width: 1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(selectedCountryFlag),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedCountryName,
                          style: TextStyle(
                            fontSize: isDesktop ? 14 : isTablet ? 12 : 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedCountryCode,
                          style: TextStyle(
                            fontSize: isDesktop ? 12 : isTablet ? 10 : 8,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.keyboard_arrow_down,
                      color: Colors.grey[600], size: isDesktop ? 20 : isTablet ? 16 : 12),
                ],
              ),
            ),
          ),

          // ── Séparateur ─────────────────────────────────────────
          Container(
            width: 1,
            height: isDesktop ? 24 : isTablet ? 20 : 16,
            color: Colors.grey[300],
          ),

          // ── Champ de téléphone ─────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 12 : isTablet ? 10 : 8,
                vertical: isDesktop ? 16 : isTablet ? 14 : 12,
              ),
              child: TextFormField(
                controller: controller,
                validator: validator,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(fontSize: isDesktop ? 18 : isTablet ? 16 : 14, color: Colors.black87),
                decoration: InputDecoration(
                  labelText: AppLocalizations.get('phone_label'),
                  prefixIcon: const Icon(Icons.phone, color: Colors.deepPurple),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCountryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.get('phone_select_country'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: Colors.grey[600],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Barre de recherche
                TextField(
                  onChanged: onFilterChanged,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.get('phone_search_country'),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),

                const SizedBox(height: 20),

                // Liste des pays
                Expanded(
                  child: ListView.builder(
                    itemCount: countries.length,
                    itemBuilder: (context, index) {
                      final country = countries[index];
                      return ListTile(
                        leading: Text(country['flag']!, style: const TextStyle(fontSize: 24)),
                        title: Text(country['name']!),
                        subtitle: Text(country['code']!),
                        onTap: () {
                          onCountrySelected(country);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
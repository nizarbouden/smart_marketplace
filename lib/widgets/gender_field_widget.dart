import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';

class GenderFieldWidget extends StatelessWidget {
  final String? selectedGender;
  final List<String> genders;
  final Function(String) onGenderSelected;
  final bool isDesktop;
  final bool isTablet;

  const GenderFieldWidget({
    super.key,
    this.selectedGender,
    required this.genders,
    required this.onGenderSelected,
    required this.isDesktop,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final hasGender = selectedGender != null && selectedGender != '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: GestureDetector(
        onTap: () => _showGenderDialog(context),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 20 : isTablet ? 16 : 12,
            vertical: isDesktop ? 16 : isTablet ? 14 : 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(Icons.person, color: Colors.deepPurple, size: isDesktop ? 24 : isTablet ? 22 : 20),
              SizedBox(width: isDesktop ? 16 : isTablet ? 12 : 8),
              Expanded(
                child: Text(
                  hasGender ? selectedGender! : AppLocalizations.get('gender_select_placeholder'),
                  style: TextStyle(
                    fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                    color: hasGender ? Colors.black87 : Colors.grey[500],
                    fontWeight: hasGender ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_down, color: Colors.grey[600], size: isDesktop ? 24 : isTablet ? 20 : 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showGenderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.get('gender_dialog_title'),
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

                // Options
                ...genders.map((gender) {
                  final isSelected = selectedGender == gender;
                  return InkWell(
                    onTap: () {
                      onGenderSelected(gender);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.deepPurple : Colors.grey[400]!,
                                width: 2,
                              ),
                              color: isSelected ? Colors.deepPurple : Colors.transparent,
                            ),
                            child: isSelected
                                ? Center(
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                              ),
                            )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            gender,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.deepPurple : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
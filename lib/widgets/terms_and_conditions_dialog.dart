import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class TermsAndConditionsDialog extends StatelessWidget {
  const TermsAndConditionsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    
    return AlertDialog(
      title: Text(
        langProvider.translate('terms_conditions'),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF8700FF),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              langProvider.translate('terms_title'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              langProvider.translate('terms_description'),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            
            // Termes et conditions complets
            _buildSection(langProvider.translate('terms_section_1_title'), langProvider.translate('terms_section_1_content')),
            const SizedBox(height: 12),
            _buildSection(langProvider.translate('terms_section_2_title'), langProvider.translate('terms_section_2_content')),
            const SizedBox(height: 12),
            _buildSection(langProvider.translate('terms_section_3_title'), langProvider.translate('terms_section_3_content')),
            const SizedBox(height: 12),
            _buildSection(langProvider.translate('terms_section_4_title'), langProvider.translate('terms_section_4_content')),
            const SizedBox(height: 12),
            _buildSection(langProvider.translate('terms_section_5_title'), langProvider.translate('terms_section_5_content')),
            const SizedBox(height: 16),
            
            Text(
              langProvider.translate('terms_last_updated'),
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: Text(
            langProvider.translate('close'),
            style: const TextStyle(
              color: Color(0xFF8700FF),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8700FF),
            foregroundColor: Colors.white,
          ),
          child: Text(langProvider.translate('i_agree')),
        ),
      ],
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8700FF),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

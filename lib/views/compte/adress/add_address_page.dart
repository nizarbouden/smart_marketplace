import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_marketplace/models/countries.dart';
import 'package:smart_marketplace/widgets/address_form_widget.dart';
import 'package:smart_marketplace/widgets/default_address_toggle_widget.dart';
import 'package:smart_marketplace/widgets/save_address_button_widget.dart';
import 'package:smart_marketplace/services/firebase_auth_service.dart';

class AddAddressPage extends StatefulWidget {
  const AddAddressPage({super.key});

  @override
  State<AddAddressPage> createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  final _formKey = GlobalKey<FormState>();

  final _contactNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _complementController = TextEditingController();
  final _provinceController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();

  String _selectedCountryCode = '+216';
  String _selectedCountryName = 'Tunisia';
  String _selectedCountryFlag = '🇹🇳';
  bool _isDefault = false;
  bool _isLoading = false;

  List<Map<String, String>> _filteredCountries = CountryData.getCountriesSorted();

  @override
  void dispose() {
    _contactNameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _complementController.dispose();
    _provinceController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(context, isDesktop, isTablet, isMobile),
      body: _buildBody(context, isDesktop, isTablet, isMobile),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDesktop, bool isTablet, bool isMobile) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(
          Icons.arrow_back,
          color: Colors.black87,
          size: isDesktop ? 28 : isTablet ? 24 : 20,
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ajouter une nouvelle adresse',
            style: TextStyle(
              color: Colors.black87,
              fontSize: isDesktop ? 24 : isTablet ? 22 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              SizedBox(width: 6),
              Text(
                'Toutes vos informations sont cryptées',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      centerTitle: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Vos informations sont cryptées et sécurisées'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.help_outline,
                color: Colors.grey[600],
                size: isDesktop ? 24 : isTablet ? 22 : 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, bool isDesktop, bool isTablet, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 24 : 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Formulaire d'adresse complet
            AddressFormWidget(
              contactNameController: _contactNameController,
              phoneController: _phoneController,
              streetController: _streetController,
              complementController: _complementController,
              provinceController: _provinceController,
              cityController: _cityController,
              postalCodeController: _postalCodeController,
              selectedCountryCode: _selectedCountryCode,
              selectedCountryName: _selectedCountryName,
              selectedCountryFlag: _selectedCountryFlag,
              filteredCountries: _filteredCountries,
              onCountryPickerTap: _showCountryPicker,
              onCountrySelected: (country) {
                setState(() {
                  _selectedCountryCode = country['code']!;
                  _selectedCountryName = country['name']!;
                  _selectedCountryFlag = country['flag']!;
                });
              },
              onFilterChanged: (query) {
                setState(() {
                  if (query.isEmpty) {
                    _filteredCountries = CountryData.getCountriesSorted();
                  } else {
                    _filteredCountries = CountryData.filterCountries(query);
                  }
                });
              },
              isDesktop: isDesktop,
              isTablet: isTablet,
              isMobile: isMobile,
            ),
            SizedBox(height: isMobile ? 28 : isTablet ? 36 : 44),

            // Par défaut Toggle
            DefaultAddressToggleWidget(
              isDefault: _isDefault,
              onChanged: (value) {
                setState(() {
                  _isDefault = value;
                });
              },
              isDesktop: isDesktop,
              isTablet: isTablet,
              isMobile: isMobile,
            ),
            SizedBox(height: isMobile ? 32 : isTablet ? 40 : 48),

            // Bouton Enregistrer
            SaveAddressButtonWidget(
              isLoading: _isLoading,
              onPressed: _handleRegister,
              isDesktop: isDesktop,
              isTablet: isTablet,
              isMobile: isMobile,
            ),
            SizedBox(height: isMobile ? 24 : 32),
          ],
        ),
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
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
              Expanded(
                child: ListView.builder(
                  itemCount: CountryData.getCountriesSorted().length,
                  itemBuilder: (context, index) {
                    final country = CountryData.getCountriesSorted()[index];
                    return ListTile(
                      leading: Text(
                        country['flag']!,
                        style: const TextStyle(fontSize: 28),
                      ),
                      title: Text(
                        country['name']!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        country['code']!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedCountryCode = country['code']!;
                          _selectedCountryName = country['name']!;
                          _selectedCountryFlag = country['flag']!;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleRegister() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Sauvegarder l'adresse dans Firestore
        await FirebaseAuthService().addAddress(
          contactName: _contactNameController.text.trim(),
          phone: _phoneController.text.trim(),
          countryCode: _selectedCountryCode,
          countryName: _selectedCountryName,
          countryFlag: _selectedCountryFlag,
          street: _streetController.text.trim(),
          complement: _complementController.text.trim(),
          province: _provinceController.text.trim(),
          city: _cityController.text.trim(),
          postalCode: _postalCodeController.text.trim(),
          isDefault: _isDefault,
        );

        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Adresse enregistrée avec succès!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }
}

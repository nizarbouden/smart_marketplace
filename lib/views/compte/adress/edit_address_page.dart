import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_marketplace/models/countries.dart';
import 'package:smart_marketplace/widgets/address_form_widget.dart';
import 'package:smart_marketplace/widgets/default_address_toggle_widget.dart';
import 'package:smart_marketplace/widgets/save_address_button_widget.dart';
import 'package:smart_marketplace/services/firebase_auth_service.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';

class EditAddressPage extends StatefulWidget {
  final Map<String, dynamic> addressData;

  const EditAddressPage({
    super.key,
    required this.addressData,
  });

  @override
  State<EditAddressPage> createState() => _EditAddressPageState();
}

class _EditAddressPageState extends State<EditAddressPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _contactNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _streetController;
  late final TextEditingController _complementController;
  late final TextEditingController _provinceController;
  late final TextEditingController _cityController;
  late final TextEditingController _postalCodeController;

  late String _selectedCountryCode;
  late String _selectedCountryName;
  late String _selectedCountryFlag;
  late bool _isDefault;
  bool _isLoading = false;

  List<Map<String, String>> _filteredCountries = CountryData.getCountriesSorted();

  // Helper traduction
  String _t(String key) => AppLocalizations.get(key);

  @override
  void initState() {
    super.initState();
    _contactNameController = TextEditingController(text: widget.addressData['contactName'] ?? '');
    _phoneController = TextEditingController(text: widget.addressData['phone'] ?? '');
    _streetController = TextEditingController(text: widget.addressData['street'] ?? '');
    _complementController = TextEditingController(text: widget.addressData['complement'] ?? '');
    _provinceController = TextEditingController(text: widget.addressData['province'] ?? '');
    _cityController = TextEditingController(text: widget.addressData['city'] ?? '');
    _postalCodeController = TextEditingController(text: widget.addressData['postalCode'] ?? '');

    _selectedCountryCode = widget.addressData['countryCode'] ?? '+216';
    _selectedCountryName = widget.addressData['countryName'] ?? 'Tunisia';
    _selectedCountryFlag = widget.addressData['countryFlag'] ?? '🇹🇳';
    _isDefault = widget.addressData['isDefault'] ?? false;
  }

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
    final isRtl = AppLocalizations.isRtl;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _buildAppBar(context, isDesktop, isTablet, isMobile),
        body: _buildBody(context, isDesktop, isTablet, isMobile),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDesktop, bool isTablet, bool isMobile) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(
          AppLocalizations.isRtl ? Icons.arrow_forward : Icons.arrow_back,
          color: Colors.black87,
          size: isDesktop ? 28 : isTablet ? 24 : 20,
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('edit_address_title'),
            style: TextStyle(
              color: Colors.black87,
              fontSize: isDesktop ? 24 : isTablet ? 22 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.edit, color: Colors.deepPurple, size: 16),
              const SizedBox(width: 6),
              Text(
                _t('update_address_info'),
                style: TextStyle(
                  color: Colors.deepPurple,
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
                SnackBar(
                  content: Text(_t('info_encrypted_secure')),
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

            DefaultAddressToggleWidget(
              isDefault: _isDefault,
              onChanged: (value) {
                setState(() { _isDefault = value; });
              },
              isDesktop: isDesktop,
              isTablet: isTablet,
              isMobile: isMobile,
            ),
            SizedBox(height: isMobile ? 32 : isTablet ? 40 : 48),

            SaveAddressButtonWidget(
              isLoading: _isLoading,
              onPressed: _handleUpdate,
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
        return Directionality(
          textDirection: AppLocalizations.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Container(
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
                const SizedBox(height: 12),
                // Champ de recherche
                TextField(
                  decoration: InputDecoration(
                    hintText: _t('search_country'),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  ),
                  onChanged: (query) {
                    setState(() {
                      if (query.isEmpty) {
                        _filteredCountries = CountryData.getCountriesSorted();
                      } else {
                        _filteredCountries = CountryData.filterCountries(query);
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
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
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
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
          ),
        );
      },
    );
  }

  void _handleUpdate() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() { _isLoading = true; });

      try {
        await FirebaseAuthService().updateAddress(
          userId: FirebaseAuthService().currentUser?.uid ?? '',
          addressId: widget.addressData['id'] as String,
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

        setState(() { _isLoading = false; });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('address_updated')),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        setState(() { _isLoading = false; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_t('error')}: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }
}
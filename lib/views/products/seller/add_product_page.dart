import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';

import '../../../models/product_categories.dart';
import '../../../models/user_model.dart';
import '../../compte/profile/edit_profile_page.dart';

class AddProductPage extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? existing;

  const AddProductPage({super.key, this.docId, this.existing});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  String _t(String key) => AppLocalizations.get(key);
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  final _nameCtrl       = TextEditingController();
  final _priceCtrl      = TextEditingController();
  final _stockCtrl      = TextEditingController();
  final _descCtrl       = TextEditingController();
  final _rewardNameCtrl = TextEditingController();

  String? _selectedCategory;

  bool _hasReward = false;
  final List<String> _productImages = [];
  String? _rewardImageBase64;

  bool _isSaving  = false;
  bool _submitted = false;
  int  _currentImageIndex = 0;
  late PageController      _pageController;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  // ── Vérification du profil ────────────────────────────────────
  bool _isCheckingProfile = true;  // true pendant le chargement
  bool _profileComplete   = false; // true si profil complet
  Map<String, bool> _missingFields = {}; // champs manquants

  bool get _isEditing     => widget.docId != null;
  bool get _imageError    => _submitted && _productImages.isEmpty;
  bool get _rewardImgErr  => _submitted && _hasReward && _rewardImageBase64 == null;
  bool get _categoryError => _submitted && _selectedCategory == null;

  String get _langCode => AppLocalizations.getLanguage();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    // ✅ Vérifier le profil en premier
    _checkSellerProfile();
  }

  // ── ✅ Vérification du profil vendeur ─────────────────────────
  Future<void> _checkSellerProfile() async {
    setState(() => _isCheckingProfile = true);
    try {
      final uid = _currentUser?.uid;
      if (uid == null) {
        setState(() {
          _isCheckingProfile = false;
          _profileComplete   = false;
        });
        return;
      }

      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data() ?? {};

      final storeName = (data['storeName'] as String?)?.trim() ?? '';
      final firstName = (data['prenom']    as String?)?.trim() ?? '';
      final lastName  = (data['nom']       as String?)?.trim() ?? '';
      final phone     = (data['phoneNumber'] as String?)?.trim() ?? '';

      final missing = <String, bool>{
        'storeName': storeName.isEmpty,
        'firstName': firstName.isEmpty,
        'lastName':  lastName.isEmpty,
        'phone':     phone.isEmpty,
      };

      final complete = missing.values.every((v) => !v);

      setState(() {
        _missingFields     = missing;
        _profileComplete   = complete;
        _isCheckingProfile = false;
      });

      // Si profil complet et mode édition, charger les données
      if (complete && widget.existing != null) {
        _populateExisting();
      }
    } catch (e) {
      setState(() {
        _isCheckingProfile = false;
        _profileComplete   = false;
      });
    }
  }

  void _populateExisting() {
    final d = widget.existing!;
    _nameCtrl.text  = d['name']              as String? ?? '';
    _priceCtrl.text = d['price']?.toString() ?? '';
    _stockCtrl.text = d['stock']?.toString() ?? '';
    _descCtrl.text  = d['description']       as String? ?? '';
    _selectedCategory = d['category']        as String?;

    final imgs = (d['images'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();
    if (imgs != null) _productImages.addAll(imgs);

    final reward = d['reward'] as Map<String, dynamic>?;
    if (reward != null) {
      _hasReward           = true;
      _rewardNameCtrl.text = reward['name']  as String? ?? '';
      _rewardImageBase64   = reward['image'] as String?;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeCtrl.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _descCtrl.dispose();
    _rewardNameCtrl.dispose();
    super.dispose();
  }

  // ── Image picking ─────────────────────────────────────────────

  Future<void> _pickProductImages() async {
    if (_productImages.length >= 8) {
      _showSnack(_t('add_product_max_images'), color: Colors.orange);
      return;
    }
    final picked = await _picker.pickMultiImage(
        imageQuality: 55, maxWidth: 800);
    if (picked.isEmpty) return;

    setState(() => _isSaving = true);
    final newImages = <String>[];
    for (final xfile in picked) {
      final bytes = await File(xfile.path).readAsBytes();
      if (bytes.lengthInBytes / 1024 > 900) continue;
      newImages.add(base64Encode(bytes));
      if (_productImages.length + newImages.length >= 8) break;
    }
    setState(() {
      _productImages.addAll(newImages);
      _isSaving = false;
    });
    if (_productImages.isNotEmpty && _pageController.hasClients) {
      _pageController.animateToPage(
        _productImages.length - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickRewardImage() async {
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 55, maxWidth: 600);
    if (picked == null) return;
    final bytes = await File(picked.path).readAsBytes();
    if (bytes.lengthInBytes / 1024 > 900) {
      _showSnack(_t('add_product_image_too_large'), color: Colors.orange);
      return;
    }
    setState(() => _rewardImageBase64 = base64Encode(bytes));
  }

  void _removeImage(int index) {
    setState(() {
      _productImages.removeAt(index);
      if (_currentImageIndex >= _productImages.length) {
        _currentImageIndex =
        _productImages.isEmpty ? 0 : _productImages.length - 1;
      }
    });
  }

  // ── Save ──────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _submitted = true);

    final formValid   = _formKey.currentState?.validate() ?? false;
    final hasImage    = _productImages.isNotEmpty;
    final hasCategory = _selectedCategory != null;
    final rewardOk    = !_hasReward || _rewardImageBase64 != null;

    if (!formValid || !hasImage || !hasCategory || !rewardOk) {
      if (!hasImage) {
        _showSnack(_t('add_product_min_image'), color: Colors.red);
      } else if (!hasCategory) {
        _showSnack(_t('add_product_category_required'), color: Colors.red);
      } else if (!rewardOk) {
        _showSnack(_t('add_product_reward_image_required'), color: Colors.red);
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
      final uid = _currentUser?.uid;
      if (uid == null) return;

      final data = <String, dynamic>{
        'name':        _nameCtrl.text.trim(),
        'price':       double.parse(_priceCtrl.text.trim()),
        'stock':       int.parse(_stockCtrl.text.trim()),
        'description': _descCtrl.text.trim(),
        'images':      _productImages,
        'category':    _selectedCategory,
        'sellerId':    uid,
        'isActive':    false,
        'status':      'pending',
        'updatedAt':   Timestamp.now(),
      };

      if (_hasReward) {
        data['reward'] = {
          'name':  _rewardNameCtrl.text.trim(),
          'image': _rewardImageBase64,
        };
      } else {
        data['reward'] = FieldValue.delete();
      }

      if (_isEditing) {
        await _firestore.collection('products').doc(widget.docId!).update(data);
      } else {
        data['createdAt'] = Timestamp.now();
        await _firestore.collection('products').add(data);
      }

      if (mounted) {
        _showSnack(_t('add_product_pending'), color: const Color(0xFFF59E0B));
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context);
      }
    } catch (_) {
      _showSnack(_t('add_product_error'), color: Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {Color color = Colors.black87}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ── 1. Chargement en cours ────────────────────────────────
    if (_isCheckingProfile) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16A34A),
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
          ),
          title: Text(
            _isEditing ? _t('seller_edit_product') : _t('seller_add_product'),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
          ),
        ),
      );
    }

    // ── 2. Profil incomplet → page d'erreur ───────────────────
    if (!_profileComplete) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16A34A),
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
          ),
          title: Text(
            _isEditing ? _t('seller_edit_product') : _t('seller_add_product'),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: _buildIncompleteProfilePage(),
      );
    }

    // ── 3. Profil complet → formulaire normal ─────────────────
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + bottomPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImageSection(),
                      const SizedBox(height: 28),
                      _buildSectionLabel(_t('add_product_section_info')),
                      const SizedBox(height: 14),
                      _buildInfoFields(),
                      const SizedBox(height: 28),
                      _buildRewardSection(),
                      const SizedBox(height: 16),
                      _buildRequiredLegend(),
                      const SizedBox(height: 16),
                      _buildValidationNoticeBanner(),
                      const SizedBox(height: 16),
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── ✅ Page profil incomplet ───────────────────────────────────
  Widget _buildIncompleteProfilePage() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icône
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.person_off_rounded,
                  size: 50, color: Color(0xFFF59E0B)),
            ),
            const SizedBox(height: 28),

            // Titre
            Text(
              _t('add_product_profile_incomplete_title'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              _t('add_product_profile_incomplete_desc'),
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // ✅ Champs manquants
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFFDE68A), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFF59E0B), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _t('add_product_missing_fields'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ..._buildMissingFieldsList(),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ✅ Bouton → aller au profil
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final uid = _currentUser?.uid;
                  if (uid == null) return;

                  final doc = await _firestore.collection('users').doc(uid).get();
                  final data = doc.data() ?? {};
                  data['uid'] = doc.id;
                  final user = UserModel.fromMap(data);

                  if (mounted) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditProfilePage(user: user),
                      ),
                    );
                    // Recharger la vérification après retour
                    _checkSellerProfile();
                  }
                },
                icon: const Icon(Icons.edit_rounded, size: 20),
                label: Text(
                  _t('add_product_complete_profile_btn'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor:
                  const Color(0xFF16A34A).withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Bouton retour
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                label: Text(
                  _t('cancel'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF16A34A),
                  side: const BorderSide(
                      color: Color(0xFF16A34A), width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Liste des champs manquants avec icône ✗ / ✓
  List<Widget> _buildMissingFieldsList() {
    final fields = [
      {
        'key': 'storeName',
        'label': _t('seller_store_name_hint'),
        'icon': Icons.storefront_rounded,
      },
      {
        'key': 'firstName',
        'label': _t('edit_profile_first_name'),
        'icon': Icons.person_rounded,
      },
      {
        'key': 'lastName',
        'label': _t('edit_profile_last_name'),
        'icon': Icons.person_outline_rounded,
      },
      {
        'key': 'phone',
        'label': _t('edit_profile_phone_required'),
        'icon': Icons.phone_rounded,
      },
    ];

    return fields.map((f) {
      final isMissing = _missingFields[f['key']] ?? false;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(f['icon'] as IconData,
                size: 18,
                color: isMissing
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF16A34A)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                f['label'] as String,
                style: TextStyle(
                  fontSize: 13,
                  color: isMissing
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF16A34A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              isMissing ? Icons.close_rounded : Icons.check_circle_rounded,
              size: 18,
              color: isMissing
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF16A34A),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: const Color(0xFF16A34A),
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 20),
      ),
      title: Text(
        _isEditing ? _t('seller_edit_product') : _t('seller_add_product'),
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
      ),
      centerTitle: true,
    );
  }

  // ── Image section ─────────────────────────────────────────────

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4, height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(_t('add_product_section_images'),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B))),
            const SizedBox(width: 4),
            const Text('*',
                style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 14),

        Container(
          height: 260,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: _imageError
                ? Border.all(color: const Color(0xFFEF4444), width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: _productImages.isEmpty
              ? _buildImageEmptyPlaceholder()
              : Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _productImages.length,
                  onPageChanged: (i) =>
                      setState(() => _currentImageIndex = i),
                  itemBuilder: (context, index) => Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        base64Decode(_productImages[index]),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_rounded,
                                color: Colors.grey)),
                      ),
                      Positioned(
                        top: 10, right: 10,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10, left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${index + 1}/${_productImages.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_productImages.length > 1)
                Positioned(
                  bottom: 12, left: 0, right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _productImages.length,
                          (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width:  _currentImageIndex == i ? 20 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _currentImageIndex == i
                              ? const Color(0xFF16A34A)
                              : Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        if (_imageError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              _t('add_product_min_image'),
              style: const TextStyle(
                  color: Color(0xFFEF4444), fontSize: 12),
            ),
          ),

        const SizedBox(height: 12),

        GestureDetector(
          onTap: _pickProductImages,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF16A34A).withOpacity(0.35),
                  width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_photo_alternate_rounded,
                    color: Color(0xFF16A34A), size: 22),
                const SizedBox(width: 8),
                Text(_t('add_product_pick_images'),
                    style: const TextStyle(
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(width: 6),
                Text('(${_productImages.length}/8)',
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageEmptyPlaceholder() {
    return GestureDetector(
      onTap: _pickProductImages,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _imageError
                    ? const Color(0xFFEF4444).withOpacity(0.08)
                    : const Color(0xFF16A34A).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_photo_alternate_rounded,
                  color: _imageError
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF16A34A),
                  size: 30),
            ),
            const SizedBox(height: 12),
            Text(_t('add_product_tap_to_add'),
                style: TextStyle(
                    color: _imageError
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF16A34A),
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
            const SizedBox(height: 4),
            Text(_t('add_product_multiple_hint'),
                style: const TextStyle(
                    color: Color(0xFF94A3B8), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ── Form fields ───────────────────────────────────────────────

  Widget _buildInfoFields() {
    return Column(
      children: [
        _buildValidatedField(
          ctrl: _nameCtrl,
          label: _t('seller_product_name'),
          icon: Icons.label_rounded,
          required: true,
          validator: (v) {
            if (v == null || v.trim().isEmpty)
              return _t('add_product_name_required');
            return null;
          },
        ),
        const SizedBox(height: 14),

        _buildCategoryPicker(),
        const SizedBox(height: 14),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildValidatedField(
                ctrl: _priceCtrl,
                label: _t('seller_product_price'),
                icon: Icons.sell_rounded,
                required: true,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d*')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return _t('add_product_price_required');
                  final val = double.tryParse(v.trim());
                  if (val == null || val <= 0)
                    return _t('add_product_price_invalid');
                  return null;
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildValidatedField(
                ctrl: _stockCtrl,
                label: _t('seller_product_stock'),
                icon: Icons.layers_rounded,
                required: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return _t('add_product_stock_required');
                  final val = int.tryParse(v.trim());
                  if (val == null || val < 0)
                    return _t('add_product_stock_invalid');
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _buildValidatedField(
          ctrl: _descCtrl,
          label: _t('seller_product_description'),
          icon: Icons.notes_rounded,
          required: false,
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildCategoryPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _t('add_product_category'),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 2),
              const Text('*',
                  style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        GestureDetector(
          onTap: _showCategoryBottomSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _categoryError
                    ? const Color(0xFFEF4444)
                    : _selectedCategory != null
                    ? const Color(0xFF16A34A)
                    : Colors.transparent,
                width: _categoryError || _selectedCategory != null ? 1.5 : 0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  _selectedCategory != null
                      ? ProductCategories.iconFromId(_selectedCategory!)
                      : '📦',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedCategory != null
                        ? ProductCategories.labelFromId(
                        _selectedCategory!, _langCode)
                        : _t('add_product_category_hint'),
                    style: TextStyle(
                      fontSize: 14,
                      color: _selectedCategory != null
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _categoryError
                      ? const Color(0xFFEF4444)
                      : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
        if (_categoryError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              _t('add_product_category_required'),
              style: const TextStyle(
                  color: Color(0xFFEF4444), fontSize: 12),
            ),
          ),
      ],
    );
  }

  void _showCategoryBottomSheet() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = ProductCategories.filter(searchQuery, _langCode);
            return Container(
              height: MediaQuery.of(context).size.height * 0.80,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.category_rounded,
                            color: Color(0xFF16A34A), size: 22),
                        const SizedBox(width: 10),
                        Text(
                          _t('add_product_category'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: TextField(
                      onChanged: (v) =>
                          setSheetState(() => searchQuery = v),
                      decoration: InputDecoration(
                        hintText: _t('add_product_category_search'),
                        hintStyle: const TextStyle(
                            color: Color(0xFFCBD5E1), fontSize: 14),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Color(0xFF16A34A), size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF0F4F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final cat = filtered[index];
                        final id    = cat['id']!;
                        final icon  = cat['icon']!;
                        final label = cat[_langCode] ?? cat['fr']!;
                        final isSelected = _selectedCategory == id;
                        return InkWell(
                          onTap: () {
                            setState(() => _selectedCategory = id);
                            Navigator.pop(context);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF16A34A).withOpacity(0.08)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(
                                  color: const Color(0xFF16A34A)
                                      .withOpacity(0.3),
                                  width: 1.5)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF16A34A)
                                        .withOpacity(0.12)
                                        : const Color(0xFFF0F4F8),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(icon,
                                        style: const TextStyle(fontSize: 20)),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle_rounded,
                                      color: Color(0xFF16A34A), size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildValidatedField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    required bool required,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B))),
              if (required) ...[
                const SizedBox(width: 2),
                const Text('*',
                    style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ],
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextFormField(
              controller:      ctrl,
              keyboardType:    keyboardType,
              inputFormatters: inputFormatters,
              maxLines:        maxLines,
              validator:       validator,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF1E293B)),
              decoration: InputDecoration(
                hintText:  label,
                hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
                prefixIcon: Icon(icon,
                    color: const Color(0xFF16A34A), size: 20),
                filled:    true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0xFF16A34A), width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0xFFEF4444), width: 1.5),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0xFFEF4444), width: 1.5),
                ),
                errorStyle: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFEF4444),
                ),
                errorMaxLines: 2,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRewardSection() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _hasReward = !_hasReward),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.card_giftcard_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_t('add_product_reward_title'),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B))),
                          const SizedBox(height: 2),
                          Text(_t('add_product_reward_subtitle'),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    Switch(
                      value: _hasReward,
                      onChanged: (v) => setState(() => _hasReward = v),
                      activeColor: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ),
            ),
            if (_hasReward) ...[
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_t('add_product_reward_image_hint'),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B))),
                          const SizedBox(width: 2),
                          const Text('*',
                              style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _pickRewardImage,
                      child: Container(
                        width: double.infinity,
                        height: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _rewardImgErr
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFFBBF24).withOpacity(0.5),
                            width: _rewardImgErr ? 2 : 1.5,
                          ),
                        ),
                        child: _rewardImageBase64 != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(
                                base64Decode(_rewardImageBase64!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _rewardImageHint(),
                              ),
                              Positioned(
                                top: 8, right: 8,
                                child: GestureDetector(
                                  onTap: () => setState(
                                          () => _rewardImageBase64 = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.55),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close_rounded,
                                        color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                            : _rewardImageHint(hasError: _rewardImgErr),
                      ),
                    ),
                    if (_rewardImgErr)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          _t('add_product_reward_image_required'),
                          style: const TextStyle(
                              color: Color(0xFFEF4444), fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_t('add_product_reward_name_hint'),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B))),
                              const SizedBox(width: 2),
                              const Text('*',
                                  style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        TextFormField(
                          controller: _rewardNameCtrl,
                          autovalidateMode:
                          AutovalidateMode.onUserInteraction,
                          validator: (v) {
                            if (!_hasReward) return null;
                            if (v == null || v.trim().isEmpty)
                              return _t('add_product_reward_name_required');
                            return null;
                          },
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF1E293B)),
                          decoration: InputDecoration(
                            hintText: _t('add_product_reward_name_hint'),
                            hintStyle: const TextStyle(
                                color: Color(0xFFCBD5E1)),
                            prefixIcon: const Icon(
                                Icons.emoji_events_rounded,
                                color: Color(0xFFF59E0B),
                                size: 20),
                            filled:    true,
                            fillColor: const Color(0xFFFFFBEB),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: Color(0xFFFBBF24), width: 0.8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: Color(0xFFF59E0B), width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: Color(0xFFEF4444), width: 1.5),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: Color(0xFFEF4444), width: 1.5),
                            ),
                            errorStyle: const TextStyle(
                                fontSize: 11, color: Color(0xFFEF4444)),
                            errorMaxLines: 2,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFFDE68A), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Color(0xFFF59E0B), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_t('add_product_reward_info'),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF92400E))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rewardImageHint({bool hasError = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            color: hasError
                ? const Color(0xFFEF4444)
                : const Color(0xFFFBBF24),
            size: 32),
        const SizedBox(height: 8),
        Text(_t('add_product_reward_image_hint'),
            style: TextStyle(
                color: hasError
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFF59E0B),
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildRequiredLegend() {
    return Row(
      children: [
        const Text('*',
            style: TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text(_t('add_product_required_legend'),
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF94A3B8))),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 4, height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B))),
      ],
    );
  }

  Widget _buildValidationNoticeBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFF59E0B).withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.access_time_rounded,
                color: Color(0xFFF59E0B), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('add_product_validation_title'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _t('add_product_validation_desc'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB45309),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16A34A),
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: const Color(0xFF16A34A).withOpacity(0.4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: _isSaving
            ? const SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white))
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, size: 20),
            const SizedBox(width: 8),
            Text(
              _isEditing
                  ? _t('seller_save_changes')
                  : _t('add_product_save'),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
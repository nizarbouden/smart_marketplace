import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';
import 'package:smart_marketplace/providers/auth_provider.dart';

class SellerProfilePage extends StatefulWidget {
  const SellerProfilePage({super.key});

  @override
  State<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends State<SellerProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _t(String key) => AppLocalizations.get(key);
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final uid = _currentUser?.uid;
      if (uid == null) return;
      final doc =
      await _firestore.collection('users').doc(uid).get();
      if (doc.exists) setState(() => _userData = doc.data());
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  /// Phone layout: sliver scroll with collapsing app bar
  Widget _buildNarrowLayout() {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate(_buildProfileContent()),
          ),
        ),
      ],
    );
  }

  /// Tablet/desktop layout: two-column
  Widget _buildWideLayout() {
    final name = _getDisplayName();
    final email = _currentUser?.email ?? '';
    final photoUrl =
        _userData?['photoUrl'] as String? ?? _currentUser?.photoURL;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: Avatar card
          SizedBox(
            width: 260,
            child: _buildProfileCard(name, email, photoUrl),
          ),
          const SizedBox(width: 24),
          // Right column: Info + menu
          Expanded(
            child: Column(
              children: _buildProfileContent(includePadding: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(
      String name, String email, String? photoUrl) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF16A34A),
            Color(0xFF15803D),
            Color(0xFF166534)
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: ClipOval(
              child: photoUrl != null
                  ? Image.network(photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _buildAvatarFallback(name))
                  : _buildAvatarFallback(name),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name.isEmpty ? _t('seller_default_name') : name,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(
                color: Colors.white.withOpacity(0.8), fontSize: 12),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.store_rounded,
                    color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  _t('seller_role_label'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildProfileContent({bool includePadding = true}) {
    final widgets = <Widget>[];
    if (_isLoading) {
      widgets.add(const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: Color(0xFF16A34A)),
        ),
      ));
    } else {
      widgets.addAll([
        _buildInfoSection(),
        const SizedBox(height: 20),
        _buildMenuSection(),
        const SizedBox(height: 20),
        _buildLogoutButton(),
        if (includePadding) const SizedBox(height: 80),
      ]);
    }
    return widgets;
  }

  String _getDisplayName() {
    if (_userData != null) {
      return '${_userData!['prenom'] ?? ''} ${_userData!['nom'] ?? ''}'
          .trim();
    }
    return _currentUser?.displayName ?? '';
  }

  Widget _buildSliverAppBar() {
    final name = _getDisplayName();
    final email = _currentUser?.email ?? '';
    final photoUrl =
        _userData?['photoUrl'] as String? ?? _currentUser?.photoURL;

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: const Color(0xFF16A34A),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF16A34A),
                Color(0xFF15803D),
                Color(0xFF166534)
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: photoUrl != null
                        ? Image.network(photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildAvatarFallback(name))
                        : _buildAvatarFallback(name),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name.isEmpty ? _t('seller_default_name') : name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.store_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _t('seller_role_label'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      title: Text(
        _t('seller_profile_title'),
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    final initials = name.isNotEmpty
        ? name
        .trim()
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join()
        : '?';
    return Container(
      color: const Color(0xFF15803D),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    final phone = _userData?['phoneNumber'] as String? ?? '-';
    final createdAt =
    (_userData?['createdAt'] as Timestamp?)?.toDate();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('seller_account_info'),
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.phone_rounded, _t('seller_phone'), phone),
          const Divider(height: 20),
          _buildInfoRow(
            Icons.calendar_today_rounded,
            _t('seller_member_since'),
            createdAt != null
                ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
                : '-',
          ),
          const Divider(height: 20),
          _buildInfoRow(
            Icons.verified_rounded,
            _t('seller_email_verified'),
            _currentUser?.emailVerified == true
                ? _t('seller_yes')
                : _t('seller_no'),
            valueColor: _currentUser?.emailVerified == true
                ? const Color(0xFF16A34A)
                : const Color(0xFFDC2626),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
          ),
          child:
          Icon(icon, color: const Color(0xFF16A34A), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                  TextStyle(fontSize: 12, color: Colors.grey[500])),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.edit_rounded,
            label: _t('seller_edit_profile'),
            color: const Color(0xFF3B82F6),
            onTap: _showEditProfileSheet,
          ),
          const Divider(height: 1, indent: 60),
          _buildMenuItem(
            icon: Icons.language_rounded,
            label: _t('seller_language'),
            color: const Color(0xFF8B5CF6),
            onTap: () {},
          ),
          const Divider(height: 1, indent: 60),
          _buildMenuItem(
            icon: Icons.help_outline_rounded,
            label: _t('seller_help'),
            color: const Color(0xFFF59E0B),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1E293B))),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: Colors.grey, size: 20),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _handleLogout,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFEF2F2),
          foregroundColor: const Color(0xFFDC2626),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          side:
          const BorderSide(color: Color(0xFFDC2626), width: 1),
        ),
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: Text(
          _t('seller_logout'),
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showEditProfileSheet() {
    final prenomCtrl = TextEditingController(
        text: _userData?['prenom'] as String? ?? '');
    final nomCtrl = TextEditingController(
        text: _userData?['nom'] as String? ?? '');
    final phoneCtrl = TextEditingController(
        text: _userData?['phoneNumber'] as String? ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _t('seller_edit_profile'),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _buildSheetField(prenomCtrl, _t('seller_firstname'),
                    Icons.person_rounded),
                const SizedBox(height: 14),
                _buildSheetField(nomCtrl, _t('seller_lastname'),
                    Icons.person_outline_rounded),
                const SizedBox(height: 14),
                _buildSheetField(phoneCtrl, _t('seller_phone'),
                    Icons.phone_rounded,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _updateProfile(
                        prenom: prenomCtrl.text.trim(),
                        nom: nomCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(_t('seller_save_changes'),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetField(
      TextEditingController ctrl,
      String hint,
      IconData icon, {
        TextInputType keyboardType = TextInputType.text,
      }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon:
        Icon(icon, color: const Color(0xFF16A34A), size: 20),
        filled: true,
        fillColor: const Color(0xFFF0FDF4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: Color(0xFF16A34A), width: 1.5),
        ),
      ),
    );
  }

  Future<void> _updateProfile({
    required String prenom,
    required String nom,
    required String phone,
  }) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).update({
      'prenom': prenom,
      'nom': nom,
      'phoneNumber': phone,
      'updatedAt': Timestamp.now(),
    });
    await _loadUserData();
  }

  Future<void> _handleLogout() async {
    final authProvider =
    Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}
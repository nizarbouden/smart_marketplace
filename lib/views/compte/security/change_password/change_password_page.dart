import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../localization/app_localizations.dart';
import '../../../../services/firebase_auth_service.dart';


class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseAuthService _authService = FirebaseAuthService();

  Future<void> _launchGoogleSecurity() async {
    const url = 'https://myaccount.google.com/security';
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) return;
      }
      await _copyUrlAndShowMessage(url);
    } catch (e) {
      await _copyUrlAndShowMessage(url);
    }
  }

  Future<void> _copyUrlAndShowMessage(String url) async {
    const link = 'https://myaccount.google.com/security';
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.get('change_password_google_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.get('change_password_google_desc'),
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text(AppLocalizations.get('change_password_google_step1')),
              Text(AppLocalizations.get('change_password_google_step2')),
              Text(AppLocalizations.get('change_password_google_step3')),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(link,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: link));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(AppLocalizations.get('change_password_link_copied')),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                          ));
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.get('ok')),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isPasswordValid(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    return true;
  }

  List<String> _getPasswordErrors(String password) {
    List<String> errors = [];
    if (password.length < 8) errors.add(AppLocalizations.get('password_min_length'));
    if (!password.contains(RegExp(r'[A-Z]'))) errors.add(AppLocalizations.get('password_uppercase'));
    if (!password.contains(RegExp(r'[a-z]'))) errors.add(AppLocalizations.get('password_lowercase'));
    return errors;
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    void showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ));

    if (currentPassword.isEmpty) { showError(AppLocalizations.get('current_password')); return; }
    if (newPassword.isEmpty) { showError(AppLocalizations.get('new_password')); return; }
    if (!_isPasswordValid(newPassword)) { showError(AppLocalizations.get('password_requirements')); return; }
    if (confirmPassword.isEmpty) { showError(AppLocalizations.get('confirm_password_required')); return; }
    if (newPassword != confirmPassword) { showError(AppLocalizations.get('passwords_not_match')); return; }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      await _authService.createNotification(
        userId: user.uid,
        title: AppLocalizations.get('change_password'),
        body: AppLocalizations.get('edit_profile_notif_body'),
        type: 'profile',
      );

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.get('success')),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ));

      Navigator.of(context).pop();
    } catch (e) {
      String errorMessage = AppLocalizations.get('error');
      if (e.toString().contains('wrong-password') || e.toString().contains('invalid-credential')) {
        errorMessage = AppLocalizations.get('current_password');
      } else if (e.toString().contains('too-many-requests')) {
        errorMessage = AppLocalizations.get('error');
      } else if (e.toString().contains('network-request-failed')) {
        errorMessage = AppLocalizations.get('error');
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    final user = _auth.currentUser;
    final isGoogleUser = user?.providerData.any((p) => p.providerId == 'google.com') ?? false;
    final isEmailUser = user?.providerData.any((p) => p.providerId == 'password') ?? false;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back, color: Colors.black87,
              size: isDesktop ? 28 : isTablet ? 24 : 20),
        ),
        title: Text(
          AppLocalizations.get('change_password'),
          style: TextStyle(
            color: Colors.black87,
            fontSize: isDesktop ? 24 : isTablet ? 22 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 24 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isMobile ? 24 : 32),
              decoration: BoxDecoration(
                color: isGoogleUser
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    isGoogleUser ? Icons.security : Icons.lock_reset,
                    size: isMobile ? 60 : 80,
                    color: isGoogleUser ? Colors.blue : Colors.deepPurple,
                  ),
                  SizedBox(height: isMobile ? 16 : 20),
                  Text(
                    AppLocalizations.get('security'),
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: isGoogleUser ? Colors.blue : Colors.deepPurple,
                    ),
                  ),
                  SizedBox(height: isMobile ? 8 : 12),
                  Text(
                    isGoogleUser
                        ? AppLocalizations.get('two_factor_auth')
                        : AppLocalizations.get('change_password'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: isMobile ? 14 : 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            SizedBox(height: isMobile ? 32 : 40),

            if (isGoogleUser) ...[
              _buildGoogleSection(isMobile, isTablet, isDesktop),
            ] else if (isEmailUser) ...[
              _buildEmailSection(isMobile, isTablet, isDesktop),
            ] else ...[
              _buildUnsupportedSection(isMobile, isTablet),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleSection(bool isMobile, bool isTablet, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 24 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.info_outline, size: isMobile ? 24 : 28, color: Colors.blue),
              ),
              SizedBox(width: isMobile ? 16 : 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.get('change_password_google_account'),
                        style: TextStyle(
                            fontSize: isMobile ? 18 : 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    SizedBox(height: isMobile ? 4 : 6),
                    Text(AppLocalizations.get('change_password_google_connected'),
                        style: TextStyle(fontSize: isMobile ? 14 : 16, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 24 : 32),
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.get('change_password_how_to'),
                    style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue)),
                SizedBox(height: isMobile ? 12 : 16),
                ...[AppLocalizations.get('change_password_google_step1_1'),
                  AppLocalizations.get('change_password_google_step2_1'),
                  AppLocalizations.get('change_password_google_step3_1'),
                  AppLocalizations.get('change_password_google_step4_1')
                ].map((instruction) => Padding(
                  padding: EdgeInsets.only(bottom: isMobile ? 8 : 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: isMobile ? 20 : 24,
                        height: isMobile ? 20 : 24,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                        ),
                        child: Center(
                          child: Text(instruction.split('.')[0],
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isMobile ? 10 : 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      SizedBox(width: isMobile ? 12 : 16),
                      Expanded(
                        child: Text(
                          instruction.substring(instruction.indexOf('.') + 2),
                          style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              color: Colors.grey[700],
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                )),
                SizedBox(height: isMobile ? 16 : 20),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange, size: isMobile ? 20 : 24),
                      SizedBox(width: isMobile ? 12 : 16),
                      Expanded(
                        child: Text(
                          AppLocalizations.get('change_password_info_secure'),
                          style: TextStyle(fontSize: isMobile ? 12 : 14, color: Colors.orange[800]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 24 : 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _launchGoogleSecurity,
              icon: const Icon(Icons.open_in_browser),
              label: Text(
                AppLocalizations.get('security'),
                style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: Colors.blue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailSection(bool isMobile, bool isTablet, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 24 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Password
          Text(AppLocalizations.get('current_password'),
              style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          SizedBox(height: isMobile ? 8 : 12),
          TextField(
            controller: _currentPasswordController,
            obscureText: !_showCurrentPassword,
            decoration: InputDecoration(
              hintText: AppLocalizations.get('current_password'),
              prefixIcon: const Icon(Icons.lock, color: Colors.deepPurple),
              suffixIcon: IconButton(
                icon: Icon(_showCurrentPassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.deepPurple),
                onPressed: () => setState(() => _showCurrentPassword = !_showCurrentPassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.deepPurple)),
            ),
          ),

          SizedBox(height: isMobile ? 24 : 32),

          // New Password
          Text(AppLocalizations.get('new_password'),
              style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          SizedBox(height: isMobile ? 8 : 12),
          TextField(
            controller: _newPasswordController,
            obscureText: !_showNewPassword,
            decoration: InputDecoration(
              hintText: AppLocalizations.get('new_password'),
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.deepPurple),
              suffixIcon: IconButton(
                icon: Icon(_showNewPassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.deepPurple),
                onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.deepPurple)),
            ),
            onChanged: (_) => setState(() {}),
          ),

          if (_newPasswordController.text.isNotEmpty &&
              !_isPasswordValid(_newPasswordController.text))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.get('password_must_contain'),
                        style: TextStyle(
                            fontSize: isMobile ? 12 : 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[700])),
                    const SizedBox(height: 4),
                    ..._getPasswordErrors(_newPasswordController.text).map((error) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, size: 14, color: Colors.red[600]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(error,
                                style: TextStyle(fontSize: isMobile ? 11 : 12, color: Colors.red[600])),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),

          SizedBox(height: isMobile ? 24 : 32),

          // Confirm Password
          Text(AppLocalizations.get('confirm_password_field'),
              style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          SizedBox(height: isMobile ? 8 : 12),
          TextField(
            controller: _confirmPasswordController,
            obscureText: !_showConfirmPassword,
            decoration: InputDecoration(
              hintText: AppLocalizations.get('confirm_password_field'),
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.deepPurple),
              suffixIcon: IconButton(
                icon: Icon(_showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.deepPurple),
                onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.deepPurple)),
            ),
            onChanged: (_) => setState(() {}),
          ),

          if (_confirmPasswordController.text.isNotEmpty &&
              _confirmPasswordController.text != _newPasswordController.text)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: Colors.red[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(AppLocalizations.get('passwords_not_match'),
                          style: TextStyle(fontSize: isMobile ? 11 : 12, color: Colors.red[600])),
                    ),
                  ],
                ),
              ),
            ),

          SizedBox(height: isMobile ? 32 : 40),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                  : Text(
                AppLocalizations.get('change_password'),
                style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnsupportedSection(bool isMobile, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 24 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Icon(Icons.info, size: isMobile ? 60 : 80, color: Colors.grey),
          SizedBox(height: isMobile ? 16 : 20),
          Text(
            AppLocalizations.get('error'),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Text(
            AppLocalizations.get('error'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: isMobile ? 14 : 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
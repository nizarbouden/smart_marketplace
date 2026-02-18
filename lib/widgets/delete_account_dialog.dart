import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../localization/app_localizations.dart';
import '../../../services/navigation_service.dart';

class DeleteAccountDialog extends StatefulWidget {
  final VoidCallback onConfirmDelete;
  final VoidCallback? onDeactivated;

  const DeleteAccountDialog({
    super.key,
    required this.onConfirmDelete,
    this.onDeactivated,
  });

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final Set<int> _selectedReasons = {};
  final TextEditingController _otherReasonController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _showOtherField = false;
  bool _confirmValid = false;
  bool _isLoading = false; // ✅ état de chargement

  @override
  void dispose() {
    _otherReasonController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  List<String> get _reasons => [
    AppLocalizations.get('delete_reason_1'),
    AppLocalizations.get('delete_reason_2'),
    AppLocalizations.get('delete_reason_3'),
    AppLocalizations.get('delete_reason_4'),
    AppLocalizations.get('delete_reason_5'),
    AppLocalizations.get('delete_reason_other'),
  ];

  bool get _canSubmit {
    final hasReason = _selectedReasons.isNotEmpty;
    final otherOk =
        !_showOtherField || _otherReasonController.text.trim().isNotEmpty;
    return hasReason && otherOk && _confirmValid && !_isLoading;
  }

  void _onReasonTap(int index) {
    final isOther = index == _reasons.length - 1;
    setState(() {
      if (_selectedReasons.contains(index)) {
        _selectedReasons.remove(index);
        if (isOther) _showOtherField = false;
      } else {
        _selectedReasons.add(index);
        if (isOther) _showOtherField = true;
      }
    });
  }

  // ── Désactivation + redirection ──────────────────────────────
  Future<void> _deactivateAccount() async {
    // ✅ Capturer le navigatorKey AVANT tout await (avant que le context soit invalide)
    final navigationService = NavigationService();

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // 1. Enregistrer la demande de suppression
      await FirebaseFirestore.instance.collection('deletion_requests').add({
        'userId': currentUser.uid,
        'reasons': _selectedReasons.toList(),
        'otherReason': _otherReasonController.text.trim(),
        'requestedAt': Timestamp.now(),
        'status': 'pending',
      });

      // 2. Mettre à jour le statut utilisateur
      final scheduledDeletionDate =
      DateTime.now().add(const Duration(days: 30));
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'status': 'deactivated',
        'deletionRequestedAt': Timestamp.now(),
        'deletionReason': _selectedReasons.toList(),
        'deletionOtherReason': _otherReasonController.text.trim(),
        'scheduledDeletionAt': Timestamp.fromDate(scheduledDeletionDate),
      });

      // 3. Déconnecter Firebase
      await FirebaseAuth.instance.signOut();

      // ✅ CORRECTION CLÉE : fermer le dialog via le navigatorKey global,
      // pas via le context local qui peut être invalide après les awaits.
      // On utilise directement le navigatorKey pour tout faire en une passe.
      navigationService.navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/login', (route) => false);

    } catch (e) {
      // Erreur Firebase — remettre l'UI en état
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.get('error')}: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirmWord = AppLocalizations.get('delete_confirm_word');

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 20,
      // ✅ Empêche la fermeture par tap extérieur pendant le chargement
      child: PopScope(
        canPop: !_isLoading,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFDC2626),
                Color(0xFFEF4444),
                Color(0xFFF87171),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icône header ────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(28),
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(Icons.person_remove_rounded,
                      color: Colors.white, size: 32),
                ),
              ),

              // ── Corps blanc ──────────────────────────────────
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.72,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: _isLoading
                // ── Loader pendant la désactivation ─────────
                    ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFFDC2626),
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 20),
                      Text(
                        '...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
                // ── Formulaire normal ────────────────────────
                    : SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Titre + sous-titre
                      Text(
                        AppLocalizations.get(
                            'delete_account_dialog_title'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.get(
                            'delete_account_dialog_subtitle'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Raisons ────────────────────────
                      Text(
                        AppLocalizations.get(
                            'delete_account_reason_label'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 12),

                      ...List.generate(_reasons.length, (i) {
                        final isOther = i == _reasons.length - 1;
                        final isSelected = _selectedReasons.contains(i);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => _onReasonTap(i),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                margin:
                                const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFDC2626)
                                      .withOpacity(0.06)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius:
                                  BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFFE2E8F0),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 180),
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFDC2626)
                                            : Colors.white,
                                        borderRadius:
                                        BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFFCBD5E1),
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check,
                                          size: 14,
                                          color: Colors.white)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _reasons[i],
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                    if (isOther)
                                      Icon(
                                        _showOtherField
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        size: 18,
                                        color: isSelected
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF94A3B8),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (isOther && _showOtherField)
                              AnimatedSize(
                                duration:
                                const Duration(milliseconds: 220),
                                curve: Curves.easeInOut,
                                child: Container(
                                  margin: const EdgeInsets.only(
                                      bottom: 8, left: 4, right: 4),
                                  child: TextField(
                                    controller: _otherReasonController,
                                    maxLines: 3,
                                    onChanged: (_) => setState(() {}),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF1E293B)),
                                    decoration: InputDecoration(
                                      hintText:
                                      AppLocalizations.get(
                                          'delete_other_placeholder'),
                                      hintStyle: const TextStyle(
                                          color: Color(0xFFCBD5E1),
                                          fontSize: 13),
                                      filled: true,
                                      fillColor:
                                      const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                        BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFE2E8F0)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                        BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFE2E8F0)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                        BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFDC2626),
                                            width: 1.5),
                                      ),
                                      contentPadding:
                                      const EdgeInsets.all(12),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      }),

                      const SizedBox(height: 20),

                      // ── Champ de confirmation ───────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5F5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFFDC2626)
                                  .withOpacity(0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    size: 18,
                                    color: Color(0xFFDC2626)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    AppLocalizations.get(
                                        'delete_confirm_instruction'),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B)),
                                children: [
                                  TextSpan(
                                      text: AppLocalizations.get(
                                          'delete_confirm_type_label')),
                                  TextSpan(
                                    text: ' $confirmWord',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFDC2626),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _confirmController,
                              onChanged: (v) => setState(() =>
                              _confirmValid =
                                  v.trim() == confirmWord),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                                color: Color(0xFF1E293B),
                              ),
                              decoration: InputDecoration(
                                hintText: confirmWord,
                                hintStyle: const TextStyle(
                                    color: Color(0xFFCBD5E1),
                                    fontWeight: FontWeight.normal,
                                    letterSpacing: 0),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFDC2626),
                                      width: 1.5),
                                ),
                                suffixIcon: _confirmValid
                                    ? const Icon(Icons.check_circle,
                                    color: Colors.green, size: 20)
                                    : _confirmController.text.isNotEmpty
                                    ? const Icon(Icons.cancel,
                                    color: Color(0xFFDC2626),
                                    size: 20)
                                    : null,
                                contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Boutons ─────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                // ✅ désactivé pendant le chargement
                                onPressed: _isLoading
                                    ? null
                                    : () =>
                                    Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                      color: Color(0xFFDC2626),
                                      width: 1.5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(14)),
                                ),
                                child: Text(
                                  AppLocalizations.get('cancel'),
                                  style: const TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: AnimatedOpacity(
                                duration:
                                const Duration(milliseconds: 200),
                                opacity: _canSubmit ? 1.0 : 0.4,
                                child: ElevatedButton(
                                  // ✅ PAS de Navigator.pop() ici —
                                  // la navigation se fait via navigatorKey
                                  onPressed: _canSubmit
                                      ? _deactivateAccount
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                    const Color(0xFFDC2626),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                    const Color(0xFFDC2626),
                                    disabledForegroundColor:
                                    Colors.white,
                                    shadowColor: const Color(0xFFDC2626)
                                        .withOpacity(0.3),
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(14)),
                                  ),
                                  child: FittedBox(
                                    child: Text(
                                      AppLocalizations.get(
                                          'delete_account_btn'),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
}
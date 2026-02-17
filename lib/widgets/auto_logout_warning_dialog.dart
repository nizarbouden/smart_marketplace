import 'package:flutter/material.dart';
import 'dart:async';
import '../localization/app_localizations.dart';

class AutoLogoutWarningDialog extends StatefulWidget {
  final int remainingSeconds;
  final VoidCallback onStayLoggedIn;
  final VoidCallback onLogout;

  const AutoLogoutWarningDialog({
    super.key,
    required this.remainingSeconds,
    required this.onStayLoggedIn,
    required this.onLogout,
  });

  @override
  State<AutoLogoutWarningDialog> createState() => _AutoLogoutWarningDialogState();
}

class _AutoLogoutWarningDialogState extends State<AutoLogoutWarningDialog> {
  late int _countdown;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdown = widget.remainingSeconds;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _countdown--);
        if (_countdown <= 0) timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Titre ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.schedule, color: Colors.orange, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      AppLocalizations.get('autologout_title'),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Compte à rebours ───────────────────────────────
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withOpacity(0.3), width: 2),
                ),
                child: Column(
                  children: [
                    Text(
                      AppLocalizations.get('autologout_will_logout'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '$_countdown',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _countdown == 1
                          ? AppLocalizations.get('autologout_second')
                          : AppLocalizations.get('autologout_seconds'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Message inactivité ─────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  AppLocalizations.get('autologout_inactivity_msg'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey[700], height: 1.5),
                ),
              ),

              const SizedBox(height: 24),

              // ── Boutons ────────────────────────────────────────
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onStayLoggedIn();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_circle),
                    label: Text(
                      AppLocalizations.get('autologout_stay'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onLogout();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red.withOpacity(0.3)),
                      ),
                    ),
                    icon: const Icon(Icons.logout),
                    label: Text(
                      AppLocalizations.get('autologout_logout'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
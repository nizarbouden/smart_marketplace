import 'package:flutter/material.dart';
import '../services/auto_logout_service.dart';

class ActivityRecorderWrapper extends StatefulWidget {
  final Widget child;
  final AutoLogoutService autoLogoutService;

  const ActivityRecorderWrapper({
    super.key,
    required this.child,
    required this.autoLogoutService,
  });

  @override
  State<ActivityRecorderWrapper> createState() => _ActivityRecorderWrapperState();
}

class _ActivityRecorderWrapperState extends State<ActivityRecorderWrapper>
    with WidgetsBindingObserver {
  late DateTime _lastActivityRecordedTime;

  // ✅ Nouvelles propriétés pour filtrer les interactions
  late Offset _lastTapPosition;
  late DateTime _lastTapTime;
  static const int _minTapInterval = 500; // 500ms minimum entre les taps

  @override
  void initState() {
    super.initState();
    _lastActivityRecordedTime = DateTime.now();
    _lastTapTime = DateTime.now();
    _lastTapPosition = Offset.zero;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ✅ Vérifier si on est sur une page où ignorer l'activité
  bool _isSettingsPage() {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    return currentRoute == '/settings' ||
        currentRoute == '/security-settings' ||
        currentRoute == '/auto-logout-test' ||
        currentRoute == '/profil' ||
        currentRoute == '/notification-settings' ||
        currentRoute == '/addresses' ||
        currentRoute == '/payment-methods' ||
        currentRoute == '/edit-profile';
  }

  // ✅ Filtre pour les interactions significatives
  bool _isSignificantInteraction(Offset position) {
    final now = DateTime.now();
    final timeSinceLastTap = now.difference(_lastTapTime).inMilliseconds;

    // Vérifier que ce n'est pas un double-tap accidentel
    final distance = (_lastTapPosition - position).distance;

    // Enregistrer seulement si:
    // 1. Au moins 500ms depuis le dernier tap
    // 2. À plus de 50 pixels de distance (pas un double-tap)
    // 3. Pas sur une page Settings

    if (timeSinceLastTap < _minTapInterval && distance < 50) {
      print('ℹ️  Double-tap ignoré (distance: ${distance.toStringAsFixed(2)}px)');
      return false;
    }

    _lastTapPosition = position;
    _lastTapTime = now;

    return true;
  }

  // ✅ Throttle et filtre pour enregistrer l'activité
  void _recordActivityWithThrottle() {
    final now = DateTime.now();
    final timeSinceLastRecord = now.difference(_lastActivityRecordedTime).inMilliseconds;

    // Enregistrer seulement si 300ms ont passé
    if (timeSinceLastRecord > 300) {
      // ✅ Vérifier que le service est initialisé
      if (widget.autoLogoutService.isAutoLogoutEnabled()) {
        widget.autoLogoutService.recordActivity();
        _lastActivityRecordedTime = now;
        print('✏️  Activité enregistrée avec succès');
      } else {
        print('ℹ️  Auto-logout désactivé, activité ignorée');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // ✅ TAP: Interaction significative
      onTapDown: (details) {
        if (!_isSettingsPage()) {
          if (_isSignificantInteraction(details.globalPosition)) {
            _recordActivityWithThrottle();
            print('✏️  Tap détecté (${details.globalPosition}) - Activité enregistrée');
          }
        } else {
          print('ℹ️  Tap sur page Settings/Profil: ignoré');
        }
      },

      // ✅ DRAG VERTICAL: Scroll vers le bas (interaction significative)
      onVerticalDragDown: (details) {
        if (!_isSettingsPage()) {
          _recordActivityWithThrottle();
          print('✏️  Scroll vertical détecté - Activité enregistrée');
        } else {
          print('ℹ️  Scroll vertical sur page Settings: ignoré');
        }
      },

      // ✅ DRAG HORIZONTAL: Swipe gauche/droite (interaction significative)
      onHorizontalDragDown: (details) {
        if (!_isSettingsPage()) {
          _recordActivityWithThrottle();
          print('✏️  Swipe horizontal détecté - Activité enregistrée');
        } else {
          print('ℹ️  Swipe horizontal sur page Settings: ignoré');
        }
      },

      // ✅ Important: laisser passer les events aux enfants
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
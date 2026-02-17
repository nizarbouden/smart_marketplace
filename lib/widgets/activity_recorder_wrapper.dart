import 'package:flutter/material.dart';
import '../../services/auto_logout_service.dart';

class ActivityRecorderWrapper extends StatefulWidget {
  final Widget child;

  const ActivityRecorderWrapper({
    required this.child,
    Key? key,
  }) : super(key: key);

  @override
  State<ActivityRecorderWrapper> createState() => _ActivityRecorderWrapperState();
}

class _ActivityRecorderWrapperState extends State<ActivityRecorderWrapper>
    with WidgetsBindingObserver {
  // ✅ Service est créé localement (singleton)
  final AutoLogoutService _autoLogoutService = AutoLogoutService();
  bool _timerInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ✅ Initialiser le timer SEULEMENT une fois (singleton)
    _initializeTimer();
  }

  Future<void> _initializeTimer() async {
    try {
      // ✅ Vérifier si déjà initialisé
      if (_autoLogoutService.isTimerRunning()) {
        print('⏸️ Timer déjà en cours d\'exécution, pas de réinitialisation');
        if (mounted) {
          setState(() {
            _timerInitialized = true;
          });
        }
        return;
      }

      // ✅ Initialiser le service SI pas encore fait
      await _autoLogoutService.init();

      // ✅ Charger les paramètres sauvegardés
      final settings = await _autoLogoutService.loadAutoLogoutSettings();
      final isEnabled = settings['enabled'] ?? false;
      final duration = settings['duration'] ?? '30 minutes';

      if (mounted) {
        setState(() {
          _timerInitialized = true;
        });
      }

      // ✅ Démarrer le timer SI activé
      if (isEnabled && !_autoLogoutService.isTimerRunning()) {
        _autoLogoutService.startAutoLogout(duration);
        print('✅ Timer démarré/maintenu: $duration');
      } else if (isEnabled) {
        print('✅ Timer déjà actif: $duration');
      } else {
        print('⏸️ Timer désactivé pour cet utilisateur');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation du timer: $e');
      if (mounted) {
        setState(() {
          _timerInitialized = true;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // ✅ NE PAS arrêter le service ici (il est singleton et utilisé partout)
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('📱 App resumed');
      _autoLogoutService.recordActivity();
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ GestureDetector pour capturer TOUS les événements
    return GestureDetector(
      onTap: () {
        print('👆 Tap');
        _autoLogoutService.recordActivity();
      },
      onPanDown: (_) {
        print('👉 Drag/Swipe');
        _autoLogoutService.recordActivity();
      },
      onLongPress: () {
        print('🟡 Long press');
        _autoLogoutService.recordActivity();
      },
      behavior: HitTestBehavior.translucent,
      child: _RouteDetectorWidget(
        onRouteChange: () {
          print('📍 Route changed');
          _autoLogoutService.recordActivity();
        },
        child: widget.child,
      ),
    );
  }
}

// ✅ Widget pour détecter les changements de route
class _RouteDetectorWidget extends StatefulWidget {
  final VoidCallback onRouteChange;
  final Widget child;

  const _RouteDetectorWidget({
    required this.onRouteChange,
    required this.child,
  });

  @override
  State<_RouteDetectorWidget> createState() => _RouteDetectorWidgetState();
}

class _RouteDetectorWidgetState extends State<_RouteDetectorWidget>
    with RouteAware {
  late RouteObserver<PageRoute<dynamic>> _routeObserver;
  String? _currentRoute;

  @override
  void initState() {
    super.initState();
    _routeObserver = RouteObserver<PageRoute<dynamic>>();
  }

  @override
  void didPush() {
    super.didPush();
    final currentRoute = ModalRoute.of(context);
    if (currentRoute is PageRoute) {
      _handleRouteChange(currentRoute);
    }
  }

  @override
  void didPopNext() {
    super.didPopNext();
    final currentRoute = ModalRoute.of(context);
    if (currentRoute is PageRoute) {
      _handleRouteChange(currentRoute);
    }
  }

  void _handleRouteChange(PageRoute<dynamic> route) {
    final routeName = route.settings.name ?? route.toString();
    if (_currentRoute != routeName) {
      _currentRoute = routeName;
      widget.onRouteChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
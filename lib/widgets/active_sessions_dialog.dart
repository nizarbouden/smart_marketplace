import 'package:flutter/material.dart';
import '../services/session_management_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActiveSessionsDialog extends StatefulWidget {
  const ActiveSessionsDialog({super.key});

  @override
  State<ActiveSessionsDialog> createState() => _ActiveSessionsDialogState();
}

class _ActiveSessionsDialogState extends State<ActiveSessionsDialog> {
  final SessionManagementService _sessionService = SessionManagementService();
  List<SessionInfo> _sessions = [];
  bool _isLoading = true;
  bool _isRevoking = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    
    try {
      final sessions = await _sessionService.getAllSessions();
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
      print('✅ Sessions chargées: ${sessions.length} totales');
    } catch (e) {
      print('❌ Erreur chargement sessions: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshSessions() async {
    print('🔄 Rafraîchissement des sessions...');
    await _loadSessions();
  }

  Future<void> _revokeSession(SessionInfo session) async {
    if (session.isCurrentSession) {
      _showErrorSnackBar('Impossible de révoquer la session actuelle');
      return;
    }

    final confirmed = await _showConfirmationDialog(
      'Révoquer la session',
      'Êtes-vous sûr de vouloir révoquer la session sur "${session.deviceName}" ?\n\nL\'utilisateur devra se reconnecter.',
    );

    if (!confirmed) return;

    setState(() => _isRevoking = true);

    try {
      final success = await _sessionService.revokeSession(session.id);
      
      if (success) {
        _showSuccessSnackBar('Session révoquée avec succès');
        await _loadSessions(); // Recharger la liste
      } else {
        _showErrorSnackBar('Erreur lors de la révocation de la session');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur: $e');
    } finally {
      setState(() => _isRevoking = false);
    }
  }

  Future<void> _revokeAllOtherSessions() async {
    final otherSessions = _sessions.where((s) => !s.isCurrentSession).toList();
    
    if (otherSessions.isEmpty) {
      _showInfoSnackBar('Aucune autre session à révoquer');
      return;
    }

    final confirmed = await _showConfirmationDialog(
      'Révoquer toutes les autres sessions',
      'Êtes-vous sûr de vouloir révoquer ${otherSessions.length} autre${otherSessions.length > 1 ? 's' : ''} session${otherSessions.length > 1 ? 's' : ''} ?\n\nTous les utilisateurs devront se reconnecter.',
    );

    if (!confirmed) return;

    setState(() => _isRevoking = true);

    try {
      final revokedCount = await _sessionService.revokeAllOtherSessions();
      
      if (revokedCount > 0) {
        _showSuccessSnackBar('$revokedCount session${revokedCount > 1 ? 's' : ''} révoquée${revokedCount > 1 ? 's' : ''}');
        await _loadSessions(); // Recharger la liste
      } else {
        _showErrorSnackBar('Erreur lors de la révocation des sessions');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur: $e');
    } finally {
      setState(() => _isRevoking = false);
    }
  }

  Future<void> _revokeAllSessions() async {
    final confirmed = await _showConfirmationDialog(
      'Supprimer toutes les sessions',
      '⚠️ ATTENTION ! Ceci supprimera TOUTES vos sessions y compris la session actuelle.\n\nVous devrez vous reconnecter sur tous vos appareils.\n\nVoulez-vous continuer ?',
    );

    if (!confirmed) return;

    setState(() => _isRevoking = true);

    try {
      // Utiliser la méthode publique avec contexte pour déconnecter et rediriger
      await _sessionService.deleteAllSessions(context: context);

      _showSuccessSnackBar('Toutes les sessions ont été supprimées');
      await _loadSessions(); // Recharger la liste (devrait être vide)
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la suppression: $e');
    } finally {
      setState(() => _isRevoking = false);
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Révoquer'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildDeviceIcon(String deviceType) {
    switch (deviceType) {
      case 'android':
        return const Icon(Icons.android, color: Colors.green);
      case 'ios':
        return const Icon(Icons.phone_iphone, color: Colors.grey);
      default:
        return const Icon(Icons.devices, color: Colors.blue);
    }
  }

  Widget _buildSessionCard(SessionInfo session) {
    final isActive = session.lastActive.difference(DateTime.now()).inMinutes < 30; // Actif si utilisé récemment
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: session.isCurrentSession 
              ? Colors.green 
              : isActive 
                  ? Colors.blue 
                  : Colors.grey[300]!,
          width: session.isCurrentSession ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildDeviceIcon(session.deviceType),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.deviceName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (session.isCurrentSession)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: const Text(
                                'Session actuelle',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isActive 
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isActive 
                                      ? Colors.blue.withOpacity(0.3)
                                      : Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isActive ? Colors.blue : Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${session.platform.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!session.isCurrentSession)
                  IconButton(
                    onPressed: _isRevoking ? null : () => _revokeSession(session),
                    icon: _isRevoking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Révoquer cette session',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Version', session.appVersion),
            _buildInfoRow('Dernière activité', session.timeAgo),
            _buildInfoRow(
              'Créée le',
              '${session.createdAt.day}/${session.createdAt.month}/${session.createdAt.year}',
            ),
            if (!isActive)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      size: 16,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Session inactive depuis longtemps',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.devices,
                    color: Colors.deepPurple,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Toutes les sessions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      // Bouton rafraîchir
                      IconButton(
                        onPressed: _refreshSessions,
                        icon: const Icon(Icons.refresh, size: 18),
                        tooltip: 'Rafraîchir les sessions',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.deepPurple.withOpacity(0.1),
                          foregroundColor: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Bouton tout révoquer (sauf actuelle)
                      if (_sessions.isNotEmpty && _sessions.any((s) => !s.isCurrentSession))
                        TextButton.icon(
                          onPressed: _isRevoking ? null : _revokeAllOtherSessions,
                          icon: _isRevoking
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.delete_sweep, size: 18),
                          label: const Text(
                            'Tout révoquer',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            backgroundColor: Colors.red.withOpacity(0.1),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _sessions.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.devices_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Aucune session',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Les sessions apparaîtront ici lorsque vous vous connecterez.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_sessions.length} session${_sessions.length > 1 ? 's' : ''} totale${_sessions.length > 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_sessions.where((s) => s.lastActive.difference(DateTime.now()).inMinutes < 30).length} active${_sessions.where((s) => s.lastActive.difference(DateTime.now()).inMinutes < 30).length > 1 ? 's' : ''} • ${_sessions.where((s) => s.lastActive.difference(DateTime.now()).inMinutes >= 30).length} inactive${_sessions.where((s) => s.lastActive.difference(DateTime.now()).inMinutes >= 30).length > 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Flexible(
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _sessions.length,
                                  itemBuilder: (context, index) {
                                    return _buildSessionCard(_sessions[index]);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Bouton supprimer tout
                  ElevatedButton.icon(
                    onPressed: _isRevoking ? null : _revokeAllSessions,
                    icon: _isRevoking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_forever, size: 18),
                    label: const Text(
                      'Supprimer tout',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                  // Bouton fermer
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

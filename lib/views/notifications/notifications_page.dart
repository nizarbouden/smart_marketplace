import 'package:flutter/material.dart';
import 'package:smart_marketplace/services/firebase_auth_service.dart';
import '../../localization/app_localizations.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;
  final FirebaseAuthService _authService = FirebaseAuthService();

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => isLoading = true);
    try {
      List<Map<String, dynamic>> userNotifications = await _authService.getUserNotifications();
      setState(() {
        notifications = userNotifications;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp is String) return timestamp;
    try {
      DateTime dateTime = (timestamp as dynamic).toDate();
      DateTime now = DateTime.now();
      Duration difference = now.difference(dateTime);

      if (difference.inMinutes < 60) {
        return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
      } else if (difference.inHours < 24) {
        return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
      } else if (difference.inDays < 7) {
        return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
      } else {
        return 'Le ${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
      }
    } catch (e) {
      return 'Il y a quelque temps';
    }
  }

  Map<String, dynamic> _getNotificationIconAndColor(String type) {
    switch (type) {
      case 'profile':
        return {'icon': Icons.person, 'color': Colors.blue};
      case 'address':
        return {'icon': Icons.location_on, 'color': Colors.green};
      case 'order':
        return {'icon': Icons.shopping_cart, 'color': Colors.orange};
      case 'product':
        return {'icon': Icons.local_offer, 'color': Colors.purple};
      default:
        return {'icon': Icons.notifications, 'color': Colors.grey};
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    final horizontalPadding = isMobile ? 16.0 : (isTablet ? 24.0 : 32.0);
    final verticalPadding = isMobile ? 16.0 : (isTablet ? 24.0 : 32.0);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isMobile ? 16.0 : (isTablet ? 24.0 : 32.0)),
              _buildHeader(isMobile, isTablet),
              SizedBox(height: isDesktop ? 32 : (isTablet ? 28 : 20)),
              Expanded(
                child: isLoading
                    ? _buildLoadingState(isMobile, isTablet)
                    : notifications.isEmpty
                    ? _buildEmptyState(isMobile, isTablet)
                    : _buildNotificationsList(isMobile, isTablet, isDesktop),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile, bool isTablet) {
    return isMobile ? _buildButtonsMobile() : _buildButtonsDesktop(isTablet);
  }

  Widget _buildButtonsMobile() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _markAllAsRead,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              AppLocalizations.get('notif_orders_subtitle'),
              style: const TextStyle(
                  color: Colors.deepPurple, fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _clearAllNotifications,
            icon: const Icon(Icons.delete_sweep, size: 15),
            label: Text(AppLocalizations.get('delete'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButtonsDesktop(bool isTablet) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: _markAllAsRead,
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: isTablet ? 16 : 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
            AppLocalizations.get('notif_orders_subtitle'),
            style: TextStyle(
                color: Colors.deepPurple,
                fontSize: isTablet ? 13 : 14,
                fontWeight: FontWeight.w500),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _clearAllNotifications,
          icon: Icon(Icons.delete_sweep, size: isTablet ? 16 : 18),
          label: Text(AppLocalizations.get('delete'),
              style: TextStyle(fontSize: isTablet ? 13 : 14, fontWeight: FontWeight.w500)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(bool isMobile, bool isTablet) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple), strokeWidth: 3),
          SizedBox(height: isMobile ? 16 : (isTablet ? 20 : 24)),
          Text(AppLocalizations.get('loading'),
              style: TextStyle(
                  color: Colors.grey[600], fontSize: isMobile ? 14 : (isTablet ? 15 : 16))),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile, bool isTablet) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isMobile ? 80 : (isTablet ? 100 : 120),
            height: isMobile ? 80 : (isTablet ? 100 : 120),
            decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.notifications_off,
                size: isMobile ? 40 : (isTablet ? 50 : 60), color: Colors.deepPurple),
          ),
          SizedBox(height: isMobile ? 24 : (isTablet ? 32 : 40)),
          Text(AppLocalizations.get('no_data'),
              style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
                  fontWeight: FontWeight.w500)),
          SizedBox(height: isMobile ? 8 : (isTablet ? 12 : 16)),
          Text(AppLocalizations.get('no_data'),
              style: TextStyle(
                  color: Colors.grey[500], fontSize: isMobile ? 14 : (isTablet ? 15 : 16)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(bool isMobile, bool isTablet, bool isDesktop) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        final isRead = notification['isRead'] ?? true;
        final type = notification['type'] ?? 'default';
        final iconData = _getNotificationIconAndColor(type);

        return GestureDetector(
          onTap: () async {
            if (!isRead) {
              try {
                await _authService.markNotificationAsRead(
                  _authService.currentUser?.uid ?? '',
                  notification['id'] ?? '',
                );
                setState(() => notification['isRead'] = true);
              } catch (e) {
                print('❌ Erreur marquage notification: $e');
              }
            }
          },
          child: Dismissible(
            key: Key(notification['id'] ?? index.toString()),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: EdgeInsets.only(right: isMobile ? 20 : (isTablet ? 25 : 30)),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.delete, color: Colors.white,
                  size: isMobile ? 24 : (isTablet ? 28 : 32)),
            ),
            onDismissed: (direction) async {
              await _authService.deleteNotification(
                  _authService.currentUser?.uid ?? '', notification['id'] ?? '');
              setState(() => notifications.removeAt(index));
            },
            child: Container(
              margin: EdgeInsets.only(bottom: isMobile ? 12 : (isTablet ? 16 : 20)),
              decoration: BoxDecoration(
                color: isRead ? Colors.white : Colors.deepPurple.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isRead ? Colors.grey.shade300 : Colors.deepPurple.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: isMobile ? 40 : (isTablet ? 48 : 56),
                      height: isMobile ? 40 : (isTablet ? 48 : 56),
                      decoration: BoxDecoration(
                          color: iconData['color'].withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(iconData['icon'],
                          size: isMobile ? 20 : (isTablet ? 24 : 28), color: iconData['color']),
                    ),
                    SizedBox(width: isMobile ? 12 : (isTablet ? 16 : 20)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification['title'] ?? AppLocalizations.get('notif_push_title'),
                            style: TextStyle(
                              fontSize: isMobile ? 14 : (isTablet ? 15 : 16),
                              fontWeight: FontWeight.bold,
                              color: isRead ? Colors.grey[700] : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isMobile ? 4 : (isTablet ? 6 : 8)),
                          Text(
                            notification['body'] ?? '',
                            style: TextStyle(
                              fontSize: isMobile ? 12 : (isTablet ? 13 : 14),
                              color: isRead ? Colors.grey[600] : Colors.grey[700],
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isMobile ? 6 : (isTablet ? 8 : 10)),
                          Row(
                            children: [
                              Icon(Icons.access_time,
                                  size: isMobile ? 12 : (isTablet ? 13 : 14),
                                  color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                _formatTime(notification['createdAt']),
                                style: TextStyle(
                                    fontSize: isMobile ? 11 : (isTablet ? 12 : 13),
                                    color: Colors.grey[500]),
                              ),
                              const Spacer(),
                              if (!isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      color: Colors.deepPurple, shape: BoxShape.circle),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _markAllAsRead() async {
    try {
      String userId = _authService.currentUser?.uid ?? '';
      for (var notification in notifications) {
        if (!(notification['isRead'] ?? true)) {
          await _authService.markNotificationAsRead(userId, notification['id'] ?? '');
        }
      }
      setState(() {
        for (var notification in notifications) {
          notification['isRead'] = true;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${AppLocalizations.get('error')}: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    }
  }

  void _clearAllNotifications() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;

        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 20,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFFF87171)],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                    ),
                    child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 32),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.get('delete'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.get('confirm_delete_address'),
                        style: const TextStyle(
                            fontSize: 16, color: Color(0xFF64748B), height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Text(AppLocalizations.get('cancel'),
                                    style: const TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  try {
                                    await _authService.deleteAllNotifications(
                                        _authService.currentUser?.uid ?? '');
                                    setState(() => notifications.clear());
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text('${AppLocalizations.get('error')}: $e'),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 3),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8)),
                                      ));
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                  shadowColor: const Color(0xFFDC2626).withOpacity(0.3),
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                child: FittedBox(
                                  child: Text(AppLocalizations.get('delete'),
                                      style: const TextStyle(
                                          fontSize: 15, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/notification_item.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../utils/time_utils.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notificationService = NotificationService();

  /// Bilang ng notifications na ipapakita by default bago i-hide yung
  /// matatanda pa — pinipigilan nitong maging mahaba/magulo ang tignan
  /// ang list kapag maraming notifications na naipon.
  static const int _initialLimit = 8;

  List<NotificationItem>? _notifications;
  String? _error;
  bool _loading = true;
  bool _showAll = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final notifications = await _notificationService.getMyNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent || _notifications == null) _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent || _notifications == null) _error = 'Unable to load notifications.';
      });
    }
  }

  Future<void> _handleTap(NotificationItem item) async {
    if (item.isRead) return;

    setState(() {
      _notifications = _notifications
          ?.map((n) => n.id == item.id ? n.copyWith(isRead: true) : n)
          .toList();
    });

    try {
      await _notificationService.markAsRead(item.id);
    } catch (_) {
      // Silent failure is acceptable here.
    }
  }

  Future<void> _handleMarkAllRead() async {
    final hasUnread = _notifications?.any((n) => !n.isRead) ?? false;
    if (!hasUnread) return;

    setState(() {
      _notifications = _notifications?.map((n) => n.copyWith(isRead: true)).toList();
    });

    try {
      await _notificationService.markAllAsRead();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to sync read status. Will retry automatically.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget body;
    final notifications = _notifications ?? [];
    final hasUnread = notifications.any((n) => !n.isRead);

    if (_loading && _notifications == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _notifications == null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: colors.primaryLight),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(onPressed: () => _load(), child: const Text('Retry')),
          ],
        ),
      );
    } else if (notifications.isEmpty) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.notifications_none_rounded, size: 48, color: colors.primaryLight),
          const SizedBox(height: 12),
          Text('No notifications yet', style: TextStyle(color: colors.textSecondary)),
        ]),
      );
    } else {
      // Ipinapakita lang ang unang _initialLimit notifications by default;
      // yung mga natitira ay naka-hide sa likod ng "See previous
      // notifications" button para hindi kumalat/dumumi ang tignan ng
      // page kapag maraming notifications na naipon.
      final visible = _showAll ? notifications : notifications.take(_initialLimit).toList();
      final hasMore = !_showAll && notifications.length > _initialLimit;

      body = RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: visible.length + (hasMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index >= visible.length) {
              // Footer button — huling item sa list kapag may hidden pa.
              final remaining = notifications.length - visible.length;
              return Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _showAll = true),
                  icon: Icon(Icons.expand_more_rounded, color: colors.primary),
                  label: Text(
                    'See previous notifications ($remaining)',
                    style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700),
                  ),
                ),
              );
            }
            return _NotificationTile(
              item: visible[index],
              onTap: () => _handleTap(visible[index]),
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        foregroundColor: colors.textPrimary,
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _handleMarkAllRead,
              child: Text('Mark all read', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: body,
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});
  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: item.isRead ? colors.surface : colors.chipBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: item.isRead ? colors.border : colors.borderStrong, width: 1.2),
          boxShadow: [BoxShadow(color: colors.shadow, blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.local_laundry_service_rounded, color: colors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6, top: 4),
                          decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: TextStyle(fontSize: 12.5, color: colors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatTimeAgo(item.createdAt),
                    style: TextStyle(fontSize: 11, color: colors.textMuted, fontWeight: FontWeight.w600),
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
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/notification_item.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../utils/time_utils.dart';
import 'booking_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notificationService = NotificationService();

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

  Future<void> _markRead(NotificationItem item) async {
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

  /// UPDATED (notification detail view): pag-tap ng isang notification
  /// tile ay hindi na diretsong pumupunta sa BookingPage — muna
  /// itong nagpapakita ng _NotificationDetailSheet na naglalaman ng
  /// EKSAKTONG laman ng notification mismo (icon batay sa type, buong
  /// title, buong message, oras) — ito na yung "kung ano mismo ang
  /// nasa notification". Sa loob ng sheet mismo, kung may bookingId,
  /// meron pang "View Booking" button na siyang pupunta sa
  /// BookingPageScaffold — hiwalay na hakbang, hindi na awtomatiko.
  Future<void> _handleTap(NotificationItem item) async {
    await _markRead(item);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _NotificationDetailSheet(
        item: item,
        onViewBooking: item.bookingId == null
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BookingPageScaffold(focusBookingId: item.bookingId),
                  ),
                );
              },
      ),
    );
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

/// Type -> (icon, color) mapping, ginagamit PAREHO ng tile at ng
/// detail sheet para consistent ang itsura sa dalawang lugar.
/// Ang mga type string dito ay eksaktong mga ginagamit ng backend sa
/// notification_controller.create_notification() calls sa buong
/// booking_controller.py.
class _NotifTypeConfig {
  const _NotifTypeConfig(this.icon, this.colorKey);
  final IconData icon;
  final String colorKey; // 'primary' | 'success' | 'warning' | 'error' | 'neutral'
}

const Map<String, _NotifTypeConfig> _typeConfigs = {
  'booking_accepted': _NotifTypeConfig(Icons.check_circle_outline_rounded, 'success'),
  'booking_declined': _NotifTypeConfig(Icons.block_rounded, 'error'),
  'booking_cancelled': _NotifTypeConfig(Icons.cancel_outlined, 'neutral'),
  'status_in_progress': _NotifTypeConfig(Icons.local_laundry_service_rounded, 'primary'),
  'status_ready': _NotifTypeConfig(Icons.inventory_2_outlined, 'success'),
  'status_claimed': _NotifTypeConfig(Icons.celebration_rounded, 'success'),
  'status_cancelled': _NotifTypeConfig(Icons.cancel_outlined, 'neutral'),
  'price_finalized': _NotifTypeConfig(Icons.receipt_long_outlined, 'primary'),
  'payment_confirmed': _NotifTypeConfig(Icons.check_circle_outline_rounded, 'success'),
  'payment_rejected': _NotifTypeConfig(Icons.error_outline_rounded, 'error'),
  'pickup_rider_assigned': _NotifTypeConfig(Icons.pedal_bike_rounded, 'primary'),
  'delivery_rider_assigned': _NotifTypeConfig(Icons.delivery_dining_rounded, 'primary'),
};

_NotifTypeConfig _configFor(String type) =>
    _typeConfigs[type] ?? const _NotifTypeConfig(Icons.local_laundry_service_rounded, 'primary');

Color _resolveColor(AppColors colors, String colorKey) {
  switch (colorKey) {
    case 'success':
      return colors.success;
    case 'warning':
      return colors.warning;
    case 'error':
      return colors.error;
    case 'neutral':
      return colors.neutral;
    default:
      return colors.primary;
  }
}

Color _resolveBg(AppColors colors, String colorKey) {
  switch (colorKey) {
    case 'success':
      return colors.successBg;
    case 'warning':
      return colors.warningBg;
    case 'error':
      return colors.errorBg;
    case 'neutral':
      return colors.neutralBg;
    default:
      return colors.chipBg;
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});
  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasBooking = item.bookingId != null;
    final config = _configFor(item.type);
    final iconColor = _resolveColor(colors, config.colorKey);
    final iconBg = _resolveBg(colors, config.colorKey);

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
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(config.icon, color: iconColor, size: 20),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: colors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        formatTimeAgo(item.createdAt),
                        style: TextStyle(fontSize: 11, color: colors.textMuted, fontWeight: FontWeight.w600),
                      ),
                      if (hasBooking) ...[
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded, size: 14, color: colors.primary),
                        const SizedBox(width: 2),
                        Text(
                          'View',
                          style: TextStyle(fontSize: 11.5, color: colors.primary, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ],
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

/// NEW — buong laman ng isang notification mismo (icon, buong title,
/// buong message, buong timestamp — walang truncation, di gaya ng
/// tile na naka-2-lines lang ang message). Ito ang "kung ano mismo
/// ang nasa notification" na lumalabas pag tinap ang isang tile,
/// BAGO pa man pumunta sa booking mismo. Kung may bookingId, may
/// dagdag na "View Booking" button sa ilalim — hiwalay na aksyon,
/// hindi na awtomatikong navigation.
class _NotificationDetailSheet extends StatelessWidget {
  const _NotificationDetailSheet({required this.item, required this.onViewBooking});

  final NotificationItem item;
  final VoidCallback? onViewBooking;

  String _formatFullTimestamp(DateTime dt) {
    final local = dt.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${months[local.month - 1]} ${local.day}, ${local.year} · $hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final config = _configFor(item.type);
    final iconColor = _resolveColor(colors, config.colorKey);
    final iconBg = _resolveBg(colors, config.colorKey);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: colors.shadowStrong, blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(config.icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              item.title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              _formatFullTimestamp(item.createdAt),
              style: TextStyle(fontSize: 11.5, color: colors.textMuted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            Text(
              item.message,
              style: TextStyle(fontSize: 14, color: colors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      side: BorderSide(color: colors.border),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Close'),
                  ),
                ),
                if (onViewBooking != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: onViewBooking,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('View Booking', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
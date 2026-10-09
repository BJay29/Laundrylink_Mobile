import '../models/notification_item.dart';
import 'api_service.dart';
import 'customer_session.dart';

/// Customer (mobile app) notification endpoints.
///
/// Matches the interface already expected by notification_page.dart:
/// getMyNotifications(), markAsRead(id), markAllAsRead() — plus
/// getUnreadCount(), used by the bell icon badge in main_nav_page.dart.
///
/// All endpoints are protected by get_current_customer on the backend,
/// so every call attaches the Bearer token from CustomerSession, same
/// pattern as BookingService.
class NotificationService {
  NotificationService({ApiService? api}) : _api = api ?? ApiService();
  final ApiService _api;

  /// Fetches ALL notifications for the logged-in customer, most recent
  /// first. Backs the Notifications Page.
  Future<List<NotificationItem>> getMyNotifications() async {
    final token = CustomerSession.instance.authToken;
    if (token == null) {
      throw const ApiException('You must be logged in to view notifications.', statusCode: 401);
    }

    final data = await _api.getList('/notifications/mine', token: token);
    return data
        .map((json) => NotificationItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Bilang ng unread notifications, ginagamit ng bell icon badge sa
  /// main_nav_page.dart top bar. Nagbabalik ng 0 (sa halip na
  /// mag-throw) kung walang session — hindi dapat i-crash ang app kung
  /// ma-poll ito bago pa man makumpleto ang login.
  Future<int> getUnreadCount() async {
    final token = CustomerSession.instance.authToken;
    if (token == null) return 0;

    final data = await _api.get('/notifications/unread-count', token: token);
    return data['unread_count'] as int? ?? 0;
  }

  /// Marks a single notification as read. Backend returns
  /// {message, updated_count} — ignored here dahil optimistic local
  /// update na lang ang ginagamit ng caller (see NotificationsPage).
  Future<void> markAsRead(int notificationId) async {
    final token = CustomerSession.instance.authToken;
    if (token == null) {
      throw const ApiException('You must be logged in.', statusCode: 401);
    }

    await _api.patch('/notifications/$notificationId/read', const {}, token: token);
  }

  /// Marks every unread notification as read in one call.
  Future<void> markAllAsRead() async {
    final token = CustomerSession.instance.authToken;
    if (token == null) {
      throw const ApiException('You must be logged in.', statusCode: 401);
    }

    await _api.patch('/notifications/mark-all-read', const {}, token: token);
  }

  /// NEW (swipe-to-dismiss feature) — permanently deletes/hides a
  /// single notification for the logged-in customer. Assumes a
  /// DELETE /notifications/{id} route on the backend, protected by
  /// get_current_customer, mirroring the pattern of every other route
  /// in this service (markAsRead uses PATCH .../{id}/read, this uses
  /// DELETE .../{id}).
  ///
  /// IMPORTANT: this backend route does not exist yet in the files
  /// shared so far — you'll need to add a matching DELETE endpoint on
  /// the FastAPI side (e.g. delete_notification() in
  /// notification_controller.py + the route in notification_routes.py)
  /// that checks the notification belongs to the current customer
  /// before deleting, the same way cancel_customer_booking() checks
  /// ownership before cancelling a booking.
  Future<void> deleteNotification(int notificationId) async {
    final token = CustomerSession.instance.authToken;
    if (token == null) {
      throw const ApiException('You must be logged in.', statusCode: 401);
    }

    await _api.delete('/notifications/$notificationId', token: token);
  }
}
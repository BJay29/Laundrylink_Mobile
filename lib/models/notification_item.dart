/// Mirrors the backend's NotificationResponse (see app/schemas.py) — isang
/// tunay na row sa database bawat isa, may sariling read/unread state na
/// kontrolado ng backend (Notification.is_read), hindi na derived/guessed
/// mula sa kasalukuyang status ng isang booking.
///
/// UPDATED: idinagdag ang `type` — machine-readable string mula sa
/// backend (hal. "booking_accepted", "booking_declined",
/// "status_in_progress", "status_ready", "status_claimed",
/// "status_cancelled", "booking_cancelled", "general"). Hindi pa ito
/// ginagamit sa UI ngayon (title/message pa rin ang binabasa), pero
/// available na para sa hinaharap na feature na mag-iba ang icon/kulay
/// kada klase ng notification nang hindi na kailangang mag-parse ng
/// laman ng `message`. Default "general" bilang safe fallback kung
/// nawawala/wala pang laman ang field mula sa isang older na response.
class NotificationItem {
  const NotificationItem({
    required this.id,
    this.bookingId,
    this.type = 'general',
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  final int id;

  /// Null kung ang booking na pinagmulan nito ay natanggal na sa DB
  /// (ondelete="SET NULL" sa backend) — bihira, pero pinapayagan.
  final int? bookingId;

  final String type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
        id: json['id'] as int,
        bookingId: json['booking_id'] as int?,
        type: json['type'] as String? ?? 'general',
        title: json['title'] as String,
        message: json['message'] as String,
        isRead: json['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  /// Ginagamit para sa optimistic local update kapag na-mark-as-read
  /// ang isang notification — iniiwasan ang kailangang mag-refetch ng
  /// buong listahan para lang sa isang binagong field.
  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id: id,
        bookingId: bookingId,
        type: type,
        title: title,
        message: message,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}
/// Formats a DateTime as a short relative "time ago" string (e.g.
/// "5m ago", "2h ago", "3d ago"). Shared by BookingPage and
/// NotificationsPage so both surfaces show consistent timestamps for
/// the same underlying booking data.
///
/// Falls back to a plain date once it's more than a week old, since
/// "9d ago" / "23d ago" stops being a useful unit at that point.
///
/// FIXED (timezone): ang mga DateTime galing backend ay maaaring UTC.
/// Ang `difference()` ay tama na kahit UTC vs local, pero ang
/// `month`/`day`/`year` sa fallback date ay UTC kapag hindi
/// kino-convert — kaya `.toLocal()` muna bago basahin.
String formatTimeAgo(DateTime? dateTime) {
  if (dateTime == null) return '';

  final diff = DateTime.now().difference(dateTime);

  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = dateTime.toLocal();
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}
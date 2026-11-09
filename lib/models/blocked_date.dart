/// Isang petsang minarkahan ng shop na "fully booked" (galing sa
/// GET /blocked-dates/shop/{shop_id}).
///
/// Ang backend ay nagpapadala ng kalendaryong petsa (YYYY-MM-DD) sa oras
/// ng Pilipinas — ginagawa itong date-only na local DateTime dito para
/// walang timezone shift kapag kinukumpara sa napili sa date picker.
class BlockedDate {
  const BlockedDate({required this.date, this.reason});

  final DateTime date;
  final String? reason;

  factory BlockedDate.fromJson(Map<String, dynamic> json) {
    final parts = (json['blocked_date'] as String).split('-');
    return BlockedDate(
      date: DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
      reason: json['reason'] as String?,
    );
  }
}

/// Mabilis na lookup ng mga fully-booked na petsa, para sa
/// `selectableDayPredicate` ng showDatePicker.
class BlockedDateSet {
  BlockedDateSet(Iterable<BlockedDate> items)
      : _byKey = {for (final i in items) _key(i.date): i};

  const BlockedDateSet.empty() : _byKey = const {};

  final Map<String, BlockedDate> _byKey;

  static String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

  bool get isEmpty => _byKey.isEmpty;

  bool isBlocked(DateTime day) => _byKey.containsKey(_key(day));

  /// Ang unang petsang puwedeng piliin, mula [from] hanggang [last]
  /// (kasama). Null kung puro fully booked ang buong saklaw.
  ///
  /// Kailangan ito dahil ang `initialDate` ng showDatePicker ay DAPAT
  /// pumasa sa `selectableDayPredicate` — kung hindi, may assertion error.
  DateTime? firstSelectable(DateTime from, DateTime last) {
    var d = DateTime(from.year, from.month, from.day);
    final end = DateTime(last.year, last.month, last.day);
    while (!d.isAfter(end)) {
      if (!isBlocked(d)) return d;
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return null;
  }
}
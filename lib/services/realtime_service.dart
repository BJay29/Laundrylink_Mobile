import 'package:supabase_flutter/supabase_flutter.dart';

class BookingRealtimeService {
  RealtimeChannel? _channel;

  /// Subscribes to UPDATE events on the `bookings` table where
  /// `id = bookingId`. [onUpdate] is called with the new row's data
  /// every time the shop (web terminal) changes this booking's status,
  /// weighs it, finalizes pricing, marks it paid, etc. — anything that
  /// touches the `bookings` row.
  ///
  /// Safe to call again without a prior unsubscribe(); any existing
  /// channel is torn down first so a screen re-entry never leaks a
  /// duplicate subscription.
  void subscribe({
    required int bookingId,
    required void Function(Map<String, dynamic> newRow) onUpdate,
    void Function(Object error)? onError,
  }) {
    unsubscribe();

    final client = Supabase.instance.client;

    _channel = client
        .channel('public:bookings:id=eq.$bookingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: bookingId,
          ),
          callback: (payload) {
            try {
              onUpdate(payload.newRecord);
            } catch (e) {
              onError?.call(e);
            }
          },
        )
        .subscribe();
  }

  /// Tears down the current subscription, if any. Always call this in
  /// the owning widget's dispose() — an un-removed channel keeps the
  /// socket connection alive and accumulates listeners across screen
  /// visits, per the "PERFORMANCE GUARDRAIL" note in the original spec.
  void unsubscribe() {
    final channel = _channel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
      _channel = null;
    }
  }
}
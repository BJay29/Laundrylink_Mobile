import 'dart:async';

import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../services/api_service.dart';
import '../services/booking_service.dart';
import '../theme/app_colors.dart';
import '../utils/time_utils.dart';
import '../widgets/booking_status_tracker.dart';
import 'shop_selection_page.dart';

class BookingPage extends StatelessWidget {
  const BookingPage({super.key, this.createMode = false});

  final bool createMode;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: createMode ? const _CreateBookingContent() : const _BookingsContent(),
      );
}

class _BookingsContent extends StatefulWidget {
  const _BookingsContent();

  @override
  State<_BookingsContent> createState() => _BookingsContentState();
}

class _BookingsContentState extends State<_BookingsContent> {
  final BookingService _bookingService = BookingService();

  static const int _historyLimit = 3;

  List<Booking>? _bookings;
  String? _error;
  bool _loading = true;
  bool _showAllHistory = false;
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
      final bookings = await _bookingService.getMyBookings();
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent || _bookings == null) _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent || _bookings == null) _error = 'Unable to load your bookings.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_loading && _bookings == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _bookings == null) {
      return Center(
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
    }

    final bookings = _bookings ?? [];

    if (bookings.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.chipBg, shape: BoxShape.circle),
            child: Icon(Icons.receipt_long_outlined, size: 40, color: colors.primary),
          ),
          const SizedBox(height: 20),
          Text('No bookings yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colors.textPrimary)),
          const SizedBox(height: 8),
          Text('Create your first booking using the + button.', textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary)),
        ]),
      );
    }

    final active = bookings.where((b) => !b.status.isFinal).toList();
    final history = bookings.where((b) => b.status.isFinal).toList();

    final visibleHistory = _showAllHistory ? history : history.take(_historyLimit).toList();
    final hasMoreHistory = !_showAllHistory && history.length > _historyLimit;

    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          if (active.isNotEmpty) ...[
            for (final booking in active) ...[
              _BookingCard(booking: booking, onCancelled: () => _load(silent: true)),
              const SizedBox(height: 14),
            ],
          ],
          if (history.isNotEmpty) ...[
            if (active.isNotEmpty) const SizedBox(height: 6),
            Text(
              'Booking history',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colors.textSecondary),
            ),
            const SizedBox(height: 12),
            for (final booking in visibleHistory) ...[
              _BookingCard(booking: booking, onCancelled: () => _load(silent: true)),
              const SizedBox(height: 14),
            ],
            if (hasMoreHistory)
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _showAllHistory = true),
                  icon: Icon(Icons.expand_more_rounded, color: colors.primary),
                  label: Text(
                    'See previous bookings (${history.length - visibleHistory.length})',
                    style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _BookingCard extends StatefulWidget {
  const _BookingCard({required this.booking, required this.onCancelled});
  final Booking booking;
  final VoidCallback onCancelled;

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  final BookingService _bookingService = BookingService();
  bool _cancelling = false;

  bool get _isCancellable =>
      widget.booking.status == BookingStatus.awaitingApproval ||
      widget.booking.status == BookingStatus.pending;

  Future<void> _confirmAndCancel() async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: Text(
          'This will cancel your ${widget.booking.serviceName} booking'
          '${widget.booking.shopName.isNotEmpty ? ' at ${widget.booking.shopName}' : ''}. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep booking'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: colors.error),
            child: const Text('Yes, cancel it'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await _bookingService.cancelBooking(widget.booking.id!);
      if (!mounted) return;
      widget.onCancelled();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Booking cancelled.'), backgroundColor: colors.neutral),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: colors.error),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Unable to cancel booking. Please try again.'), backgroundColor: colors.error),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BookingStatusTracker(booking: booking),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (booking.totalPrice != null)
                _DetailRow(label: 'Total', value: '₱${booking.totalPrice!.toStringAsFixed(0)}'),
              if (booking.weight != null && booking.weight! > 0)
                _DetailRow(label: 'Weight', value: '${booking.weight!.toStringAsFixed(1)} kg'),
              if (booking.loads != null && booking.loads! > 0)
                _DetailRow(label: 'Loads', value: '${booking.loads}'),
              if (booking.fulfillmentMode != null)
                _DetailRow(
                  label: 'Fulfillment',
                  value: booking.fulfillmentMode == 'delivery' ? 'Delivery' : 'Drop-off',
                ),
              if (booking.pickupDatetime != null)
                _DetailRow(
                  label: 'Pickup',
                  value: '${booking.pickupDatetime!.month}/${booking.pickupDatetime!.day} '
                      '${booking.pickupDatetime!.hour.toString().padLeft(2, '0')}:'
                      '${booking.pickupDatetime!.minute.toString().padLeft(2, '0')}',
                ),
              if (booking.promoCode != null)
                _DetailRow(label: 'Promo', value: '${booking.promoCode} (-₱${booking.discountAmount?.toStringAsFixed(0) ?? '0'})'),
              if (booking.specialInstructions != null && booking.specialInstructions!.trim().isNotEmpty)
                _DetailRow(label: 'Notes', value: booking.specialInstructions!),
              if (booking.status == BookingStatus.declined && booking.declineReason != null)
                _DetailRow(label: 'Reason', value: booking.declineReason!),
              if (booking.bookingTimestamp != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Booked ${formatTimeAgo(booking.bookingTimestamp)}',
                    style: TextStyle(fontSize: 11, color: colors.textMuted, fontWeight: FontWeight.w600),
                  ),
                ),
              if (_isCancellable) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: colors.border),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _cancelling ? null : _confirmAndCancel,
                    icon: _cancelling
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: colors.error),
                          )
                        : const Icon(Icons.close_rounded, size: 16),
                    label: Text(_cancelling ? 'Cancelling...' : 'Cancel booking'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(color: colors.errorBorder),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(fontSize: 12.5, color: colors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 12.5, color: colors.textPrimary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _CreateBookingContent extends StatelessWidget {
  const _CreateBookingContent();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Create booking', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: colors.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Choose a shop to see their available services and book directly from the shop page.',
          style: TextStyle(color: colors.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ShopSelectionPage()),
          ),
          icon: const Icon(Icons.storefront_outlined),
          label: const Text('Browse shops'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
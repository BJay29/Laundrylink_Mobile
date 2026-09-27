import 'dart:async';

import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../services/api_service.dart';
import '../services/booking_service.dart';
import '../theme/app_colors.dart';
import '../widgets/collapsible_invoice_card.dart';
import '../widgets/live_status_banner.dart';
import '../widgets/order_timeline_tracker.dart';
import 'shop_selection_page.dart';

class BookingPage extends StatelessWidget {
  const BookingPage({super.key, this.createMode = false, this.focusBookingId});

  final bool createMode;
  final int? focusBookingId;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: createMode
            ? const _CreateBookingContent()
            : _BookingsContent(focusBookingId: focusBookingId),
      );
}

class BookingPageScaffold extends StatelessWidget {
  const BookingPageScaffold({super.key, this.focusBookingId});

  final int? focusBookingId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('Your Bookings', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: BookingPage(focusBookingId: focusBookingId),
    );
  }
}

class _BookingsContent extends StatefulWidget {
  const _BookingsContent({this.focusBookingId});

  final int? focusBookingId;

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

  final Map<int, GlobalKey> _cardKeys = {};
  bool _hasHandledFocus = false;

  GlobalKey _keyFor(int bookingId) => _cardKeys.putIfAbsent(bookingId, () => GlobalKey());

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
      _handleFocusIfNeeded();
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

  void _handleFocusIfNeeded() {
    if (_hasHandledFocus || widget.focusBookingId == null) return;
    _hasHandledFocus = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _cardKeys[widget.focusBookingId];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          alignment: 0.05,
        );
      }
    });
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
              _BookingCard(
                key: booking.id != null ? _keyFor(booking.id!) : null,
                booking: booking,
                onRefresh: () => _load(silent: true),
              ),
              const SizedBox(height: 16),
            ],
          ],
          if (history.isNotEmpty) ...[
            if (active.isNotEmpty) const SizedBox(height: 6),
            Text('Booking history', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colors.textSecondary)),
            const SizedBox(height: 12),
            for (final booking in visibleHistory) ...[
              _BookingCard(
                key: booking.id != null ? _keyFor(booking.id!) : null,
                booking: booking,
                onRefresh: () => _load(silent: true),
              ),
              const SizedBox(height: 16),
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

/// Isang booking card, TOP / MID / BOTTOM na disenyo:
///   TOP    — LiveStatusBanner
///   MID    — OrderTimelineTracker (buong vertical stepper, kasama na
///            ngayon ang Payment node/modal trigger — walang hiwalay
///            na payment section sa labas ng timeline)
///   BOTTOM — CollapsibleInvoiceCard, at hiwalay na Cancel button
class _BookingCard extends StatefulWidget {
  const _BookingCard({super.key, required this.booking, required this.onRefresh});

  final Booking booking;
  final VoidCallback onRefresh;

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  final BookingService _bookingService = BookingService();
  bool _cancelling = false;

  bool get _isCancellable =>
      widget.booking.status == BookingStatus.awaitingApproval || widget.booking.status == BookingStatus.pending;

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
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep booking')),
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
      widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Booking cancelled.'), backgroundColor: colors.neutral),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: colors.error));
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
        Hero(
          tag: 'booking-${booking.id}-header',
          child: Material(
            color: Colors.transparent,
            child: LiveStatusBanner(booking: booking),
          ),
        ),

        const SizedBox(height: 14),

        // MID — full vertical timeline, now including the Payment node
        // + modal trigger (see OrderTimelineTracker).
        OrderTimelineTracker(booking: booking, onRefresh: widget.onRefresh),

        const SizedBox(height: 14),

        CollapsibleInvoiceCard(booking: booking),

        if (_isCancellable) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _cancelling ? null : _confirmAndCancel,
              icon: _cancelling
                  ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: colors.error))
                  : const Icon(Icons.close_rounded, size: 16),
              label: Text(_cancelling ? 'Cancelling...' : 'Cancel booking'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide(color: colors.errorBorder),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ],
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
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopSelectionPage())),
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
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/booking.dart';
import '../models/shop.dart';
import '../services/booking_service.dart';
import '../services/realtime_service.dart';
import '../widgets/qr_payment_card.dart';

/// Neon-blue palette for reached/active timeline steps (spec §2:
/// "vibrant neon-blue color profile scheme"). Unreached steps use this
/// same hue but compressed to 30% opacity over a grayscale base,
/// per _dimmedNeon().
const Color _kNeonBlue = Color(0xFF00B8FF);
const Color _kNeonBlueDark = Color(0xFF0091EA);

/// Vertical timeline/stepper tracker for a single booking.
///
/// Loads the booking once via REST (GET /bookings/mine, filtered
/// client-side to this id — see BookingService.getBookingById), then
/// subscribes to Supabase Realtime for live updates whenever the shop
/// changes this booking's status, weighs it, finalizes pricing, or
/// verifies/rejects payment from the web terminal.
///
/// [shop] is optional and only used to source the QR code image
/// (Shop.qrCodeUrl) for the morphing payment card that appears once
/// the booking status becomes "Awaiting Payment" with an online_qr
/// payment method — pass it in when the caller already has the Shop
/// object handy (e.g. navigating straight from ShopDetailPage/
/// BookingConfirmationPage) to avoid a second network round trip.
class OrderTrackingPage extends StatefulWidget {
  const OrderTrackingPage({super.key, required this.bookingId, this.shop});

  final int bookingId;
  final Shop? shop;

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  final BookingService _bookingService = BookingService();
  final BookingRealtimeService _realtime = BookingRealtimeService();

  Booking? _booking;
  bool _isLoading = true;
  String? _errorMessage;

  /// Tracks whether the morphing payment card should be visible — kept
  /// as its own bool (rather than deriving inline in build()) so
  /// AnimatedCrossFade/AnimatedSize below has a stable condition to
  /// animate between across rebuilds triggered by Realtime pushes.
  bool get _showPaymentCard =>
      _booking != null &&
      _booking!.status == BookingStatus.awaitingPayment &&
      _booking!.paymentMethod == 'online_qr';

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _realtime.subscribe(
      bookingId: widget.bookingId,
      onUpdate: (newRow) {
        if (!mounted) return;
        setState(() {
          _booking = Booking.fromJson(newRow, shopName: _booking?.shopName ?? '');
        });
      },
      onError: (e) {
        debugPrint('Realtime update parse error: $e');
      },
    );
  }

  @override
  void dispose() {
    // PERFORMANCE GUARDRAIL: always remove the channel when leaving this
    // screen, or the socket connection + listener stay alive and pile up
    // across repeated visits.
    _realtime.unsubscribe();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final booking = await _bookingService.getBookingById(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _booking = booking;
        _isLoading = false;
        if (booking == null) {
          _errorMessage = 'Booking not found.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load booking. Pull down to retry.';
      });
    }
  }

  Future<void> _handleRefresh() => _loadInitial();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Order Tracking')),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _booking == null) {
      return const Center(child: CircularProgressIndicator(color: _kNeonBlue));
    }

    if (_errorMessage != null && _booking == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    final booking = _booking!;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        _buildHeader(booking),
        const SizedBox(height: 20),

        // --- Morphing payment action card (spec §3) ---
        // AnimatedSize + AnimatedCrossFade give the physics-based morph
        // the spec asks for: the card doesn't hard-cut into view, it
        // eases open/closed as _showPaymentCard flips (driven purely by
        // Realtime pushes updating booking.status/paymentMethod).
        AnimatedSize(
          duration: const Duration(milliseconds: 450),
          curve: Curves.fastOutSlowIn,
          alignment: Alignment.topCenter,
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 450),
            sizeCurve: Curves.fastOutSlowIn,
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeIn,
            crossFadeState: _showPaymentCard ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: _showPaymentCard
                ? QrPaymentCard(
                    booking: booking,
                    qrCodeUrl: widget.shop?.qrCodeUrl,
                    onSubmitted: _loadInitial,
                  )
                : const SizedBox.shrink(),
            secondChild: const SizedBox.shrink(),
          ),
        ),

        if (booking.status == BookingStatus.pending ||
            booking.status == BookingStatus.awaitingPayment && booking.paymentMethod == 'cash')
          _buildCashDueBanner(booking),

        _buildStaggeredStepper(booking),
        const SizedBox(height: 24),
        if (booking.status == BookingStatus.cancelled || booking.status == BookingStatus.declined)
          _buildTerminalBanner(booking),
      ],
    );
  }

  Widget _buildHeader(Booking booking) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          booking.shopName,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          booking.serviceName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          booking.status.label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _statusColor(booking.status),
          ),
        ),
        if (booking.finalPrice != null) ...[
          const SizedBox(height: 4),
          Text(
            'Final total: ₱${booking.finalPrice!.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 14),
          ),
        ] else if (booking.estimatedPrice != null) ...[
          const SizedBox(height: 4),
          Text(
            'Estimated: ₱${booking.estimatedPrice!.toStringAsFixed(2)} (pending weighing)',
            style: const TextStyle(fontSize: 14, color: Colors.orange),
          ),
        ],
      ],
    );
  }

  /// CASE 'cash' from spec §3 — shown once the booking's price is
  /// finalized and payment_method is cash: a plain instructions block
  /// rather than the morphing QR card (which is online_qr-only).
  Widget _buildCashDueBanner(Booking booking) {
    if (booking.finalPrice == null || booking.finalWeight == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kNeonBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kNeonBlue.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.payments_outlined, color: _kNeonBlueDark, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Final Weight: ${booking.finalWeight} kg | Total Amount Due: '
              '₱${booking.finalPrice!.toStringAsFixed(2)}. Please settle the '
              'exact cash payment with the counter clerk at the shop.',
              style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalBanner(Booking booking) {
    final isCancelled = booking.status == BookingStatus.cancelled;
    final reason = booking.declineReason;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.red.shade400, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isCancelled
                  ? 'This booking was cancelled.'
                  : 'This booking was declined by the shop.${reason != null ? ' Reason: $reason' : ''}',
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.ready:
        return Colors.green;
      case BookingStatus.claimed:
        return Colors.blueGrey;
      case BookingStatus.cancelled:
      case BookingStatus.declined:
        return Colors.red;
      case BookingStatus.awaitingPayment:
        return Colors.orange;
      case BookingStatus.awaitingApproval:
      case BookingStatus.awaitingWeighing:
      case BookingStatus.pending:
      case BookingStatus.inProgress:
      case BookingStatus.unknown:
        return _kNeonBlueDark;
    }
  }

  /// Builds the 5-step vertical timeline with a staggered entrance:
  /// Received → Weighed/Price Ready → Washing In Progress →
  /// Ready for Pickup → Completed/Picked up.
  ///
  /// Each row is wrapped in _StaggeredStepEntrance, which delays its
  /// own slide-up + fade-in by (index * stagger) — spec §2's "index-
  /// delayed entrance transition layout handler". This only plays once
  /// per row's first build (see _StaggeredStepEntrance's initState),
  /// so a Realtime push that just updates timestamps later doesn't
  /// re-trigger the whole cascade — only the initial page load does.
  Widget _buildStaggeredStepper(Booking booking) {
    final steps = <_TrackerStep>[
      _TrackerStep(
        title: 'Received / For Weighing',
        description: 'Your booking request has been received.',
        timestamp: booking.createdAt,
      ),
      _TrackerStep(
        title: 'Weighed / Price Ready',
        description: booking.finalWeight != null
            ? 'Weighed at ${booking.finalWeight} — final price set.'
            : 'Waiting for the shop to weigh your laundry.',
        timestamp: booking.weighedAt,
      ),
      _TrackerStep(
        title: 'Washing In Progress',
        description: 'Your laundry is currently being washed.',
        timestamp: booking.startedAt,
      ),
      _TrackerStep(
        title: 'Ready for Pickup',
        description: 'Your laundry is ready for pickup or delivery.',
        timestamp: booking.readyAt,
      ),
      _TrackerStep(
        title: 'Completed / Picked up',
        description: 'This booking has been completed. Thank you!',
        timestamp: booking.completedAt,
      ),
    ];

    final lastReachedIndex = steps.lastIndexWhere((s) => s.timestamp != null);

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isReached = index <= lastReachedIndex;
        final isLast = index == steps.length - 1;

        return _StaggeredStepEntrance(
          index: index,
          child: _buildStepRow(step: step, isReached: isReached, isLast: isLast),
        );
      }),
    );
  }

  Widget _buildStepRow({required _TrackerStep step, required bool isReached, required bool isLast}) {
    // Neon-blue when reached; a 30%-opacity grayscale mask when not
    // (spec §2's "TIMELINE STATE PALETTES").
    final lineAndDotColor = isReached ? _kNeonBlue : Colors.grey.withOpacity(0.3);
    final titleColor = isReached ? Colors.black87 : Colors.grey.withOpacity(0.5);
    final descColor = isReached ? Colors.grey.shade700 : Colors.grey.withOpacity(0.4);
    final timeColor = isReached ? _kNeonBlueDark : Colors.grey.withOpacity(0.4);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lineAndDotColor,
                  boxShadow: isReached
                      ? [
                          BoxShadow(
                            color: _kNeonBlue.withOpacity(0.45),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  isReached ? Icons.check : Icons.circle,
                  size: isReached ? 16 : 8,
                  color: Colors.white,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: lineAndDotColor),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          step.title,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: titleColor),
                        ),
                      ),
                      Text(
                        _formatStepTimestamp(step.timestamp),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: timeColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.description,
                    style: TextStyle(fontSize: 13, color: descColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Converts a UTC timestamp from the backend into the device's local
  /// time and formats it as "hh:mm a" (e.g. "04:15 PM") using the
  /// `intl` package, per spec §2. Falls back to "Pending" for null
  /// (step not yet reached), and appends "| MM/dd" for timestamps not
  /// from today.
  String _formatStepTimestamp(DateTime? utc) {
    if (utc == null) return 'Pending';

    final local = utc.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year && local.month == now.month && local.day == now.day;

    final timePart = DateFormat('hh:mm a').format(local);
    if (isToday) return timePart;

    final datePart = DateFormat('MM/dd').format(local);
    return '$timePart | $datePart';
  }
}

class _TrackerStep {
  const _TrackerStep({
    required this.title,
    required this.description,
    required this.timestamp,
  });

  final String title;
  final String description;
  final DateTime? timestamp;
}

/// Wraps a single stepper row with an index-delayed slide-up + fade-in
/// entrance (spec §2: "staggered cascade animation sequence utilizing
/// an index-delayed entrance transition layout handler"). Plays once
/// per widget instance — since _buildStaggeredStepper() rebuilds fresh
/// _StaggeredStepEntrance widgets keyed by list position on every
/// parent rebuild (e.g. a Realtime push), Flutter's element diffing
/// reuses the same State object for the same position, so the
/// animation is NOT replayed just because a timestamp elsewhere
/// updated — only a fresh page load (a brand new widget tree) triggers
/// the cascade.
class _StaggeredStepEntrance extends StatefulWidget {
  const _StaggeredStepEntrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_StaggeredStepEntrance> createState() => _StaggeredStepEntranceState();
}

class _StaggeredStepEntranceState extends State<_StaggeredStepEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  static const Duration _stepDuration = Duration(milliseconds: 400);
  static const Duration _staggerDelay = Duration(milliseconds: 90);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _stepDuration);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn));

    Future.delayed(_staggerDelay * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../models/shop.dart';
import 'order_tracking_page.dart';

/// Local color constant — see other screens for the same note on why
/// this isn't AppColors.primary directly.
const Color _kPrimary = Color(0xFF1B7A6E);

/// Shown right after a customer successfully submits a booking
/// (POST /bookings/customer succeeds). Sequence:
///   1. Brief "Just a moment..." loading state.
///   2. "Your booking is confirmed!" with a summary + two actions:
///      [View Your Bookings] and [Exit].
///
/// UPDATED (spec §2 — STACK ROUTING SEQUENCE): [View Your Bookings]
/// now clears the navigation stack and pushes straight into
/// OrderTrackingPage for the newly created booking, using a Hero
/// transition on the header block (tag must match the one used in
/// OrderTrackingPage's header — 'booking-{id}-header').
class BookingConfirmationPage extends StatefulWidget {
  const BookingConfirmationPage({
    super.key,
    required this.booking,
    required this.onExit,
    this.shop,
  });

  final Booking booking;

  /// Optional — passed through to OrderTrackingPage so it can render
  /// the shop's QR code (Shop.qrCodeUrl) without a second network call,
  /// same reasoning as OrderTrackingPage's own `shop` param.
  final Shop? shop;

  /// Called when the customer taps "Exit". Typically pops back to Home.
  final VoidCallback onExit;

  @override
  State<BookingConfirmationPage> createState() => _BookingConfirmationPageState();
}

class _BookingConfirmationPageState extends State<BookingConfirmationPage> {
  bool _isConfirmed = false;

  @override
  void initState() {
    super.initState();
    // Cosmetic delay only — the booking already exists in the backend
    // by the time this page is shown. This just avoids an abrupt jump
    // straight to "confirmed" with no transition.
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _isConfirmed = true);
    });
  }

  void _goToTracking() {
    final bookingId = widget.booking.id;
    if (bookingId == null) {
      // Shouldn't happen for a real created booking, but guard anyway
      // rather than pushing a tracking page with no id to fetch.
      widget.onExit();
      return;
    }

    // STACK ROUTING SEQUENCE (spec §2): clear the current navigation
    // stack context entirely, then push OrderTrackingPage as the new
    // root — the customer should not be able to "back" into the
    // checkout flow they just completed.
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) => OrderTrackingPage(
          bookingId: bookingId,
          shop: widget.shop,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: _isConfirmed ? _buildConfirmed(context) : _buildLoading(context),
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return const Center(
      key: ValueKey('loading'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _kPrimary),
          SizedBox(height: 20),
          Text(
            'Just a moment...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmed(BuildContext context) {
    final booking = widget.booking;

    return Padding(
      key: const ValueKey('confirmed'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Hero tag matches OrderTrackingPage's header wrap — the
          // check-circle here morphs visually into that page's header
          // block position during the transition.
          Hero(
            tag: 'booking-${booking.id}-header',
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kPrimary,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 52),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your booking is confirmed!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            '${booking.serviceName} at ${booking.shopName}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Colors.grey),
          ),
          if (booking.estimatedPrice != null) ...[
            const SizedBox(height: 8),
            Text(
              'Estimated total: ₱${booking.estimatedPrice!.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'This is an estimated price. The final bill will be '
                    'verified once the shop weighs your laundry.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _goToTracking,
              child: const Text('View Your Bookings'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              onPressed: widget.onExit,
              child: const Text('Exit'),
            ),
          ),
        ],
      ),
    );
  }
}
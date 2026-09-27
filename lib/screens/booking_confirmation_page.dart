import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../models/shop.dart';
import 'booking_page.dart';

/// Local color constant — see other screens for the same note on why
/// this isn't AppColors.primary directly.
const Color _kPrimary = Color(0xFF1B7A6E);

/// Shown right after a customer successfully submits a booking
/// (POST /bookings/customer succeeds). Sequence:
///   1. Brief "Just a moment..." loading state.
///   2. "Your booking is confirmed!" with a summary + two actions:
///      [Track Your Order] and [Exit].
class BookingConfirmationPage extends StatefulWidget {
  const BookingConfirmationPage({
    super.key,
    required this.booking,
    required this.onExit,
    this.shop,
  });

  final Booking booking;

  /// Optional — kept for callers that already have the Shop object on
  /// hand.
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
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _isConfirmed = true);
    });
  }

  /// FIXED (Booking & Order Tracking Flow Fix — missing back button
  /// bug): dating gumagamit ito ng `pushAndRemoveUntil(..., (route) =>
  /// false)`, na inaalis ang BUONG navigation stack — KASAMA na mismo
  /// ang MainNavPage/HomePage na root ng buong app. Resulta: walang
  /// matutuluyan pabalik ang back button sa tracking screen, dahil
  /// wala nang naiwang route sa likod nito.
  ///
  /// Ngayon: `popUntil` munang ibalik ang stack sa root route (kung
  /// saan naka-mount pa rin ang MainNavPage), tapos saka lang mag-
  /// `push` (hindi na `pushAndRemoveUntil`) ng BookingPageScaffold sa
  /// ibabaw nito. Buhay pa rin ang root, kaya normal na gumagana na
  /// ang back button — babalik sa Home, hindi mag-e-exit ng app o
  /// mag-crash sa walang laman na stack.
  void _goToTracking() {
    final bookingId = widget.booking.id;
    if (bookingId == null) {
      widget.onExit();
      return;
    }

    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) =>
            BookingPageScaffold(focusBookingId: bookingId),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
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
              child: const Text('Track Your Order'),
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
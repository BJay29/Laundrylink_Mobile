// ============================= home_page.dart =============================
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../models/customer.dart';
import '../models/shop.dart';
import '../services/api_service.dart';
import '../services/booking_service.dart';
import '../services/shop_service.dart';
import '../theme/app_colors.dart';
import '../widgets/booking_status_tracker.dart';
import '../widgets/illustrated_icon.dart';
import 'booking_page.dart';
import 'shop_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.customer});

  final Customer customer;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ShopService _shopService = ShopService();
  final BookingService _bookingService = BookingService();

  late Future<List<Shop>> _shopsFuture;

  Booking? _activeBooking;
  int _completedCount = 0;
  int _totalBookingsCount = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _shopsFuture = _shopService.getShops();
    _loadBookings();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadBookings(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBookings({bool silent = false}) async {
    try {
      final bookings = await _bookingService.getMyBookings();
      if (!mounted) return;

      Booking? active;
      for (final b in bookings) {
        if (!b.status.isFinal) {
          active = b;
          break;
        }
      }

      final completed = bookings.where((b) => b.status == BookingStatus.claimed).length;

      setState(() {
        _activeBooking = active;
        _completedCount = completed;
        _totalBookingsCount = bookings.length;
      });
    } on ApiException {
      // Silent fail — background poll lang.
    } catch (_) {
      // Same reasoning as above.
    }
  }

  Future<void> _reload() async {
    setState(() {
      _shopsFuture = _shopService.getShops();
    });
    await Future.wait([_shopsFuture, _loadBookings()]);
  }

  void _openActiveBookingTracking() {
    final bookingId = _activeBooking?.id;
    if (bookingId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookingPageScaffold(focusBookingId: bookingId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final customer = widget.customer;

    final Widget topCard = _activeBooking != null
        ? InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _openActiveBookingTracking,
            child: _CardShell(child: BookingStatusTracker(booking: _activeBooking!)),
          )
        : _CardShell(child: _NoActiveBookingBanner(colors: colors));

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        // FIX: ang header ay hiwalay na row na sa itaas ng MainNavPage
        // (hindi na Positioned background), kaya normal na top padding na
        // lang ang kailangan dito — wala nang overlap/negative-offset na
        // "peek" trick para hindi na rin masapawan ang laman ng card ng
        // border ng header.
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        children: [
          topCard,
          const SizedBox(height: 28),
          Text(
            'Hi ${customer.fullName.split(' ').first}, ready for fresh laundry?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: colors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a booking and track every step of your laundry order.',
            style: TextStyle(color: colors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 28),
          Text(
            'Quick overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.textPrimary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _OverviewCard(
                  icon: Icons.receipt_long_outlined,
                  label: 'Bookings',
                  value: '$_totalBookingsCount',
                  color: colors.primary,
                  bgColor: colors.chipBg,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OverviewCard(
                  icon: Icons.check_circle_outline,
                  label: 'Completed',
                  value: '$_completedCount',
                  color: colors.success,
                  bgColor: colors.successBg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Nearby shops',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Browse shops and book your laundry.',
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 190,
            child: FutureBuilder<List<Shop>>(
              future: _shopsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _InlineError(message: '${snapshot.error}', onRetry: _reload);
                }
                final shops = snapshot.data ?? [];
                if (shops.isEmpty) {
                  return IllustratedEmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'No shops yet',
                    message: 'Check back soon — new shops are joining LaundryLink regularly.',
                  );
                }
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: shops.length,
                  itemBuilder: (context, index) => Padding(
                    padding: EdgeInsets.only(right: index == shops.length - 1 ? 0 : 14),
                    child: SizedBox(
                      width: 240,
                      child: _ShopCard(shop: shops[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Simpleng shadow/rounded-corner shell na lang ito ngayon — wala nang
/// negative-offset overlap trick, dahil hindi na kailangang "umakyat"
/// papasok sa header. Header at body ay magkahiwalay nang maayos.
class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 22, offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: child,
        ),
      );
}

class _NoActiveBookingBanner extends StatelessWidget {
  const _NoActiveBookingBanner({required this.colors});
  final AppColors colors;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors.primary, colors.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -30, right: -20, child: _bubble(90, Colors.white.withValues(alpha: 0.12))),
            Positioned(bottom: -40, right: 40, child: _bubble(70, Colors.white.withValues(alpha: 0.08))),
            Positioned(bottom: -10, left: -25, child: _bubble(60, Colors.white.withValues(alpha: 0.1))),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.local_laundry_service_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'No active bookings yet\nTap the + button to create one.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, height: 1.45),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _bubble(double size, Color color) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load shops', style: TextStyle(color: context.colors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bgColor, width: 1.5),
        boxShadow: [BoxShadow(color: colors.shadow, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 14),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: colors.textPrimary)),
          Text(label, style: TextStyle(color: colors.textSecondary)),
        ],
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.shop});
  final Shop shop;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ShopDetailPage(shopId: shop.id, shopPreview: shop)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: colors.shadowStrong, blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Container(
                height: 6,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [colors.primary, colors.primaryLight])),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: colors.chipBg, shape: BoxShape.circle),
                        child: Icon(Icons.local_laundry_service_rounded, color: colors.primary, size: 22),
                      ),
                      if (!shop.isOnline)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: colors.neutralBg, borderRadius: BorderRadius.circular(20)),
                          child: Text('Closed', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: colors.neutral)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    shop.shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: colors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          shop.address ?? 'Address not set',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: colors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  if (shop.distanceKm != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: colors.chipBg, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.directions_walk_rounded, size: 13, color: colors.primary),
                          const SizedBox(width: 4),
                          Text(
                            '${shop.distanceKm!.toStringAsFixed(1)} km away',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: colors.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
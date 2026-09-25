import 'dart:async';

import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../theme/app_colors.dart';

/// TOP SECTION — Foodpanda/Grab-style na malaking status banner.
/// Nagpapalit ng icon, kulay, at mensahe base sa kasalukuyang
/// booking.status (kasama ang delivery-specific na rider states).
/// Pulsing animation kapag "waiting" na state (walang pang aktibong
/// rider/machine), steady icon kapag may aktibong progress na.
class LiveStatusBanner extends StatefulWidget {
  const LiveStatusBanner({super.key, required this.booking});
  final Booking booking;

  @override
  State<LiveStatusBanner> createState() => _LiveStatusBannerState();
}

class _LiveStatusBannerState extends State<LiveStatusBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  _BannerConfig _configFor(AppColors colors, Booking b) {
    final isDelivery = b.fulfillmentMode == 'delivery';

    switch (b.status) {
      case BookingStatus.awaitingApproval:
        return _BannerConfig(
          icon: Icons.hourglass_top_rounded,
          color: colors.warning,
          bg: colors.warningBg,
          title: 'Waiting for shop confirmation',
          subtitle: '${b.shopName} hasn\'t accepted your booking request yet.',
          pulsing: true,
        );

      case BookingStatus.awaitingWeighing:
        if (isDelivery) {
          if (b.pickupRiderName == null) {
            return _BannerConfig(
              icon: Icons.pending_actions_rounded,
              color: colors.warning,
              bg: colors.warningBg,
              title: 'Preparing your pickup',
              subtitle: 'Waiting for ${b.shopName} to assign a rider to collect your laundry.',
              pulsing: true,
            );
          }
          return _BannerConfig(
            icon: Icons.pedal_bike_rounded,
            color: colors.primary,
            bg: colors.chipBg,
            title: '${b.pickupRiderName} is on the way',
            subtitle: b.pickupRiderContact != null
                ? 'Heading to pick up your laundry · ${b.pickupRiderContact}'
                : 'Heading to pick up your laundry.',
            pulsing: false,
          );
        }
        return _BannerConfig(
          icon: Icons.scale_outlined,
          color: colors.warning,
          bg: colors.warningBg,
          title: 'Waiting to be weighed',
          subtitle: 'Your laundry is waiting at the counter to be weighed.',
          pulsing: true,
        );

      case BookingStatus.awaitingPayment:
        return _BannerConfig(
          icon: Icons.qr_code_rounded,
          color: colors.warning,
          bg: colors.warningBg,
          title: 'Payment needed',
          subtitle: 'Your final bill is ready — please complete your payment below.',
          pulsing: true,
        );

      case BookingStatus.pending:
        return _BannerConfig(
          icon: Icons.check_circle_outline_rounded,
          color: colors.primary,
          bg: colors.chipBg,
          title: 'Booking confirmed',
          subtitle: 'Your laundry will start processing shortly.',
          pulsing: false,
        );

      case BookingStatus.inProgress:
        return _BannerConfig(
          icon: Icons.local_laundry_service_rounded,
          color: colors.primary,
          bg: colors.chipBg,
          title: 'Your laundry is being cleaned',
          subtitle: 'Washing and drying in progress at ${b.shopName}.',
          pulsing: false,
        );

      case BookingStatus.ready:
        if (isDelivery) {
          if (b.deliveryRiderName != null) {
            return _BannerConfig(
              icon: Icons.delivery_dining_rounded,
              color: colors.success,
              bg: colors.successBg,
              title: '${b.deliveryRiderName} is delivering your laundry',
              subtitle: b.deliveryRiderContact != null
                  ? 'On the way to your address · ${b.deliveryRiderContact}'
                  : 'On the way to your address.',
              pulsing: false,
            );
          }
          return _BannerConfig(
            icon: Icons.inventory_2_outlined,
            color: colors.success,
            bg: colors.successBg,
            title: 'Your laundry is ready',
            subtitle: 'Waiting for a rider to deliver it to you.',
            pulsing: true,
          );
        }
        return _BannerConfig(
          icon: Icons.storefront_rounded,
          color: colors.success,
          bg: colors.successBg,
          title: 'Ready for pickup',
          subtitle: 'Your laundry is ready at ${b.shopName}.',
          pulsing: false,
        );

      case BookingStatus.claimed:
        return _BannerConfig(
          icon: Icons.celebration_rounded,
          color: colors.success,
          bg: colors.successBg,
          title: 'Booking completed',
          subtitle: 'Thank you for choosing ${b.shopName}!',
          pulsing: false,
        );

      case BookingStatus.cancelled:
        return _BannerConfig(
          icon: Icons.cancel_outlined,
          color: colors.neutral,
          bg: colors.neutralBg,
          title: 'Booking cancelled',
          subtitle: 'This booking was cancelled.',
          pulsing: false,
        );

      case BookingStatus.declined:
        return _BannerConfig(
          icon: Icons.block_rounded,
          color: colors.error,
          bg: colors.errorBg,
          title: 'Booking declined',
          subtitle: b.declineReason ?? 'This booking was declined by the shop.',
          pulsing: false,
        );

      case BookingStatus.unknown:
        return _BannerConfig(
          icon: Icons.info_outline_rounded,
          color: colors.neutral,
          bg: colors.neutralBg,
          title: 'Status unavailable',
          subtitle: 'Pull down to refresh.',
          pulsing: false,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final config = _configFor(colors, widget.booking);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: colors.shadowStrong, blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = config.pulsing ? 1.0 + (_pulseController.value * 0.12) : 1.0;
              final glow = config.pulsing ? 0.15 + (_pulseController.value * 0.2) : 0.0;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: config.bg,
                    shape: BoxShape.circle,
                    boxShadow: config.pulsing
                        ? [BoxShadow(color: config.color.withValues(alpha: glow), blurRadius: 16, spreadRadius: 2)]
                        : null,
                  ),
                  child: child,
                ),
              );
            },
            child: Icon(config.icon, color: config.color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: colors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  config.subtitle,
                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerConfig {
  const _BannerConfig({
    required this.icon,
    required this.color,
    required this.bg,
    required this.title,
    required this.subtitle,
    required this.pulsing,
  });
  final IconData icon;
  final Color color;
  final Color bg;
  final String title;
  final String subtitle;
  final bool pulsing;
}
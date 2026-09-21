import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../theme/app_colors.dart';

class BookingStatusTracker extends StatelessWidget {
  const BookingStatusTracker({super.key, required this.booking});
  final Booking booking;

  static const _steps = [
    BookingStatus.pending,
    BookingStatus.inProgress,
    BookingStatus.ready,
    BookingStatus.claimed,
  ];

  bool get _isLinearStatus => _steps.contains(booking.status);

  @override
  Widget build(BuildContext context) {
    if (!_isLinearStatus) {
      return _NonLinearStatusCard(booking: booking);
    }

    final colors = context.colors;
    final currentIndex = _steps.indexOf(booking.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: colors.shadowStrong, blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: colors.chipBg, shape: BoxShape.circle),
                child: Icon(Icons.local_laundry_service_rounded, color: colors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.shopName, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                    Text(booking.serviceName, style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(_steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                final leftDone = (i ~/ 2) <= currentIndex - 1;
                return Expanded(
                  child: Container(
                    height: 3,
                    color: leftDone ? colors.primary : colors.border,
                  ),
                );
              }
              final stepIndex = i ~/ 2;
              final isDone = stepIndex < currentIndex;
              final isCurrent = stepIndex == currentIndex;
              return _StepDot(active: isDone || isCurrent, current: isCurrent);
            }),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _steps
                .map(
                  (step) => Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: step == booking.status ? FontWeight.w700 : FontWeight.w500,
                      color: step == booking.status ? colors.primary : colors.textSecondary,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _NonLinearStatusCard extends StatelessWidget {
  const _NonLinearStatusCard({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final config = _configFor(colors, booking.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: colors.shadowStrong, blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: config.bgColor, shape: BoxShape.circle),
            child: Icon(config.icon, color: config.fgColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.shopName, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                Text(booking.serviceName, style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: config.bgColor, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    config.message,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: config.fgColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _NonLinearStatusConfig _configFor(AppColors colors, BookingStatus status) {
    switch (status) {
      case BookingStatus.awaitingApproval:
        return _NonLinearStatusConfig(
          icon: Icons.hourglass_top_rounded,
          bgColor: colors.warningBg,
          fgColor: colors.warning,
          message: 'Waiting for shop to accept',
        );
      // NEW (Weighing / Finalize Pricing feature) — booking na na-accept
      // na ng shop pero hinihintay pa timbangin/i-presyuhan.
      case BookingStatus.awaitingWeighing:
        return _NonLinearStatusConfig(
          icon: Icons.scale_outlined,
          bgColor: colors.warningBg,
          fgColor: colors.warning,
          message: 'Waiting for shop to weigh your laundry',
        );
      // NEW (Weighing / Finalize Pricing + Online Payment feature) —
      // na-finalize na ang presyo, online ang payment method, hinihintay
      // pa ang customer magbayad/mag-upload ng proof.
      case BookingStatus.awaitingPayment:
        return _NonLinearStatusConfig(
          icon: Icons.qr_code_rounded,
          bgColor: colors.warningBg,
          fgColor: colors.warning,
          message: 'Ready for payment',
        );
      case BookingStatus.cancelled:
        return _NonLinearStatusConfig(
          icon: Icons.cancel_outlined,
          bgColor: colors.neutralBg,
          fgColor: colors.neutral,
          message: 'Cancelled',
        );
      case BookingStatus.declined:
        return _NonLinearStatusConfig(
          icon: Icons.block_rounded,
          bgColor: colors.errorBg,
          fgColor: colors.error,
          message: 'Declined by shop',
        );
      case BookingStatus.pending:
      case BookingStatus.inProgress:
      case BookingStatus.ready:
      case BookingStatus.claimed:
      case BookingStatus.unknown:
        return _NonLinearStatusConfig(
          icon: Icons.info_outline_rounded,
          bgColor: colors.neutralBg,
          fgColor: colors.neutral,
          message: 'Status unavailable',
        );
    }
  }
}

class _NonLinearStatusConfig {
  const _NonLinearStatusConfig({
    required this.icon,
    required this.bgColor,
    required this.fgColor,
    required this.message,
  });
  final IconData icon;
  final Color bgColor;
  final Color fgColor;
  final String message;
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.active, required this.current});
  final bool active;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: current ? 18 : 14,
      height: current ? 18 : 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? colors.primary : colors.border,
        border: current ? Border.all(color: colors.borderStrong, width: 4) : null,
      ),
    );
  }
}
// ============================= history_page.dart =============================
import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../services/booking_service.dart';
import '../theme/app_colors.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final BookingService _bookingService = BookingService();
  late Future<List<Booking>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _bookingsFuture = _bookingService.getMyBookings();
  }

  Future<void> _reload() async {
    setState(() {
      _bookingsFuture = _bookingService.getMyBookings();
    });
    await _bookingsFuture;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Booking>>(
        future: _bookingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(message: '${snapshot.error}', onRetry: _reload);
          }

          final bookings = snapshot.data ?? [];
          if (bookings.isEmpty) {
            return _EmptyState(onRefresh: _reload);
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
              itemCount: bookings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _BookingHistoryCard(booking: bookings[index]),
            ),
          );
        },
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 60),
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colors.chipBg, shape: BoxShape.circle),
              child: Icon(Icons.history_rounded, size: 44, color: colors.primary),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No bookings yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Your laundry orders will appear here once you book a service.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.errorBg, shape: BoxShape.circle),
            child: Icon(Icons.error_outline_rounded, size: 32, color: colors.error),
          ),
          const SizedBox(height: 14),
          Text('Failed to load your bookings', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(message, style: TextStyle(color: colors.textMuted, fontSize: 11.5)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _BookingHistoryCard extends StatelessWidget {
  const _BookingHistoryCard({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = _statusStyle(colors, booking.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border, width: 1),
        boxShadow: [BoxShadow(color: colors.shadowStrong, blurRadius: 16, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: colors.chipBg, borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.local_laundry_service_rounded, color: colors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.shopName.isEmpty ? 'Laundry Shop' : booking.shopName,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(booking.serviceName, style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: style.fg, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      booking.status.label,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: style.fg),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (booking.status == BookingStatus.declined && (booking.declineReason?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.errorBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.errorBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: colors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      booking.declineReason!,
                      style: TextStyle(fontSize: 11.5, color: colors.error, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetaChip(icon: Icons.event_outlined, label: _formatDate(booking.bookingTimestamp)),
              const SizedBox(width: 8),
              if (booking.totalPrice != null)
                _MetaChip(icon: Icons.payments_outlined, label: '₱${booking.totalPrice!.toStringAsFixed(2)}'),
              if (booking.fulfillmentMode != null) ...[
                const SizedBox(width: 8),
                _MetaChip(
                  icon: booking.fulfillmentMode == 'delivery' ? Icons.local_shipping_outlined : Icons.storefront_outlined,
                  label: booking.fulfillmentMode == 'delivery' ? 'Delivery' : 'Drop-off',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  _StatusStyle _statusStyle(AppColors colors, BookingStatus status) {
    switch (status) {
      case BookingStatus.awaitingApproval:
        return _StatusStyle(bg: colors.warningBg, fg: colors.warning);
      case BookingStatus.awaitingWeighing:
        return _StatusStyle(bg: colors.warningBg, fg: colors.warning);
      case BookingStatus.awaitingPayment:
        return _StatusStyle(bg: colors.warningBg, fg: colors.warning);
      case BookingStatus.pending:
        return _StatusStyle(bg: colors.chipBg, fg: colors.primary);
      case BookingStatus.inProgress:
        return _StatusStyle(bg: colors.statusInProgressBg, fg: colors.statusInProgress);
      case BookingStatus.ready:
        return _StatusStyle(bg: colors.statusReadyBg, fg: colors.statusReady);
      case BookingStatus.claimed:
        return _StatusStyle(bg: colors.successBg, fg: colors.success);
      case BookingStatus.cancelled:
        return _StatusStyle(bg: colors.neutralBg, fg: colors.neutral);
      case BookingStatus.declined:
        return _StatusStyle(bg: colors.errorBg, fg: colors.error);
      case BookingStatus.unknown:
        return _StatusStyle(bg: colors.neutralBg, fg: colors.neutral);
    }
  }
}

class _StatusStyle {
  const _StatusStyle({required this.bg, required this.fg});
  final Color bg;
  final Color fg;
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: colors.neutralBg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.textMuted),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: colors.neutral)),
        ],
      ),
    );
  }
}
// ============================= lib/widgets/order_timeline_tracker.dart =============================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/booking.dart';
import '../theme/app_colors.dart';
import 'countdown_timer.dart';
import 'payment_action_modal.dart';

/// MID SECTION — vertical timeline. 5 nodes para sa drop-off, 6-7 para
/// sa delivery. Dagdag ang "Payment" node sa pagitan ng "Weighed" at
/// "Washing" — lumalabas lang kapag status == awaitingPayment, at
/// naglalaman ng button na nagbubukas ng payment action modal.
class OrderTimelineTracker extends StatelessWidget {
  const OrderTimelineTracker({super.key, required this.booking, required this.onRefresh});

  final Booking booking;

  /// Called after the payment modal closes (whether or not anything
  /// changed) — triggers a silent parent re-fetch so a submitted proof
  /// or a staff-side verification picked up mid-modal reflects
  /// immediately rather than waiting for the next poll tick.
  final VoidCallback onRefresh;

  List<_Node> _buildNodes(BuildContext context) {
    final isDelivery = booking.fulfillmentMode == 'delivery';
    final nodes = <_Node>[
      _Node(
        title: 'Request Received',
        description: 'Your booking request has been received.',
        timestamp: booking.createdAt,
      ),
    ];

    if (isDelivery) {
      nodes.add(_Node(
        title: 'Courier Assigned for Pick-up',
        description: booking.pickupRiderName != null
            ? '${booking.pickupRiderName} is heading to collect your laundry.'
            : 'Waiting for the shop to assign a rider.',
        timestamp: booking.pickupRiderAssignedAt,
        riderName: booking.pickupRiderName,
        riderContact: booking.pickupRiderContact,
      ));
    }

    nodes.add(_Node(
      title: 'Weighed / Price Confirmed',
      description: booking.finalWeight != null
          ? 'Weighed at ${booking.finalWeight} — final price set.'
          : 'Waiting for the shop to weigh your laundry.',
      timestamp: booking.weighedAt,
    ));

    // NEW — Payment node. Only meaningfully "actionable" while the
    // booking sits at Awaiting Payment; once paid, this node just
    // shows as reached (timestamp = paidAt) with no button, same
    // pattern as every other node.
    if (booking.status == BookingStatus.awaitingPayment || booking.paidAt != null) {
      nodes.add(_Node(
        title: 'Payment',
        description: booking.paidAt != null
            ? 'Payment confirmed. Thank you!'
            : (booking.paymentStatus == 'pending_verification'
                ? 'Your payment is under review by the shop.'
                : 'Your final bill is ready — please complete payment.'),
        timestamp: booking.paidAt,
        actionLabel: booking.paidAt == null
            ? (booking.paymentStatus == 'pending_verification' ? 'View Receipt' : 'Pay Now')
            : null,
        onAction: booking.paidAt == null
            ? () => showPaymentActionModal(context, booking: booking, onUpdated: onRefresh)
            : null,
      ));
    }

    nodes.add(_Node(
      title: 'Washing & Drying In Progress',
      description: 'Your laundry is currently being cleaned.',
      timestamp: booking.startedAt,
      countdownTarget: (booking.status == BookingStatus.inProgress && booking.estimatedCompletionTime != null)
          ? booking.estimatedCompletionTime
          : null,
      countdownPhase: booking.activePhase,
    ));

    if (isDelivery) {
      nodes.add(_Node(
        title: 'Ready — Rider Returning',
        description: booking.deliveryRiderName != null
            ? '${booking.deliveryRiderName} is on the way to deliver your fresh laundry.'
            : 'Your laundry is ready and waiting for a delivery rider.',
        timestamp: booking.readyAt,
        riderName: booking.deliveryRiderName,
        riderContact: booking.deliveryRiderContact,
      ));
    } else {
      nodes.add(_Node(
        title: 'Ready for Pickup',
        description: 'Your laundry is ready for pickup at the shop.',
        timestamp: booking.readyAt,
      ));
    }

    nodes.add(_Node(
      title: 'Completed',
      description: 'This booking has been completed. Thank you!',
      timestamp: booking.completedAt,
    ));

    return nodes;
  }

  String _formatTimestamp(DateTime? utc) {
    if (utc == null) return 'Pending';
    final local = utc.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year && local.month == now.month && local.day == now.day;
    final timePart = DateFormat('hh:mm a').format(local);
    if (isToday) return timePart;
    return '$timePart · ${DateFormat('MM/dd').format(local)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final nodes = _buildNodes(context);
    final lastReachedIndex = nodes.lastIndexWhere((n) => n.timestamp != null);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: colors.shadowStrong, blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: List.generate(nodes.length, (index) {
          final node = nodes[index];
          final isReached = index <= lastReachedIndex;
          final isLast = index == nodes.length - 1;
          return _buildRow(colors, node, isReached, isLast);
        }),
      ),
    );
  }

  Widget _buildRow(AppColors colors, _Node node, bool isReached, bool isLast) {
    final dotColor = isReached ? colors.primary : colors.border;
    final titleColor = isReached ? colors.textPrimary : colors.textMuted;
    final descColor = isReached ? colors.textSecondary : colors.textMuted;
    final timeColor = isReached ? colors.primary : colors.textMuted;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
                child: Icon(
                  isReached ? Icons.check : Icons.circle,
                  size: isReached ? 15 : 7,
                  color: Colors.white,
                ),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: dotColor)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          node.title,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: titleColor),
                        ),
                      ),
                      Text(
                        _formatTimestamp(node.timestamp),
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: timeColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(node.description, style: TextStyle(fontSize: 12.5, color: descColor, height: 1.4)),
                  if (node.riderName != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: colors.chipBg, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 15, color: colors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              node.riderContact != null ? '${node.riderName} · ${node.riderContact}' : node.riderName!,
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: colors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (node.countdownTarget != null) ...[
                    const SizedBox(height: 10),
                    CountdownTimer(targetTime: node.countdownTarget!, phase: node.countdownPhase),
                  ],
                  if (node.actionLabel != null && node.onAction != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: node.onAction,
                        icon: const Icon(Icons.payments_outlined, size: 16),
                        label: Text(node.actionLabel!),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Node {
  const _Node({
    required this.title,
    required this.description,
    required this.timestamp,
    this.riderName,
    this.riderContact,
    this.countdownTarget,
    this.countdownPhase,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String description;
  final DateTime? timestamp;
  final String? riderName;
  final String? riderContact;
  final DateTime? countdownTarget;
  final String? countdownPhase;
  final String? actionLabel;
  final VoidCallback? onAction;
}
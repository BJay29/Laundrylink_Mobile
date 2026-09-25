import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../theme/app_colors.dart';
import '../utils/time_utils.dart';

/// BOTTOM SECTION — "nakatiklop na resibo". Collapsed by default;
/// pag-tap sa "View Invoice Details" ang siyang magbubukas ng buong
/// listahan ng detalye (dating naka-tambak agad sa card body).
class CollapsibleInvoiceCard extends StatefulWidget {
  const CollapsibleInvoiceCard({super.key, required this.booking});
  final Booking booking;

  @override
  State<CollapsibleInvoiceCard> createState() => _CollapsibleInvoiceCardState();
}

class _CollapsibleInvoiceCardState extends State<CollapsibleInvoiceCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final b = widget.booking;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 17, color: colors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'View Invoice Details',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: colors.textPrimary),
                      ),
                    ],
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, color: colors.border),
                  const SizedBox(height: 10),
                  if (b.totalPrice != null) _DetailRow(label: 'Total', value: '₱${b.totalPrice!.toStringAsFixed(0)}'),
                  if (b.weight != null && b.weight! > 0)
                    _DetailRow(label: 'Weight', value: '${b.weight!.toStringAsFixed(1)} kg'),
                  if (b.loads != null && b.loads! > 0) _DetailRow(label: 'Loads', value: '${b.loads}'),
                  if (b.fulfillmentMode != null)
                    _DetailRow(label: 'Fulfillment', value: b.fulfillmentMode == 'delivery' ? 'Delivery' : 'Drop-off'),
                  if (b.deliveryFeeCharged != null && b.deliveryFeeCharged! > 0)
                    _DetailRow(label: 'Delivery fee', value: '₱${b.deliveryFeeCharged!.toStringAsFixed(0)}'),
                  if (b.deliveryAddressLine != null && b.deliveryAddressLine!.trim().isNotEmpty)
                    _DetailRow(label: 'Deliver to', value: b.deliveryAddressLine!),
                  if (b.pickupDatetime != null)
                    _DetailRow(
                      label: 'Pickup',
                      value: '${b.pickupDatetime!.month}/${b.pickupDatetime!.day} '
                          '${b.pickupDatetime!.hour.toString().padLeft(2, '0')}:'
                          '${b.pickupDatetime!.minute.toString().padLeft(2, '0')}',
                    ),
                  if (b.pickupRiderName != null)
                    _DetailRow(
                      label: 'Pickup rider',
                      value: b.pickupRiderContact != null ? '${b.pickupRiderName} · ${b.pickupRiderContact}' : b.pickupRiderName!,
                    ),
                  if (b.deliveryRiderName != null)
                    _DetailRow(
                      label: 'Delivery rider',
                      value: b.deliveryRiderContact != null
                          ? '${b.deliveryRiderName} · ${b.deliveryRiderContact}'
                          : b.deliveryRiderName!,
                    ),
                  if (b.promoCode != null)
                    _DetailRow(label: 'Promo', value: '${b.promoCode} (-₱${b.discountAmount?.toStringAsFixed(0) ?? '0'})'),
                  if (b.specialInstructions != null && b.specialInstructions!.trim().isNotEmpty)
                    _DetailRow(label: 'Notes', value: b.specialInstructions!),
                  if (b.status == BookingStatus.declined && b.declineReason != null)
                    _DetailRow(label: 'Reason', value: b.declineReason!),
                  if (b.bookingTimestamp != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Booked ${formatTimeAgo(b.bookingTimestamp)}',
                      style: TextStyle(fontSize: 11, color: colors.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
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
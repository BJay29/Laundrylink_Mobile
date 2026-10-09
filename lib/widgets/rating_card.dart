import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../services/api_service.dart';
import '../services/booking_service.dart';
import '../theme/app_colors.dart';
import 'rating_badge.dart';

/// Read-only na hanay ng 5 bituin (puno hanggang [rating]). Ginagamit sa
/// RatingCard kapag nakapag-rate na, at sa History page.
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating, this.size = 16});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = index < rating;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: filled ? kStarColor : colors.border,
        );
      }),
    );
  }
}

/// NEW (Rating after order) — "Rate your experience" card.
///
/// Kailangan lang ipakita para sa booking na "Claimed" na (ang caller
/// ang nagpapasya niyan — see booking_page.dart at history_page.dart).
///
/// Dalawang anyo:
///   1. Form — kapag hindi pa nakapag-rate ang customer: 5 bituin na
///      pwedeng i-tap, opsyonal na komento (hanggang 300 characters), at
///      Submit button na naka-disable hangga't walang napiling bituin.
///   2. Read-only — kapag nakapag-rate na (booking.hasRated) o kasisubmit
///      lang: ipinapakita ang bituin at komento. Hindi na mababago.
///
/// Pagkatapos ng matagumpay na submit, tinatawag ang [onSubmitted] para
/// mag-refresh ang listahan ng bookings (para dumating ang hasRated =
/// true mula sa backend). Kapag 409 ("nakapag-rate ka na", hal. double
/// tap o na-rate sa ibang device), tinatawag din ang [onSubmitted] para
/// makuha ang naka-save na rating.
class RatingCard extends StatefulWidget {
  const RatingCard({super.key, required this.booking, required this.onSubmitted});

  final Booking booking;
  final VoidCallback onSubmitted;

  @override
  State<RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends State<RatingCard> {
  static const int _maxCommentLength = 300;
  static const List<String> _labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  final BookingService _bookingService = BookingService();
  final TextEditingController _commentController = TextEditingController();

  int _rating = 0;
  bool _submitting = false;
  bool _justSubmitted = false;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final bookingId = widget.booking.id;
    if (_rating == 0 || _submitting || bookingId == null) return;

    // Kinukuha bago ang await, para ligtas gamitin kahit na-pop na ang
    // widget (hal. kapag nasa bottom sheet ito).
    final messenger = ScaffoldMessenger.of(context);
    final colors = context.colors;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _bookingService.submitReview(
        bookingId: bookingId,
        rating: _rating,
        comment: _commentController.text,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _justSubmitted = true;
      });
      messenger.showSnackBar(
        SnackBar(content: const Text('Thanks for your feedback!'), backgroundColor: colors.success),
      );
      widget.onSubmitted();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      if (e.statusCode == 409) {
        // Nakapag-rate na pala — i-refresh para makuha ang naka-save.
        messenger.showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: colors.neutral),
        );
        widget.onSubmitted();
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Unable to submit your rating. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final alreadyRated = booking.hasRated || _justSubmitted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: context.colors.shadowStrong, blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: alreadyRated ? _buildReadOnly(context) : _buildForm(context),
    );
  }

  Widget _buildReadOnly(BuildContext context) {
    final colors = context.colors;
    final booking = widget.booking;

    final rating = booking.rating ?? _rating;
    final comment = booking.ratingComment ??
        (_justSubmitted && _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your rating', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colors.textPrimary)),
        const SizedBox(height: 10),
        Row(
          children: [
            RatingStars(rating: rating, size: 24),
            const SizedBox(width: 10),
            if (rating >= 1 && rating <= 5)
              Text(
                _labels[rating],
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.textSecondary),
              ),
          ],
        ),
        if (comment != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: colors.chipBg, borderRadius: BorderRadius.circular(12)),
            child: Text(
              comment,
              style: TextStyle(fontSize: 12.5, color: colors.textPrimary, height: 1.4),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    final colors = context.colors;
    final shopName = widget.booking.shopName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'How was your experience?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: colors.textPrimary),
        ),
        if (shopName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Rate your order at $shopName',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final value = index + 1;
            final selected = value <= _rating;
            return IconButton(
              onPressed: _submitting ? null : () => setState(() => _rating = value),
              iconSize: 38,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 46, minHeight: 46),
              icon: Icon(
                selected ? Icons.star_rounded : Icons.star_outline_rounded,
                color: selected ? kStarColor : colors.border,
              ),
            );
          }),
        ),
        SizedBox(
          height: 20,
          child: Center(
            child: Text(
              _rating == 0 ? 'Tap a star to rate' : _labels[_rating],
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _rating == 0 ? colors.textMuted : colors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _commentController,
          enabled: !_submitting,
          maxLength: _maxCommentLength,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Tell us about your experience (optional)',
            hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.primary, width: 1.4),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 4),
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
                  child: Text(_error!, style: TextStyle(fontSize: 11.5, color: colors.error, height: 1.3)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: (_rating == 0 || _submitting) ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit rating', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
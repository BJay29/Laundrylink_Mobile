import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/booking.dart';
import '../models/shop.dart';
import '../services/booking_service.dart';
import '../services/shop_service.dart';
import '../services/upload_service.dart';
import '../theme/app_colors.dart';

/// Opens the payment action bottom sheet for a booking sitting at
/// "Awaiting Payment" (price already finalized by the shop). Called
/// from the "Payment" node in OrderTimelineTracker.
///
/// Two branches, decided by `booking.paymentMethod`:
///   - "online_qr": QR display + save-to-gallery + upload proof +
///     submit -> receipt/under-review state.
///   - "cash" / "cod": simple instructions block (no upload needed —
///     settled in person). Just a "Got it" dismiss.
///
/// [onUpdated] is called after a successful proof submission so the
/// caller can trigger a silent refresh (the real status transition
/// itself arrives via the existing customer WebSocket push once staff
/// verifies on the web side — this callback just nudges an immediate
/// re-fetch rather than waiting for the next poll tick).
///
/// UPDATED (layout compaction, round 2) — the online-payment branch's
/// sheet height (initialChildSize/maxChildSize) was previously sized
/// at 0.9/0.95, left over from before the QR and upload box were
/// shrunk. That left a large empty gap below the "Submit Payment"
/// button. Sheet height is now 0.62/0.68 so it hugs the actual content
/// height instead. QR is 130x130, upload box is 90 tall, and all
/// spacing/padding/font sizes throughout are compacted so the whole
/// flow — bill, QR, save button, upload box, and submit button — fits
/// without needing to scroll to find the button.
///
/// UPDATED (receipt UI polish) — _ReceiptView redesigned: animated
/// check-circle entrance (scale+fade), a "receipt ticket" card with a
/// dashed divider separating the summary rows from the reference
/// details, a status pill, and a "press down" Close button. No logic
/// changed anywhere in this file — same fields, same calls, same
/// states.
Future<void> showPaymentActionModal(
  BuildContext context, {
  required Booking booking,
  required VoidCallback onUpdated,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaymentActionSheet(booking: booking, onUpdated: onUpdated),
  );
}

class _PaymentActionSheet extends StatelessWidget {
  const _PaymentActionSheet({required this.booking, required this.onUpdated});

  final Booking booking;
  final VoidCallback onUpdated;

  bool get _isCashLike => booking.paymentMethod == 'cash' || booking.paymentMethod == 'cod';

  @override
  Widget build(BuildContext context) {
    // Sheet height as a fraction of the screen. Cash/COD stays small
    // (0.42) since it's just a short instructions block. Online
    // payment is 0.62/0.68 so the sheet hugs the actual content
    // instead of leaving a big empty gap below the Submit button.
    return DraggableScrollableSheet(
      initialChildSize: _isCashLike ? 0.42 : 0.62,
      minChildSize: 0.3,
      maxChildSize: 0.68,
      expand: false,
      builder: (context, scrollController) {
        final colors = context.colors;
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(4)),
              ),
              Expanded(
                child: _isCashLike
                    ? _CashInstructions(booking: booking, scrollController: scrollController)
                    : _OnlinePaymentFlow(
                        booking: booking,
                        scrollController: scrollController,
                        onUpdated: onUpdated,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Cash / COD branch — no upload, just tells the customer how much to
/// prepare and where/how they'll pay.
class _CashInstructions extends StatelessWidget {
  const _CashInstructions({required this.booking, required this.scrollController});

  final Booking booking;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final price = booking.finalPrice ?? booking.estimatedPrice;
    final label = booking.fulfillmentMode == 'delivery' ? 'upon delivery' : 'upon pickup at the shop';

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.chipBg, shape: BoxShape.circle),
            child: Icon(Icons.payments_rounded, color: colors.primary, size: 26),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Payment Due',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: colors.textPrimary),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: colors.chipBg, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Amount due', style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                  Text(
                    price != null ? '₱${price.toStringAsFixed(2)}' : '—',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: colors.primary),
                  ),
                ],
              ),
              if (booking.finalWeight != null) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Weighed', style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                    Text('${booking.finalWeight} kg', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Please prepare the exact amount — you\'ll settle this in cash $label.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: colors.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

/// Online QR branch — full flow: bill breakdown, QR (fetched from the
/// shop), save-to-gallery, upload proof, submit -> receipt/under-review.
class _OnlinePaymentFlow extends StatefulWidget {
  const _OnlinePaymentFlow({
    required this.booking,
    required this.scrollController,
    required this.onUpdated,
  });

  final Booking booking;
  final ScrollController scrollController;
  final VoidCallback onUpdated;

  @override
  State<_OnlinePaymentFlow> createState() => _OnlinePaymentFlowState();
}

class _OnlinePaymentFlowState extends State<_OnlinePaymentFlow> {
  final BookingService _bookingService = BookingService();
  final UploadService _uploadService = UploadService();
  final ImagePicker _imagePicker = ImagePicker();

  Shop? _shop;
  bool _loadingShop = true;

  /// FIXED (Flutter Web support): dating `File? _selectedProofImage`
  /// (dart:io) — ipinapakita gamit ang `Image.file`, na hindi
  /// suportado sa Flutter Web ("Image.file is not supported on
  /// Flutter Web" sa error log). Ngayon, `XFile` (cross-platform, mula
  /// mismo sa image_picker) ang tinatago, kasabay ng cached na bytes
  /// (`_selectedProofBytes`) para sa preview gamit ang `Image.memory`
  /// — gumagana ito pareho sa web at mobile.
  XFile? _selectedProofImage;
  Uint8List? _selectedProofBytes;

  bool _submitting = false;
  bool _submitted = false;
  String? _errorMessage;

  bool get _alreadyPendingVerification => widget.booking.paymentStatus == 'pending_verification';

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  Future<void> _loadShop() async {
    final shopId = widget.booking.shopId;
    if (shopId == null) {
      setState(() => _loadingShop = false);
      return;
    }
    try {
      final shop = await ShopService().getShopDetail(shopId);
      if (!mounted) return;
      setState(() {
        _shop = shop;
        _loadingShop = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingShop = false);
    }
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;

    // Read bytes once, up front — needed for the Image.memory preview
    // regardless of platform, and reused later for the actual upload
    // (UploadService.uploadPaymentProof also reads via image.readAsBytes(),
    // but reading it here too just for the preview is fine — image_picker
    // keeps the underlying blob/file available for repeat reads).
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selectedProofImage = image;
      _selectedProofBytes = bytes;
      _errorMessage = null;
    });
  }

  Future<void> _saveQrToGallery(String qrUrl) async {
    try {
      await _uploadService.saveNetworkImageToGallery(qrUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR code saved to your gallery.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the QR code. Please try again.')),
      );
    }
  }

  Future<void> _submit() async {
    final bookingId = widget.booking.id;
    final image = _selectedProofImage;
    if (bookingId == null || image == null) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final proofUrl = await _uploadService.uploadPaymentProof(imageFile: image, bookingId: bookingId);
      await _bookingService.submitPaymentProof(bookingId: bookingId, proofOfPaymentUrl: proofUrl);

      if (!mounted) return;
      setState(() {
        _submitted = true;
        _submitting = false;
      });
      widget.onUpdated();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = 'Could not submit your payment proof. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted || _alreadyPendingVerification) {
      return _ReceiptView(booking: widget.booking, scrollController: widget.scrollController);
    }

    final colors = context.colors;
    final b = widget.booking;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
      children: [
        Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: colors.primary, size: 20),
            const SizedBox(width: 8),
            Text('Complete Your Payment', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: colors.textPrimary)),
          ],
        ),
        const SizedBox(height: 10),

        // Bill breakdown — compacted padding/spacing.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: colors.chipBg, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              _billRow(colors, 'Weighed', b.finalWeight != null ? '${b.finalWeight} kg' : '—'),
              const SizedBox(height: 4),
              _billRow(colors, 'Amount due', b.finalPrice != null ? '₱${b.finalPrice!.toStringAsFixed(2)}' : '—', emphasize: true),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // QR section — shrunk from 200x200 to 130x130, tighter labels.
        Text('Scan to pay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.textSecondary)),
        const SizedBox(height: 6),
        if (_loadingShop)
          const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 14), child: CircularProgressIndicator()))
        else if (_shop?.qrCodeUrl == null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: colors.warningBg, borderRadius: BorderRadius.circular(12)),
            child: Text(
              "This shop hasn't set up their QR code yet. Please contact them directly to settle payment.",
              style: TextStyle(fontSize: 12, color: colors.warning),
            ),
          )
        else ...[
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              // Image.network is fine on both web and mobile — this
              // one was never the problem, only the local proof
              // preview below (Image.file) was.
              child: Image.network(_shop!.qrCodeUrl!, width: 130, height: 130, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: TextButton.icon(
              onPressed: () => _saveQrToGallery(_shop!.qrCodeUrl!),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Save QR to Gallery', style: TextStyle(fontSize: 12.5)),
            ),
          ),
        ],

        const SizedBox(height: 12),
        Text('Upload proof of payment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.textSecondary)),
        const SizedBox(height: 6),
        InkWell(
          onTap: _submitting ? null : _pickImage,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            // Shrunk from 150 to 90 — was the single biggest reason the
            // Submit button needed a scroll to reach.
            height: 90,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _selectedProofBytes == null ? colors.border : colors.primary),
            ),
            child: _selectedProofBytes == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 22, color: colors.primary),
                        const SizedBox(height: 5),
                        Text('Tap to attach a screenshot', style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    // FIXED: Image.memory instead of Image.file — works
                    // on Flutter Web (no real filesystem there) as well
                    // as mobile.
                    child: Image.memory(_selectedProofBytes!, fit: BoxFit.cover, width: double.infinity, height: 90),
                  ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(_errorMessage!, style: TextStyle(fontSize: 11.5, color: colors.error)),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: (_selectedProofImage == null || _submitting) ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Submit Payment', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _billRow(AppColors colors, String label, String value, {bool emphasize = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 16 : 12,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: emphasize ? colors.primary : colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Receipt / "Under Review" state — shown right after a successful
/// submit, and again on reopen while payment_status is still
/// "pending_verification" (so navigating away and back shows the same
/// state instead of the upload form again).
///
/// UPDATED (UI polish) — redesigned as a "receipt ticket" card: an
/// animated check-circle (scale+fade entrance, subtle glow) up top, a
/// status pill under the title, a summary block (Amount + Method)
/// separated by a dashed "tear line" from a Reference-code block
/// below it (classic printed-receipt look), and a "press down" tap
/// scale on the Close button. Same fields/data as before — booking.id,
/// finalPrice, paymentMethod, paymentRejectionReason — nothing new is
/// read from the model.
class _ReceiptView extends StatefulWidget {
  const _ReceiptView({required this.booking, required this.scrollController});

  final Booking booking;
  final ScrollController scrollController;

  @override
  State<_ReceiptView> createState() => _ReceiptViewState();
}

class _ReceiptViewState extends State<_ReceiptView> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Animation<double> _fadeFor(double start, double end) => CurvedAnimation(
        parent: _entrance,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );

  Widget _staggered({required double start, required double end, required Widget child}) {
    final fade = _fadeFor(start, end);
    return AnimatedBuilder(
      animation: fade,
      builder: (context, _) => Opacity(
        opacity: fade.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - fade.value) * 14),
          child: child,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final booking = widget.booking;
    final checkCurve = CurvedAnimation(parent: _entrance, curve: const Interval(0.0, 0.55, curve: Curves.elasticOut));

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      children: [
        // Animated check-circle — scale in with a soft elastic pop,
        // plus a subtle glow ring behind it.
        Center(
          child: AnimatedBuilder(
            animation: checkCurve,
            builder: (context, child) => Transform.scale(
              scale: checkCurve.value.clamp(0.0, 1.2),
              child: Opacity(opacity: _entrance.value.clamp(0.0, 1.0), child: child),
            ),
            child: Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [colors.warning.withOpacity(0.22), colors.warning.withOpacity(0.08)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: colors.warning.withOpacity(0.18), blurRadius: 24, spreadRadius: 2),
                ],
              ),
              child: Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: colors.warningBg, shape: BoxShape.circle),
                child: Icon(Icons.hourglass_top_rounded, color: colors.warning, size: 26),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _staggered(
          start: 0.35,
          end: 0.75,
          child: Text(
            'Payment Submitted',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: colors.textPrimary),
          ),
        ),
        const SizedBox(height: 8),
        // Status pill — quick-glance state, sits right under the title.
        _staggered(
          start: 0.4,
          end: 0.8,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: colors.warningBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.warning.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: colors.warning, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Under review',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colors.warning),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _staggered(
          start: 0.45,
          end: 0.85,
          child: Text(
            'The shop is verifying your payment. You\'ll be notified — and your tracking will continue automatically — once it\'s confirmed.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: colors.textSecondary, height: 1.5),
          ),
        ),
        const SizedBox(height: 20),

        // "Receipt ticket" card — summary up top, dashed tear line,
        // reference code below. Classic printed-receipt silhouette.
        _staggered(
          start: 0.5,
          end: 0.9,
          child: Container(
            decoration: BoxDecoration(
              color: colors.chipBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border.withOpacity(0.6)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Amount', style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                          Text(
                            booking.finalPrice != null ? '₱${booking.finalPrice!.toStringAsFixed(2)}' : '—',
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: colors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Method', style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                          Row(
                            children: [
                              Icon(Icons.qr_code_2_rounded, size: 14, color: colors.textPrimary),
                              const SizedBox(width: 5),
                              Text(
                                booking.paymentMethod == 'online_qr' ? 'Online (QR Ph)' : (booking.paymentMethod ?? '—'),
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: colors.textPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Dashed "tear line" between the summary and the
                // reference code, like a physical receipt.
                CustomPaint(
                  size: const Size(double.infinity, 1),
                  painter: _DashedLinePainter(color: colors.border),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.confirmation_number_outlined, size: 14, color: colors.textMuted),
                          const SizedBox(width: 6),
                          Text('Reference', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                        ],
                      ),
                      Text(
                        '#${booking.id ?? '—'}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.textPrimary, letterSpacing: 0.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        if (booking.paymentRejectionReason != null) ...[
          const SizedBox(height: 14),
          _staggered(
            start: 0.55,
            end: 0.95,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.errorBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.errorBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline_rounded, size: 15, color: colors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Previously rejected: ${booking.paymentRejectionReason}',
                      style: TextStyle(fontSize: 12, color: colors.error, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 22),
        _staggered(
          start: 0.6,
          end: 1.0,
          child: SizedBox(
            width: double.infinity,
            child: _TapScale(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                ),
                child: OutlinedButton(
                  onPressed: null, // handled by _TapScale's Listener
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                    disabledForegroundColor: colors.textSecondary,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Paints a horizontal dashed line — used as the "tear line" in the
/// receipt ticket card.
class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) => oldDelegate.color != color;
}

/// "Press down" tap scale — Listener-based (raw pointer, no tap-gesture
/// recognizer) so it never conflicts with the real onPressed on the
/// button underneath, same fix used across the auth pages.
class _TapScale extends StatefulWidget {
  const _TapScale({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}
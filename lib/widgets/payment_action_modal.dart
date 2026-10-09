import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/booking.dart';
import '../models/shop.dart';
import '../services/booking_service.dart';
import '../services/shop_service.dart';
import '../services/upload_service.dart';
import '../theme/app_colors.dart';

/// Allowed file extensions for the uploaded receipt. Document extensions
/// (.pdf especially) are blocked outright — image_picker's gallery source
/// already filters to images, but a renamed/misreported file could slip
/// through on some platforms, so this is re-checked against the picked
/// file's own name as a second guard.
const Set<String> _kAllowedReceiptExtensions = {'jpg', 'jpeg', 'png'};

/// Format rule mirrored from the backend's REFERENCE_NUMBER_PATTERN
/// (schemas.py): 6-20 characters, letters/numbers/dashes only. Kept
/// deliberately loose since the shop may accept GCash, Maya, or bank
/// transfer reference numbers — the backend remains the source of truth.
final RegExp _kReferenceNumberPattern = RegExp(r'^[A-Za-z0-9-]{6,20}$');

/// Opens the payment action bottom sheet for a booking sitting at
/// "Awaiting Payment" (price already finalized by the shop). Called
/// from the "Payment" node in OrderTimelineTracker.
///
/// Two branches, decided by `booking.paymentMethod`:
///   - "online_qr": QR display + save-to-gallery + reference number +
///     upload proof + submit -> receipt/under-review state.
///   - "cash" / "cod": simple instructions block (no upload needed).
///
/// [onUpdated] is called after a successful proof submission so the
/// caller can trigger a silent refresh.
///
/// UPDATED (Secure Payment Verification System): required reference
/// number (format-checked), JPEG/PNG-only check, instant submit masking.
///
/// FIXED (Receipt reference bug): after a successful submit, the
/// booking returned by submitPaymentProof() is kept (_submittedBooking)
/// and passed to the receipt view, so the customer's actual reference
/// number is shown instead of the "#bookingId" fallback.
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
    return DraggableScrollableSheet(
      initialChildSize: _isCashLike ? 0.42 : 0.68,
      minChildSize: 0.3,
      maxChildSize: 0.74,
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
/// shop), save-to-gallery, reference number + upload proof, submit ->
/// receipt/under-review.
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
  final _referenceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Shop? _shop;
  bool _loadingShop = true;

  /// XFile (cross-platform) + cached bytes for the Image.memory preview —
  /// works on both Flutter Web and mobile.
  XFile? _selectedProofImage;
  Uint8List? _selectedProofBytes;

  /// Client-side file-type error, shown right after picking a file.
  String? _fileTypeError;

  bool _submitting = false;
  bool _submitted = false;

  /// NEW — the booking returned by the backend after a successful
  /// submit. Contains the saved reference_number / is_verified_by_ocr,
  /// which the stale widget.booking doesn't have yet.
  Booking? _submittedBooking;

  String? _errorMessage;

  bool get _alreadyPendingVerification => widget.booking.paymentStatus == 'pending_verification';

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
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

  /// Returns the lowercase extension of [name] (no dot), or '' if none.
  String _extensionOf(String name) {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == name.length - 1) return '';
    return name.substring(dotIndex + 1).toLowerCase();
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;

    final extension = _extensionOf(image.name);
    if (!_kAllowedReceiptExtensions.contains(extension)) {
      setState(() {
        _fileTypeError = 'Only JPEG or PNG screenshots are allowed. Please pick a different file.';
      });
      return;
    }

    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selectedProofImage = image;
      _selectedProofBytes = bytes;
      _fileTypeError = null;
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

  /// `_submitting = true` is set via setState() before any `await`, so
  /// a rapid second tap can't fire a duplicate request.
  Future<void> _submit() async {
    final bookingId = widget.booking.id;
    final image = _selectedProofImage;
    if (bookingId == null || image == null) return;
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final referenceNumber = _referenceController.text.trim().toUpperCase();

    try {
      final proofUrl = await _uploadService.uploadPaymentProof(imageFile: image, bookingId: bookingId);
      final updated = await _bookingService.submitPaymentProof(
        bookingId: bookingId,
        proofOfPaymentUrl: proofUrl,
        referenceNumber: referenceNumber,
      );

      if (!mounted) return;
      setState(() {
        _submittedBooking = updated;
        _submitted = true;
        _submitting = false;
      });
      widget.onUpdated();
    } on Object catch (e) {
      if (!mounted) return;
      // ApiException carries a human-readable `.message` from the
      // backend (duplicate reference, OCR "Fraud Alert", etc.).
      final message = _messageFrom(e) ?? 'Could not submit your payment proof. Please try again.';
      setState(() {
        _submitting = false;
        _errorMessage = message;
      });
    }
  }

  String? _messageFrom(Object error) {
    try {
      final dynamic dyn = error;
      final message = dyn.message;
      if (message is String && message.trim().isNotEmpty) return message;
    } catch (_) {
      // Not an object with a `.message` getter — fall through to null.
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted || _alreadyPendingVerification) {
      return _ReceiptView(
        booking: _submittedBooking ?? widget.booking,
        scrollController: widget.scrollController,
      );
    }

    final colors = context.colors;
    final b = widget.booking;
    final canSubmit = _selectedProofImage != null && !_submitting;

    return Form(
      key: _formKey,
      child: ListView(
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

          // Bill breakdown
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

          // QR section
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
          // Reference number field — required, format-checked.
          Text('Reference number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.textSecondary)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _referenceController,
            enabled: !_submitting,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'e.g. 1234567890123',
              hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
              filled: true,
              fillColor: colors.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.primary, width: 1.5)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.error)),
            ),
            validator: (value) {
              final cleaned = (value ?? '').trim();
              if (cleaned.isEmpty) return 'Please enter the reference number from your receipt.';
              if (!_kReferenceNumberPattern.hasMatch(cleaned)) {
                return 'Enter 6–20 letters/numbers from your receipt (no spaces).';
              }
              return null;
            },
          ),
          const SizedBox(height: 4),
          Text(
            'Find this on your GCash/Maya/bank receipt — usually labeled "Ref No." or "Transaction ID".',
            style: TextStyle(fontSize: 10.5, color: colors.textMuted, height: 1.3),
          ),

          const SizedBox(height: 14),
          Text('Upload proof of payment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.textSecondary)),
          const SizedBox(height: 6),
          InkWell(
            onTap: _submitting ? null : _pickImage,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
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
                          Text('Tap to attach a screenshot (JPEG/PNG only)', style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
                        ],
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(_selectedProofBytes!, fit: BoxFit.cover, width: double.infinity, height: 90),
                    ),
            ),
          ),
          if (_fileTypeError != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, size: 14, color: colors.error),
                const SizedBox(width: 6),
                Expanded(child: Text(_fileTypeError!, style: TextStyle(fontSize: 11.5, color: colors.error))),
              ],
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(_errorMessage!, style: TextStyle(fontSize: 11.5, color: colors.error)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canSubmit ? _submit : null,
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
      ),
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
/// "pending_verification".
///
/// The Reference block shows the customer's actual submitted
/// reference_number (falling back to the booking id only if it isn't
/// set), plus an "OCR verified" badge once booking.isVerifiedByOcr.
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
    final referenceLabel = (booking.referenceNumber?.trim().isNotEmpty ?? false)
        ? booking.referenceNumber!
        : '#${booking.id ?? '—'}';

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      children: [
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
                  colors: [colors.warning.withValues(alpha: 0.22), colors.warning.withValues(alpha: 0.08)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: colors.warning.withValues(alpha: 0.18), blurRadius: 24, spreadRadius: 2),
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
        _staggered(
          start: 0.4,
          end: 0.8,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: colors.warningBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
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

        // "Receipt ticket" card
        _staggered(
          start: 0.5,
          end: 0.9,
          child: Container(
            decoration: BoxDecoration(
              color: colors.chipBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border.withValues(alpha: 0.6)),
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
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                referenceLabel,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.textPrimary, letterSpacing: 0.4),
                              ),
                            ),
                            if (booking.isVerifiedByOcr) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.verified_rounded, size: 14, color: colors.success),
                            ],
                          ],
                        ),
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

/// Paints a horizontal dashed line — the "tear line" in the receipt card.
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

/// "Press down" tap scale — Listener-based so it never conflicts with
/// the real onPressed on the button underneath.
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
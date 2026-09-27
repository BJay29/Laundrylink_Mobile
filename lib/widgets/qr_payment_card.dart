import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/booking.dart';
import '../services/booking_service.dart';
import '../services/upload_service.dart';

const Color _kPrimary = Color(0xFF1B7A6E);

/// Morphing "Action Required: Secure Your Payment" card.
///
/// FIXED (Flutter Web support): same fix as booking_payment_page.dart —
/// XFile + cached bytes + Image.memory instead of File + Image.file.
class QrPaymentCard extends StatefulWidget {
  const QrPaymentCard({
    super.key,
    required this.booking,
    required this.qrCodeUrl,
    this.onSubmitted,
  });

  final Booking booking;
  final String? qrCodeUrl;
  final VoidCallback? onSubmitted;

  @override
  State<QrPaymentCard> createState() => _QrPaymentCardState();
}

class _QrPaymentCardState extends State<QrPaymentCard> {
  final BookingService _bookingService = BookingService();
  final UploadService _uploadService = UploadService();
  final ImagePicker _imagePicker = ImagePicker();

  XFile? _selectedProofImage;
  Uint8List? _selectedProofBytes;
  bool _isSubmitting = false;
  bool _submitted = false;
  String? _errorMessage;

  @override
  void didUpdateWidget(covariant QrPaymentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.booking.paymentStatus == 'pending_verification' &&
        widget.booking.paymentStatus != 'pending_verification' &&
        widget.booking.paymentStatus != 'paid') {
      setState(() {
        _submitted = false;
        _selectedProofImage = null;
        _selectedProofBytes = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPendingVerification = widget.booking.paymentStatus == 'pending_verification';
    final showUnderReview = _submitted || isPendingVerification;

    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.fastOutSlowIn,
        switchOutCurve: Curves.fastOutSlowIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SizeTransition(sizeFactor: animation, axisAlignment: -1, child: child),
        ),
        child: showUnderReview
            ? _buildUnderReviewCard(key: const ValueKey('under_review'))
            : _buildActionCard(key: const ValueKey('action_required')),
      ),
    );
  }

  Widget _buildActionCard({required Key key}) {
    final weight = widget.booking.finalWeight;
    final price = widget.booking.finalPrice;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kPrimary.withOpacity(0.25), width: 1.4),
        boxShadow: [
          BoxShadow(color: _kPrimary.withOpacity(0.12), blurRadius: 18, spreadRadius: 1, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.qr_code_2, color: _kPrimary, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Action Required: Secure Your Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBillRow('Final Weight', weight != null ? '$weight kg' : '—'),
          const SizedBox(height: 6),
          _buildBillRow('Total Amount Due', price != null ? '₱${price.toStringAsFixed(2)}' : '—', emphasize: true),
          const SizedBox(height: 18),
          _buildQrSection(),
          const SizedBox(height: 18),
          _buildUploadSection(),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (_selectedProofImage == null || _isSubmitting) ? null : _handleSubmit,
              child: _isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Payment Verification'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool emphasize = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600)),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 18 : 13.5,
            fontWeight: emphasize ? FontWeight.bold : FontWeight.w500,
            color: emphasize ? _kPrimary : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildQrSection() {
    final qrUrl = widget.qrCodeUrl;

    if (qrUrl == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
        child: Text(
          "This shop hasn't set up their QR code yet. Please contact them directly to settle payment.",
          style: TextStyle(color: Colors.orange.shade800, fontSize: 12.5),
        ),
      );
    }

    return Column(
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              qrUrl,
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox(width: 200, height: 200, child: Center(child: CircularProgressIndicator()));
              },
              errorBuilder: (context, error, stack) => const SizedBox(
                width: 200,
                height: 200,
                child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _saveQrToGallery(qrUrl),
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Save QR Image to Gallery'),
        ),
      ],
    );
  }

  Widget _buildUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Upload Proof of Payment Screenshot', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickProofImage,
          child: Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _selectedProofBytes == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.attach_file, size: 28, color: Colors.grey.shade500),
                        const SizedBox(height: 6),
                        Text('Tap to attach a screenshot', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_selectedProofBytes!, fit: BoxFit.cover, width: double.infinity, height: 140),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnderReviewCard({required Key key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          _PulsingDot(color: Colors.orange.shade600),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment Under Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Colors.orange.shade800)),
                const SizedBox(height: 3),
                Text('The shop is verifying your transaction.', style: TextStyle(fontSize: 12.5, color: Colors.orange.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickProofImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selectedProofImage = picked;
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

  Future<void> _handleSubmit() async {
    final bookingId = widget.booking.id;
    final image = _selectedProofImage;
    if (bookingId == null || image == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final proofUrl = await _uploadService.uploadPaymentProof(imageFile: image, bookingId: bookingId);
      await _bookingService.submitPaymentProof(bookingId: bookingId, proofOfPaymentUrl: proofUrl);

      if (!mounted) return;
      setState(() {
        _submitted = true;
        _isSubmitting = false;
      });
      widget.onSubmitted?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Could not submit your payment proof. Please try again.';
      });
    }
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 0.7 + (_controller.value * 0.5);
        final opacity = 0.5 + (_controller.value * 0.5);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
          ),
        );
      },
    );
  }
}
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/booking.dart';
import '../services/booking_service.dart';
import '../services/upload_service.dart';

const Color _kPrimary = Color(0xFF1B7A6E);

/// Module C — Dynamic Conditional Payment Screen.
///
/// FIXED (Flutter Web support): dating `File? _selectedProofImage`
/// (dart:io) na ipinapakita gamit ang `Image.file` — hindi suportado
/// sa Flutter Web ("Image.file is not supported on Flutter Web").
/// Ngayon, `XFile` (cross-platform, mula sa image_picker) ang tinatago
/// kasabay ng cached bytes (`_selectedProofBytes`) para sa preview
/// gamit ang `Image.memory` — gumagana ito pareho sa web at mobile.
class BookingPaymentPage extends StatefulWidget {
  const BookingPaymentPage({
    super.key,
    required this.booking,
    this.gcashQrUrl,
    this.paymayaQrUrl,
    required this.onBackToHome,
  });

  final Booking booking;
  final String? gcashQrUrl;
  final String? paymayaQrUrl;
  final VoidCallback onBackToHome;

  @override
  State<BookingPaymentPage> createState() => _BookingPaymentPageState();
}

class _BookingPaymentPageState extends State<BookingPaymentPage> {
  final BookingService _bookingService = BookingService();
  final UploadService _uploadService = UploadService();
  final ImagePicker _imagePicker = ImagePicker();

  XFile? _selectedProofImage;
  Uint8List? _selectedProofBytes;
  bool _isUploadingProof = false;
  bool _isSubmitting = false;
  bool _submitted = false;
  String? _errorMessage;

  bool get _isCashLike =>
      widget.booking.paymentMethod == 'cash' || widget.booking.paymentMethod == 'cod';

  bool get _isAwaitingOnlinePayment =>
      (widget.booking.paymentMethod == 'gcash' ||
          widget.booking.paymentMethod == 'paymaya' ||
          widget.booking.paymentMethod == 'online_qr') &&
      widget.booking.status == BookingStatus.awaitingPayment;

  String? get _qrUrl =>
      widget.booking.paymentMethod == 'gcash' ? widget.gcashQrUrl : widget.paymayaQrUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(title: const Text('Payment')),
      body: SafeArea(
        child: _isCashLike ? _buildCashCase() : _buildOnlineCase(),
      ),
    );
  }

  // ---------------------------------------------------------------
  // CASE 1: Cash / COD
  // ---------------------------------------------------------------
  Widget _buildCashCase() {
    final price = widget.booking.finalPrice ?? widget.booking.estimatedPrice;
    final label = widget.booking.fulfillmentMode == 'delivery'
        ? 'upon delivery'
        : 'upon drop-off or pickup';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _kPrimary.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.payments_outlined, size: 46, color: _kPrimary),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(
              children: [
                const Text('Cash Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(
                  price != null
                      ? 'Please prepare exactly ₱${price.toStringAsFixed(2)} $label.'
                      : 'Please prepare the exact amount $label. Final price will be confirmed once weighed.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: widget.onBackToHome,
              child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // CASE 2: Online (QR) + Awaiting Payment
  // ---------------------------------------------------------------
  Widget _buildOnlineCase() {
    if (!_isAwaitingOnlinePayment) {
      return _buildNonActionableStatus();
    }

    if (_submitted) {
      return _buildUnderReview();
    }

    final finalPrice = widget.booking.finalPrice;
    final finalWeight = widget.booking.finalWeight;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildBillSummary(finalWeight, finalPrice),
        const SizedBox(height: 24),
        _buildQrSection(),
        const SizedBox(height: 24),
        _buildUploadSection(),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: (_selectedProofImage == null || _isSubmitting) ? null : _submitPaymentVerification,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Submit Payment Verification', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildNonActionableStatus() {
    String message;
    switch (widget.booking.paymentStatus) {
      case 'pending_verification':
        message = 'Your payment is under review. The shop is verifying your transaction.';
        break;
      case 'paid':
        message = 'This booking has already been paid. Thank you!';
        break;
      default:
        message = widget.booking.status == BookingStatus.awaitingWeighing
            ? 'Waiting for the shop to weigh your laundry before payment can be settled.'
            : 'Payment is not yet available for this booking.';
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(Icons.hourglass_top, size: 40, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 20),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: widget.onBackToHome,
              child: const Text('Back to Home'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnderReview() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.hourglass_top, size: 40, color: Colors.orange),
          ),
          const SizedBox(height: 20),
          const Text('Payment Under Review', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'The shop is verifying your transaction. We\'ll notify you once it\'s confirmed.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: widget.onBackToHome,
              child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillSummary(double? weight, double? price) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Final Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          _billRow('Weighed', weight != null ? '$weight kg' : '—'),
          const Divider(height: 22),
          _billRow('Total Amount', price != null ? '₱${price.toStringAsFixed(2)}' : '—', emphasize: true),
        ],
      ),
    );
  }

  Widget _billRow(String label, String value, {bool emphasize = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 18 : 14,
            fontWeight: emphasize ? FontWeight.bold : FontWeight.normal,
            color: emphasize ? _kPrimary : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildQrSection() {
    final qrUrl = _qrUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scan to pay via ${widget.booking.paymentMethod == 'gcash' ? 'GCash' : widget.booking.paymentMethod == 'paymaya' ? 'PayMaya' : 'QR'}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 14),
          if (qrUrl == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(14)),
              child: Text(
                'This shop hasn\'t set up their QR code yet. Please contact the shop directly to arrange payment.',
                style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
              ),
            )
          else ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    qrUrl,
                    width: 220,
                    height: 220,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(width: 220, height: 220, child: Center(child: CircularProgressIndicator()));
                    },
                    errorBuilder: (context, error, stackTrace) => const SizedBox(
                      width: 220,
                      height: 220,
                      child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: () => _saveQrToGallery(qrUrl),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Save QR Image to Gallery'),
                style: TextButton.styleFrom(foregroundColor: _kPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Upload Proof of Payment / Screenshot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _isUploadingProof ? null : _pickProofImage,
          child: Container(
            width: double.infinity,
            height: 170,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedProofBytes == null ? Colors.grey.shade300 : _kPrimary,
                width: _selectedProofBytes == null ? 1.4 : 1.8,
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: _selectedProofBytes == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: _kPrimary.withOpacity(0.08), shape: BoxShape.circle),
                          child: Icon(Icons.add_photo_alternate_outlined, size: 26, color: _kPrimary),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tap to attach a screenshot',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                // FIXED: Image.memory instead of Image.file — works on
                // Flutter Web AND mobile.
                : ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.memory(_selectedProofBytes!, fit: BoxFit.cover, width: double.infinity, height: 170),
                  ),
          ),
        ),
        if (_selectedProofBytes != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _isUploadingProof ? null : _pickProofImage,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Choose a different image'),
            style: TextButton.styleFrom(foregroundColor: _kPrimary),
          ),
        ],
      ],
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the QR code. Please try again.')),
      );
    }
  }

  Future<void> _submitPaymentVerification() async {
    final bookingId = widget.booking.id;
    final image = _selectedProofImage;
    if (bookingId == null || image == null) return;

    setState(() {
      _isSubmitting = true;
      _isUploadingProof = true;
      _errorMessage = null;
    });

    try {
      final proofUrl = await _uploadService.uploadPaymentProof(imageFile: image, bookingId: bookingId);
      await _bookingService.submitPaymentProof(bookingId: bookingId, proofOfPaymentUrl: proofUrl);

      if (!mounted) return;
      setState(() {
        _submitted = true;
        _isSubmitting = false;
        _isUploadingProof = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isUploadingProof = false;
        _errorMessage = 'Could not submit your payment proof. Please try again.';
      });
    }
  }
}
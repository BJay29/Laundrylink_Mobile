import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/booking.dart';
import '../services/booking_service.dart';
import '../services/upload_service.dart';

/// Local color constant — see booking_confirmation_page.dart for the
/// same note on why this isn't AppColors.primary directly.
const Color _kPrimary = Color(0xFF1B7A6E);

/// Module C — Dynamic Conditional Payment Screen.
///
/// Reads booking.paymentMethod + booking.status to decide which UI to
/// show:
///   CASE 1: paymentMethod is "cash" or "cod"
///     -> Cash message block + [Back to Home].
///   CASE 2: paymentMethod is "gcash"/"paymaya" AND status is
///            awaitingPayment
///     -> Final bill breakdown, shop's QR code, [Save QR to Gallery],
///        image picker for proof of payment, [Submit Payment
///        Verification].
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

  File? _selectedProofImage;
  bool _isUploadingProof = false;
  bool _isSubmitting = false;
  bool _submitted = false;
  String? _errorMessage;

  bool get _isCashLike =>
      widget.booking.paymentMethod == 'cash' || widget.booking.paymentMethod == 'cod';

  bool get _isAwaitingOnlinePayment =>
      (widget.booking.paymentMethod == 'gcash' || widget.booking.paymentMethod == 'paymaya') &&
      widget.booking.status == BookingStatus.awaitingPayment;

  String? get _qrUrl =>
      widget.booking.paymentMethod == 'gcash' ? widget.gcashQrUrl : widget.paymayaQrUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          const Icon(Icons.payments_outlined, size: 64, color: _kPrimary),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                const Text(
                  'Cash Payment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
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
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: widget.onBackToHome,
              child: const Text('Back to Home'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // CASE 2: Online (GCash / PayMaya) + Awaiting Payment
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
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: (_selectedProofImage == null || _isSubmitting) ? null : _submitPaymentVerification,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Submit Payment Verification'),
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
          Icon(Icons.hourglass_top, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
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
          const Icon(Icons.hourglass_top, size: 56, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            'Payment Under Review',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
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
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: widget.onBackToHome,
              child: const Text('Back to Home'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillSummary(double? weight, double? price) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Final Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          _billRow('Weighed', weight != null ? '$weight kg' : '—'),
          const Divider(height: 20),
          _billRow(
            'Total Amount',
            price != null ? '₱${price.toStringAsFixed(2)}' : '—',
            emphasize: true,
          ),
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
            fontSize: emphasize ? 17 : 14,
            fontWeight: emphasize ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildQrSection() {
    final qrUrl = _qrUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scan to pay via ${widget.booking.paymentMethod == 'gcash' ? 'GCash' : 'PayMaya'}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 12),
        if (qrUrl == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'This shop hasn\'t set up their QR code yet. Please contact the shop directly to arrange payment.',
              style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
            ),
          )
        else ...[
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                qrUrl,
                width: 220,
                height: 220,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    width: 220,
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  width: 220,
                  height: 220,
                  child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => _saveQrToGallery(qrUrl),
              icon: const Icon(Icons.download),
              label: const Text('Save QR Image to Gallery'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload Proof of Payment / Screenshot',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _isUploadingProof ? null : _pickProofImage,
          child: Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _selectedProofImage == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.attach_file, size: 32, color: Colors.grey.shade500),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to attach a screenshot',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedProofImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 160,
                    ),
                  ),
          ),
        ),
        if (_selectedProofImage != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _isUploadingProof ? null : _pickProofImage,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Choose a different image'),
          ),
        ],
      ],
    );
  }

  Future<void> _pickProofImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      _selectedProofImage = File(picked.path);
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
      // Step 1: upload the screenshot to Supabase Storage (bucket
      // "payment-proofs") via POST /uploads/payment-proof, get back the
      // public URL.
      final proofUrl = await _uploadService.uploadPaymentProof(
        imageFile: image,
        bookingId: bookingId,
      );

      // Step 2: attach that URL to the EXISTING booking and flip
      // payment_status to "pending_verification".
      //
      // ⚠️ BACKEND GAP: this assumes a new endpoint,
      //   PATCH /bookings/{id}/submit-payment-proof
      // that we haven't created in booking_controller.py yet — see
      // BookingService.submitPaymentProof() note.
      await _bookingService.submitPaymentProof(
        bookingId: bookingId,
        proofOfPaymentUrl: proofUrl,
      );

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
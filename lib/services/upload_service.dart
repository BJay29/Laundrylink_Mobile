import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';

import 'api_service.dart';
import 'customer_session.dart';

/// Handles file uploads to Supabase Storage via the backend's /uploads
/// endpoints (see app/services/supabase_storage.py +
/// app/routes/upload_routes.py), and saving a network image to the
/// device's photo gallery.
class UploadService {
  UploadService();

  String get _baseUrl => ApiService.baseUrl;

  /// Uploads a payment-proof screenshot for [bookingId] to Supabase
  /// Storage (bucket "payment-proofs") via POST /uploads/payment-proof.
  /// Returns the public URL, which the caller then attaches to a
  /// booking via BookingService.submitPaymentProof() (or, at creation
  /// time, BookingService.createBooking's proofOfPaymentUrl param).
  ///
  /// Requires the customer to be logged in — protected by
  /// get_current_customer on the backend.
  Future<String> uploadPaymentProof({
    required File imageFile,
    required int bookingId,
  }) async {
    final token = CustomerSession.instance.authToken;
    if (token == null) {
      throw const ApiException('You must be logged in to upload a file.', statusCode: 401);
    }

    final uri = Uri.parse('$_baseUrl/uploads/payment-proof');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['booking_id'] = bookingId.toString()
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: _mediaTypeForPath(imageFile.path),
      ));

    final streamedResponse = await request.send().timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw const ApiException(
            'The upload took too long. Please check your connection and try again.',
          ),
        );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorDetail(response.body) ?? 'Failed to upload proof of payment.',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final url = data['url'] as String?;
    if (url == null || url.isEmpty) {
      throw const ApiException('Upload succeeded but no URL was returned.', statusCode: 500);
    }
    return url;
  }

  /// Uploads the shop's SINGLE generic online-payment QR code image
  /// (web/staff-side use — Optimization Settings) via
  /// POST /uploads/payment-qr. Requires a staff/owner session
  /// (get_current_user on the backend), NOT a customer session — the
  /// caller must supply [staffToken] directly since this method
  /// doesn't use CustomerSession.
  ///
  /// UPDATED (online_qr consolidation): the 'provider' parameter
  /// ("gcash" | "paymaya") has been REMOVED — a shop now has only ONE
  /// QR code (National QR Ph style), matching the backend's
  /// consolidated /uploads/payment-qr endpoint and Shop.qr_code_url
  /// column. This method is included here for completeness in case a
  /// future staff-facing screen reuses UploadService.
  Future<String> uploadShopQrCode({
    required File imageFile,
    required String staffToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/uploads/payment-qr');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $staffToken'
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: _mediaTypeForPath(imageFile.path),
      ));

    final streamedResponse = await request.send().timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw const ApiException(
            'The upload took too long. Please check your connection and try again.',
          ),
        );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorDetail(response.body) ?? 'Failed to upload QR code.',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final url = data['url'] as String?;
    if (url == null || url.isEmpty) {
      throw const ApiException('Upload succeeded but no URL was returned.', statusCode: 500);
    }
    return url;
  }

  /// Downloads the image at [imageUrl] and saves it to the device's
  /// photo gallery — backs the "[⬇️ Save QR Image to Gallery]" button
  /// in qr_payment_card.dart / booking_payment_page.dart.
  ///
  /// Uses the `gal` package, which handles the Android/iOS gallery
  /// write permission prompts internally.
  Future<void> saveNetworkImageToGallery(String imageUrl) async {
    final http.Response response;
    try {
      response = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const ApiException('The download took too long. Please try again.');
    } on SocketException {
      throw const ApiException('No internet connection. Please check your network and try again.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Could not download the image (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final tempDir = await getTemporaryDirectory();
    final fileName = 'qr_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(response.bodyBytes);

    final hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        throw const ApiException(
          'Gallery access was denied. Please enable photo permissions in Settings.',
          statusCode: 403,
        );
      }
    }

    await Gal.putImage(tempFile.path, album: 'Laundry App');
  }

  /// Best-effort content-type guess from a file path's extension, since
  /// image_picker doesn't always expose a reliable MIME type directly.
  /// Defaults to JPEG — a safe fallback the backend's
  /// ALLOWED_IMAGE_CONTENT_TYPES set (jpeg/jpg/png/webp) also accepts.
  MediaType _mediaTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }

  String? _extractErrorDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String) return detail;
      }
    } catch (_) {
      // Body wasn't JSON — ignore and fall back to the generic message.
    }
    return null;
  }
}
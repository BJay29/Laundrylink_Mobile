import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import 'api_service.dart';
import 'customer_session.dart';
import 'gallery_download.dart';

/// Handles file uploads to Supabase Storage via the backend's /uploads
/// endpoints (see app/services/supabase_storage.py +
/// app/routes/upload_routes.py), and saving a network image locally
/// (gallery on mobile, browser download on web).
class UploadService {
  UploadService();

  String get _baseUrl => ApiService.baseUrl;

  /// Uploads a payment-proof screenshot for [bookingId] to Supabase
  /// Storage (bucket "payment-proofs") via POST /uploads/payment-proof.
  /// Returns the public URL, which the caller then attaches to a
  /// booking via BookingService.submitPaymentProof().
  ///
  /// Uses `XFile` (image_picker's cross-platform file type) + bytes +
  /// `http.MultipartFile.fromBytes()` — works identically on Flutter
  /// Web AND mobile, unlike `File`/`fromPath()` which only work where
  /// a real filesystem exists.
  Future<String> uploadPaymentProof({
    required XFile imageFile,
    required int bookingId,
  }) async {
    final token = CustomerSession.instance.authToken;
    if (token == null) {
      throw const ApiException('You must be logged in to upload a file.', statusCode: 401);
    }

    final Uint8List bytes = await imageFile.readAsBytes();

    final uri = Uri.parse('$_baseUrl/uploads/payment-proof');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['booking_id'] = bookingId.toString()
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: imageFile.name,
        contentType: _mediaTypeForPath(imageFile.name),
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
  /// POST /uploads/payment-qr. Requires a staff/owner session — caller
  /// supplies [staffToken] directly (no CustomerSession involved).
  Future<String> uploadShopQrCode({
    required XFile imageFile,
    required String staffToken,
  }) async {
    final Uint8List bytes = await imageFile.readAsBytes();

    final uri = Uri.parse('$_baseUrl/uploads/payment-qr');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $staffToken'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: imageFile.name,
        contentType: _mediaTypeForPath(imageFile.name),
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

  /// FIXED (works on web AND mobile now): Downloads the image at
  /// [imageUrl], then hands the bytes to `saveBytesToGallery()` —
  /// which resolves at compile time to either the mobile (gal /
  /// device photo gallery) or web (browser file download)
  /// implementation via gallery_download.dart's conditional export.
  /// Callers don't need to know or care which platform they're on.
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

    final fileName = 'qr_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await saveBytesToGallery(response.bodyBytes, fileName);
  }

  /// Best-effort content-type guess from a file name's extension.
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
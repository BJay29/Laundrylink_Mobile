import '../models/booking.dart';
import 'api_service.dart';
import 'customer_session.dart';

/// NEW (Edit Booking feature) — sentinel object para sa
/// BookingService.updateBooking(). Ginagamit ito bilang DEFAULT value
/// ng bawat optional parameter doon, para may paraan tayong
/// makilala ang tatlong estado ng bawat field:
///   1. Hindi ipinasa ang parameter (default = kUnset) → HINDI isasama
///      sa request body — hindi galawin ng backend ang field na ito.
///   2. Ipinasa nang `null` (hal. `dropoffWindow: null`) → isasama sa
///      body bilang `null` — ini-clear ng backend ang field.
///   3. Ipinasa ng tunay na value → isasama sa body ng value na iyon.
/// Kailangan ito dahil ang CustomerBookingUpdate sa backend ay gumagamit
/// ng `model_dump(exclude_unset=True)` — partial update, kung saan ang
/// "hindi pinansin" at ang "sinadyang i-null" ay dalawang magkaibang
/// bagay.
const Object kUnset = Object();

/// Customer (mobile app) booking endpoints.
///
/// Requires the customer to be logged in — both POST /bookings/customer
/// and GET /bookings/mine are protected by get_current_customer on the
/// backend, so every call here attaches the Bearer token from
/// CustomerSession.
class BookingService {
  BookingService({ApiService? api}) : _api = api ?? ApiService();
  final ApiService _api;

  /// Creates a booking on behalf of the logged-in customer.
  ///
  /// [shopName] is passed through purely for local display purposes —
  /// used as a fallback if the backend response doesn't include
  /// shop_name; once the backend's BookingResponse includes shop_name
  /// directly, that value takes priority (see Booking.fromJson).
  ///
  /// [paymentMethod] ("cash" | "cod" | "gcash" | "paymaya" |
  /// "online_qr", default "cash") at [proofOfPaymentUrl] — ang public
  /// URL na ibinalik ng POST /uploads/payment-proof.
  ///
  /// [addressId] — id ng isa sa mga saved Address ng customer, REQUIRED
  /// ng backend kapag [fulfillmentMode] == "delivery".
  ///
  /// [dropoffDatetime] — OPTIONAL na oras kung kailan balak pumunta ng
  /// customer sa shop. Para sa "dropoff" lang; hindi ipinapadala kung
  /// null. Hiwalay ito sa [pickupDatetime] (delivery pickup leg,
  /// required doon).
  ///
  /// [dropoffWindow] at [pickupWindow] — optional time window labels
  /// ("morning" | "afternoon" | "evening" | "anytime"), independiyente
  /// sa mismong datetime.
  Future<Booking> createBooking({
    required int shopId,
    required String shopName,
    required String serviceType,
    required double quantity,
    String? specialInstructions,
    String fulfillmentMode = 'dropoff',
    DateTime? pickupDatetime,
    DateTime? dropoffDatetime,
    String? dropoffWindow,
    String? pickupWindow,
    int? addressId,
    List<int> addOnIds = const [],
    String? promoCode,
    String paymentMethod = 'cash',
    String? proofOfPaymentUrl,
  }) async {
    final token = CustomerSession.instance.authToken;
    if (token == null) {
      throw const ApiException('You must be logged in to book a service.', statusCode: 401);
    }

    final body = <String, dynamic>{
      'shop_id': shopId,
      'service_type': serviceType,
      'quantity': quantity,
      'fulfillment_mode': fulfillmentMode,
      'add_on_ids': addOnIds,
      'payment_method': paymentMethod,
      if (specialInstructions != null && specialInstructions.trim().isNotEmpty)
        'special_instructions': specialInstructions.trim(),
      if (pickupDatetime != null) 'pickup_datetime': pickupDatetime.toIso8601String(),
      if (dropoffDatetime != null) 'dropoff_datetime': dropoffDatetime.toIso8601String(),
      if (dropoffWindow != null) 'dropoff_window': dropoffWindow,
      if (pickupWindow != null) 'pickup_window': pickupWindow,
      if (addressId != null) 'address_id': addressId,
      if (promoCode != null && promoCode.trim().isNotEmpty) 'promo_code': promoCode.trim().toUpperCase(),
      if (proofOfPaymentUrl != null && proofOfPaymentUrl.trim().isNotEmpty)
        'proof_of_payment_url': proofOfPaymentUrl.trim(),
    };

    final data = await _api.post('/bookings/customer', body, token: token);
    return Booking.fromJson(data, shopName: shopName);
  }

  /// Checks a promo code against a shop + subtotal WITHOUT creating a
  /// booking, so BookingFormPage can show a live discount and
  /// recalculated total as the customer types.
  /// Calls the backend's POST /bookings/promo-preview.
  ///
  /// Expected response shape (PromoPreviewResponse on the backend):
  ///   { "valid": true, "code": "WELCOME10", "discount_amount": 50.0 }
  /// or, when the code is invalid/expired/not applicable:
  ///   { "valid": false, "message": "This code has expired." }
  Future<Map<String, dynamic>> previewPromoCode({
    required int shopId,
    required String code,
    required double subtotal,
  }) async {
    final token = CustomerSession.instance.authToken;
    if (token == null) {
      throw const ApiException('You must be logged in to preview a promo code.', statusCode: 401);
    }

    final body = <String, dynamic>{
      'shop_id': shopId,
      'code': code.trim().toUpperCase(),
      'subtotal': subtotal,
    };

    final data = await _api.post('/bookings/promo-preview', body, token: token);
    return data as Map<String, dynamic>;
  }

  /// Fetches ALL bookings made by the logged-in customer (any shop, any
  /// status), most recent first. Backs the Booking Page (history +
  /// tracking) and the Notifications Page.
  Future<List<Booking>> getMyBookings() async {
    final token = CustomerSession.instance.authToken;
    if (token == null) {
      throw const ApiException('You must be logged in to view your bookings.', statusCode: 401);
    }

    final data = await _api.getList('/bookings/mine', token: token);
    return data
        .map((json) => Booking.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetches a single booking by id (mula sa listahan ng
  /// getMyBookings(), walang hiwalay na GET /bookings/{id} endpoint sa
  /// backend na naka-scope sa customer). Ginagamit ng order tracking
  /// page bilang paunang load at manual-refresh fallback.
  Future<Booking?> getBookingById(int bookingId) async {
    final bookings = await getMyBookings();
    for (final booking in bookings) {
      if (booking.id == bookingId) return booking;
    }
    return null;
  }

  /// Cancels a booking the customer made themselves. Only works while
  /// the backend still considers it cancellable (Awaiting Approval or
  /// Pending); a 400 ApiException with a human-readable message is
  /// thrown otherwise, which the caller can show directly.
  Future<Booking> cancelBooking(int bookingId) async {
    final token = CustomerSession.instance.authToken;
    if (token == null) {
      throw const ApiException('You must be logged in to cancel a booking.', statusCode: 401);
    }

    final data = await _api.patch('/bookings/$bookingId/cancel', const {}, token: token);
    return Booking.fromJson(data);
  }

  /// NEW (Flexible Booking — Edit Booking feature) — partial update ng
  /// customer sa sarili niyang booking, habang "Awaiting Approval" pa
  /// lang (chinecheck ito ng backend — 400 ApiException kung hindi na
  /// pwede). Calls PATCH /bookings/{id}.
  ///
  /// Ang bawat optional parameter dito ay may default na [kUnset] — see
  /// docstring ng const na iyon sa taas ng file para sa buong
  /// paliwanag. Halimbawa:
  ///   - Hindi babaguhin ang dropoffWindow → huwag ilagay ang param
  ///     (o `dropoffWindow: kUnset` — pareho lang).
  ///   - I-clear ang dropoffDatetime → `dropoffDatetime: null`.
  ///   - Palitan ang dropoffDatetime → `dropoffDatetime: someDateTime`.
  ///
  /// IMPORTANT: huwag magpasa ng dropoff_datetime/dropoff_window kapag
  /// "delivery" ang mode ng booking, o pickup_datetime/pickup_window
  /// kapag "dropoff" — magre-reject ang backend nito (400) dahil
  /// cross-mode field ang mga iyon. Ang caller (EditBookingPage) ang
  /// responsable na huwag isama ang mga field na 'di angkop sa mode.
  Future<Booking> updateBooking({
    required int bookingId,
    Object? dropoffDatetime = kUnset,
    Object? dropoffWindow = kUnset,
    Object? pickupDatetime = kUnset,
    Object? pickupWindow = kUnset,
    Object? addressId = kUnset,
    Object? specialInstructions = kUnset,
    Object? paymentMethod = kUnset,
  }) async {
    final token = CustomerSession.instance.authToken;
    if (token == null) {
      throw const ApiException('You must be logged in to edit a booking.', statusCode: 401);
    }

    final body = <String, dynamic>{};

    if (!identical(dropoffDatetime, kUnset)) {
      body['dropoff_datetime'] = dropoffDatetime == null ? null : (dropoffDatetime as DateTime).toIso8601String();
    }
    if (!identical(dropoffWindow, kUnset)) {
      body['dropoff_window'] = dropoffWindow as String?;
    }
    if (!identical(pickupDatetime, kUnset)) {
      body['pickup_datetime'] = pickupDatetime == null ? null : (pickupDatetime as DateTime).toIso8601String();
    }
    if (!identical(pickupWindow, kUnset)) {
      body['pickup_window'] = pickupWindow as String?;
    }
    if (!identical(addressId, kUnset)) {
      body['address_id'] = addressId as int?;
    }
    if (!identical(specialInstructions, kUnset)) {
      final trimmed = (specialInstructions as String?)?.trim();
      body['special_instructions'] = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    }
    if (!identical(paymentMethod, kUnset)) {
      body['payment_method'] = paymentMethod as String?;
    }

    if (body.isEmpty) {
      throw const ApiException('No changes to save.', statusCode: 400);
    }

    final data = await _api.patch('/bookings/$bookingId', body, token: token);
    return Booking.fromJson(data);
  }

  /// UPDATED (Secure Payment Verification System) — submits proof of
  /// payment for a booking that is already "Awaiting Payment" (price
  /// finalized by the shop, online payment method). The image itself
  /// must already be uploaded to Supabase Storage BEFORE calling this
  /// — [proofOfPaymentUrl] is the public URL returned by
  /// UploadService.uploadPaymentProof(), not the raw file.
  ///
  /// [referenceNumber] is now REQUIRED — this is what the backend uses
  /// to (1) enforce a unique-reference check, (2) detect Sandbox Mode
  /// submissions (prefix "TEST-", development env only), and (3) run
  /// OCR substring-matching against the uploaded receipt in production.
  /// A 400 ApiException is thrown with a human-readable message if the
  /// backend rejects it — duplicate reference, OCR mismatch ("Fraud
  /// Alert"), or a format error — which the caller should show
  /// directly to the customer.
  ///
  /// Calls PATCH /bookings/{id}/submit-payment-proof. On success, the
  /// booking's payment_status moves to "pending_verification".
  Future<Booking> submitPaymentProof({
    required int bookingId,
    required String proofOfPaymentUrl,
    required String referenceNumber,
  }) async {
    final token = CustomerSession.instance.authToken;
    if (token == null) {
      throw const ApiException('You must be logged in to submit payment proof.', statusCode: 401);
    }

    final body = <String, dynamic>{
      'proof_of_payment_url': proofOfPaymentUrl,
      'reference_number': referenceNumber.trim().toUpperCase(),
    };

    final data = await _api.patch(
      '/bookings/$bookingId/submit-payment-proof',
      body,
      token: token,
    );
    return Booking.fromJson(data);
  }

  /// NEW (Rating after order) — nagsa-submit ng rating (1-5 na bituin,
  /// opsyonal na komento) para sa isang booking na "Claimed" na.
  /// Calls POST /reviews/ (may trailing slash, tugma sa backend route —
  /// kapag wala ang slash, magre-redirect ang FastAPI at mawawala ang
  /// Authorization header).
  ///
  /// Ang komento ay tinatanggal ang labis na espasyo at hindi
  /// ipinapadala kung blangko. Hanggang 300 characters (chinecheck ng
  /// backend; ang RatingCard ay may maxLength din).
  ///
  /// Mga posibleng ApiException:
  ///   - 404: wala ang booking, o hindi sa customer na ito
  ///   - 400: hindi pa "Claimed" ang booking
  ///   - 409: nakapag-rate na sa booking na ito
  ///   - 422: di-wasto ang rating o masyadong mahaba ang komento
  /// Ang `message` ng bawat isa ay pwedeng ipakita nang diretso sa
  /// customer.
  Future<void> submitReview({
    required int bookingId,
    required int rating,
    String? comment,
  }) async {
    final token = CustomerSession.instance.authToken;
    if (token == null) {
      throw const ApiException('You must be logged in to rate an order.', statusCode: 401);
    }

    final trimmedComment = comment?.trim();
    final body = <String, dynamic>{
      'booking_id': bookingId,
      'rating': rating,
      if (trimmedComment != null && trimmedComment.isNotEmpty) 'comment': trimmedComment,
    };

    await _api.post('/reviews/', body, token: token);
  }
}
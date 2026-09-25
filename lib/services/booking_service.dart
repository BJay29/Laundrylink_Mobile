import '../models/booking.dart';
import 'api_service.dart';
import 'customer_session.dart';

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
  /// shop_name (older backend versions); once the backend's
  /// BookingResponse includes shop_name directly, that value takes
  /// priority (see Booking.fromJson).
  ///
  /// UPDATED (Payment / Online Payment feature): idinagdag ang
  /// [paymentMethod] ("cash" | "cod" | "gcash" | "paymaya" |
  /// "online_qr", default "cash" gaya ng CustomerBookingCreate sa
  /// backend) at [proofOfPaymentUrl] — ang public URL na ibinalik ng
  /// POST /uploads/payment-proof (see UploadService), ipapasa lang kung
  /// gcash/paymaya/online_qr AT may na-upload na resibo BAGO tawagin ang
  /// function na ito.
  ///
  /// NEW (Delivery Address feature): idinagdag ang [addressId] — id ng
  /// isa sa mga saved Address ng customer (see AddressService), REQUIRED
  /// ng backend kapag [fulfillmentMode] == "delivery" (see
  /// CustomerBookingCreate.address_id validator sa app/schemas.py).
  /// Ignored/omitted kapag "dropoff" — walang epekto kahit ipasa, kaya
  /// ligtas itong laging ipasa mula sa form kung meron man, hindi
  /// kailangang i-null-out manually sa drop-off case.
  Future<Booking> createBooking({
    required int shopId,
    required String shopName,
    required String serviceType,
    required double quantity,
    String? specialInstructions,
    String fulfillmentMode = 'dropoff',
    DateTime? pickupDatetime,
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
      if (addressId != null) 'address_id': addressId,
      if (promoCode != null && promoCode.trim().isNotEmpty) 'promo_code': promoCode.trim().toUpperCase(),
      if (proofOfPaymentUrl != null && proofOfPaymentUrl.trim().isNotEmpty)
        'proof_of_payment_url': proofOfPaymentUrl.trim(),
    };

    final data = await _api.post('/bookings/customer', body, token: token);
    return Booking.fromJson(data, shopName: shopName);
  }

  /// NEW (Real-time Promo Preview feature) — Checks a promo code against
  /// a shop + subtotal WITHOUT creating a booking, so BookingFormPage can
  /// show a live discount and recalculated total as the customer types.
  /// Calls the backend's POST /bookings/promo-preview.
  ///
  /// Expected response shape (PromoPreviewResponse on the backend):
  ///   { "valid": true, "code": "WELCOME10", "discount_amount": 50.0 }
  /// or, when the code is invalid/expired/not applicable:
  ///   { "valid": false, "message": "This code has expired." }
  ///
  /// Same auth requirement as the rest of this service — the customer
  /// must already be logged in to reach BookingFormPage in the first
  /// place, so this throws the same 401 ApiException as the others if
  /// somehow called without a session.
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
  /// tracking) and the Notifications Page — both poll this same method
  /// periodically to detect status changes made by the shop from the
  /// web dashboard.
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

  /// NEW — Fetches a single booking by id (mula sa listahan ng
  /// getMyBookings(), walang hiwalay na GET /bookings/{id} endpoint sa
  /// backend na naka-scope sa customer). Ginagamit ng order tracking
  /// page bilang paunang load bago pa man mag-Realtime, at bilang
  /// manual-refresh fallback kapag walang Realtime connection.
  Future<Booking?> getBookingById(int bookingId) async {
    final bookings = await getMyBookings();
    for (final booking in bookings) {
      if (booking.id == bookingId) return booking;
    }
    return null;
  }

  /// Cancels a booking the customer made themselves. Only works while
  /// the backend still considers it cancellable (Awaiting Approval or
  /// Pending — see cancel_customer_booking() in booking_controller.py);
  /// a 400 ApiException with a human-readable message is thrown
  /// otherwise, which the caller can show directly.
  Future<Booking> cancelBooking(int bookingId) async {
    final token = CustomerSession.instance.authToken;
    if (token == null) {
      throw const ApiException('You must be logged in to cancel a booking.', statusCode: 401);
    }

    final data = await _api.patch('/bookings/$bookingId/cancel', const {}, token: token);
    return Booking.fromJson(data);
  }

  /// NEW (Order Tracking / Dynamic Payment Screen feature) — Submits
  /// proof of payment for a booking that is already "Awaiting Payment"
  /// (price finalized by the shop, online payment method). The image
  /// itself must already be uploaded to Supabase Storage BEFORE calling
  /// this — [proofOfPaymentUrl] is the public URL returned by
  /// UploadService.uploadPaymentProof(), not the raw file.
  ///
  /// Calls the backend's PATCH /bookings/{id}/submit-payment-proof
  /// (customer-facing, protected by get_current_customer — see
  /// booking_routes.py / booking_controller.submit_payment_proof()).
  /// On success, the booking's payment_status moves to
  /// "pending_verification" on the backend, matching
  /// BookingSubmitPaymentProofRequest's single field.
  Future<Booking> submitPaymentProof({
    required int bookingId,
    required String proofOfPaymentUrl,
  }) async {
    final token = CustomerSession.instance.authToken;
    if (token == null) {
      throw const ApiException('You must be logged in to submit payment proof.', statusCode: 401);
    }

    final body = <String, dynamic>{
      'proof_of_payment_url': proofOfPaymentUrl,
    };

    final data = await _api.patch(
      '/bookings/$bookingId/submit-payment-proof',
      body,
      token: token,
    );
    return Booking.fromJson(data);
  }
}
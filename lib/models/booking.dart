/// Mirrors the `status` values actually set by the backend (see
/// app/models.py's Booking.status default + app/controller/
/// booking_controller.py's transitions).
///
/// UPDATED (Weighing / Finalize Pricing feature): added
/// `awaitingWeighing` ("Awaiting Weighing" — mobile booking accepted by
/// the shop but not yet weighed/priced) and `awaitingPayment`
/// ("Awaiting Payment" — price finalized, online payment method,
/// waiting for the customer to pay/upload proof). Both are real status
/// strings the backend now sets — see accept_customer_booking() and
/// finalize_booking_pricing() in booking_controller.py.
enum BookingStatus {
  awaitingApproval,
  awaitingWeighing,
  awaitingPayment,
  pending,
  inProgress,
  ready,
  claimed,
  cancelled,
  declined,
  unknown,
}

extension BookingStatusLabel on BookingStatus {
  String get label {
    switch (this) {
      case BookingStatus.awaitingApproval:
        return 'Awaiting Approval';
      case BookingStatus.awaitingWeighing:
        return 'Awaiting Shop Weight Verification';
      case BookingStatus.awaitingPayment:
        return 'Awaiting Payment';
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.inProgress:
        return 'In Progress';
      case BookingStatus.ready:
        return 'Ready for Pickup';
      case BookingStatus.claimed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.declined:
        return 'Declined';
      case BookingStatus.unknown:
        return 'Unknown';
    }
  }

  /// Kung tapos na ang buong lifecycle ng booking na ito (walang dapat pang
  /// mangyari) — ginagamit para malaman kung ipapakita pa ba ito bilang
  /// "active booking" sa Home page.
  bool get isFinal =>
      this == BookingStatus.claimed || this == BookingStatus.cancelled || this == BookingStatus.declined;
}

/// Converts the backend's raw status string (e.g. "In Progress") into the
/// matching BookingStatus. Falls back to .unknown for anything unrecognized
/// instead of throwing — a status the app doesn't know about yet shouldn't
/// crash the booking list, it should just display generically.
BookingStatus _statusFromApi(String? raw) {
  switch (raw) {
    case 'Awaiting Approval':
      return BookingStatus.awaitingApproval;
    case 'Awaiting Weighing':
      return BookingStatus.awaitingWeighing;
    case 'Awaiting Payment':
      return BookingStatus.awaitingPayment;
    case 'Pending':
      return BookingStatus.pending;
    case 'In Progress':
      return BookingStatus.inProgress;
    case 'Ready':
      return BookingStatus.ready;
    case 'Claimed':
      return BookingStatus.claimed;
    case 'Cancelled':
      return BookingStatus.cancelled;
    case 'Declined':
      return BookingStatus.declined;
    default:
      return BookingStatus.unknown;
  }
}

class Booking {
  const Booking({
    this.id,
    required this.shopName,
    required this.serviceName,
    required this.status,
    this.shopId,
    this.totalPrice,
    this.weight,
    this.loads,
    this.fulfillmentMode,
    this.specialInstructions,
    this.pickupDatetime,
    this.deliveryDatetime,
    this.deliveryFeeCharged,
    this.promoCode,
    this.discountAmount,
    this.bookingTimestamp,
    this.washerNumber,
    this.dryerNumber,
    this.declineReason,
    this.paymentMethod,
    this.paymentStatus,
    this.paidAt,
    this.proofOfPaymentUrl,
    this.paymentRejectionReason,
    this.estimatedWeight,
    this.estimatedPrice,
    this.finalWeight,
    this.finalPrice,
    this.weighingAddonCharges,
    this.weighedAt,
    this.createdAt,
    this.startedAt,
    this.readyAt,
    this.completedAt,
  });

  /// Backend Booking.id — null lang para sa mock/placeholder data na wala
  /// pang totoong record sa database.
  final int? id;

  /// UPDATED: kasama na ngayon ang shop_name sa backend's BookingResponse
  /// (resolved server-side mula sa Booking.shop relationship — see
  /// models.py's Booking.shop_name property). fromJson() gagamitin ito
  /// KUNG NASA response, kung hindi (hal. luma pang cached data), babalik
  /// sa manually-passed [shopName] parameter bilang fallback.
  final String shopName;
  final String serviceName;
  final BookingStatus status;

  final int? shopId;
  final double? totalPrice;
  final double? weight;
  final int? loads;
  final String? fulfillmentMode; // "dropoff" | "delivery"
  final String? specialInstructions;
  final DateTime? pickupDatetime;
  final DateTime? deliveryDatetime;
  final double? deliveryFeeCharged;
  final String? promoCode;
  final double? discountAmount;
  final DateTime? bookingTimestamp;
  final int? washerNumber;
  final int? dryerNumber;

  /// NEW — dahilan kung bakit na-decline ng shop (hal. "Fully booked"),
  /// null maliban kung status == declined. Ipapakita ito sa History/
  /// Notifications page para malaman ng customer kung bakit hindi
  /// natuloy ang kanilang booking.
  final String? declineReason;

  // --- NEW (Payment / Online Payment feature) ---
  /// "cash" | "cod" | "gcash" | "paymaya"
  final String? paymentMethod;

  /// "unpaid" | "pending_verification" | "paid" | "rejected"
  final String? paymentStatus;
  final DateTime? paidAt;

  /// Public Supabase Storage URL ng na-upload na proof-of-payment
  /// screenshot. Null hanggang may na-upload.
  final String? proofOfPaymentUrl;

  /// Dahilan kung bakit tinanggihan ng staff ang proof of payment
  /// (reject_payment() sa booking_controller.py). Null maliban kung
  /// paymentStatus == "rejected" nang matagal na, o kailangan ulit
  /// mag-upload ang customer.
  final String? paymentRejectionReason;

  // --- NEW (Weighing / Finalize Pricing feature) ---
  /// Estimate ng customer sa checkout — hula lang bago pa timbangin.
  final double? estimatedWeight;
  final double? estimatedPrice;

  /// Itinakda ng staff PAGKATAPOS ng aktwal na pagtimbang. Null hanggang
  /// ma-finalize ng shop (status == awaitingWeighing pa lang).
  final double? finalWeight;
  final double? finalPrice;

  /// Ad-hoc na extra charge (₱) na idinagdag ng staff habang tinitimbang.
  final double? weighingAddonCharges;

  /// Kailan aktwal na na-finalize ng staff ang presyo — ito ang
  /// timestamp ng "Weighed / Price Ready" step sa order tracking stepper.
  final DateTime? weighedAt;

  // --- NEW (Order Tracking / Live Stepper feature) ---
  /// Kailan na-create ang booking — timestamp ng "Received" step.
  final DateTime? createdAt;

  /// Kailan naging "In Progress" (naka-assign na ng unang machine) —
  /// timestamp ng "Washing In Progress" step.
  final DateTime? startedAt;

  /// Kailan naging "Ready" — timestamp ng "Ready for Pickup" step.
  final DateTime? readyAt;

  /// Kailan naging "Claimed" — timestamp ng "Completed / Picked up" step.
  final DateTime? completedAt;

  /// Parses a single booking object from the backend's BookingResponse
  /// JSON shape. [shopName] is an OPTIONAL fallback — used only when the
  /// response doesn't carry its own "shop_name" (shouldn't normally
  /// happen now, but kept for resilience / older cached data). When the
  /// caller already knows the shop (e.g. right after creating a booking
  /// from ShopDetailPage), passing it in avoids depending on the network
  /// round-trip having it.
  factory Booking.fromJson(Map<String, dynamic> json, {String shopName = ''}) => Booking(
        id: json['id'] as int?,
        shopName: (json['shop_name'] as String?) ?? shopName,
        serviceName: json['service_type'] as String? ?? '',
        status: _statusFromApi(json['status'] as String?),
        shopId: json['shop_id'] as int?,
        totalPrice: (json['total_price'] as num?)?.toDouble(),
        weight: (json['weight'] as num?)?.toDouble(),
        loads: json['loads'] as int?,
        fulfillmentMode: json['fulfillment_mode'] as String?,
        specialInstructions: json['special_instructions'] as String?,
        pickupDatetime: json['pickup_datetime'] == null
            ? null
            : DateTime.tryParse(json['pickup_datetime'] as String),
        deliveryDatetime: json['delivery_datetime'] == null
            ? null
            : DateTime.tryParse(json['delivery_datetime'] as String),
        deliveryFeeCharged: (json['delivery_fee_charged'] as num?)?.toDouble(),
        promoCode: json['promo_code'] as String?,
        discountAmount: (json['discount_amount'] as num?)?.toDouble(),
        bookingTimestamp: json['booking_timestamp'] == null
            ? null
            : DateTime.tryParse(json['booking_timestamp'] as String),
        washerNumber: json['washer_number'] as int?,
        dryerNumber: json['dryer_number'] as int?,
        declineReason: json['decline_reason'] as String?,
        paymentMethod: json['payment_method'] as String?,
        paymentStatus: json['payment_status'] as String?,
        paidAt: json['paid_at'] == null
            ? null
            : DateTime.tryParse(json['paid_at'] as String),
        proofOfPaymentUrl: json['proof_of_payment_url'] as String?,
        paymentRejectionReason: json['payment_rejection_reason'] as String?,
        estimatedWeight: (json['estimated_weight'] as num?)?.toDouble(),
        estimatedPrice: (json['estimated_price'] as num?)?.toDouble(),
        finalWeight: (json['final_weight'] as num?)?.toDouble(),
        finalPrice: (json['final_price'] as num?)?.toDouble(),
        weighingAddonCharges: (json['weighing_addon_charges'] as num?)?.toDouble(),
        weighedAt: json['weighed_at'] == null
            ? null
            : DateTime.tryParse(json['weighed_at'] as String),
        createdAt: json['created_at'] == null
            ? null
            : DateTime.tryParse(json['created_at'] as String),
        startedAt: json['started_at'] == null
            ? null
            : DateTime.tryParse(json['started_at'] as String),
        readyAt: json['ready_at'] == null
            ? null
            : DateTime.tryParse(json['ready_at'] as String),
        completedAt: json['completed_at'] == null
            ? null
            : DateTime.tryParse(json['completed_at'] as String),
      );
}

// Temporary mock data — will be replaced with a real API call later.
//
// FIX (unnecessary_nullable_for_final_variable_declarations): dating
// `const Booking? mockActiveBooking` — nullable ang type pero laging may
// halaga (hindi kailanman null), kaya ini-fix sa non-nullable `Booking`.
const Booking mockActiveBooking = Booking(
  shopName: 'CleanWave Laundry',
  serviceName: 'Regular Wash',
  status: BookingStatus.inProgress,
);
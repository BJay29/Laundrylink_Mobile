/// Mirrors the `status` values actually set by the backend (see
/// app/models.py's Booking.status default + app/controller/
/// booking_controller.py's transitions).
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

  bool get isFinal =>
      this == BookingStatus.claimed || this == BookingStatus.cancelled || this == BookingStatus.declined;
}

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

/// FIXED (timezone) — ang backend ay nagbabalik ng timestamps na may
/// timezone offset (UTC). Ang `DateTime.tryParse()` ay nagbabalik ng
/// UTC DateTime sa ganoong kaso, at ang `.hour`/`.day` nito ay UTC —
/// kaya 8 oras ang aatras sa Manila kapag direktang ipinakita. Dito
/// pa lang ay kino-convert na sa local time ng device, para tama ang
/// lahat ng display sa buong app (booking form, edit page, tracking).
///
/// IMPORTANT: may mga column sa database na `timestamp` (WALANG
/// timezone) kaya ibinabalik ng backend ang string nang walang "Z" o
/// offset (hal. "2026-11-03T07:18:00"). Itinuturing ng Dart na LOCAL
/// ang ganoong string, kaya hindi na kino-convert at lumalabas ang UTC
/// na oras bilang kung ito'y local (8 oras ang atras sa Manila). Ang
/// lahat ng timestamp ng backend ay UTC, kaya kapag walang timezone,
/// dinadagdagan natin ng "Z" bago i-parse.
DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  var text = (value as String).trim();
  if (text.isEmpty) return null;
  final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(text);
  if (!hasZone) text = '${text}Z';
  return DateTime.tryParse(text)?.toLocal();
}

/// Mirrors the backend's MachineAssignmentResponse (one row per
/// load in a multi-machine booking — see BookingMachineAssignment in
/// app/models.py). `phase` is "washing" | "drying" | "done" and is the
/// source of truth for whether a given load is currently being washed
/// or dried — used to pick the right label for the live countdown
/// timer instead of a hardcoded "Washing In Progress" that never
/// changed once a load moved to the dryer.
class BookingMachineAssignment {
  const BookingMachineAssignment({
    required this.id,
    required this.loadNumber,
    required this.phase,
    this.washerNumber,
    this.dryerNumber,
    this.washingStartedAt,
    this.washingCompletedAt,
    this.dryingStartedAt,
    this.dryingCompletedAt,
  });

  final int id;
  final int loadNumber;

  /// "washing" | "drying" | "done"
  final String phase;

  final int? washerNumber;
  final int? dryerNumber;
  final DateTime? washingStartedAt;
  final DateTime? washingCompletedAt;
  final DateTime? dryingStartedAt;
  final DateTime? dryingCompletedAt;

  factory BookingMachineAssignment.fromJson(Map<String, dynamic> json) => BookingMachineAssignment(
        id: json['id'] as int,
        loadNumber: json['load_number'] as int,
        phase: json['phase'] as String? ?? 'washing',
        washerNumber: json['washer_number'] as int?,
        dryerNumber: json['dryer_number'] as int?,
        washingStartedAt: _parseDate(json['washing_started_at']),
        washingCompletedAt: _parseDate(json['washing_completed_at']),
        dryingStartedAt: _parseDate(json['drying_started_at']),
        dryingCompletedAt: _parseDate(json['drying_completed_at']),
      );
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
    this.dropoffDatetime,
    this.dropoffWindow,
    this.pickupWindow,
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
    this.referenceNumber,
    this.isVerifiedByOcr = false,
    this.extractedAmount,
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
    this.estimatedCompletionTime,
    this.deliveryAddressId,
    this.deliveryAddressLine,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.pickupRiderName,
    this.pickupRiderContact,
    this.pickupRiderAssignedAt,
    this.deliveryRiderName,
    this.deliveryRiderContact,
    this.deliveryRiderAssignedAt,
    this.machineAssignments = const [],
    this.hasRated = false,
    this.rating,
    this.ratingComment,
  });

  final int? id;
  final String shopName;
  final String serviceName;
  final BookingStatus status;

  final int? shopId;
  final double? totalPrice;
  final double? weight;
  final int? loads;
  final String? fulfillmentMode;
  final String? specialInstructions;

  /// Delivery pickup leg (kailan kukunin ng rider ang laundry sa bahay).
  final DateTime? pickupDatetime;

  /// Optional na oras kung kailan balak pumunta ng customer sa shop.
  /// Para sa "dropoff" bookings lang; null kung hindi nagbigay o kung
  /// delivery ang booking.
  final DateTime? dropoffDatetime;

  /// Time window labels: "morning" | "afternoon" | "evening" |
  /// "anytime" | null. Independiyente sa *_datetime — pwedeng meron
  /// window nang walang exact time, o pareho, o wala man lang.
  /// dropoffWindow para sa "dropoff" mode, pickupWindow para sa
  /// "delivery" mode.
  final String? dropoffWindow;
  final String? pickupWindow;

  final DateTime? deliveryDatetime;
  final double? deliveryFeeCharged;
  final String? promoCode;
  final double? discountAmount;
  final DateTime? bookingTimestamp;

  /// Legacy single-machine fields — still populated by the backend for
  /// single-load bookings that used the legacy assign path.
  final int? washerNumber;
  final int? dryerNumber;
  final String? declineReason;

  final String? paymentMethod;
  final String? paymentStatus;
  final DateTime? paidAt;
  final String? proofOfPaymentUrl;
  final String? paymentRejectionReason;

  /// NEW (Secure Payment Verification System) — ang reference number ng
  /// online payment na ipinasok ng customer (GCash/Maya/bank transfer).
  final String? referenceNumber;

  /// NEW — true kapag na-verify na ng OCR pipeline (o na-bypass via
  /// Sandbox Mode) na ang reference number ay lumalabas sa resibo
  /// mismo.
  final bool isVerifiedByOcr;

  /// NEW — amount na na-extract ng OCR mula sa resibo mismo (hindi mula
  /// sa customer input).
  final double? extractedAmount;

  final double? estimatedWeight;
  final double? estimatedPrice;
  final double? finalWeight;
  final double? finalPrice;
  final double? weighingAddonCharges;
  final DateTime? weighedAt;

  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? readyAt;
  final DateTime? completedAt;

  /// Live countdown target, mula sa naka-assign na machine's
  /// cycle_started_at + remaining_time (backend-computed property).
  /// Null kung hindi "In Progress" o walang aktibong machine cycle.
  final DateTime? estimatedCompletionTime;

  final int? deliveryAddressId;
  final String? deliveryAddressLine;
  final double? deliveryLatitude;
  final double? deliveryLongitude;

  final String? pickupRiderName;
  final String? pickupRiderContact;
  final DateTime? pickupRiderAssignedAt;
  final String? deliveryRiderName;
  final String? deliveryRiderContact;
  final DateTime? deliveryRiderAssignedAt;

  /// Per-load machine assignment rows (multi-machine bookings).
  /// Empty for legacy single-machine bookings, which instead use
  /// washerNumber/dryerNumber directly.
  final List<BookingMachineAssignment> machineAssignments;

  /// NEW (Rating after order) — mirrors BookingResponse.has_rated /
  /// rating / rating_comment sa backend (computed properties sa Booking
  /// model). `hasRated` ay true kapag nakapag-rate na ang customer sa
  /// booking na ito; `rating` ay 1-5 (null kung hindi pa); `ratingComment`
  /// ay ang opsyonal na komento.
  final bool hasRated;
  final int? rating;
  final String? ratingComment;

  /// Resolves whether the booking's active machine cycle right
  /// now is a "washing" or "drying" phase, for the countdown timer's
  /// label. Priority:
  ///   1. Any not-yet-"done" load in machineAssignments (multi-machine
  ///      path) — if ANY load is still "drying", treat the whole
  ///      booking as "drying".
  ///   2. Legacy single-machine fallback: dryerNumber set → "drying";
  ///      otherwise "washing".
  /// Returns null if status isn't inProgress at all.
  String? get activePhase {
    if (status != BookingStatus.inProgress) return null;

    if (machineAssignments.isNotEmpty) {
      final active = machineAssignments.where((a) => a.phase != 'done').toList();
      if (active.isEmpty) return 'washing';
      if (active.any((a) => a.phase == 'drying')) return 'drying';
      return 'washing';
    }

    if (dryerNumber != null) return 'drying';
    return 'washing';
  }

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
        pickupDatetime: _parseDate(json['pickup_datetime']),
        dropoffDatetime: _parseDate(json['dropoff_datetime']),
        dropoffWindow: json['dropoff_window'] as String?,
        pickupWindow: json['pickup_window'] as String?,
        deliveryDatetime: _parseDate(json['delivery_datetime']),
        deliveryFeeCharged: (json['delivery_fee_charged'] as num?)?.toDouble(),
        promoCode: json['promo_code'] as String?,
        discountAmount: (json['discount_amount'] as num?)?.toDouble(),
        bookingTimestamp: _parseDate(json['booking_timestamp']),
        washerNumber: json['washer_number'] as int?,
        dryerNumber: json['dryer_number'] as int?,
        declineReason: json['decline_reason'] as String?,
        paymentMethod: json['payment_method'] as String?,
        paymentStatus: json['payment_status'] as String?,
        paidAt: _parseDate(json['paid_at']),
        proofOfPaymentUrl: json['proof_of_payment_url'] as String?,
        paymentRejectionReason: json['payment_rejection_reason'] as String?,
        referenceNumber: json['reference_number'] as String?,
        isVerifiedByOcr: json['is_verified_by_ocr'] as bool? ?? false,
        extractedAmount: (json['extracted_amount'] as num?)?.toDouble(),
        estimatedWeight: (json['estimated_weight'] as num?)?.toDouble(),
        estimatedPrice: (json['estimated_price'] as num?)?.toDouble(),
        finalWeight: (json['final_weight'] as num?)?.toDouble(),
        finalPrice: (json['final_price'] as num?)?.toDouble(),
        weighingAddonCharges: (json['weighing_addon_charges'] as num?)?.toDouble(),
        weighedAt: _parseDate(json['weighed_at']),
        createdAt: _parseDate(json['created_at']),
        startedAt: _parseDate(json['started_at']),
        readyAt: _parseDate(json['ready_at']),
        completedAt: _parseDate(json['completed_at']),
        estimatedCompletionTime: _parseDate(json['estimated_completion_time']),
        deliveryAddressId: json['delivery_address_id'] as int?,
        deliveryAddressLine: json['delivery_address_line'] as String?,
        deliveryLatitude: (json['delivery_latitude'] as num?)?.toDouble(),
        deliveryLongitude: (json['delivery_longitude'] as num?)?.toDouble(),
        pickupRiderName: json['pickup_rider_name'] as String?,
        pickupRiderContact: json['pickup_rider_contact'] as String?,
        pickupRiderAssignedAt: _parseDate(json['pickup_rider_assigned_at']),
        deliveryRiderName: json['delivery_rider_name'] as String?,
        deliveryRiderContact: json['delivery_rider_contact'] as String?,
        deliveryRiderAssignedAt: _parseDate(json['delivery_rider_assigned_at']),
        machineAssignments: (json['machine_assignments'] as List<dynamic>?)
                ?.map((e) => BookingMachineAssignment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        hasRated: json['has_rated'] as bool? ?? false,
        rating: json['rating'] as int?,
        ratingComment: json['rating_comment'] as String?,
      );
}

const Booking mockActiveBooking = Booking(
  shopName: 'CleanWave Laundry',
  serviceName: 'Regular Wash',
  status: BookingStatus.inProgress,
);
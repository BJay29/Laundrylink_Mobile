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

/// NEW — mirrors the backend's MachineAssignmentResponse (one row per
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
        washingStartedAt: json['washing_started_at'] == null
            ? null
            : DateTime.tryParse(json['washing_started_at'] as String),
        washingCompletedAt: json['washing_completed_at'] == null
            ? null
            : DateTime.tryParse(json['washing_completed_at'] as String),
        dryingStartedAt: json['drying_started_at'] == null
            ? null
            : DateTime.tryParse(json['drying_started_at'] as String),
        dryingCompletedAt: json['drying_completed_at'] == null
            ? null
            : DateTime.tryParse(json['drying_completed_at'] as String),
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
  final DateTime? pickupDatetime;
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

  /// NEW — per-load machine assignment rows (multi-machine bookings).
  /// Empty for legacy single-machine bookings, which instead use
  /// washerNumber/dryerNumber directly.
  final List<BookingMachineAssignment> machineAssignments;

  /// NEW — resolves whether the booking's active machine cycle right
  /// now is a "washing" or "drying" phase, for the countdown timer's
  /// label. Priority:
  ///   1. Any not-yet-"done" load in machineAssignments (multi-machine
  ///      path) — if ANY load is still "drying", treat the whole
  ///      booking as "drying" (a later phase supersedes an earlier one
  ///      for display purposes, since the countdown itself already
  ///      reflects the single longest-remaining active cycle).
  ///   2. Legacy single-machine fallback: dryerNumber set and no
  ///      washerNumber (dry_only) or both set (full_service, assume
  ///      drying once dryer is present) → "drying"; otherwise
  ///      "washing".
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
        estimatedCompletionTime: json['estimated_completion_time'] == null
            ? null
            : DateTime.tryParse(json['estimated_completion_time'] as String),
        deliveryAddressId: json['delivery_address_id'] as int?,
        deliveryAddressLine: json['delivery_address_line'] as String?,
        deliveryLatitude: (json['delivery_latitude'] as num?)?.toDouble(),
        deliveryLongitude: (json['delivery_longitude'] as num?)?.toDouble(),
        pickupRiderName: json['pickup_rider_name'] as String?,
        pickupRiderContact: json['pickup_rider_contact'] as String?,
        pickupRiderAssignedAt: json['pickup_rider_assigned_at'] == null
            ? null
            : DateTime.tryParse(json['pickup_rider_assigned_at'] as String),
        deliveryRiderName: json['delivery_rider_name'] as String?,
        deliveryRiderContact: json['delivery_rider_contact'] as String?,
        deliveryRiderAssignedAt: json['delivery_rider_assigned_at'] == null
            ? null
            : DateTime.tryParse(json['delivery_rider_assigned_at'] as String),
        machineAssignments: (json['machine_assignments'] as List<dynamic>?)
                ?.map((e) => BookingMachineAssignment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

const Booking mockActiveBooking = Booking(
  shopName: 'CleanWave Laundry',
  serviceName: 'Regular Wash',
  status: BookingStatus.inProgress,
);
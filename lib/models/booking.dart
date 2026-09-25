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

  /// NEW — live countdown target, mula sa naka-assign na machine's
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
      );
}

const Booking mockActiveBooking = Booking(
  shopName: 'CleanWave Laundry',
  serviceName: 'Regular Wash',
  status: BookingStatus.inProgress,
);
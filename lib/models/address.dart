/// Client-side model for a customer's saved address.
/// Mirrors AddressResponse in app/schemas.py.
class Address {
  const Address({
    required this.id,
    required this.customerId,
    required this.label,
    required this.addressLine,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  final int id;
  final int customerId;
  final String label;
  final String addressLine;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        id: json['id'] as int,
        customerId: json['customer_id'] as int,
        label: json['label'] as String? ?? 'Home',
        addressLine: json['address_line'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        isDefault: json['is_default'] as bool? ?? false,
      );

  /// Payload para sa POST /addresses/ at PATCH /addresses/{id} — hindi
  /// kasama ang id/customer_id dahil server-derived/server-scoped ito.
  Map<String, dynamic> toJson() => {
        'label': label,
        'address_line': addressLine,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'is_default': isDefault,
      };

  Address copyWith({
    String? label,
    String? addressLine,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) =>
      Address(
        id: id,
        customerId: customerId,
        label: label ?? this.label,
        addressLine: addressLine ?? this.addressLine,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        isDefault: isDefault ?? this.isDefault,
      );
}
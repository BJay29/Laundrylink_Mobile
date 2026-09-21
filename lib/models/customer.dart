class Customer {
  const Customer({
    this.id,
    required this.fullName,
    this.email,
    required this.mobileNumber,
    this.isActive = true,
    this.isVerified = false,
    this.profileImageUrl,
  });

  /// Backend Customer.id — null lang para sa demo/placeholder data.
  final int? id;

  final String fullName;

  /// NEW — nasa CustomerResponse ang email pero wala pa dito noon.
  /// Nullable dahil sa demo constant sa ibaba (walang totoong email).
  final String? email;

  final String mobileNumber;

  /// NEW — kailangan natin itong malaman (hal. i-block ang pag-book kung
  /// deactivated ang account, o ipakita sa Profile page).
  final bool isActive;

  /// NEW — email verification status. Ginagamit ng splash/login flow
  /// para malaman kung dapat pang ipadala ang customer sa Verify Email
  /// screen bago sila pumasok sa Home.
  final bool isVerified;

  /// Wala pang katumbas na field sa backend (Customer model walang
  /// profile picture column ngayon) — nananatiling client-only/optional
  /// hanggang idagdag ito sa API.
  final String? profileImageUrl;

  String get initials {
    final names = fullName.trim().split(RegExp(r'\s+'));
    if (names.isEmpty || names.first.isEmpty) return 'U';
    if (names.length == 1) return names.first.substring(0, 1).toUpperCase();
    return '${names.first.substring(0, 1)}${names.last.substring(0, 1)}'.toUpperCase();
  }

  /// Parses the `customer` object returned inside CustomerLoginResponse /
  /// CustomerResponse (see app/schemas.py).
  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as int?,
        fullName: json['full_name'] as String? ?? '',
        email: json['email'] as String?,
        mobileNumber: json['mobile_number'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
        isVerified: json['is_verified'] as bool? ?? false,
      );

  static const demo = Customer(
    fullName: 'Juan Dela Cruz',
    mobileNumber: '+63 912 345 6789',
    isVerified: true,
  );
}
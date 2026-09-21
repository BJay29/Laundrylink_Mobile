class ShopServiceItem {
  const ShopServiceItem({
    required this.id,
    required this.name,
    required this.price,
    this.durationMinutes,
    this.pricingUnit = 'load',
  });

  final int id;
  final String name;
  final double price;

  /// NULLABLE — ang backend's ShopServicePreview (public, customer-facing
  /// endpoint) ay HINDI naglalabas ng duration (id/name/price/pricing_unit
  /// lang, see schemas.py). Ang washer_duration_minutes/
  /// dryer_duration_minutes ay staff-only fields na nasa
  /// ServiceTypeResponse — hindi ito available sa mobile app's public
  /// Shop Detail fetch. Kaya kung wala sa JSON, null lang ito; huwag
  /// itong asahan sa checkout UI.
  final int? durationMinutes;

  /// "load", "kg", o "piece" (see ShopServicePreview sa backend).
  /// Kontrolado nito kung ano ang ipapakita/hihingiin sa quantity field
  /// ng booking form (hal. "Weight (kg)" vs "Number of loads").
  final String pricingUnit;

  factory ShopServiceItem.fromJson(Map<String, dynamic> json) => ShopServiceItem(
        id: json['id'] as int,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        durationMinutes: json['duration_minutes'] as int?,
        pricingUnit: json['pricing_unit'] as String? ?? 'load',
      );
}

/// Mirrors the backend's AddOnPreview (id, name, price). Populated only
/// on Shop Detail (GET /shops/{id}), same as `services`.
class AddOnItem {
  const AddOnItem({
    required this.id,
    required this.name,
    required this.price,
  });

  final int id;
  final String name;
  final double price;

  factory AddOnItem.fromJson(Map<String, dynamic> json) => AddOnItem(
        id: json['id'] as int,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
      );
}

class Shop {
  const Shop({
    required this.id,
    required this.shopName,
    this.address,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.isOnline = false,
    this.hasDelivery = false,
    this.deliveryFee = 0.0,
    this.services = const [],
    this.addOns = const [],
    this.qrCodeUrl,
  });

  final int id;
  final String shopName;
  final String? address;
  final double? latitude;
  final double? longitude;

  /// Populated lang kapag galing sa GET /shops/nearby. Null habang wala
  /// pang geolocator/coordinates setup.
  final double? distanceKm;

  /// Real-time na "online" status ng shop — see the earlier is_online
  /// feature notes in shop_detail_page.dart / home_page.dart.
  final bool isOnline;

  /// Kung meron bang delivery option ang shop, at magkano ito.
  /// Ginagamit ng booking form para i-decide kung ipapakita ang
  /// "Delivery" bilang fulfillment_mode option; kung false, "Drop-off"
  /// na lang ang pipiliin.
  final bool hasDelivery;
  final double deliveryFee;

  /// Laman lang ito kapag galing sa GET /shops/{id} (Shop Detail).
  /// Blangko sa GET /shops/ (listing) — hindi kasama ang services doon.
  final List<ShopServiceItem> services;

  /// Parehong dahilan, laman lang sa Shop Detail response.
  final List<AddOnItem> addOns;

  /// UPDATED (online_qr consolidation) — dating hiwalay na
  /// gcashQrUrl/paymayaQrUrl, ngayon iisang generic QR na lang per
  /// shop (see Shop.qr_code_url sa backend — National QR Ph style,
  /// tumatanggap ng GCash/PayMaya/atbp. sa iisang QR image).
  ///
  /// Null kung hindi pa naka-set ng shop ang kanilang QR sa
  /// Optimization Settings — ginagamit ito ng booking_form_page.dart
  /// bilang "shop toggle": kung null ito, hindi dapat ipakita ang
  /// "Online Payment (QR Ph)" option sa payment method selector,
  /// "Cash on Counter" na lang ang available.
  final String? qrCodeUrl;

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
        id: json['id'] as int,
        shopName: json['shop_name'] as String,
        address: json['address'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
        isOnline: json['is_online'] as bool? ?? false,
        hasDelivery: json['has_delivery'] as bool? ?? false,
        deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
        services: json['services'] == null
            ? const []
            : (json['services'] as List<dynamic>)
                .map((s) => ShopServiceItem.fromJson(s as Map<String, dynamic>))
                .toList(),
        addOns: json['add_ons'] == null
            ? const []
            : (json['add_ons'] as List<dynamic>)
                .map((a) => AddOnItem.fromJson(a as Map<String, dynamic>))
                .toList(),
        qrCodeUrl: json['qr_code_url'] as String?,
      );
}
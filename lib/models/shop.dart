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

/// NEW (Home page promo carousel) — mirrors the backend's
/// PromoCodePreview (schemas.py): a safe, customer-facing view of one
/// of a shop's currently-ACTIVE promo codes. The backend has already
/// filtered out inactive/expired/exhausted codes before this ever
/// reaches the app (see shop_service._get_active_promos()) — this
/// class does no validity checking of its own, it's purely display +
/// the code text itself, which doubles as what the customer types into
/// the "Promo code" field on BookingFormPage.
class PromoPreview {
  const PromoPreview({
    required this.code,
    required this.discountType,
    required this.discountValue,
  });

  final String code;

  /// "percent" or "fixed" — same two values the backend's PromoCode
  /// model uses (see discount_type in models.py).
  final String discountType;
  final double discountValue;

  /// Short display label for a badge/chip — "20% OFF" for a percent
  /// discount, "₱50 OFF" for a fixed peso discount.
  String get label => discountType == 'percent'
      ? '${discountValue.toStringAsFixed(0)}% OFF'
      : '₱${discountValue.toStringAsFixed(0)} OFF';

  factory PromoPreview.fromJson(Map<String, dynamic> json) => PromoPreview(
        code: json['code'] as String,
        discountType: json['discount_type'] as String? ?? 'percent',
        discountValue: (json['discount_value'] as num?)?.toDouble() ?? 0.0,
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
    this.activePromos = const [],
    this.acceptsCash = true,
    this.acceptsCod = false,
    this.acceptsOnline = false,
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
  /// Optimization Settings. Sa sarili nito, HINDI na ito sapat para
  /// malaman kung dapat bang tanggapin ang "Online Payment" — see
  /// [acceptsOnline] sa ibaba, na siyang HIWALAY na "gustong tanggapin
  /// ba" toggle. Parehong kailangan (`acceptsOnline && qrCodeUrl !=
  /// null`) bago ipakita bilang available ang online payment.
  final String? qrCodeUrl;

  /// NEW (Home page promo carousel) — currently-active promo codes for
  /// this shop, populated on BOTH GET /shops/ (listing) and
  /// GET /shops/nearby, same as the other listing-level fields above.
  /// Empty for a shop with no live promos right now. The Home page
  /// filters shops down to the ones where this is non-empty to build
  /// the "Promos for you" carousel — see widgets/promo_carousel.dart.
  final List<PromoPreview> activePromos;

  /// NEW (Online Payment toggle fix — Booking & Order Tracking Flow
  /// Fix). Mirrors the shop's "Payment Methods" toggles from
  /// Optimization Settings (Shop.accepts_cash/accepts_cod/
  /// accepts_online in the backend). Only populated on Shop Detail
  /// (GET /shops/{id}), same as qrCodeUrl — defaults (true/false/false)
  /// match the backend's own column defaults, so a shop that hasn't
  /// touched these settings still resolves sensibly.
  ///
  /// FIXED: dati ay `qrCodeUrl != null` LANG ang tinitingnan ng
  /// BookingFormPage para malaman kung available ba ang online
  /// payment — kaya kahit naka-ON na ang toggle na ito sa web,
  /// nananatiling naka-disable ang option hangga't walang na-upload na
  /// QR image (dalawang magkaibang bagay na dati'y pinagsama bilang
  /// isa). Ngayon, PAREHONG kailangan: [acceptsOnline] == true AT
  /// [qrCodeUrl] != null.
  final bool acceptsCash;
  final bool acceptsCod;
  final bool acceptsOnline;

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
        activePromos: json['active_promos'] == null
            ? const []
            : (json['active_promos'] as List<dynamic>)
                .map((p) => PromoPreview.fromJson(p as Map<String, dynamic>))
                .toList(),
        acceptsCash: json['accepts_cash'] as bool? ?? true,
        acceptsCod: json['accepts_cod'] as bool? ?? false,
        acceptsOnline: json['accepts_online'] as bool? ?? false,
      );
}
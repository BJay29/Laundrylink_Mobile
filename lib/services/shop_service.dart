import 'api_service.dart';
import '../models/blocked_date.dart';
import '../models/shop.dart';

/// Public shop-discovery endpoints (walang auth na kailangan) — ginagamit
/// ng Home carousel, Shop Selection Page, at Shop Detail Page.
class ShopService {
  ShopService({ApiService? api}) : _api = api ?? ApiService();
  final ApiService _api;

  /// Buong listahan ng published shops. Ito ang gagamitin ng Home carousel
  /// at Shop Selection Page habang wala pang location/geolocator.
  Future<List<Shop>> getShops() async {
    final data = await _api.getList('/shops/');
    return data
        .map((json) => Shop.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Shops sa loob ng radius_km mula sa ibinigay na coordinates.
  /// Babalikan na lang ito pagkatapos ma-setup ang geolocator.
  Future<List<Shop>> getNearbyShops({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  }) async {
    final data = await _api.getList(
      '/shops/nearby?latitude=$latitude&longitude=$longitude&radius_km=$radiusKm',
    );
    return data
        .map((json) => Shop.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Shop Detail page: shop info + services list.
  Future<Shop> getShopDetail(int shopId) async {
    final data = await _api.get('/shops/$shopId');
    return Shop.fromJson(data);
  }

  /// NEW (Fully Booked dates) — mga petsang minarkahan ng shop na fully
  /// booked na (upcoming lang). Ginagamit ng booking form at edit
  /// booking para i-grey out ang mga petsang iyon sa date picker.
  ///
  /// PAALALA: customer-authenticated ang endpoint na ito
  /// (GET /blocked-dates/shop/{id}) — dapat ipadala ng ApiService ang
  /// token ng naka-login na customer gaya ng ginagawa nito sa ibang
  /// customer endpoints (hal. addresses, bookings).
  Future<List<BlockedDate>> getBlockedDates(int shopId) async {
    final data = await _api.getList('/blocked-dates/shop/$shopId');
    return data
        .map((json) => BlockedDate.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
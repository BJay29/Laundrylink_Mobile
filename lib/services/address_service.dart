import '../models/address.dart';
import 'api_service.dart';
import 'customer_session.dart';

/// Customer (mobile app) saved-addresses endpoints. Same auth pattern
/// as BookingService/NotificationService — every call attaches the
/// Bearer token from CustomerSession.
class AddressService {
  AddressService({ApiService? api}) : _api = api ?? ApiService();
  final ApiService _api;

  String get _requireToken {
    final token = CustomerSession.instance.authToken;
    if (token == null) {
      throw const ApiException('You must be logged in to manage addresses.', statusCode: 401);
    }
    return token;
  }

  /// Fetches all saved addresses for the logged-in customer — default
  /// first, then most recently added.
  Future<List<Address>> getMyAddresses() async {
    final data = await _api.getList('/addresses/mine', token: _requireToken);
    return data
        .map((json) => Address.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Adds a new saved address. The first address a customer adds
  /// automatically becomes their default (handled server-side).
  Future<Address> createAddress({
    required String label,
    required String addressLine,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    final body = <String, dynamic>{
      'label': label,
      'address_line': addressLine,
      'is_default': isDefault,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
    final data = await _api.post('/addresses/', body, token: _requireToken);
    return Address.fromJson(data);
  }

  /// Edits an existing address, or promotes it to the default (backend
  /// automatically un-defaults any other address for this customer).
  Future<Address> updateAddress(
    int addressId, {
    String? label,
    String? addressLine,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) async {
    final body = <String, dynamic>{
      if (label != null) 'label': label,
      if (addressLine != null) 'address_line': addressLine,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (isDefault != null) 'is_default': isDefault,
    };
    final data = await _api.patch('/addresses/$addressId', body, token: _requireToken);
    return Address.fromJson(data);
  }

  /// Deletes a saved address. If it was the default, the backend
  /// automatically promotes the next most-recent address (if any).
  Future<void> deleteAddress(int addressId) async {
    await _api.delete('/addresses/$addressId', token: _requireToken);
  }
}
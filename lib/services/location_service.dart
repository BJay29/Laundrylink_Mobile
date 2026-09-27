// ============================= lib/services/location_service.dart (BAGO) =============================
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Thrown when location cannot be resolved — mensahe na dapat ipakita
/// nang direkta sa user (permission denied, services off, walang address
/// nakuha sa reverse geocode, etc).
class LocationException implements Exception {
  const LocationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Resolved location — raw coordinates + human-readable address string,
/// kasing-hugis ng kailangan ng Address model/AddressService (lat, lng,
/// addressLine).
class ResolvedLocation {
  const ResolvedLocation({
    required this.latitude,
    required this.longitude,
    required this.addressLine,
  });

  final double latitude;
  final double longitude;
  final String addressLine;
}

/// Wrapper sa geolocator + geocoding — dalawang hakbang lang ang ginagawa
/// nito: (1) kunin ang aktwal na GPS coordinates ng device, (2) i-reverse
/// geocode iyon papunta sa readable address string. Ginagamit ito ng
/// SavedAddressesPage's "Use my current location" button.
class LocationService {
  /// Kumukuha ng kasalukuyang GPS position + kaakibat na address, na may
  /// buong permission-request flow. Nagta-throw ng [LocationException]
  /// (hindi crash) sa bawat failure case, para madaling ipakita bilang
  /// SnackBar/dialog sa UI.
  Future<ResolvedLocation> getCurrentLocationWithAddress() async {
    final position = await _getCurrentPosition();
    final addressLine = await _reverseGeocode(position.latitude, position.longitude);
    return ResolvedLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      addressLine: addressLine,
    );
  }

  Future<Position> _getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
        'Location services are turned off. Please enable GPS/Location and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException(
          'Location permission was denied. Please allow location access to use this feature.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permission is permanently denied. Please enable it from your device settings.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      throw const LocationException('Unable to get your current location. Please try again.');
    }
  }

  Future<String> _reverseGeocode(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) {
        throw const LocationException('Could not determine an address for this location.');
      }

      final p = placemarks.first;
      // Binubuo ang address string mula sa magkakahiwalay na parte
      // (street, subLocality, locality, province) — sinasala muna ang
      // mga blangko bago pagsamahin, para hindi lumabas na may
      // sunod-sunod na ", ,".
      final parts = <String>[
        if ((p.street ?? '').trim().isNotEmpty) p.street!.trim(),
        if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
        if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
        if ((p.administrativeArea ?? '').trim().isNotEmpty) p.administrativeArea!.trim(),
      ];

      if (parts.isEmpty) {
        throw const LocationException('Could not determine an address for this location.');
      }

      return parts.join(', ');
    } on LocationException {
      rethrow;
    } catch (_) {
      throw const LocationException('Could not determine an address for this location.');
    }
  }
}
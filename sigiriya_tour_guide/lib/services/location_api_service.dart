import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// API Service for location prediction and nearby suggestions.
/// 
/// Connects to the deployed Railway backend for real-time location
/// intelligence and tourist recommendations.
class LocationApiService {
  /// Production Railway API base URL
  static const String _baseUrl = 'https://web-production-b9903.up.railway.app';

  /// Timeout duration for API calls
  static const Duration _timeout = Duration(seconds: 25);

  final http.Client _client;

  LocationApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Predicts the current location based on GPS coordinates.
  /// 
  /// Returns location name, description and coordinates.
  Future<PredictResponse> predictLocation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/predict'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'lat': latitude,
              'lon': longitude,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return PredictResponse.fromJson(jsonData);
      } else {
        throw LocationApiException(
          'Failed to predict location',
          code: response.statusCode,
        );
      }
    } on SocketException {
      throw LocationApiException(
        'No internet connection',
        code: -1,
      );
    } on TimeoutException {
      throw LocationApiException(
        'Request timed out',
        code: -2,
      );
    } catch (e) {
      if (e is LocationApiException) rethrow;
      throw LocationApiException(
        'Something went wrong: $e',
        code: -4,
      );
    }
  }

  /// Gets the nearest location and nearby places based on coordinates.
  /// 
  /// Returns current location, nearest location with distance,
  /// and a list of nearby locations sorted by distance.
  Future<SuggestNearestResponse> suggestNearest({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/suggest-nearest'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'lat': latitude,
              'lon': longitude,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return SuggestNearestResponse.fromJson(jsonData);
      } else {
        throw LocationApiException(
          'Failed to get nearby locations',
          code: response.statusCode,
        );
      }
    } on SocketException {
      throw LocationApiException(
        'No internet connection',
        code: -1,
      );
    } on TimeoutException {
      throw LocationApiException(
        'Request timed out',
        code: -2,
      );
    } catch (e) {
      if (e is LocationApiException) rethrow;
      throw LocationApiException(
        'Something went wrong: $e',
        code: -4,
      );
    }
  }

  void dispose() {
    _client.close();
  }
}

/// Response model for /predict endpoint
class PredictResponse {
  final String locationName;
  final String description;
  final double latitude;
  final double longitude;

  PredictResponse({
    required this.locationName,
    required this.description,
    required this.latitude,
    required this.longitude,
  });

  factory PredictResponse.fromJson(Map<String, dynamic> json) {
    return PredictResponse(
      locationName: json['location_name'] ?? 'Unknown Location',
      description: json['description'] ?? '',
      latitude: (json['coords']?['lat'] ?? 0.0).toDouble(),
      longitude: (json['coords']?['lon'] ?? 0.0).toDouble(),
    );
  }
}

/// Response model for /suggest-nearest endpoint
class SuggestNearestResponse {
  final CurrentPosition currentPosition;
  final String currentLocationName;
  final NearestLocation nearestLocation;
  final List<NearbyLocation> nearbyLocations;

  SuggestNearestResponse({
    required this.currentPosition,
    required this.currentLocationName,
    required this.nearestLocation,
    required this.nearbyLocations,
  });

  factory SuggestNearestResponse.fromJson(Map<String, dynamic> json) {
    return SuggestNearestResponse(
      currentPosition: CurrentPosition.fromJson(json['current_position'] ?? {}),
      currentLocationName: json['current_location'] ?? 'Unknown',
      nearestLocation: NearestLocation.fromJson(json['nearest_location'] ?? {}),
      nearbyLocations: (json['nearby_locations'] as List<dynamic>?)
              ?.map((e) => NearbyLocation.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class CurrentPosition {
  final double lat;
  final double lon;

  CurrentPosition({required this.lat, required this.lon});

  factory CurrentPosition.fromJson(Map<String, dynamic> json) {
    return CurrentPosition(
      lat: (json['lat'] ?? 0.0).toDouble(),
      lon: (json['lon'] ?? 0.0).toDouble(),
    );
  }
}

class NearestLocation {
  final String name;
  final double lat;
  final double lon;
  final double distanceMeters;
  final double distanceKm;
  final String distanceText;
  final String description;

  NearestLocation({
    required this.name,
    required this.lat,
    required this.lon,
    required this.distanceMeters,
    required this.distanceKm,
    required this.distanceText,
    required this.description,
  });

  factory NearestLocation.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] ?? {};
    return NearestLocation(
      name: json['name'] ?? 'Unknown',
      lat: (coords['lat'] ?? 0.0).toDouble(),
      lon: (coords['lon'] ?? 0.0).toDouble(),
      distanceMeters: (json['distance_meters'] ?? 0.0).toDouble(),
      distanceKm: (json['distance_km'] ?? 0.0).toDouble(),
      distanceText: json['distance_text'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class NearbyLocation {
  final String locationName;
  final double distanceMeters;
  final double distanceKm;

  NearbyLocation({
    required this.locationName,
    required this.distanceMeters,
    required this.distanceKm,
  });

  factory NearbyLocation.fromJson(Map<String, dynamic> json) {
    return NearbyLocation(
      locationName: json['location_name'] ?? 'Unknown',
      distanceMeters: (json['distance_meters'] ?? 0.0).toDouble(),
      distanceKm: (json['distance_km'] ?? 0.0).toDouble(),
    );
  }
}

/// Custom exception for Location API errors
class LocationApiException implements Exception {
  final String message;
  final int code;

  LocationApiException(this.message, {required this.code});

  @override
  String toString() => 'LocationApiException: $message (code: $code)';
}

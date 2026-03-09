import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

/// Service to handle navigation to external mapping apps
class NavigationService {
  /// POI coordinates mapping
  static const Map<String, Map<String, double>> _poiCoordinates = {
    'Water Fountains': {'lat': 7.957264470805178, 'lng': 80.75561410058413},
    'Water Garden': {'lat': 7.957415931176702, 'lng': 80.75471084073263},
    'Sigiriya Entrance': {'lat': 7.956697268003286, 'lng': 80.75396345864562},
    'Bridge over Moat': {'lat': 7.956954106371255, 'lng': 80.75510077981652},
    'Summer Palace': {'lat': 7.957171470685438, 'lng': 80.75584225016989},
    'Caves with Inscriptions': {'lat': 7.957883353805996, 'lng': 80.75669275009768},
    'Lion\'s Paw': {'lat': 7.958399235097665, 'lng': 80.75724009323848},
    'Main Palace': {'lat': 7.958911891209235, 'lng': 80.75722173247165},
    'Boulder Gardens': {'lat': 7.957615931176702, 'lng': 80.75488084073263},
    'Mirror Wall': {'lat': 7.958299235097665, 'lng': 80.75714009323848},
    'Frescoes': {'lat': 7.958199235097665, 'lng': 80.75704009323848},
    'Summit': {'lat': 7.958911891209235, 'lng': 80.75722173247165},
  };

  /// Opens Google Maps navigation to the specified destination
  /// 
  /// [destinationName] - The name of the POI to navigate to
  /// [currentLatitude] - Current user latitude (optional)
  /// [currentLongitude] - Current user longitude (optional)
  static Future<bool> openGoogleMapsNavigation({
    required String destinationName,
    double? currentLatitude,
    double? currentLongitude,
  }) async {
    try {
      // Get destination coordinates
      final destination = _getCoordinatesForPOI(destinationName);
      if (destination == null) {
        return false;
      }

      final destLat = destination['lat']!;
      final destLng = destination['lng']!;

      Uri? mapsUri;

      if (Platform.isAndroid) {
        // Android: Use Google Maps app or browser
        if (currentLatitude != null && currentLongitude != null) {
          // Navigation with current location
          mapsUri = Uri.parse(
            'google.navigation:q=$destLat,$destLng&mode=w'
          );
        } else {
          // Just show location
          mapsUri = Uri.parse(
            'geo:$destLat,$destLng?q=$destLat,$destLng($destinationName)'
          );
        }
      } else if (Platform.isIOS) {
        // iOS: Use Apple Maps
        if (currentLatitude != null && currentLongitude != null) {
          // Navigation with directions
          mapsUri = Uri.parse(
            'maps:?saddr=$currentLatitude,$currentLongitude&daddr=$destLat,$destLng&dirflg=w'
          );
        } else {
          // Just show location
          mapsUri = Uri.parse(
            'maps:?q=$destLat,$destLng'
          );
        }
      } else {
        // Web/Desktop: Use Google Maps web
        if (currentLatitude != null && currentLongitude != null) {
          mapsUri = Uri.parse(
            'https://www.google.com/maps/dir/$currentLatitude,$currentLongitude/$destLat,$destLng/@$destLat,$destLng,17z/data=!3m1!4b1!4m2!4m1!3e2'
          );
        } else {
          mapsUri = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$destLat,$destLng'
          );
        }
      }

      // Try to launch the maps app
      if (await canLaunchUrl(mapsUri)) {
        return await launchUrl(
          mapsUri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Fallback to web Google Maps
        final fallbackUri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$destLat,$destLng'
        );
        return await launchUrl(
          fallbackUri,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      print('Error opening maps: $e');
      return false;
    }
  }

  /// Gets coordinates for a POI by name or partial match
  static Map<String, double>? _getCoordinatesForPOI(String poiName) {
    // Direct match
    if (_poiCoordinates.containsKey(poiName)) {
      return _poiCoordinates[poiName];
    }

    // Partial match (case insensitive)
    final lowerPoiName = poiName.toLowerCase();
    for (final entry in _poiCoordinates.entries) {
      if (entry.key.toLowerCase().contains(lowerPoiName) ||
          lowerPoiName.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    return null;
  }

  /// Extracts destination name from AI navigation messages
  /// Returns null if no navigation destination is found
  static String? extractNavigationDestination(String message) {
    // Look for patterns like:
    // "WALKING TO Water Fountains"
    // "Head northeast towards the Water Garden"
    // "Navigate to Lion's Paw"
    
    final walkingToPattern = RegExp(r'WALKING TO\s+(.+?)(?:\s|$)', caseSensitive: false);
    final towardsPattern = RegExp(r'towards?\s+(?:the\s+)?(.+?)(?:\s|$)', caseSensitive: false);
    final navigatePattern = RegExp(r'navigate\s+to\s+(?:the\s+)?(.+?)(?:\s|$)', caseSensitive: false);
    final headToPattern = RegExp(r'head\s+.+?\s+to\s+(?:the\s+)?(.+?)(?:\s|$)', caseSensitive: false);

    // Try different patterns
    final patterns = [walkingToPattern, towardsPattern, navigatePattern, headToPattern];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null && match.group(1) != null) {
        String destination = match.group(1)!.trim();
        
        // Clean up common suffixes
        destination = destination.replaceAll(RegExp(r'\s+(path|area|location|site|attraction)$'), '');
        
        // Check if this matches any known POI
        if (_getCoordinatesForPOI(destination) != null) {
          return destination;
        }
      }
    }

    return null;
  }

  /// Checks if a message contains navigation information
  static bool isNavigationMessage(String message) {
    return extractNavigationDestination(message) != null ||
           message.toLowerCase().contains('walking to') ||
           message.toLowerCase().contains('head northeast') ||
           message.toLowerCase().contains('navigate to') ||
           message.toLowerCase().contains('directions to');
  }

  /// Gets current user location
  static Future<Position?> getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final newPermission = await Geolocator.requestPermission();
        if (newPermission == LocationPermission.denied) {
          return null;
        }
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }
}
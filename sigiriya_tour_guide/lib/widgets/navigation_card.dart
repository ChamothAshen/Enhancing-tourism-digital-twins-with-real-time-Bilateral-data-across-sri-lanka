import 'package:flutter/material.dart';
import '../services/navigation_service.dart';

/// A specialized widget for displaying navigation messages with Google Maps integration
class NavigationCard extends StatelessWidget {
  final String message;
  final String? destinationName;

  const NavigationCard({
    super.key,
    required this.message,
    this.destinationName,
  });

  @override
  Widget build(BuildContext context) {
    final destination = destinationName ?? NavigationService.extractNavigationDestination(message);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Navigation header with walking icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.directions_walk,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WALKING TO',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (destination != null)
                        Text(
                          destination,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                // Google Maps navigation button
                if (destination != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => _openGoogleMaps(destination, context),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.navigation,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Maps',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Navigation message content
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            
            // Distance and time info (if available in message)
            if (_extractDistanceAndTime(message) != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _extractDistanceAndTime(message)!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Opens Google Maps with navigation to the destination
  Future<void> _openGoogleMaps(String destination, BuildContext context) async {
    try {
      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Opening Google Maps...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Get current location
      final currentLocation = await NavigationService.getCurrentLocation();
      
      // Open navigation
      final success = await NavigationService.openGoogleMapsNavigation(
        destinationName: destination,
        currentLatitude: currentLocation?.latitude,
        currentLongitude: currentLocation?.longitude,
      );

      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open maps app. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening maps: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Extracts distance and time information from the message
  String? _extractDistanceAndTime(String message) {
    // Look for patterns like "311 m" and "~4 min"
    final distancePattern = RegExp(r'(\d+)\s*m');
    final timePattern = RegExp(r'~?(\d+)\s*min');
    
    final distanceMatch = distancePattern.firstMatch(message);
    final timeMatch = timePattern.firstMatch(message);
    
    if (distanceMatch != null || timeMatch != null) {
      final parts = <String>[];
      
      if (distanceMatch != null) {
        parts.add('${distanceMatch.group(1)} m');
      }
      
      if (timeMatch != null) {
        parts.add('~${timeMatch.group(1)} min');
      }
      
      return parts.join(' • ');
    }
    
    return null;
  }
}
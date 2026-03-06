import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sigiriya_tour_guide/theme/app_theme.dart';
import 'package:sigiriya_tour_guide/widgets/chat_bottom_sheet.dart';
import 'package:sigiriya_tour_guide/services/location_api_service.dart';
import 'dart:math' as math;
import 'package:flutter_tts/flutter_tts.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  bool _isLoading = true;
  String _errorMessage = '';
  String? _selectedLocation;
  String _selectedCategory = 'All';
  late AnimationController _pulseController;
  int _currentStep = 0;
  bool _showAchievementNotification = false;
  
  String? _mlLocationName;
  String? _mlDescription;
  bool _isMLProcessing = false;
  final FlutterTts _flutterTts = FlutterTts();
  
  // Location API Service - Railway deployed backend
  final LocationApiService _locationApi = LocationApiService();
  SuggestNearestResponse? _nearbyData;
  bool _showNearbyPanel = false;

  // Sigiriya Rock coordinates
  static const LatLng sigiriyaRock = LatLng(7.9570, 80.7603);

  // Ordered tourist route - Aligned with user provided correct locations
  final List<String> _visitingRoute = [
    'Sigiriya Entrance',
    'Bridge over Moat',
    'Water Garden',
    'Water Fountains',
    'Summer Palace',
    'Caves with Inscriptions',
    'Lion\'s Paw',
    'Main Palace',
  ];

  // Tourist attractions - Synced with ML Model (2nd version updated with precise user coordinates)
  final Map<String, Map<String, dynamic>> _attractions = {
    'Sigiriya Entrance': {
      'position': const LatLng(7.957678, 80.753474),
      'icon': Icons.door_front_door,
      'category': 'Historical Site',
      'visitOrder': 1,
    },
    'Bridge over Moat': {
      'position': const LatLng(7.957762, 80.753608),
      'icon': Icons.straighten,
      'category': 'Historical Site',
      'visitOrder': 2,
    },
    'Water Garden': {
      'position': const LatLng(7.957415, 80.754714),
      'icon': Icons.park,
      'category': 'Nature Spot',
      'visitOrder': 3,
    },
    'Water Fountains': {
      'position': const LatLng(7.957265, 80.755617),
      'icon': Icons.opacity,
      'category': 'Nature Spot',
      'visitOrder': 4,
    },
    'Summer Palace': {
      'position': const LatLng(7.956593, 80.756135),
      'icon': Icons.foundation,
      'category': 'Historical Site',
      'visitOrder': 5,
    },
    'Caves with Inscriptions': {
      'position': const LatLng(7.957886, 80.757803),
      'icon': Icons.architecture,
      'category': 'Historical Site',
      'visitOrder': 6,
    },
    'Lion\'s Paw': {
      'position': const LatLng(7.957729, 80.760275),
      'icon': Icons.pets,
      'category': 'Main Attraction',
      'visitOrder': 7,
    },
    'Main Palace': {
      'position': const LatLng(7.957017, 80.759852),
      'icon': Icons.castle,
      'category': 'Main Attraction',
      'visitOrder': 8,
    },
    'Boulder Gardens': {
      'position': const LatLng(7.954621, 80.754708),
      'icon': Icons.landscape,
      'category': 'Nature Spot',
      'visitOrder': 9,
    },
    'Mirror Wall': {
      'position': const LatLng(7.95733,  80.75935),
      'icon': Icons.auto_awesome,
      'category': 'Main Attraction',
      'visitOrder': 10,
    },
    'Sigiriya Museum': {
      'position': const LatLng(7.957001, 80.752003),
      'icon': Icons.museum,
      'category': 'Historical Site',
      'visitOrder': 11,
    },
  };

  final List<String> _categories = [
    'All',
    'Historical Site',
    'Nature Spot',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _getCurrentLocation();
    _initTts();

    // Auto-fit bounds after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitAllMarkers();
      
      // Feedback for research
      print("🔍 Location API: Connected to Railway backend");
    });
  }

  void _fitAllMarkers() {
    try {
      final points = _attractions.values.map((e) => e['position'] as LatLng).toList();
      if (points.isEmpty) return;

      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(70),
        ),
      );
    } catch (e) {
      // Controller might not be ready yet, retry after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _fitAllMarkers();
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _flutterTts.stop();
    _locationApi.dispose();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    if (text.isNotEmpty) {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services disabled';
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permissions denied';
            _isLoading = false;
          });
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _updateUserLocation(LatLng(position.latitude, position.longitude));
    } catch (e) {
      setState(() {
        _errorMessage = '';
        _isLoading = false;
      });
    }
  }

  void _showSimulateLocationDialog() {
    String? selectedLocation;
    final latController = TextEditingController();
    final lngController = TextEditingController();
    bool showManualInput = false;

    // Fill with current position if available for convenience
    if (_currentPosition != null) {
      latController.text = _currentPosition!.latitude.toString();
      lngController.text = _currentPosition!.longitude.toString();
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.location_searching, color: AppTheme.primaryGreen, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Location',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Select a predefined location or enter custom coordinates',
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Predefined locations dropdown
                const Text(
                  'Quick Select Location:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedLocation,
                      hint: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text('Choose a location to test...'),
                      ),
                      isExpanded: true,
                      itemHeight: 72,
                      items: _attractions.entries.map((entry) {
                        final name = entry.key;
                        final data = entry.value;
                        final position = data['position'] as LatLng;
                        final icon = data['icon'] as IconData;
                        final category = data['category'] as String;
                        
                        return DropdownMenuItem<String>(
                          value: name,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6E00).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(icon, size: 16, color: const Color(0xFFFF6E00)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      Text(
                                        category,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.primaryGreen,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setDialogState(() {
                          selectedLocation = value;
                          if (value != null) {
                            final position = _attractions[value]!['position'] as LatLng;
                            latController.text = position.latitude.toString();
                            lngController.text = position.longitude.toString();
                          }
                        });
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Toggle for manual input
                Row(
                  children: [
                    const Text(
                      'Or enter custom coordinates:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const Spacer(),
                    Switch(
                      value: showManualInput,
                      onChanged: (value) {
                        setDialogState(() {
                          showManualInput = value;
                        });
                      },
                      activeColor: AppTheme.primaryGreen,
                    ),
                  ],
                ),
                
                if (showManualInput) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: latController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      hintText: 'e.g. 7.957511',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.my_location),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: lngController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      hintText: 'e.g. 80.759083',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.place),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Info box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This will simulate your GPS location for testing the location detection APIs.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final lat = double.tryParse(latController.text);
                final lng = double.tryParse(lngController.text);
                if (lat != null && lng != null) {
                  Navigator.pop(context);
                  final newPos = LatLng(lat, lng);
                  _updateUserLocation(newPos);
                  _mapController.move(newPos, 17.5);
                  
                  // Enhanced feedback with location name if selected
                  final locationName = selectedLocation ?? 'Custom Location';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Testing: $locationName',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppTheme.primaryGreen,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter valid coordinates'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.location_searching, size: 18),
              label: const Text('Test Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateUserLocation(LatLng position) {
    setState(() {
      _currentPosition = position;
      _isLoading = false;
      _checkArrival(position);
      _predictLocationWithML(position); // Call the Railway deployed ML API
    });
  }

  Future<void> _predictLocationWithML(LatLng pos) async {
    if (_isMLProcessing) return;

    setState(() {
      _isMLProcessing = true;
    });

    try {
      // Call both APIs in parallel for better performance
      final results = await Future.wait([
        _locationApi.predictLocation(
          latitude: pos.latitude,
          longitude: pos.longitude,
        ),
        _locationApi.suggestNearest(
          latitude: pos.latitude,
          longitude: pos.longitude,
        ),
      ]);

      final predictResponse = results[0] as PredictResponse;
      final nearbyResponse = results[1] as SuggestNearestResponse;

      final newLocation = predictResponse.locationName;
      final newDesc = predictResponse.description;

      // Speak location name if changed
      if (_mlLocationName != newLocation) {
        _speak("You are at $newLocation. $newDesc");
      }

      setState(() {
        _mlLocationName = newLocation;
        _mlDescription = newDesc;
        _nearbyData = nearbyResponse;
        _showNearbyPanel = true;
        _isMLProcessing = false;
      });
    } catch (e) {
      // API might be offline
      setState(() {
        _isMLProcessing = false;
      });
      print("Location API Error: $e");
    }
  }

  void _showNearbyLocationsSheet() {
    if (_nearbyData == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildNearbyLocationsSheet(),
    );
  }

  Widget _buildNearbyLocationsSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryGreen, Color(0xFF2E7D32)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.explore, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nearby Attractions',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkStone,
                            ),
                          ),
                          Text(
                            '${_nearbyData!.nearbyLocations.length} places to explore',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Nearby locations list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _nearbyData!.nearbyLocations.length,
                  itemBuilder: (context, index) {
                    final nearby = _nearbyData!.nearbyLocations[index];
                    final isFirst = index == 0;
                    
                    return _buildNearbyLocationCard(
                      nearby,
                      isNearest: isFirst,
                      index: index,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNearbyLocationCard(NearbyLocation nearby, {bool isNearest = false, int index = 0}) {
    final attraction = _attractions[nearby.locationName];
    final IconData iconData = attraction != null 
        ? attraction['icon'] as IconData 
        : Icons.place;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isNearest ? AppTheme.primaryGreen.withOpacity(0.08) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNearest ? AppTheme.primaryGreen.withOpacity(0.3) : Colors.grey[200]!,
          width: isNearest ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pop(context);
            if (attraction != null) {
              final pos = attraction['position'] as LatLng;
              _mapController.move(pos, 17.5);
              setState(() {
                _selectedLocation = nearby.locationName;
              });
              // Open chat for this location
              ChatBottomSheet.show(
                context,
                nearby.locationName,
                latitude: pos.latitude,
                longitude: pos.longitude,
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isNearest ? AppTheme.primaryGreen : const Color(0xFFFF6E00),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (isNearest ? AppTheme.primaryGreen : const Color(0xFFFF6E00))
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(iconData, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                // Location info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isNearest)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'NEAREST',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              nearby.locationName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isNearest ? FontWeight.bold : FontWeight.w600,
                                color: AppTheme.darkStone,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.directions_walk,
                            size: 14,
                            color: isNearest ? AppTheme.primaryGreen : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              nearby.distanceMeters < 1000
                                  ? '${nearby.distanceMeters.toStringAsFixed(0)}m • ~${(nearby.distanceMeters / 80).ceil()}min walk'
                                  : '${nearby.distanceKm.toStringAsFixed(2)}km • ~${(nearby.distanceMeters / 80).ceil()}min walk',
                              style: TextStyle(
                                fontSize: 12,
                                color: isNearest ? AppTheme.primaryGreen : Colors.grey[600],
                                fontWeight: isNearest ? FontWeight.w600 : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  void _checkArrival(LatLng userPos) {
    // Check if within 20 meters of ANY attraction (as per test requirements)
    String? foundAttraction;
    
    _attractions.forEach((name, data) {
      final targetPos = data['position'] as LatLng;
      final distance = _calculateDistance(userPos, targetPos);
      
      if (distance < 20) {
        foundAttraction = name;
      }
    });

    if (foundAttraction != null) {
      if (_selectedLocation != foundAttraction) {
        setState(() {
          _selectedLocation = foundAttraction;
          
          // Also update current step if this is one of our route points
          final index = _visitingRoute.indexOf(foundAttraction!);
          if (index != -1) {
            _currentStep = index;
          }
        });
        
        // Feedback to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 Proximity Trigger: $foundAttraction'),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFFFF6E00),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _findNearestAttraction() {
    if (_currentPosition == null) return;

    double minDistance = double.infinity;
    int nearestIndex = 0;

    for (int i = _currentStep; i < _visitingRoute.length; i++) {
      final locationName = _visitingRoute[i];
      final attraction = _attractions[locationName]!;
      final attractionPos = attraction['position'] as LatLng;

      final distance = _calculateDistance(_currentPosition!, attractionPos);
      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }

    setState(() {
      _currentStep = nearestIndex;
    });
  }

  double _calculateDistance(LatLng from, LatLng to) {
    const double earthRadius = 6371000; // meters
    final double lat1 = from.latitude * math.pi / 180;
    final double lat2 = to.latitude * math.pi / 180;
    final double deltaLat = (to.latitude - from.latitude) * math.pi / 180;
    final double deltaLon = (to.longitude - from.longitude) * math.pi / 180;

    final double a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
        math.sin(deltaLon / 2) * math.sin(deltaLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  List<Marker> _buildMarkers() {
    List<Marker> markers = [];

    _attractions.forEach((name, data) {
      if (_selectedCategory != 'All' && data['category'] != _selectedCategory) {
        return;
      }

      final visitOrder = data['visitOrder'] as int;
      final isCurrentStep = (visitOrder - 1) == _currentStep;
      // final isNextStep = (visitOrder - 1) == (_currentStep + 1);
      // final isCompleted = (visitOrder - 1) < _currentStep;

      markers.add(
        Marker(
          point: data['position'] as LatLng,
          width: isCurrentStep ? 90 : 80, // Cleaner, more compact markers
          height: isCurrentStep ? 90 : 80,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedLocation = name;
              });
              _mapController.move(data['position'] as LatLng, 17.0);
              // Open chatbot bottom sheet with selected location
              ChatBottomSheet.show(
                context,
                name,
                latitude: (data['position'] as LatLng).latitude,
                longitude: (data['position'] as LatLng).longitude,
              );
            },
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulse effect for current step
                        if (isCurrentStep)
                          Container(
                            width: 70 + (_pulseController.value * 20),
                            height: 70 + (_pulseController.value * 20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFF6E00)
                                  .withOpacity(0.3 - (_pulseController.value * 0.3)),
                            ),
                          ),
                        // Main marker - matched to reference image style
                        Container(
                          width: isCurrentStep ? 45 : 38,
                          height: isCurrentStep ? 45 : 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6E00),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              data['icon'] as IconData,
                              color: Colors.white,
                              size: isCurrentStep ? 24 : 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isCurrentStep)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6E00),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    });

    // User location marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: _currentPosition!,
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withOpacity(0.2),
                ),
              ),
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.6),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.my_location,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return markers;
  }

  List<Polyline> _buildWalkingPaths() {
    List<Polyline> paths = [];

    for (int i = 0; i < _visitingRoute.length - 1; i++) {
       final currentAttraction = _attractions[_visitingRoute[i]];
       final nextAttraction = _attractions[_visitingRoute[i + 1]];
       
       if (currentAttraction == null || nextAttraction == null) continue;

      // final isActivePath = i >= _currentStep;
      // final isCompletedPath = i < _currentStep;

      paths.add(
        Polyline(
          points: [
            currentAttraction['position'] as LatLng,
            nextAttraction['position'] as LatLng,
          ],
          strokeWidth: 4.5,
          color: const Color(0xFFFF6E00).withOpacity(0.85),
          borderStrokeWidth: 1.5,
          borderColor: Colors.white.withOpacity(0.5),
        ),
      );
    }

    return paths;
  }

  // Helper methods for enhanced progress bar
  int _getVisitedCount() {
    // Count locations that have been visited (current step + completed locations)
    Set<String> visited = {};
    
    // Add completed route locations
    for (int i = 0; i <= _currentStep && i < _visitingRoute.length; i++) {
      visited.add(_visitingRoute[i]);
    }
    
    // Add any other visited locations (if user explored off-route)
    // This could be extended to track actual visits
    
    return visited.length;
  }

  IconData _getProgressIcon() {
    final progress = _getVisitedCount() / 11;
    if (progress >= 1.0) return Icons.emoji_events; // Trophy for completion
    if (progress >= 0.8) return Icons.star; // Star for high progress
    if (progress >= 0.5) return Icons.explore; // Explorer icon for mid progress
    return Icons.location_on; // Basic location icon for start
  }

  Widget _getAchievementBadge() {
    final visitedCount = _getVisitedCount();
    
    if (visitedCount >= 11) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Colors.amber, Colors.orange]),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events, color: Colors.white, size: 12),
            SizedBox(width: 2),
            Text('EXPLORER', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    } else if (visitedCount >= 8) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.purple,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, color: Colors.white, size: 12),
            SizedBox(width: 2),
            Text('ADVENTURER', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    } else if (visitedCount >= 5) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore, color: Colors.white, size: 12),
            SizedBox(width: 2),
            Text('DISCOVERER', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  Color _getProgressColor() {
    final progress = _getVisitedCount() / 11;
    if (progress >= 1.0) return Colors.amber; // Gold for completion
    if (progress >= 0.8) return Colors.purple; // Purple for high progress
    if (progress >= 0.5) return Colors.blue; // Blue for mid progress
    return AppTheme.primaryGreen; // Green for beginning
  }

  String _getMotivationalMessage() {
    final visitedCount = _getVisitedCount();
    final remaining = 11 - visitedCount;
    
    switch (visitedCount) {
      case 0:
        return "🚀 Start your adventure! 11 amazing places await discovery!";
      case 1:
        return "🎉 Great start! ${remaining} more incredible locations to explore!";
      case >= 2 && < 5:
        return "🌟 You're doing amazing! Keep exploring - ${remaining} locations left!";
      case >= 5 && < 8:
        return "🔥 Halfway there! Only ${remaining} more places to complete your journey!";
      case >= 8 && < 11:
        return "⭐ Almost there! Just ${remaining} more location${remaining == 1 ? '' : 's'} to become a true Sigiriya Explorer!";
      case 11:
        return "🏆 CONGRATULATIONS! You've become a Sigiriya Master Explorer!";
      default:
        return "🗺️ Continue your amazing journey through Sigiriya!";
    }
  }

  String _getCompactMotivationalMessage() {
    final visitedCount = _getVisitedCount();
    final remaining = 11 - visitedCount;
    
    switch (visitedCount) {
      case 1:
        return "🎉 Great start! ${remaining} more to explore!";
      case >= 2 && < 5:
        return "🌟 Keep going! ${remaining} locations left!";
      case >= 5 && < 8:
        return "🔥 Halfway there! ${remaining} more to go!";
      case >= 8 && < 11:
        return "⭐ Almost done! Just ${remaining} more!";
      case 11:
        return "🏆 Master Explorer achieved!";
      default:
        return "Continue exploring Sigiriya!";
    }
  }

  void _showProgressDetail() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_getProgressColor(), _getProgressColor().withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Your Journey Progress',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_getVisitedCount()} out of 11 locations discovered!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _getVisitedCount() / 11,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getMotivationalMessage(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLatestAchievement() {
    final visitedCount = _getVisitedCount();
    switch (visitedCount) {
      case 1:
        return '🎉 Achievement Unlocked: First Steps!';
      case 3:
        return '🌟 Achievement Unlocked: Explorer!';
      case 5:
        return '🔥 Achievement Unlocked: Discoverer!';
      case 8:
        return '⭐ Achievement Unlocked: Adventurer!';
      case 11:
        return '🏆 Achievement Unlocked: Sigiriya Master!';
      default:
        return '✨ Keep exploring to unlock achievements!';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1B5E20),
                    Color(0xFF4E342E),
                  ],
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: AppTheme.primaryGreen,
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Loading Tourist Guide...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: sigiriyaRock,
                    initialZoom: 15.5,
                    minZoom: 13.0,
                    maxZoom: 19.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    // Base Adventure/Terrain Map - Using Carto Voyager for better reliability
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.sigiriya.guide.sigiriya_smart_guide',
                    ),
                    // Stable soft overlay for depth and nature theme
                    Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.5,
                          colors: [
                            const Color(0xFF1B5E20).withOpacity(0.0),
                            const Color(0xFF1B5E20).withOpacity(0.12),
                          ],
                        ),
                      ),
                    ),
                     PolygonLayer(
                       polygons: [
                         // Water Gardens Area (Greenish Highlight like reference)
                         Polygon(
                           points: const [
                             LatLng(7.9546, 80.7580),
                             LatLng(7.9546, 80.7595),
                             LatLng(7.9538, 80.7595),
                             LatLng(7.9538, 80.7580),
                           ],
                           color: Colors.green.withOpacity(0.15),
                           isFilled: true,
                           borderStrokeWidth: 1.5,
                           borderColor: Colors.green.withOpacity(0.3),
                         ),
                         // Sigiriya Rock Summit Area (Reddish Highlight like reference)
                         Polygon(
                           points: const [
                             LatLng(7.9575, 80.7600),
                             LatLng(7.9575, 80.7615),
                             LatLng(7.9565, 80.7615),
                             LatLng(7.9565, 80.7600),
                           ],
                           color: const Color(0xFFFF6E00).withOpacity(0.12),
                           isFilled: true,
                           borderStrokeWidth: 1.5,
                           borderColor: const Color(0xFFFF6E00).withOpacity(0.25),
                         ),
                       ],
                     ),
                     PolylineLayer(polylines: _buildWalkingPaths()),
                     MarkerLayer(markers: _buildMarkers()),
                    if (_currentPosition != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _currentPosition!,
                            radius: 30,
                            useRadiusInMeter: true,
                            color: Colors.blue.withOpacity(0.15),
                            borderColor: Colors.blue.withOpacity(0.5),
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                  ],
                ),

                // Header
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.primaryGreen,
                          AppTheme.primaryGreen.withOpacity(0.9),
                          AppTheme.primaryGreen.withOpacity(0.0),
                        ],
                        stops: const [0.0, 0.7, 1.0],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: BackdropFilter(
                                      filter: ColorFilter.mode(
                                        Colors.white.withOpacity(0.2),
                                        BlendMode.overlay,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.85),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.15),
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.castle,
                                          color: Color(0xFF1B5E20),
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Sigiriya Tourist Guide',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black26,
                                              offset: Offset(0, 2),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        'UNESCO World Heritage Site',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.flash_on, color: Colors.orangeAccent),
                                  tooltip: 'Teleport to Current',
                                  onPressed: () {
                                    // Simulation Mode: Teleport user to current target
                                    final target = _attractions[_visitingRoute[_currentStep]]!['position'] as LatLng;
                                    _updateUserLocation(target);
                                    _mapController.move(target, 17.5);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.bug_report, color: Colors.white70),
                                  tooltip: 'Simulate Location',
                                  onPressed: _showSimulateLocationDialog,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.my_location, color: Colors.white),
                                  onPressed: () {
                                    if (_currentPosition != null) {
                                      _mapController.move(_currentPosition!, 16.0);
                                      _findNearestAttraction();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Tourist-Friendly Location Panel (Bottom Floating Card)
                if (_mlLocationName != null && _showNearbyPanel)
                  Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Current location header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryGreen,
                                  AppTheme.primaryGreen.withOpacity(0.85),
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'YOUR CURRENT LOCATION',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white70,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _mlLocationName!,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_isMLProcessing)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  GestureDetector(
                                    onTap: () => setState(() => _showNearbyPanel = false),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Description
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                            child: Text(
                              _mlDescription ?? "",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                height: 1.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Nearest location quick view
                          if (_nearbyData != null) ...[
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.amber.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.near_me, color: Colors.white, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'NEAREST ATTRACTION',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.amber,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _nearbyData!.nearestLocation.name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.darkStone,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.directions_walk, size: 14, color: Colors.amber),
                                        const SizedBox(width: 4),
                                        Text(
                                          _nearbyData!.nearestLocation.distanceText,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // View all nearby button
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _showNearbyLocationsSheet,
                                  icon: const Icon(Icons.explore, size: 20),
                                  label: Text(
                                    'Explore ${_nearbyData!.nearbyLocations.length} Nearby Places',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF6E00),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                            ),
                          ] else
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                // Category filters
                Positioned(
                  top: MediaQuery.of(context).padding.top + 170,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = _selectedCategory == category;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: isSelected,
                            label: Text(
                              category,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.primaryGreen,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            backgroundColor: Colors.white,
                            selectedColor: AppTheme.primaryGreen,
                            elevation: 4,
                            shadowColor: Colors.black26,
                            side: BorderSide(
                              color: isSelected
                                  ? AppTheme.primaryGreen
                                  : AppTheme.primaryGreen.withOpacity(0.3),
                              width: 2,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = category;
                                _selectedLocation = null;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Interactive Gamified Progress Bar
                Positioned(
                  top: MediaQuery.of(context).padding.top + 80,
                  left: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => _showProgressDetail(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _getProgressColor().withOpacity(0.95),
                            _getProgressColor().withOpacity(0.85),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _getProgressColor().withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.8),
                            blurRadius: 20,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Animated Progress Ring
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              SizedBox(
                                width: 45,
                                height: 45,
                                child: CircularProgressIndicator(
                                  value: _getVisitedCount() / 11,
                                  strokeWidth: 4,
                                  backgroundColor: Colors.white.withOpacity(0.3),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getProgressIcon(),
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  Text(
                                    '${_getVisitedCount()}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          
                          const SizedBox(width: 14),
                          
                          // Progress Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'DISCOVER SIGIRIYA',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const Spacer(),
                                    _getAchievementBadge(),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_getVisitedCount()} of 11 Places Explored',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                
                                // Interactive Progress Dots
                                Row(
                                  children: List.generate(11, (index) {
                                    final isVisited = index < _getVisitedCount();
                                    return AnimatedContainer(
                                      duration: Duration(milliseconds: 300 + (index * 50)),
                                      margin: const EdgeInsets.only(right: 4),
                                      width: isVisited ? 12 : 8,
                                      height: isVisited ? 12 : 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isVisited 
                                            ? Colors.white 
                                            : Colors.white.withOpacity(0.3),
                                        boxShadow: isVisited ? [
                                          BoxShadow(
                                            color: Colors.white.withOpacity(0.5),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ] : null,
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                          
                          // Interactive Arrow
                          AnimatedRotation(
                            turns: _getVisitedCount() > 0 ? 0 : 0.5,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.2),
                              ),
                              child: const Icon(
                                Icons.touch_app,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Floating Achievement Notification
                if (_showAchievementNotification)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 160,
                    left: 20,
                    right: 20,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.amber, Colors.orange],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.celebration,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _getLatestAchievement(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _showAchievementNotification = false),
                            icon: const Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Selected location info
                if (_selectedLocation != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      elevation: 12,
                      shadowColor: Colors.black45,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              AppTheme.stoneWhite,
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF6E00),
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF6E00).withOpacity(0.3),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _attractions[_selectedLocation]!['icon'] as IconData,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: const BoxDecoration(
                                                color: AppTheme.primaryGreen,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                '${_attractions[_selectedLocation]!['visitOrder']}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _selectedLocation!,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.darkStone,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.grey),
                                    onPressed: () {
                                      setState(() {
                                        _selectedLocation = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _mlLocationName == _selectedLocation ? (_mlDescription ?? "Analyzing location history...") : "Location information loading...",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        final visitOrder = _attractions[_selectedLocation]!['visitOrder'] as int;
                                        setState(() {
                                          _currentStep = visitOrder - 1;
                                        });
                                        _mapController.move(
                                          _attractions[_selectedLocation]!['position'] as LatLng,
                                          17.5,
                                        );
                                      },
                                      icon: const Icon(Icons.navigation, size: 20),
                                      label: const Text('Navigate'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryGreen,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed: () {
                                      final visitOrder = _attractions[_selectedLocation]!['visitOrder'] as int;
                                      if (visitOrder - 1 == _currentStep) {
                                        setState(() {
                                          if (_currentStep < _visitingRoute.length - 1) {
                                            _currentStep++;
                                            _selectedLocation = null;
                                          }
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('✓ Completed! Moving to next location'),
                                            backgroundColor: Colors.green,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.all(14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Icon(Icons.check, size: 24),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Show nearby panel button (when panel is hidden)
                if (!_showNearbyPanel && _mlLocationName != null && _selectedLocation == null)
                  Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: () => setState(() => _showNearbyPanel = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withOpacity(0.9)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on, color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              _mlLocationName!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.expand_less, color: Colors.white, size: 16),
                                  Text(
                                    'Tap to expand',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Places count badge
                if (_selectedLocation == null && !_showNearbyPanel && _mlLocationName == null)
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primaryGreen, Color(0xFF1B5E20)],
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryGreen.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '${_attractions.length} Places',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

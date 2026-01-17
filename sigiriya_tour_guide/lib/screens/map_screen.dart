import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sigiriya_tour_guide/theme/app_theme.dart';
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
  
  String? _mlLocationName;
  String? _mlDescription;
  bool _isMLProcessing = false;
  final FlutterTts _flutterTts = FlutterTts();
  // Use your computer's IP address (10.60.14.73) so your phone can reach the server
  final String _apiUrl = "http://10.60.14.73:8000/predict"; 


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
      'position': const LatLng(7.957674546451712, 80.75346579852389),
      'icon': Icons.door_front_door,
      'category': 'Historical Site',
      'visitOrder': 1,
    },
    'Bridge over Moat': {
      'position': const LatLng(7.957759746687992, 80.75360677640833),
      'icon': Icons.straighten,
      'category': 'Historical Site',
      'visitOrder': 2,
    },
    'Water Garden': {
      'position': const LatLng(7.957415931176702, 80.75471084073263),
      'icon': Icons.park,
      'category': 'Nature Spot',
      'visitOrder': 3,
    },
    'Water Fountains': {
      'position': const LatLng(7.957264470805178, 80.75561410058413),
      'icon': Icons.opacity,
      'category': 'Nature Spot',
      'visitOrder': 4,
    },
    'Summer Palace': {
      'position': const LatLng(7.95658849506351, 80.7561308770434),
      'icon': Icons.foundation,
      'category': 'Historical Site',
      'visitOrder': 5,
    },
    'Caves with Inscriptions': {
      'position': const LatLng(7.957884271426544, 80.7578080290472),
      'icon': Icons.architecture,
      'category': 'Historical Site',
      'visitOrder': 6,
    },
    'Lion\'s Paw': {
      'position': const LatLng(7.957720004148874, 80.76027366845629),
      'icon': Icons.pets,
      'category': 'Main Attraction',
      'visitOrder': 7,
    },
    'Main Palace': {
      'position': const LatLng(7.957020481195492, 80.75984744010141),
      'icon': Icons.castle,
      'category': 'Main Attraction',
      'visitOrder': 8,
    },
  };

  final List<String> _categories = [
    'All',
    'Main Attraction',
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
      print("🔍 ML Research Mode: Connected to $_apiUrl");
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
    final latController = TextEditingController();
    final lngController = TextEditingController();

    // Fill with current position if available for convenience
    if (_currentPosition != null) {
      latController.text = _currentPosition!.latitude.toString();
      lngController.text = _currentPosition!.longitude.toString();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.terminal, color: AppTheme.primaryGreen),
            SizedBox(width: 10),
            Text('Simulate Location'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter custom coordinates to test proximity triggers.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: latController,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                hintText: 'e.g. 7.9576',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lngController,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                hintText: 'e.g. 80.7534',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final lat = double.tryParse(latController.text);
              final lng = double.tryParse(lngController.text);
              if (lat != null && lng != null) {
                Navigator.pop(context);
                final newPos = LatLng(lat, lng);
                _updateUserLocation(newPos);
                _mapController.move(newPos, 17.5);
                
                // Extra feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📍 Simulated Location set to $lat, $lng'),
                    backgroundColor: AppTheme.primaryGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Simulate'),
          ),
        ],
      ),
    );
  }

  void _updateUserLocation(LatLng position) {
    setState(() {
      _currentPosition = position;
      _isLoading = false;
      _checkArrival(position);
      _predictLocationWithML(position); // Call the Python ML model
    });
  }

  Future<void> _predictLocationWithML(LatLng pos) async {
    if (_isMLProcessing) return;

    setState(() {
      _isMLProcessing = true;
    });

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "lat": pos.latitude,
          "lon": pos.longitude,
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newLocation = data['location_name'];
        final newDesc = data['description'];

        if (_mlLocationName != newLocation) {
          _speak("$newLocation. $newDesc");
        }

        setState(() {
          _mlLocationName = newLocation;
          _mlDescription = newDesc;
          _isMLProcessing = false;
        });
      } else {
        setState(() => _isMLProcessing = false);
      }
    } catch (e) {
      // API might be offline
      setState(() => _isMLProcessing = false);
      print("ML API Error: $e");
    }
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
            backgroundColor: const Color(0xFF880E4F),
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
                              color: const Color(0xFF880E4F)
                                  .withOpacity(0.3 - (_pulseController.value * 0.3)),
                            ),
                          ),
                        // Main marker - matched to reference image style
                        Container(
                          width: isCurrentStep ? 45 : 38,
                          height: isCurrentStep ? 45 : 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF880E4F),
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
                          color: const Color(0xFF880E4F),
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
          color: const Color(0xFF880E4F).withOpacity(0.85),
          borderStrokeWidth: 1.5,
          borderColor: Colors.white.withOpacity(0.5),
        ),
      );
    }

    return paths;
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
                           color: const Color(0xFF880E4F).withOpacity(0.12),
                           isFilled: true,
                           borderStrokeWidth: 1.5,
                           borderColor: const Color(0xFF880E4F).withOpacity(0.25),
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

                // ML Prediction Panel (Bottom Floating Card)
                if (_mlLocationName != null)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3), width: 1.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.auto_awesome, color: AppTheme.primaryGreen, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'AI LOCATION IDENTIFIED',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryGreen,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const Spacer(),
                              if (_isMLProcessing)
                                const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
                                ),
                              GestureDetector(
                                onTap: () => setState(() => _mlLocationName = null),
                                child: const Icon(Icons.close, size: 18, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _mlLocationName!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _mlDescription ?? "",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Category filters
                Positioned(
                  top: MediaQuery.of(context).padding.top + 80,
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

                // Progress indicator
                Positioned(
                  top: MediaQuery.of(context).padding.top + 140,
                  left: 16,
                  right: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ColorFilter.mode(Colors.white.withOpacity(0.01), BlendMode.dstOver),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.route,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'STORY PROGRESS • ${_currentStep + 1}/${_visitingRoute.length}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1.2,
                                      color: Color(0xFF4E342E),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _visitingRoute[_currentStep],
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CircularProgressIndicator(
                              value: (_currentStep + 1) / _visitingRoute.length,
                              strokeWidth: 3,
                              color: const Color(0xFF1B5E20),
                              backgroundColor: const Color(0xFF1B5E20).withOpacity(0.1),
                            ),
                          ],
                        ),
                      ),
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
                                      color: const Color(0xFF880E4F),
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF880E4F).withOpacity(0.3),
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
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.psychology, size: 14, color: AppTheme.primaryGreen),
                                            const SizedBox(width: 4),
                                            const Text(
                                              'AI Identified Location',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.primaryGreen,
                                                fontWeight: FontWeight.bold,
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
                                _mlLocationName == _selectedLocation ? (_mlDescription ?? "Analyzing location history...") : "Please move closer or use AI Identification panel.",
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

                // Places count badge
                if (_selectedLocation == null)
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: Container(
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
                  ),
              ],
            ),
    );
  }
}

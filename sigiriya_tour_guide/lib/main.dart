import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'model_viewer_screen.dart';

// ===== TESTING MODE =====
// Set this to true to use mock location for testing
// ignore: constant_identifier_names
const bool USE_MOCK_LOCATION = true;

// Mock location for testing (Central Sigiriya area)
// ignore: constant_identifier_names
const double MOCK_LAT = 7.95748472889413;
// ignore: constant_identifier_names
const double MOCK_LNG = 80.75468987370043;
// =======================

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sigiriya Tour Guide',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final _homeKey = GlobalKey<_HomePageState>();

  late final List<Widget> _screens;
  final List<String> _titles = [
    'Sigiriya Tour Guide Map',
    '3D Model Viewer',
    " Test",
  ];

  @override
  void initState() {
    super.initState();
    _screens = [HomePage(key: _homeKey), const ModelViewerScreen()];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showModelInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About This Model'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Model File: test.glb',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'This is a 3D model viewer that allows you to interact with GLB/GLTF models. '
                'You can rotate, zoom, and pan the model using touch gestures.',
              ),
              SizedBox(height: 12),
              Text('Features:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• Auto-rotation enabled'),
              Text('• Camera controls'),
              Text('• Interactive gestures'),
              Text('• AR support (on compatible devices)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: _selectedIndex == 1
            ? [
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: _showModelInfo,
                ),
              ]
            : null,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.view_in_ar),
            label: '3D Model',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal,
        onTap: _onItemTapped,
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                _homeKey.currentState?.showPOIList(context);
              },
              icon: const Icon(Icons.location_on),
              label: const Text('Nearby Sites'),
            )
          : null,
    );
  }
}

// POI Model
class PointOfInterest {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String description;

  PointOfInterest({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.description,
  });

  LatLng get latLng => LatLng(latitude, longitude);
}

// Static POI Data for Sigiriya
final sigiriyaPOIs = [
  PointOfInterest(
    id: 'water_fountains',
    name: 'Water Fountains',
    latitude: 7.957264470805178,
    longitude: 80.75561410058413,
    description:
        'Ancient water distribution system and ornamental fountains. Part of the elaborate hydraulic engineering at Sigiriya that demonstrates King Kashyapa'
        "'"
        's advanced understanding of water management.',
  ),
  PointOfInterest(
    id: 'water_garden',
    name: 'Water Garden',
    latitude: 7.957415931176702,
    longitude: 80.75471084073263,
    description:
        'A symmetrical garden with water features and pleasure pools. Built as a recreational space, showcasing the sophisticated landscape design of the 5th century.',
  ),
  PointOfInterest(
    id: 'sigiriya_entrance',
    name: 'Sigiriya Entrance',
    latitude: 7.957674546451712,
    longitude: 80.75346579852389,
    description:
        'Main entry point to the fortress complex. Visitors begin their ascent through the lower palace gardens from here.',
  ),
  PointOfInterest(
    id: 'bridge_moat',
    name: 'Bridge over Moat',
    latitude: 7.957759746687992,
    longitude: 80.75360677640833,
    description:
        'A stone bridge crossing the moat surrounding the inner palace. Originally a strategic defense feature protecting the upper palace.',
  ),
  PointOfInterest(
    id: 'summer_palace',
    name: 'Summer Palace',
    latitude: 7.95658849506351,
    longitude: 80.7561308770434,
    description:
        'The residential chambers of the royal family. Situated away from the main palace for comfort during warmer months. Archaeological remains reveal luxury and artistic refinement.',
  ),
  PointOfInterest(
    id: 'caves_inscriptions',
    name: 'Caves with Inscriptions',
    latitude: 7.957884271426544,
    longitude: 80.7578080290472,
    description:
        'Ancient rock shelters with inscribed graffiti left by pilgrims and visitors. These inscriptions provide insights into the site'
        "'"
        's religious significance.',
  ),
  PointOfInterest(
    id: 'lions_paw',
    name:
        'Lion'
        "'"
        's Paw',
    latitude: 7.957720004148874,
    longitude: 80.76027366845629,
    description:
        'The iconic entrance to the upper palace, featuring the remains of a giant lion statue. Visitors must climb steep stairs carved into the rock to reach it.',
  ),
  PointOfInterest(
    id: 'main_palace',
    name: 'Main Palace',
    latitude: 7.957020481195492,
    longitude: 80.75984744010141,
    description:
        'The summit of Sigiriya Rock, home to the royal palace and audience chambers. Offers panoramic views of the surrounding landscape. Only accessible to those with proper fitness.',
  ),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();

  static GlobalKey<_HomePageState> createKey() => GlobalKey<_HomePageState>();
}

class _HomePageState extends State<HomePage> {
  static const triggerRadiusMeters = 10.0;

  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSub;
  Position? _lastPosition;
  String _status = 'Initializing';
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  int _selectedPOIIndex = -1;
  final Set<String> _shownPOIs = {};
  bool _isWidgetReady = false; // Flag to track if widget is fully initialized
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isShowingNotification = false; // Prevent overlapping dialogs

  @override
  Widget build(BuildContext context) {
    final pos = _lastPosition;
    return Scaffold(
      key: _scaffoldKey,
      body: pos == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_status),
                ],
              ),
            )
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(pos.latitude, pos.longitude),
                    zoom: 17,
                  ),
                  markers: _markers,
                  circles: _circles,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _status,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Lat: ${pos.latitude.toStringAsFixed(5)}, Lng: ${pos.longitude.toStringAsFixed(5)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPOIList(context),
        icon: const Icon(Icons.location_on),
        label: const Text('Nearby Sites'),
      ),
      drawer: _selectedPOIIndex >= 0
          ? Drawer(child: _buildPOIDetail(sigiriyaPOIs[_selectedPOIIndex]))
          : null,
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _updateMarkers();
  }

  void _updateMarkers() {
    final markers = <Marker>{};
    final circles = <Circle>{};

    // User location circle
    if (_lastPosition != null) {
      circles.add(
        Circle(
          circleId: const CircleId('user_radius'),
          center: LatLng(_lastPosition!.latitude, _lastPosition!.longitude),
          radius: triggerRadiusMeters,
          fillColor: Colors.blue.withValues(alpha: 0.1),
          strokeColor: Colors.blue,
          strokeWidth: 2,
        ),
      );
    }

    // POI markers
    for (int i = 0; i < sigiriyaPOIs.length; i++) {
      final poi = sigiriyaPOIs[i];
      final isSelected = _selectedPOIIndex == i;
      markers.add(
        Marker(
          markerId: MarkerId(poi.id),
          position: poi.latLng,
          infoWindow: InfoWindow(
            title: poi.name,
            onTap: () => setState(() => _selectedPOIIndex = i),
          ),
          icon: isSelected
              ? BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange,
                )
              : BitmapDescriptor.defaultMarker,
          onTap: () {
            setState(() => _selectedPOIIndex = i);
            _showDrawer();
          },
        ),
      );
    }

    setState(() {
      _markers = markers;
      _circles = circles;
    });
  }

  void _showDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void showPOIList(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nearby Sites'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sigiriyaPOIs.length,
            itemBuilder: (context, index) {
              final poi = sigiriyaPOIs[index];
              final distance = _lastPosition == null
                  ? null
                  : Geolocator.distanceBetween(
                      _lastPosition!.latitude,
                      _lastPosition!.longitude,
                      poi.latitude,
                      poi.longitude,
                    );
              return ListTile(
                title: Text(poi.name),
                subtitle: distance != null
                    ? Text('${distance.toStringAsFixed(0)} m away')
                    : null,
                onTap: () {
                  setState(() => _selectedPOIIndex = index);
                  Navigator.pop(context);
                  _animateToPOI(index);
                  _showDrawer();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _animateToPOI(int index) {
    if (_mapController != null) {
      final poi = sigiriyaPOIs[index];
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: poi.latLng, zoom: 18),
        ),
      );
    }
  }

  Widget _buildPOIDetail(PointOfInterest poi) {
    final distance = _lastPosition == null
        ? null
        : Geolocator.distanceBetween(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            poi.latitude,
            poi.longitude,
          );
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      poi.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() => _selectedPOIIndex = -1);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (distance != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        distance <= triggerRadiusMeters
                            ? Icons.check_circle
                            : Icons.location_on,
                        color: distance <= triggerRadiusMeters
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text('${distance.toStringAsFixed(1)} m away'),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Description',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(poi.description),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _animateToPOI(_selectedPOIIndex),
                icon: const Icon(Icons.map),
                label: const Text('View on Map'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Delay location initialization until after the first frame is built
    // This prevents "dependOnInheritedWidgetOfExactType" errors
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        setState(() => _isWidgetReady = true);
        // Add small delay to ensure widget tree is fully ready
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          _initLocation();
        }
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    if (USE_MOCK_LOCATION) {
      // Use mock location for testing
      setState(() => _status = 'Using mock location (Testing)');
      final mockPosition = Position(
        longitude: MOCK_LNG,
        latitude: MOCK_LAT,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      // Add delay before processing mock position to ensure widget tree is fully ready
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        _onPosition(mockPosition);
      }
      return;
    }

    setState(() => _status = 'Checking permissions');
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      setState(() => _status = 'Location services disabled');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _status = 'Location permission denied');
      return;
    }

    setState(() => _status = 'Fetching location');

    await _positionSub?.cancel();
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
    );
    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_onPosition);

    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
      _onPosition(current);
    } catch (_) {}
  }

  void _onPosition(Position pos) {
    setState(() {
      _lastPosition = pos;
      _status = 'Live tracking';
      _updateMarkers();
    });

    // Check nearby POIs and show dialog if close
    for (int i = 0; i < sigiriyaPOIs.length; i++) {
      final poi = sigiriyaPOIs[i];
      final distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        poi.latitude,
        poi.longitude,
      );
      if (distance <= triggerRadiusMeters &&
          !_shownPOIs.contains(poi.id) &&
          _isWidgetReady &&
          !_isShowingNotification) {
        // Defer slightly to avoid build-cycle conflicts
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            _showPOIBottomSheet(poi, distance);
          }
        });
      }
    }
  }

  void _showPOIBottomSheet(PointOfInterest poi, double distance) {
    if (!mounted) return;
    // Mark as showing and record this POI so it won't re-trigger
    setState(() {
      _isShowingNotification = true;
      _shownPOIs.add(poi.id);
      _selectedPOIIndex = sigiriyaPOIs.indexWhere((p) => p.id == poi.id);
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            poi.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text('${distance.toStringAsFixed(0)} meters away'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(poi.description),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _animateToPOI(_selectedPOIIndex);
                          },
                          icon: const Icon(Icons.map),
                          label: const Text('View on Map'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() => _isShowingNotification = false);
      } else {
        _isShowingNotification = false;
      }
    });
  }
}

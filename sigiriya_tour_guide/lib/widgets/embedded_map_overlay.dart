import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as latlong2;

/// An expandable embedded Google Map widget that displays route navigation
/// within the navigation panel's blue box.
class EmbeddedMapOverlay extends StatefulWidget {
  final latlong2.LatLng currentPosition;
  final latlong2.LatLng destination;
  final String destinationName;
  final List<latlong2.LatLng> routePoints;
  final VoidCallback onClose;

  const EmbeddedMapOverlay({
    super.key,
    required this.currentPosition,
    required this.destination,
    required this.destinationName,
    required this.routePoints,
    required this.onClose,
  });

  @override
  State<EmbeddedMapOverlay> createState() => _EmbeddedMapOverlayState();
}

class _EmbeddedMapOverlayState extends State<EmbeddedMapOverlay> {
  GoogleMapController? _mapController;
  bool _isExpanded = false;
  double _currentHeight = 200; // Default height
  static const double _minHeight = 150;
  static const double _maxHeight = 450;

  // Convert latlong2.LatLng to Google Maps LatLng
  LatLng _toGoogleLatLng(latlong2.LatLng point) {
    return LatLng(point.latitude, point.longitude);
  }

  @override
  void initState() {
    super.initState();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitMapToRoute();
  }

  void _fitMapToRoute() {
    if (_mapController == null) return;
    
    try {
      List<LatLng> allPoints = [
        _toGoogleLatLng(widget.currentPosition),
        _toGoogleLatLng(widget.destination),
      ];
      
      if (widget.routePoints.isNotEmpty) {
        allPoints.addAll(widget.routePoints.map(_toGoogleLatLng));
      }
      
      if (allPoints.length >= 2) {
        // Calculate bounds
        double minLat = allPoints.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
        double maxLat = allPoints.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
        double minLng = allPoints.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
        double maxLng = allPoints.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);
        
        final bounds = LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        );
        
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 50),
        );
      }
    } catch (e) {
      debugPrint('Error fitting map to route: $e');
    }
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      _currentHeight = _isExpanded ? _maxHeight : 200;
    });
    
    // Refit map after animation
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _fitMapToRoute();
    });
  }

  Set<Marker> _buildMarkers() {
    return {
      // Current position marker (blue)
      Marker(
        markerId: const MarkerId('current_position'),
        position: _toGoogleLatLng(widget.currentPosition),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'You are here'),
      ),
      // Destination marker (green)
      Marker(
        markerId: const MarkerId('destination'),
        position: _toGoogleLatLng(widget.destination),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: widget.destinationName),
      ),
    };
  }

  Set<Polyline> _buildPolylines() {
    List<LatLng> points;
    
    if (widget.routePoints.isNotEmpty) {
      points = widget.routePoints.map(_toGoogleLatLng).toList();
    } else {
      // Direct line if no route points
      points = [
        _toGoogleLatLng(widget.currentPosition),
        _toGoogleLatLng(widget.destination),
      ];
    }
    
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: Colors.blue[700]!,
        width: 5,
        patterns: widget.routePoints.isEmpty 
            ? [PatternItem.dash(10), PatternItem.gap(10)] 
            : [],
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _currentHeight,
      child: Column(
        children: [
          // Drag handle and controls
          GestureDetector(
            onVerticalDragUpdate: (details) {
              setState(() {
                _currentHeight = (_currentHeight - details.delta.dy)
                    .clamp(_minHeight, _maxHeight);
              });
            },
            onVerticalDragEnd: (_) {
              // Snap to nearest height
              if (_currentHeight > (_minHeight + _maxHeight) / 2) {
                setState(() {
                  _currentHeight = _maxHeight;
                  _isExpanded = true;
                });
              } else {
                setState(() {
                  _currentHeight = _minHeight;
                  _isExpanded = false;
                });
              }
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) _fitMapToRoute();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.map, color: Colors.blue[700], size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Route to ${widget.destinationName}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Expand/collapse button
                      GestureDetector(
                        onTap: _toggleExpand,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            _isExpanded ? Icons.expand_more : Icons.expand_less,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Close button
                      GestureDetector(
                        onTap: widget.onClose,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.red[700],
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Drag indicator
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Map view - Google Maps
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: _toGoogleLatLng(widget.currentPosition),
                  zoom: 17.0,
                ),
                markers: _buildMarkers(),
                polylines: _buildPolylines(),
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: true,
                mapToolbarEnabled: false,
                compassEnabled: true,
                mapType: MapType.normal,
              ),
            ),
          ),
          // Legend/info bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(Colors.blue, 'You'),
                const SizedBox(width: 20),
                _buildLegendItem(Colors.green[600]!, widget.destinationName),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

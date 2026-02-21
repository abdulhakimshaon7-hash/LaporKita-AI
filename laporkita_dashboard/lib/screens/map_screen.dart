// File: app/laporkita_dashboard/lib/screens/map_screen.dart
// Interactive Google Maps view of complaints at The Grand Subang SS13

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();

  // Verified coordinates from Google Maps URLs
  // Main building / Tower 1: 3.0700928, 101.596767
  // Tower 2 lobby:           3.0711299, 101.5966792
  static const LatLng _defaultCenter = LatLng(3.0706, 101.5967);

  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  String _filterUrgency = 'ALL';
  bool _showClusters = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  Future<void> _loadMapData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadReportMarkers(), _loadClusterCircles()]);
    setState(() => _isLoading = false);
  }

  // ─────────────────────────────────────────────
  // LOAD REPORT MARKERS
  // ─────────────────────────────────────────────
  Future<void> _loadReportMarkers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('reports')
        .get();

    final Set<Marker> newMarkers = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();

      if (data['urgency'] == null || data['urgency'] == 'ANALYZING') continue;
      if (_filterUrgency != 'ALL' && data['urgency'] != _filterUrgency)
        continue;

      final locationStr = (data['location'] as String?) ?? '';
      final coords = _locationToCoords(locationStr);
      if (coords == null) continue;

      final urgency = data['urgency'] as String? ?? 'MEDIUM';

      newMarkers.add(
        Marker(
          markerId: MarkerId(doc.id),
          position: coords,
          icon: BitmapDescriptor.defaultMarkerWithHue(_urgencyToHue(urgency)),
          infoWindow: InfoWindow(
            title: '$urgency — ${data['category'] ?? 'Unknown'}',
            snippet: data['summary'] ?? data['message'] ?? 'No info',
          ),
        ),
      );
    }

    setState(() => _markers = newMarkers);
    print('✅ Loaded ${newMarkers.length} markers on map');
  }

  // ─────────────────────────────────────────────
  // LOAD CLUSTER CIRCLES
  // ─────────────────────────────────────────────
  Future<void> _loadClusterCircles() async {
    if (!_showClusters) {
      setState(() => _circles = {});
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('clusters')
        .where('status', isEqualTo: 'open')
        .get();

    final Set<Circle> newCircles = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final category = data['category'] as String? ?? '';
      final urgency = data['urgency'] as String? ?? 'MEDIUM';
      final reportCount = data['report_count'] as int? ?? 3;

      LatLng? coords;

      // Get location from first report in cluster
      final reportIds = data['report_ids'] as List?;
      if (reportIds != null && reportIds.isNotEmpty) {
        try {
          final reportDoc = await FirebaseFirestore.instance
              .collection('reports')
              .doc(reportIds.first as String)
              .get();
          if (reportDoc.exists) {
            final locationStr =
                (reportDoc.data()?['location'] as String?) ?? '';
            coords = _locationToCoords(locationStr);
          }
        } catch (e) {
          print('Could not fetch cluster report location: $e');
        }
      }

      // Fallback to category-based location
      coords ??= _categoryToCoords(category);

      newCircles.add(
        Circle(
          circleId: CircleId(doc.id),
          center: coords,
          radius: 25.0 + (reportCount * 8),
          fillColor: _urgencyToColor(urgency).withOpacity(0.25),
          strokeColor: _urgencyToColor(urgency),
          strokeWidth: 3,
        ),
      );
    }

    setState(() => _circles = newCircles);
    print('✅ Loaded ${newCircles.length} cluster circles on map');
  }

  // ─────────────────────────────────────────────
  // LOCATION → COORDINATES
  // Based on verified Google Maps coordinates:
  //   Tower 1 (main): 3.0700928, 101.596767
  //   Tower 2 lobby:  3.0711299, 101.5966792
  //   Shared facilities between the two towers
  // ─────────────────────────────────────────────
  LatLng? _locationToCoords(String location) {
    final l = location.toLowerCase();

    // Tower 1 — verified coordinate: 3.0700928, 101.596767
    if (l.contains('tower 1') || l.contains('tower1')) {
      return LatLng(3.0700928 + _tinyOffset(), 101.596767 + _tinyOffset());
    }

    // Tower 2 — verified coordinate: 3.0711299, 101.5966792
    if (l.contains('tower 2') || l.contains('tower2')) {
      return LatLng(3.0711299 + _tinyOffset(), 101.5966792 + _tinyOffset());
    }

    // Shared facilities — placed between the two towers
    if (l.contains('swimming pool') || l.contains('kolam renang')) {
      return const LatLng(3.0706, 101.5968);
    }
    if (l.contains('gym')) {
      return const LatLng(3.0705, 101.5966);
    }
    if (l.contains('playground') || l.contains('taman permainan')) {
      return const LatLng(3.0707, 101.5965);
    }
    if (l.contains('surau') || l.contains('musolla')) {
      return const LatLng(3.0704, 101.5967);
    }

    // Guard house — near main entrance at Tower 1
    if (l.contains('guard house') ||
        l.contains('guardhouse') ||
        l.contains('main entrance') ||
        l.contains('pintu masuk')) {
      return const LatLng(3.0699, 101.5966);
    }

    // Basement parking — below Tower 1 (slightly offset down)
    if (l.contains('basement') || l.contains('parking')) {
      return const LatLng(3.0701, 101.5964);
    }

    // Any other location — place near building center
    return LatLng(3.0706 + _tinyOffset(), 101.5967 + _tinyOffset());
  }

  // Category fallback — used when no report location is found
  LatLng _categoryToCoords(String category) {
    switch (category) {
      case 'infrastructure':
        return const LatLng(3.0702, 101.5967);
      case 'environment':
        return const LatLng(3.0701, 101.5965);
      case 'safety':
        return const LatLng(3.0699, 101.5966);
      case 'health':
        return const LatLng(3.0706, 101.5968);
      default:
        return const LatLng(3.0706, 101.5967);
    }
  }

  // Tiny random offset so stacked markers are slightly separated
  double _tinyOffset() {
    final values = [-0.0003, -0.0002, -0.0001, 0.0001, 0.0002, 0.0003];
    return values[DateTime.now().microsecond % values.length];
  }

  // ─────────────────────────────────────────────
  // URGENCY HELPERS
  // ─────────────────────────────────────────────
  double _urgencyToHue(String urgency) {
    switch (urgency) {
      case 'CRITICAL':
        return BitmapDescriptor.hueRed;
      case 'HIGH':
        return BitmapDescriptor.hueOrange;
      case 'MEDIUM':
        return BitmapDescriptor.hueYellow;
      case 'LOW':
        return BitmapDescriptor.hueGreen;
      default:
        return BitmapDescriptor.hueBlue;
    }
  }

  Color _urgencyToColor(String urgency) {
    switch (urgency) {
      case 'CRITICAL':
        return Colors.red;
      case 'HIGH':
        return Colors.orange;
      case 'MEDIUM':
        return Colors.amber;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  // ─────────────────────────────────────────────
  // BUILD UI
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Text(
                '🗺️ Complaint Map',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text(
                'The Grand Subang SS13',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const Spacer(),

              // Urgency filter
              DropdownButton<String>(
                value: _filterUrgency,
                onChanged: (val) {
                  setState(() => _filterUrgency = val!);
                  _loadReportMarkers();
                },
                items: ['ALL', 'CRITICAL', 'HIGH', 'MEDIUM', 'LOW']
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
              ),
              const SizedBox(width: 16),

              // Show clusters toggle
              Row(
                children: [
                  const Text('Show Clusters'),
                  Switch(
                    value: _showClusters,
                    onChanged: (val) {
                      setState(() => _showClusters = val);
                      _loadClusterCircles();
                    },
                  ),
                ],
              ),
              const SizedBox(width: 8),

              // Refresh button
              IconButton(
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: _isLoading ? null : _loadMapData,
                tooltip: 'Refresh map',
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Legend row
          Row(
            children: [
              _legendItem(Colors.red, 'CRITICAL'),
              const SizedBox(width: 16),
              _legendItem(Colors.orange, 'HIGH'),
              const SizedBox(width: 16),
              _legendItem(Colors.amber, 'MEDIUM'),
              const SizedBox(width: 16),
              _legendItem(Colors.green, 'LOW'),
              const SizedBox(width: 16),
              const Icon(Icons.circle_outlined, size: 16, color: Colors.blue),
              const SizedBox(width: 4),
              const Text('Cluster', style: TextStyle(fontSize: 12)),
              const Spacer(),
              Text(
                '${_markers.length} complaints • ${_circles.length} clusters',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Google Map
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _defaultCenter,
                  zoom: 18, // Building level — shows both towers
                ),
                markers: _markers,
                circles: _circles,
                onMapCreated: (GoogleMapController controller) {
                  _controller.complete(controller);
                },
                myLocationButtonEnabled: false,
                zoomControlsEnabled: true,
                mapToolbarEnabled: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

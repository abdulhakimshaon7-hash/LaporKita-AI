// File: lib/screens/map_screen.dart
// Interactive Google Maps view — reads lat/lng from Firestore reports

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

  // KL city center — zoomed out so all markers across KL are visible
  static const LatLng _defaultCenter = LatLng(3.1390, 101.6869);

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
  // Reads latitude/longitude directly from Firestore — no text conversion
  // ─────────────────────────────────────────────
  Future<void> _loadReportMarkers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('reports')
        .get();

    final Set<Marker> newMarkers = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();

      // Skip reports still being analyzed
      if (data['urgency'] == null || data['urgency'] == 'ANALYZING') continue;

      // Apply urgency filter if set
      if (_filterUrgency != 'ALL' && data['urgency'] != _filterUrgency) {
        continue;
      }

      // READ lat/lng directly from Firestore fields — this is the key fix!
      final lat = data['latitude'];
      final lng = data['longitude'];

      // Skip if no coordinates stored
      if (lat == null || lng == null) continue;

      final urgency = data['urgency'] as String? ?? 'MEDIUM';
      final category = data['category'] as String? ?? 'general';
      final message = data['message'] as String? ?? '';
      final snippet = message.length > 60 ? message.substring(0, 60) : message;

      newMarkers.add(
        Marker(
          markerId: MarkerId(doc.id),
          position: LatLng((lat as num).toDouble(), (lng as num).toDouble()),
          icon: BitmapDescriptor.defaultMarkerWithHue(_urgencyToHue(urgency)),
          infoWindow: InfoWindow(
            title: '$urgency — $category',
            snippet: snippet,
          ),
        ),
      );
    }

    setState(() => _markers = newMarkers);
    print('✅ Loaded ${newMarkers.length} markers on map');
  }

  // ─────────────────────────────────────────────
  // LOAD CLUSTER CIRCLES
  // Also reads lat/lng from the first report in each cluster
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
      final urgency = data['urgency'] as String? ?? 'MEDIUM';
      final reportCount = data['report_count'] as int? ?? 3;

      LatLng? center;

      // Get coordinates from first report in the cluster
      final reportIds = data['report_ids'] as List?;
      if (reportIds != null && reportIds.isNotEmpty) {
        try {
          final reportDoc = await FirebaseFirestore.instance
              .collection('reports')
              .doc(reportIds.first as String)
              .get();

          if (reportDoc.exists) {
            final lat = reportDoc.data()?['latitude'];
            final lng = reportDoc.data()?['longitude'];
            if (lat != null && lng != null) {
              center = LatLng((lat as num).toDouble(), (lng as num).toDouble());
            }
          }
        } catch (e) {
          print('Could not fetch cluster report coords: $e');
        }
      }

      // Fallback to KL center if no coords found
      center ??= _defaultCenter;

      newCircles.add(
        Circle(
          circleId: CircleId(doc.id),
          center: center,
          radius: 500.0 + (reportCount * 100), // Bigger radius at city scale
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
                'Klang Valley Community Reports',
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
                  zoom: 11, // City level — shows all of KL/Selangor
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

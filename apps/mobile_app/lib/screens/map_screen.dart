import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  
  LatLng _userPosition = const LatLng(-6.8915, 107.6161); // Default Simpang Dago, Bandung
  bool _isLoading = true;
  bool _isLocatingUser = false;
  List<Map<String, dynamic>> _reports = [];
  Map<String, dynamic>? _selectedReport;

  @override
  void initState() {
    super.initState();
    _initMapAndData();
  }

  Future<void> _initMapAndData() async {
    await _getUserLocation();
    await _fetchNearbyReports();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Get current user location
  Future<void> _getUserLocation() async {
    setState(() {
      _isLocatingUser = true;
    });

    if (kIsWeb) {
      setState(() {
        _userPosition = const LatLng(-6.8915, 107.6161);
        _isLocatingUser = false;
      });
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLocatingUser = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLocatingUser = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLocatingUser = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 3),
      );

      setState(() {
        _userPosition = LatLng(position.latitude, position.longitude);
        _isLocatingUser = false;
      });

      _mapController.move(_userPosition, 15.0);
    } catch (e) {
      setState(() {
        _isLocatingUser = false;
      });
    }
  }

  // Fetch reports from API helper
  Future<void> _fetchNearbyReports() async {
    try {
      final apiService = context.read<ApiService>();
      final result = await apiService.getNearbyReports(_userPosition.latitude, _userPosition.longitude);
      
      if (result['status'] == 'success') {
        final List<dynamic> reportsList = result['data']['reports'] ?? [];
        setState(() {
          _reports = List<Map<String, dynamic>>.from(reportsList);
        });
      }
    } catch (e) {
      // Handled silently by fallback data in api_service
    }
  }

  // Distance calculation helper (returns String formatted)
  String _calculateDistanceString(double targetLat, double targetLng) {
    final double distanceInMeters = Geolocator.distanceBetween(
      _userPosition.latitude,
      _userPosition.longitude,
      targetLat,
      targetLng,
    );
    if (distanceInMeters >= 1000) {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} KM';
    }
    return '${distanceInMeters.toStringAsFixed(0)} meter';
  }

  // Show Bottom Sheet for Selected Report
  void _showReportDetailSheet(Map<String, dynamic> report) {
    setState(() {
      _selectedReport = report;
    });

    final bool isVoice = report['type'] == 'SOS_VOICE';
    final String distanceStr = _calculateDistanceString(
      double.parse(report['latitude'].toString()),
      double.parse(report['longitude'].toString()),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black26,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        child: GlassCard(
          opacity: 0.1,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isVoice ? const Color(0xFFFF1744).withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isVoice ? Icons.notifications_active_rounded : Icons.photo_library_rounded,
                      color: isVoice ? const Color(0xFFFF1744) : Colors.amber,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVoice ? 'SOS SUARA AKTIF' : 'LAPORAN VISUAL WARGA',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Jarak dari posisi Anda: $distanceStr',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (report['urgency'] == 'HIGH' || isVoice)
                          ? const Color(0xFFFF1744).withValues(alpha: 0.12)
                          : Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isVoice ? 'CRITICAL' : report['urgency'] ?? 'MEDIUM',
                      style: TextStyle(
                        color: isVoice ? const Color(0xFFFF1744) : Colors.amber,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                ],
              ),
              const Divider(color: Colors.white10, height: 24),

              // Description
              Text(
                'Deskripsi Kejadian:',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
              ),
              const SizedBox(height: 6),
              Text(
                report['description'] ?? 'Tidak ada keterangan tambahan.',
                style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 20),

              // Bottom Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('TUTUP', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF1744),
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Rute aman sedang dikalkulasikan ke SIGAP Police Map...')),
                        );
                      },
                      child: const Text('RUTE AMAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _selectedReport = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Generate map markers
    final List<Marker> mapMarkers = [
      // 1. User current location marker
      Marker(
        point: _userPosition,
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Cyan pulse ring
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3), width: 1.5),
              ),
            ),
            // Solid center circle
            Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Colors.cyanAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.cyanAccent, blurRadius: 8, spreadRadius: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    ];

    // 2. Incident reports markers
    for (final report in _reports) {
      final double lat = double.parse(report['latitude'].toString());
      final double lng = double.parse(report['longitude'].toString());
      final LatLng point = LatLng(lat, lng);
      
      final bool isVoice = report['type'] == 'SOS_VOICE';

      mapMarkers.add(
        Marker(
          point: point,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _showReportDetailSheet(report);
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glowing ring
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isVoice ? const Color(0xFFFF1744).withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: isVoice ? const Color(0xFFFF1744) : Colors.amber,
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                ),
                // Inner Icon
                Icon(
                  isVoice ? Icons.notifications_active_rounded : Icons.warning_amber_rounded,
                  color: isVoice ? Colors.white : Colors.black87,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1219),
      body: Stack(
        children: [
          // Peta Layer (OpenStreetMap tiles with dark thematic map filters)
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF1744)),
                  ),
                )
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _userPosition,
                    initialZoom: 14.5,
                    maxZoom: 18.0,
                    minZoom: 10.0,
                  ),
                  children: [
                    // A. Base map tile layer (CartoDB Dark Matter style map tile provider)
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.panggilin.app',
                    ),
                    
                    // B. Heatmap/Red zones layers (Circles with translucent red denoting high crime zones)
                    CircleLayer(
                      circles: [
                        // Zone 1: Simpang Dago (High Alert Zone)
                        CircleMarker(
                          point: const LatLng(-6.8915, 107.6161),
                          color: const Color(0xFFFF1744).withValues(alpha: 0.16),
                          borderColor: const Color(0xFFFF1744).withValues(alpha: 0.35),
                          borderStrokeWidth: 1.5,
                          useRadiusInMeter: true,
                          radius: 350,
                        ),
                        // Zone 2: Dipatiukur (Medium Alert Zone)
                        CircleMarker(
                          point: const LatLng(-6.8975, 107.6186),
                          color: Colors.red.withValues(alpha: 0.12),
                          borderColor: Colors.red.withValues(alpha: 0.28),
                          borderStrokeWidth: 1.5,
                          useRadiusInMeter: true,
                          radius: 250,
                        ),
                        // Zone 3: Cihampelas (Medium Alert Zone)
                        CircleMarker(
                          point: const LatLng(-6.8902, 107.6105),
                          color: Colors.red.withValues(alpha: 0.12),
                          borderColor: Colors.red.withValues(alpha: 0.28),
                          borderStrokeWidth: 1.5,
                          useRadiusInMeter: true,
                          radius: 200,
                        ),
                      ],
                    ),

                    // C. Interactive Markers Layer (User location + incident pins)
                    MarkerLayer(markers: mapMarkers),
                  ],
                ),

          // Header Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  // Back button
                  ClipOval(
                    child: Container(
                      color: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PETA ZONE RAWAN BEGAL',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.8),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Kab. Bandung Kota (Radius 2KM)',
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Refresh button
                  ClipOval(
                    child: Container(
                      color: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.tealAccent, size: 20),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _fetchNearbyReports();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right floating action buttons (Locate user)
          Positioned(
            right: 16,
            bottom: _selectedReport != null ? 220 : 32,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'gps_fab',
                  backgroundColor: const Color(0xFF1E2638),
                  foregroundColor: Colors.tealAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  mini: true,
                  onPressed: _isLocatingUser ? null : _getUserLocation,
                  child: _isLocatingUser
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                          ),
                        )
                      : const Icon(Icons.gps_fixed_rounded, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

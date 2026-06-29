import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../widgets/glass_card.dart';
import '../theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        // Calculate statistics
        final activeSosCount = state.reports
            .where(
              (r) => r['status'] == 'PENDING' || r['status'] == 'ON_PROCESS',
            )
            .length;
        final onDutyPatrols = state.patrolUnits
            .where((u) => u['status'] == 'ON_DUTY')
            .length;
        final availablePatrols = state.patrolUnits
            .where((u) => u['status'] == 'AVAILABLE')
            .length;
        final totalCctvs = state.cctvCameras.length;

        // Coordinates for centering map (Default: Bandung Simpang Dago area)
        LatLng mapCenter = const LatLng(-6.90344, 107.61872);
        if (state.reports.isNotEmpty) {
          mapCenter = LatLng(
            state.reports.first['latitude'],
            state.reports.first['longitude'],
          );
        }

        // Build list of markers
        final List<Marker> mapMarkers = [];

        // 1. Add SOS Reports markers
        for (var report in state.reports) {
          final isPending = report['status'] == 'PENDING';
          final isSpoofed = report['is_spoofed'] == true;

          Color markerColor = Colors.orangeAccent;
          if (isPending) markerColor = SigapTheme.primaryColor;
          if (isSpoofed) markerColor = Colors.grey;

          mapMarkers.add(
            Marker(
              point: LatLng(report['latitude'], report['longitude']),
              width: 50,
              height: 50,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isPending)
                        Container(
                          width: 14 + (_pulseController.value * 28),
                          height: 14 + (_pulseController.value * 28),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: markerColor.withOpacity(
                              1.0 - _pulseController.value,
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: () {
                          context.read<DashboardBloc>().add(
                            SelectReportEvent(report),
                          );
                          context.read<DashboardBloc>().add(
                            ChangeTabEvent(1),
                          ); // Navigate to detail
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: markerColor,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: markerColor.withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            report['type'] == 'SOS_VOICE'
                                ? Icons.phone_android_rounded
                                : Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        }

        // 2. Add Patrol Units markers
        for (var unit in state.patrolUnits) {
          if (unit['status'] == 'OFFLINE') continue;
          final isOnDuty = unit['status'] == 'ON_DUTY';
          final Color markerColor = isOnDuty
              ? SigapTheme.primaryColor
              : SigapTheme.successColor;

          mapMarkers.add(
            Marker(
              point: LatLng(unit['latitude'], unit['longitude']),
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: markerColor.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_police_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          );
        }

        // 3. Add CCTV Cameras markers
        for (var camera in state.cctvCameras) {
          if (camera['status'] == 'INACTIVE') continue;
          final isHighFps = camera['fps_mode'] == 'HIGH';
          final Color markerColor = isHighFps
              ? SigapTheme.primaryColor
              : Colors.amber;

          mapMarkers.add(
            Marker(
              point: LatLng(camera['latitude'], camera['longitude']),
              width: 32,
              height: 32,
              child: GestureDetector(
                onTap: () {
                  context.read<DashboardBloc>().add(
                    ChangeTabEvent(2),
                  ); // Live CCTV Monitor
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: markerColor.withOpacity(0.9),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.6),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.videocam_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DASHBOARD TAKTIS',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        'Peta Sebaran Laporan Begal & CCTV Real-time Kota Bandung',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SigapTheme.surfaceColor,
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.08)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () {
                      context.read<DashboardBloc>().add(LoadInitialDataEvent());
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('REFRESH DATA'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. Statistics Cards Grid
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'SOS BEGAL AKTIF',
                      value: activeSosCount.toString(),
                      icon: Icons.emergency_share_rounded,
                      color: SigapTheme.primaryColor,
                      subtitle: 'Butuh Validasi & Tindakan',
                      pulse: activeSosCount > 0,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      title: 'PATROLI ON-DUTY',
                      value:
                          '$onDutyPatrols / ${onDutyPatrols + availablePatrols}',
                      icon: Icons.local_police_rounded,
                      color: SigapTheme.infoColor,
                      subtitle: 'Unit Sabhara Lapangan',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      title: 'CCTV INTEGRASI',
                      value: totalCctvs.toString(),
                      icon: Icons.videocam_rounded,
                      color: Colors.amber,
                      subtitle: 'Aktif AI YOLOv9',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      title: 'SKOR KEAMANAN KOTA',
                      value: '94.2%',
                      icon: Icons.trending_up_rounded,
                      color: SigapTheme.successColor,
                      subtitle: 'Bulan Juni (Kondusif)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 3. Main Map & Feed Area
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // A. Map Area (OpenStreetMap)
                    Expanded(
                      flex: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withOpacity(0.06),
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: mapCenter,
                              initialZoom: 14.5,
                              minZoom: 12,
                              maxZoom: 18,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName:
                                    'com.panggil_in.sigap_police_dashboard',
                                tileBuilder: (context, tileWidget, tile) {
                                  // Apply dark theme matrix overlay to standard map tiles for cohesive aesthetics
                                  return ColorFiltered(
                                    colorFilter: const ColorFilter.matrix([
                                      -0.2126,
                                      -0.7152,
                                      -0.0722,
                                      0,
                                      255,
                                      -0.2126,
                                      -0.7152,
                                      -0.0722,
                                      0,
                                      255,
                                      -0.2126,
                                      -0.7152,
                                      -0.0722,
                                      0,
                                      255,
                                      0,
                                      0,
                                      0,
                                      1,
                                      0,
                                    ]),
                                    child: ColorFiltered(
                                      colorFilter: const ColorFilter.matrix([
                                        0.3,
                                        0,
                                        0,
                                        0,
                                        0,
                                        0,
                                        0.3,
                                        0,
                                        0,
                                        10,
                                        0,
                                        0,
                                        0.35,
                                        0,
                                        20,
                                        0,
                                        0,
                                        0,
                                        1,
                                        0,
                                      ]),
                                      child: tileWidget,
                                    ),
                                  );
                                },
                              ),
                              MarkerLayer(markers: mapMarkers),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),

                    // B. Alert Feed & Quick Simulator Simulator
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'ALARM AI TERKINI',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: state.cctvAlerts.isEmpty
                                ? GlassCard(
                                    opacity: 0.03,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.shield_rounded,
                                            color: Colors.white.withOpacity(
                                              0.15,
                                            ),
                                            size: 40,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Tidak ada alert aktif',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.3,
                                              ),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: state.cctvAlerts.length > 5
                                        ? 5
                                        : state.cctvAlerts.length,
                                    itemBuilder: (context, idx) {
                                      final alert = state.cctvAlerts[idx];
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8.0,
                                        ),
                                        child: GlassCard(
                                          padding: const EdgeInsets.all(12),
                                          opacity: 0.06,
                                          border: Border.all(
                                            color: SigapTheme.primaryColor
                                                .withOpacity(0.2),
                                          ),
                                          child: Row(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                child: Image.network(
                                                  alert['snapshot_url'] ??
                                                      alert['snapshotUrl'] ??
                                                      '',
                                                  width: 50,
                                                  height: 50,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        _,
                                                        __,
                                                      ) => Container(
                                                        color: Colors.white10,
                                                        width: 50,
                                                        height: 50,
                                                        child: const Icon(
                                                          Icons.videocam_off,
                                                          size: 18,
                                                        ),
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Begal Senjata Tajam',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: SigapTheme
                                                            .primaryColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'CCTV ${alert['cctv_id']?.substring(0, 8) ?? 'Kamera'}',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.white
                                                            .withOpacity(0.5),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                '${((alert['confidence'] ?? 0.85) * 100).toStringAsFixed(0)}%',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.amber,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 16),

                          // Quick Simulation Panel
                          Text(
                            'SIMULASI DETEKSI AI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SigapTheme.primaryColor
                                  .withOpacity(0.15),
                              foregroundColor: SigapTheme.primaryColor,
                              side: const BorderSide(
                                color: SigapTheme.primaryColor,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: state.cctvCameras.isEmpty
                                ? null
                                : () {
                                    final camera = state.cctvCameras.first;
                                    context.read<DashboardBloc>().add(
                                      TriggerMockSosEvent(
                                        cctvId: camera['id'],
                                        suspectFeatures:
                                            'jaket_hitam_helm_merah_sajam_katana',
                                      ),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Simulasi alert anomali CCTV berhasil dikirim ke server AI',
                                        ),
                                        backgroundColor:
                                            SigapTheme.primaryColor,
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.warning_rounded, size: 16),
                            label: const Text(
                              'PICU BEGAL SAJAM (MOCK AI)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
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
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
    bool pulse = false,
  }) {
    return GlassCard(
      opacity: 0.05,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.35),
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final double scale = pulse
                  ? 1.0 + (_pulseController.value * 0.15)
                  : 1.0;
              return Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(pulse ? 0.25 : 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withOpacity(pulse ? 0.6 : 0.15),
                      width: pulse ? 2 : 1,
                    ),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

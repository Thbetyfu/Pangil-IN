import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../widgets/glass_card.dart';
import '../theme.dart';

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final MapController _miniMapController = MapController();
  bool _isPlayingAudio = false;
  double _audioProgress = 0.0;
  String? _selectedPatrolUnitId;

  // Simple distance calculator
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    var p = 0.017453292519943295;
    var c = cos;
    var a =
        0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // km
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        final report = state.selectedReport;
        if (report == null) {
          return const Center(child: Text('Tidak ada laporan yang dipilih'));
        }

        final reporter = report['reporter'] ?? {};
        final bool isSos = report['type'] == 'SOS_VOICE';
        final bool isSpoofed = report['is_spoofed'] == true;
        final double antiSpoofScore = report['anti_spoofing_score'] ?? 1.0;
        final String status = report['status'];
        final String urgency = report['urgency'];

        // Node coordinates mapping for GNN predicted route conversion
        final Map<String, LatLng> nodeCoordinates = {
          'simpang_dago': const LatLng(-6.90344, 107.61872),
          'dago_bawah': const LatLng(-6.90844, 107.61872),
          'dago_atas': const LatLng(-6.89844, 107.61872),
          'dipatiukur': const LatLng(-6.90344, 107.61472),
          'siliwangi': const LatLng(-6.90344, 107.62272),
          'cihampelas': const LatLng(-6.90344, 107.62672),
          'flyover_pasupati': const LatLng(-6.90644, 107.61472),
          'merdeka': const LatLng(-6.91144, 107.61872),
        };

        // Convert GNN predicted escape routes to map polylines
        final List<Polyline> escapePolylines = [];
        for (var route in state.predictedRoutes) {
          final List<dynamic> pathNodes = route['path'] ?? [];
          final List<LatLng> points = pathNodes
              .where((node) => nodeCoordinates.containsKey(node))
              .map<LatLng>((node) => nodeCoordinates[node]!)
              .toList();

          if (points.isNotEmpty) {
            escapePolylines.add(
              Polyline(
                points: points,
                color: Colors.amber.withOpacity(0.55),
                strokeWidth: 5,
              ),
            );
          }
        }

        // Convert GNN matching CCTV predictions to map markers
        final List<Marker> reidMarkers = state.reidPredictions.map<Marker>((
          pred,
        ) {
          final double probability = pred['reid_probability'] ?? 0.0;
          final double lat = pred['latitude'] ?? -6.90344;
          final double lng = pred['longitude'] ?? 107.61872;

          return Marker(
            point: LatLng(lat, lng),
            width: 70,
            height: 70,
            child: Tooltip(
              message:
                  '${pred['node_name']} (Re-ID: ${(probability * 100).toInt()}%)',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.videocam_rounded,
                      color: probability > 0.7
                          ? Colors.redAccent
                          : Colors.amberAccent,
                      size: 14,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      '${(probability * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.amberAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList();

        // Get GPS track logs for polyline
        final List<dynamic> rawLogs = state.gpsTrackLogs[report['id']] ?? [];
        final bool lastUpdateWasBle =
            rawLogs.isNotEmpty && rawLogs.last['isBleRelay'] == 1.0;

        final List<LatLng> trackPoints = rawLogs
            .map<LatLng>(
              (coord) => LatLng(coord['latitude']!, coord['longitude']!),
            )
            .toList();

        // Coordinates for centering mini map
        LatLng incidentLatLng = LatLng(report['latitude'], report['longitude']);

        // Filter and calculate distances for available patrol units
        final patrolWithDistance = state.patrolUnits.map((unit) {
          final dist = _calculateDistance(
            report['latitude'],
            report['longitude'],
            unit['latitude'],
            unit['longitude'],
          );
          return {
            ...unit,
            'distance': dist, // in km
          };
        }).toList();

        // Sort by distance (nearest first)
        patrolWithDistance.sort(
          (a, b) =>
              (a['distance'] as double).compareTo(b['distance'] as double),
        );

        // Get currently assigned unit if any
        final assignedUnit = state.patrolUnits.firstWhere(
          (u) => u['id'] == report['assigned_unit_id'],
          orElse: () => null,
        );

        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Navigation & Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.04),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
                        onPressed: () {
                          context.read<DashboardBloc>().add(
                            SelectReportEvent(null),
                          );
                        },
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isSos
                                    ? 'SOS Voice (Zero-Click)'
                                    : 'Laporan Visual Warga',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              _buildStatusBadge(status),
                              const SizedBox(width: 8),
                              _buildUrgencyBadge(urgency),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID Laporan: ${report['id']}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.4),
                              fontFamily: 'Courier',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. Main Body Grid
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // A. Left Side: Incident details, transcription or visual image
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // I. Pelapor Info Card
                            _buildSectionTitle('IDENTITAS PELAPOR'),
                            const SizedBox(height: 8),
                            GlassCard(
                              opacity: 0.05,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: SigapTheme.infoColor
                                        .withOpacity(0.12),
                                    foregroundColor: SigapTheme.infoColor,
                                    radius: 20,
                                    child: const Icon(Icons.person_rounded),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          reporter['name'] ?? 'Warga Anonim',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Nomor Telp: ${reporter['phone'] ?? '-'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white.withOpacity(
                                              0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildReputationGauge(
                                    reporter['reputation_score'] ?? 100.0,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // II. Content Media (SOS Voice vs Visual Report)
                            if (isSos) ...[
                              _buildSectionTitle(
                                'REKAMAN BUKTI SUARA SOS (30 DETIK)',
                              ),
                              const SizedBox(height: 8),
                              GlassCard(
                                opacity: 0.05,
                                child: Column(
                                  children: [
                                    // Audio Player Interface
                                    Row(
                                      children: [
                                        IconButton(
                                          style: IconButton.styleFrom(
                                            backgroundColor:
                                                SigapTheme.primaryColor,
                                            foregroundColor: Colors.white,
                                          ),
                                          iconSize: 28,
                                          onPressed: () {
                                            setState(() {
                                              _isPlayingAudio =
                                                  !_isPlayingAudio;
                                            });
                                          },
                                          icon: Icon(
                                            _isPlayingAudio
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Slider(
                                                value: _audioProgress,
                                                activeColor:
                                                    SigapTheme.primaryColor,
                                                inactiveColor: Colors.white12,
                                                onChanged: (val) {
                                                  setState(() {
                                                    _audioProgress = val;
                                                  });
                                                },
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 22.0,
                                                    ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      '00:${(_audioProgress * 30).toInt().toString().padLeft(2, '0')}',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                    const Text(
                                                      '00:30',
                                                      style: TextStyle(
                                                        fontSize: 10,
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
                                    const SizedBox(height: 16),
                                    // NLP Transcript
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.04),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.translate_rounded,
                                                color:
                                                    SigapTheme.secondaryColor,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'TRANSKRIP BAHASA ALAMI (NLP)',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      SigapTheme.secondaryColor,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            report['description'] ??
                                                '"Tolong saya dibegal! Motor saya dirampas di Simpang Dago, pelaku membawa senjata tajam jenis parang!"',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              height: 1.5,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: SigapTheme.primaryColor
                                                  .withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Kategori Kecurigaan: Bersenjata Tajam / Begal Motor',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: SigapTheme.primaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              _buildSectionTitle(
                                'FOTO BUKTI VISUAL & AI ANALYSIS',
                              ),
                              const SizedBox(height: 8),
                              GlassCard(
                                opacity: 0.05,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        report['image_url'] ??
                                            'https://images.unsplash.com/photo-1614064641938-3bbee52942c7?auto=format&fit=crop&w=600&q=80',
                                        height: 240,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, _, __) =>
                                            Container(
                                              color: Colors.white10,
                                              height: 200,
                                              child: const Icon(
                                                Icons.broken_image_outlined,
                                                size: 36,
                                              ),
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // AI Image analysis description
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.04),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.analytics_outlined,
                                                color:
                                                    SigapTheme.secondaryColor,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'DESKRIPSI CAPTIONING AI',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      SigapTheme.secondaryColor,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            report['description'] ??
                                                'Dua orang mencurigakan berboncengan di trotoar, salah satu pelaku membawa logam panjang berkilau menyerupai golok.',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              height: 1.4,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),

                            // III. AI Spoof verification metrics
                            _buildSectionTitle(
                              'AI ANTI-SPOOFING FILTER INTEGRITAS',
                            ),
                            const SizedBox(height: 8),
                            GlassCard(
                              opacity: 0.05,
                              child: Column(
                                children: [
                                  _buildVerificationRow(
                                    label: 'Autentisitas Foto (Metadata EXIF)',
                                    success: !isSpoofed,
                                    score: antiSpoofScore,
                                  ),
                                  const Divider(
                                    height: 16,
                                    color: Colors.white10,
                                  ),
                                  _buildVerificationRow(
                                    label:
                                        'Deteksi Rekayasa AI Generatif (Pixel Analysis)',
                                    success: !isSpoofed,
                                    score: antiSpoofScore,
                                  ),
                                  const Divider(
                                    height: 16,
                                    color: Colors.white10,
                                  ),
                                  _buildVerificationRow(
                                    label:
                                        'Deteksi Duplikasi Gambar Internet (Reverse Lookup)',
                                    success: !isSpoofed,
                                    score: 1.0,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),

                    // B. Right Side: Miniature Maps and Dispatch logic
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionTitle(
                                'PETA PELACAKAN LOKASI (REAL-TIME)',
                              ),
                              if (lastUpdateWasBle)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blueAccent.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Colors.blueAccent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'ESTAFET BLE MESH AKTIF',
                                        style: TextStyle(
                                          color: Colors.blueAccent,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.06),
                                  ),
                                ),
                                child: FlutterMap(
                                  mapController: _miniMapController,
                                  options: MapOptions(
                                    initialCenter: incidentLatLng,
                                    initialZoom: 15.5,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName:
                                          'com.panggil_in.sigap_police_dashboard',
                                      tileBuilder: (context, tileWidget, tile) {
                                        return ColorFiltered(
                                          colorFilter:
                                              const ColorFilter.matrix([
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
                                            colorFilter:
                                                const ColorFilter.matrix([
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
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(
                                          points: trackPoints,
                                          color: SigapTheme.primaryColor,
                                          strokeWidth: 4,
                                          isDotted: true,
                                        ),
                                        ...escapePolylines,
                                      ],
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        // Incident / user
                                        Marker(
                                          point: incidentLatLng,
                                          width: 60,
                                          height: 60,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: lastUpdateWasBle
                                                  ? Colors.blueAccent
                                                        .withOpacity(0.2)
                                                  : SigapTheme.primaryColor
                                                        .withOpacity(0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: lastUpdateWasBle
                                                    ? Colors.blueAccent
                                                    : SigapTheme.primaryColor,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: lastUpdateWasBle
                                                        ? Colors.blueAccent
                                                        : SigapTheme
                                                              .primaryColor,
                                                    blurRadius: 12,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                lastUpdateWasBle
                                                    ? Icons
                                                          .bluetooth_audio_rounded
                                                    : Icons
                                                          .person_pin_circle_rounded,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                        ...reidMarkers,
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Patrol Unit dispatcher
                          _buildSectionTitle(
                            'PENGIRIMAN UNIT PATROLI TERDEKAT',
                          ),
                          const SizedBox(height: 8),
                          GlassCard(
                            opacity: 0.05,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (assignedUnit != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: SigapTheme.successColor
                                          .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: SigapTheme.successColor
                                            .withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_outline_rounded,
                                          color: SigapTheme.successColor,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'UNIT TELAH DITUGASKAN',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  color:
                                                      SigapTheme.successColor,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                assignedUnit['name'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              Text(
                                                'Telepon unit: ${assignedUnit['phone']}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white
                                                      .withOpacity(0.5),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  // Dropdown to pick patrol unit
                                  DropdownButtonFormField<String>(
                                    value: _selectedPatrolUnitId,
                                    dropdownColor: SigapTheme.surfaceColor,
                                    decoration: InputDecoration(
                                      labelText: 'PILIH REGUP PATROLI',
                                      labelStyle: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white.withOpacity(0.5),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      filled: true,
                                      fillColor: Colors.black12,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.06),
                                        ),
                                      ),
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                    items: patrolWithDistance.map((unit) {
                                      final double dist =
                                          unit['distance'] as double;
                                      final isAvailable =
                                          unit['status'] == 'AVAILABLE';
                                      return DropdownMenuItem<String>(
                                        value: unit['id'],
                                        child: Text(
                                          '${unit['name']} (${dist.toStringAsFixed(1)} km) - ${isAvailable ? 'STANDBY' : 'BERTUGAS'}',
                                          style: TextStyle(
                                            color: isAvailable
                                                ? Colors.white
                                                : Colors.white24,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedPatrolUnitId = val;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: SigapTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: _selectedPatrolUnitId == null
                                        ? null
                                        : () {
                                            context.read<DashboardBloc>().add(
                                              AssignPatrolUnitEvent(
                                                reportId: report['id'],
                                                patrolUnitId:
                                                    _selectedPatrolUnitId!,
                                              ),
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Unit patroli berhasil ditugaskan ke lokasi kejadian',
                                                ),
                                                backgroundColor:
                                                    SigapTheme.successColor,
                                              ),
                                            );
                                          },
                                    icon: const Icon(
                                      Icons.send_rounded,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'KIRIM UNIT PATROLI SEKARANG',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildSectionTitle(
                            'AI SUSPECT ESCAPE & RE-ID ANALYSIS',
                          ),
                          const SizedBox(height: 8),
                          GlassCard(
                            opacity: 0.05,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (state.predictedRoutes.isEmpty &&
                                    state.reidPredictions.isEmpty) ...[
                                  const Text(
                                    'Analisis pelarian dan Re-ID CCTV belum dijalankan untuk insiden ini.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () {
                                      context.read<DashboardBloc>().add(
                                        FetchSuspectAnalysisEvent(
                                          startNode: 'simpang_dago',
                                          headingNode: 'dago_atas',
                                          suspectFeatures:
                                              'helm_merah_jaket_hitam_honda_beat',
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.analytics_rounded,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'JALANKAN ANALISIS TERSANGKA',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'ANALISIS AI AKTIF',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: Colors.amber,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.refresh_rounded,
                                          color: Colors.amber,
                                          size: 16,
                                        ),
                                        onPressed: () {
                                          context.read<DashboardBloc>().add(
                                            FetchSuspectAnalysisEvent(
                                              startNode: 'simpang_dago',
                                              headingNode: 'dago_atas',
                                              suspectFeatures:
                                                  'helm_merah_jaket_hitam_honda_beat',
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '• Rute Pelarian Terdeteksi: ${state.predictedRoutes.length} rute potensial.',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '• CCTV Re-ID Lintas Kamera: ${state.reidPredictions.length} persimpangan aktif.',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ],
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        color: Colors.white.withOpacity(0.4),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    if (status == 'PENDING') color = Colors.orange;
    if (status == 'ON_PROCESS') color = Colors.blue;
    if (status == 'RESOLVED') color = SigapTheme.successColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildUrgencyBadge(String urgency) {
    Color color = Colors.orangeAccent;
    if (urgency == 'CRITICAL' || urgency == 'HIGH')
      color = SigapTheme.primaryColor;
    if (urgency == 'LOW') color = Colors.blueAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        urgency,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildReputationGauge(double score) {
    Color color = SigapTheme.successColor;
    if (score < 75) color = Colors.orangeAccent;
    if (score < 40) color = SigapTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            'Reputasi: ${score.toStringAsFixed(0)}%',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationRow({
    required String label,
    required bool success,
    required double score,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
        ),
        Row(
          children: [
            Icon(
              success ? Icons.verified_rounded : Icons.cancel_rounded,
              color: success
                  ? SigapTheme.successColor
                  : SigapTheme.primaryColor,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              '${(score * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: success
                    ? SigapTheme.successColor
                    : SigapTheme.primaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

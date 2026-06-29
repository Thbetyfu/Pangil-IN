import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../widgets/cctv_player.dart';
import '../theme.dart';

class LiveCctvScreen extends StatefulWidget {
  const LiveCctvScreen({super.key});

  @override
  State<LiveCctvScreen> createState() => _LiveCctvScreenState();
}

class _LiveCctvScreenState extends State<LiveCctvScreen>
    with SingleTickerProviderStateMixin {
  bool _showBoundingBoxes = true;
  double _aiConfidenceThreshold = 0.75;
  late AnimationController _trackerController;
  final List<String> _mockStreamImages = [
    'https://images.unsplash.com/photo-1549317661-bd32c8ce0db2?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1573164713714-d95e436ab8d6?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=400&q=80',
  ];

  @override
  void initState() {
    super.initState();
    _trackerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _trackerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        final cameras = state.cctvCameras;

        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Control Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LIVE CCTV MONITOR',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        'Integrasi Deteksi Anomali YOLOv9 & Pelacakan Estafet Lintas Kamera',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),

                  // Controls
                  Row(
                    children: [
                      // Toggle Bounding Boxes
                      Row(
                        children: [
                          const Text(
                            'Overlay YOLOv9',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: _showBoundingBoxes,
                            activeColor: SigapTheme.secondaryColor,
                            onChanged: (val) {
                              setState(() {
                                _showBoundingBoxes = val;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      // AI Threshold Slider
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'AI THRESHOLD: ${(_aiConfidenceThreshold * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                            width: 140,
                            height: 24,
                            child: Slider(
                              value: _aiConfidenceThreshold,
                              activeColor: SigapTheme.secondaryColor,
                              inactiveColor: Colors.white12,
                              onChanged: (val) {
                                setState(() {
                                  _aiConfidenceThreshold = val;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // CCTV Grid
              Expanded(
                child: cameras.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: SigapTheme.primaryColor,
                        ),
                      )
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.5,
                            ),
                        itemCount: cameras.length > 4 ? 4 : cameras.length,
                        itemBuilder: (context, index) {
                          final camera = cameras[index];
                          final isHighFps = camera['fps_mode'] == 'HIGH';
                          final streamImg =
                              _mockStreamImages[index %
                                  _mockStreamImages.length];

                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              color: Colors.black,
                              child: Stack(
                                children: [
                                  // Live Stream Player / Background Image
                                  Positioned.fill(
                                    child:
                                        camera['stream_url'] != null &&
                                            (camera['stream_url']
                                                    .toString()
                                                    .endsWith('.m3u8') ||
                                                camera['stream_url']
                                                    .toString()
                                                    .endsWith('.mp4') ||
                                                camera['stream_url']
                                                    .toString()
                                                    .contains('/static/'))
                                        ? CctvPlayer(
                                            url: camera['stream_url'],
                                            showBoundingBoxes:
                                                _showBoundingBoxes,
                                            aiConfidenceThreshold:
                                                _aiConfidenceThreshold,
                                            cameraIndex: index,
                                            fpsMode:
                                                camera['fps_mode'] ?? 'LOW',
                                          )
                                        : Image.network(
                                            camera['stream_url'] != null &&
                                                    camera['stream_url']
                                                        .toString()
                                                        .startsWith('http')
                                                ? camera['stream_url']
                                                : streamImg,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, _, __) =>
                                                Container(
                                                  color: Colors.white10,
                                                  child: const Icon(
                                                    Icons.videocam_off,
                                                    color: Colors.white24,
                                                    size: 40,
                                                  ),
                                                ),
                                          ),
                                  ),

                                  // Watermark Masking overlays (to cover television logos and incorrect locations)
                                  Positioned(
                                    bottom: 48,
                                    left: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.white10,
                                        ),
                                      ),
                                      child: Text(
                                        '${camera['name']?.toString().toUpperCase() ?? 'KAMERA CCTV'} // DAGO, BANDUNG',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),

                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: SigapTheme.primaryColor
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.security,
                                            color: SigapTheme.primaryColor,
                                            size: 10,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'SIGAP FEED SECURE',
                                            style: TextStyle(
                                              color: SigapTheme.primaryColor
                                                  .withOpacity(0.9),
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Adaptive Frame-Rate Status Badge
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    child: _buildAdaptiveStatusBadge(isHighFps),
                                  ),

                                  // Camera Title Card
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black.withOpacity(0.95),
                                            Colors.black.withOpacity(0.0),
                                          ],
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                camera['name'] ?? 'Kamera CCTV',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              Text(
                                                'Koordinat: ${camera['latitude']}, ${camera['longitude']}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white
                                                      .withOpacity(0.5),
                                                ),
                                              ),
                                            ],
                                          ),

                                          // Toggle FPS Mode manually button
                                          IconButton(
                                            tooltip: isHighFps
                                                ? 'Switch to low-FPS saving mode'
                                                : 'Switch to high-FPS active detect mode',
                                            style: IconButton.styleFrom(
                                              backgroundColor: Colors.white12,
                                              hoverColor: Colors.white24,
                                            ),
                                            onPressed: () {
                                              context.read<DashboardBloc>().add(
                                                UpdateCctvFpsEvent(
                                                  cctvId: camera['id'],
                                                  fpsMode: isHighFps
                                                      ? 'LOW'
                                                      : 'HIGH',
                                                ),
                                              );
                                            },
                                            icon: Icon(
                                              isHighFps
                                                  ? Icons.speed_rounded
                                                  : Icons
                                                        .slow_motion_video_rounded,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

  Widget _buildAdaptiveStatusBadge(bool isHighFps) {
    final Color color = isHighFps
        ? SigapTheme.primaryColor
        : SigapTheme.successColor;
    final String label = isHighFps
        ? 'ACTIVE DETECT - 30 FPS (1080p)'
        : 'SAVING MODE - 10 FPS (480p)';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMockYoloOverlays(int cameraIndex, bool isHighFps) {
    final progress = _trackerController.value;
    final List<Widget> overlays = [];

    // Tentukan kamera mana yang saat ini sedang aktif mendeteksi tersangka berdasarkan waktu (progress)
    // progress berjalan dari 0.0 sampai 1.0 (siklus 10 detik)
    // Kita bagi waktu menjadi 3 fase estafet:
    // - Kamera 0 (Dago Utara): aktif pada 0.0 - 0.33
    // - Kamera 1 (Dago Selatan): aktif pada 0.33 - 0.66
    // - Kamera 2 (Pasupati): aktif pada 0.66 - 1.0
    int activeCameraIndex = 0;
    if (progress >= 0.33 && progress < 0.66) {
      activeCameraIndex = 1;
    } else if (progress >= 0.66) {
      activeCameraIndex = 2;
    }

    if (isHighFps && cameraIndex == activeCameraIndex) {
      // 1. ACTIVE DETECT MODE: Tampilkan tersangka dan senjata tajam pada kamera aktif
      // Hitung progress lokal untuk animasi halus per kamera
      double localProgress = 0.0;
      if (cameraIndex == 0) {
        localProgress = progress / 0.33;
      } else if (cameraIndex == 1) {
        localProgress = (progress - 0.33) / 0.33;
      } else {
        localProgress = (progress - 0.66) / 0.34;
      }

      // Amankan batas progress lokal
      localProgress = localProgress.clamp(0.0, 1.0);

      // Gerakan berjalan melintasi layar
      final double xOffset = localProgress * 55;
      final double yOffset = localProgress * 15;

      final double suspectX = 85 + xOffset;
      final double suspectY = 60 + yOffset;

      // Suspect Bounding Box (Neon Red untuk ancaman tinggi)
      if (0.98 >= _aiConfidenceThreshold) {
        overlays.add(
          _buildBoundingBox(
            label: 'TERSANGKA: 98%',
            top: suspectY,
            left: suspectX,
            width: 80,
            height: 130,
            color: SigapTheme.primaryColor,
          ),
        );
      }

      // Weapon detected (SAJAM (CELURIT): 95% confidence) - Neon Amber/Yellow
      if (0.95 >= _aiConfidenceThreshold) {
        overlays.add(
          _buildBoundingBox(
            label: 'SAJAM (CELURIT): 95%',
            top: suspectY + 55,
            left: suspectX + 35,
            width: 35,
            height: 35,
            color: SigapTheme.warningColor,
          ),
        );
      }

      // Vehicle/Person Re-ID label
      if (0.98 >= _aiConfidenceThreshold) {
        overlays.add(
          Positioned(
            top: suspectY + 130,
            left: suspectX,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: SigapTheme.secondaryColor.withOpacity(0.5),
                ),
              ),
              child: const Text(
                'Re-ID ID: 09 [Helm Putih | Beat Hitam]',
                style: TextStyle(
                  color: SigapTheme.secondaryColor,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }
    } else {
      // 2. SAVING MODE / NORMAL STATE: Tampilkan objek-objek normal di jalanan
      // Ini mensimulasikan situasi aman ketika tersangka belum melewati kamera ini.

      // Parked Motorcycle 1
      if (0.93 >= _aiConfidenceThreshold) {
        overlays.add(
          _buildBoundingBox(
            label: 'MOTORCYCLE: 93%',
            top: 110,
            left:
                70 +
                (cameraIndex *
                    15), // Variasi posisi per kamera agar tidak monoton
            width: 60,
            height: 80,
            color: SigapTheme.secondaryColor.withOpacity(0.7),
          ),
        );
      }

      // Parked Motorcycle 2
      if (0.91 >= _aiConfidenceThreshold) {
        overlays.add(
          _buildBoundingBox(
            label: 'MOTORCYCLE: 91%',
            top: 105,
            left: 140 - (cameraIndex * 10),
            width: 55,
            height: 75,
            color: SigapTheme.secondaryColor.withOpacity(0.7),
          ),
        );
      }

      // Normal Pedestrian walking by slowly
      final double pedX = 200 + (progress * 30) + (cameraIndex * 20);
      if (0.92 >= _aiConfidenceThreshold) {
        overlays.add(
          _buildBoundingBox(
            label: 'PERSON: 92%',
            top: 85,
            left: pedX,
            width: 40,
            height: 100,
            color: SigapTheme.successColor.withOpacity(0.7),
          ),
        );
      }
    }

    return overlays;
  }

  Widget _buildBoundingBox({
    required String label,
    required double top,
    required double left,
    required double width,
    required double height,
    required Color color,
  }) {
    return Positioned(
      top: top,
      left: left,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(border: Border.all(color: color, width: 2)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -18,
              left: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: color,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

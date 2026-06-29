import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../widgets/glass_card.dart';
import '../theme.dart';

class LiveCctvScreen extends StatefulWidget {
  const LiveCctvScreen({super.key});

  @override
  State<LiveCctvScreen> createState() => _LiveCctvScreenState();
}

class _LiveCctvScreenState extends State<LiveCctvScreen> {
  bool _showBoundingBoxes = true;
  double _aiConfidenceThreshold = 0.75;
  final List<String> _mockStreamImages = [
    'https://images.unsplash.com/photo-1549317661-bd32c8ce0db2?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1573164713714-d95e436ab8d6?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=400&q=80',
  ];

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
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      Text(
                        'Integrasi Deteksi Anomali YOLOv9 & Pelacakan Estafet Lintas Kamera',
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                      ),
                    ],
                  ),
                  
                  // Controls
                  Row(
                    children: [
                      // Toggle Bounding Boxes
                      Row(
                        children: [
                          const Text('Overlay YOLOv9', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
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
                        child: CircularProgressIndicator(color: SigapTheme.primaryColor),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.5,
                        ),
                        itemCount: cameras.length > 4 ? 4 : cameras.length,
                        itemBuilder: (context, index) {
                          final camera = cameras[index];
                          final isHighFps = camera['fps_mode'] == 'HIGH';
                          final streamImg = _mockStreamImages[index % _mockStreamImages.length];

                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              color: Colors.black,
                              child: Stack(
                                children: [
                                  // Live Stream Background Image Mockup
                                  Positioned.fill(
                                    child: Image.network(
                                      camera['stream_url'] != null && camera['stream_url'].toString().startsWith('http')
                                          ? camera['stream_url']
                                          : streamImg,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, _, __) => Container(
                                        color: Colors.white10,
                                        child: const Icon(Icons.videocam_off, color: Colors.white24, size: 40),
                                      ),
                                    ),
                                  ),

                                  // YOLOv9 Bounding Box Overlays
                                  if (_showBoundingBoxes) ..._buildMockYoloOverlays(isHighFps),

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
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                camera['name'] ?? 'Kamera CCTV',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                              ),
                                              Text(
                                                'Koordinat: ${camera['latitude']}, ${camera['longitude']}',
                                                style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5)),
                                              ),
                                            ],
                                          ),
                                          
                                          // Toggle FPS Mode manually button
                                          IconButton(
                                            tooltip: isHighFps ? 'Switch to low-FPS saving mode' : 'Switch to high-FPS active detect mode',
                                            style: IconButton.styleFrom(
                                              backgroundColor: Colors.white12,
                                              hoverColor: Colors.white24,
                                            ),
                                            onPressed: () {
                                              context.read<DashboardBloc>().add(
                                                UpdateCctvFpsEvent(
                                                  cctvId: camera['id'],
                                                  fpsMode: isHighFps ? 'LOW' : 'HIGH',
                                                ),
                                              );
                                            },
                                            icon: Icon(
                                              isHighFps ? Icons.speed_rounded : Icons.slow_motion_video_rounded,
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
    final Color color = isHighFps ? SigapTheme.primaryColor : SigapTheme.successColor;
    final String label = isHighFps ? 'ACTIVE DETECT - 30 FPS (1080p)' : 'SAVING MODE - 10 FPS (480p)';
    
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMockYoloOverlays(bool isHighFps) {
    if (!isHighFps) {
      // Normal state: Less/no active threat detections overlay
      return [
        // Person tracking (Normal)
        _buildBoundingBox(
          label: 'WARGA: 92%',
          top: 60,
          left: 120,
          width: 80,
          height: 120,
          color: Colors.greenAccent,
        ),
      ];
    }

    // High alarm state: Active weapon and suspect detection mockups
    return [
      // Suspect Begal
      _buildBoundingBox(
        label: 'TERSANGKA: 94%',
        top: 40,
        left: 80,
        width: 100,
        height: 160,
        color: SigapTheme.primaryColor,
      ),
      
      // Weapon detected
      _buildBoundingBox(
        label: 'SAJAM (CELURIT): 89%',
        top: 90,
        left: 140,
        width: 50,
        height: 50,
        color: Colors.amber,
      ),
      
      // Vehicle Re-ID label
      Positioned(
        top: 200,
        left: 80,
        child: Container(
          padding: const EdgeInsets.all(4),
          color: Colors.black87,
          child: const Text(
            'Re-ID ID: 09 [Helm Merah | Beat Hitam]',
            style: TextStyle(color: SigapTheme.secondaryColor, fontSize: 8, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    ];
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
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

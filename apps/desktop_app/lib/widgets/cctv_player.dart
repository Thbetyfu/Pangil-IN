import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../theme.dart';

class CctvPlayer extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final bool showBoundingBoxes;
  final double aiConfidenceThreshold;
  final int cameraIndex;
  final String fpsMode;

  const CctvPlayer({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.showBoundingBoxes = true,
    this.aiConfidenceThreshold = 0.75,
    this.cameraIndex = 0,
    this.fpsMode = 'LOW',
  });

  @override
  State<CctvPlayer> createState() => _CctvPlayerState();
}

class _CctvPlayerState extends State<CctvPlayer> {
  late final Player _player;
  late final VideoController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(covariant CctvPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _player.open(Media(widget.url));
    }
  }

  void _initializePlayer() {
    try {
      _player = Player();
      _controller = VideoController(_player);

      // Listen to error streams
      _subscriptions.add(
        _player.stream.error.listen((event) {
          debugPrint("MediaKit Player Error: $event");
          if (mounted) {
            setState(() {
              _hasError = true;
            });
          }
        }),
      );

      // Listen to position changes to synchronize overlays in real-time
      _subscriptions.add(
        _player.stream.position.listen((pos) {
          if (mounted) {
            setState(() {
              _position = pos;
            });
          }
        }),
      );

      // Listen to duration updates
      _subscriptions.add(
        _player.stream.duration.listen((dur) {
          if (mounted) {
            setState(() {
              _duration = dur;
            });
          }
        }),
      );

      // Mute traffic cameras and set playlist loop mode
      _player.setVolume(0.0);
      _player.setPlaylistMode(PlaylistMode.loop);

      // Start playing HLS stream / MP4 video
      _player.open(Media(widget.url), play: true);

      // Stagger start times based on camera index for realistic cross-camera relays
      if (widget.cameraIndex > 0) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            // Seek to offset (e.g. 4s for camera 1, 8s for camera 2)
            _player.seek(Duration(milliseconds: widget.cameraIndex * 4000));
          }
        });
      }

      setState(() {
        _isInitialized = true;
        _hasError = false;
      });
    } catch (e) {
      debugPrint("Error initializing MediaKit player: $e");
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam_off_rounded,
                color: Colors.redAccent,
                size: 36,
              ),
              SizedBox(height: 8),
              Text(
                "Gagal memuat feed CCTV",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
            ),
          ),
        ),
      );
    }

    final bool isHighFps = widget.fpsMode == 'HIGH';

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // 1. Live Stream Player
          Positioned.fill(
            child: Video(
              controller: _controller,
              fit: widget.fit,
              controls: NoVideoControls, // Mute standard overlays
            ),
          ),

          // 2. Real-time Synchronized YOLOv9 Bounding Box Overlays
          if (widget.showBoundingBoxes)
            Positioned.fill(
              child: ClipRect(
                child: Builder(
                  builder: (context) {
                    final int durationMs = _duration.inMilliseconds > 0
                        ? _duration.inMilliseconds
                        : 15000;
                    final int ms = _position.inMilliseconds % durationMs;
                    final List<Widget> overlays = [];

                    if (isHighFps) {
                      // ACTIVE DETECT MODE: Show suspect & weapon aligned with video timeline
                      // Suspect enters hallway and is visible from 1.5s to 11.5s in cctv_begal.mp4
                      if (ms >= 1500 && ms < 11500) {
                        final double localProgress = (ms - 1500) / 10000;

                        // Path: suspect walks from right (x = 240) to left (x = 80)
                        final double suspectX = 240.0 - (localProgress * 160.0);
                        final double suspectY =
                            65.0 +
                            (localProgress < 0.5
                                ? localProgress * 20
                                : (1.0 - localProgress) * 20);

                        // Suspect Bounding Box (Neon Red)
                        if (0.98 >= widget.aiConfidenceThreshold) {
                          overlays.add(
                            _buildBoundingBox(
                              label: 'TERSANGKA: 98%',
                              top: suspectY,
                              left: suspectX,
                              width: 75,
                              height: 125,
                              color: SigapTheme.primaryColor,
                            ),
                          );
                        }

                        // Weapon (Celurit) visible when suspect is close (from 4.0s to 10.0s)
                        if (ms >= 4000 &&
                            ms < 10000 &&
                            0.95 >= widget.aiConfidenceThreshold) {
                          overlays.add(
                            _buildBoundingBox(
                              label: 'SAJAM (CELURIT): 95%',
                              top: suspectY + 50,
                              left: suspectX + 30,
                              width: 32,
                              height: 32,
                              color: SigapTheme.warningColor,
                            ),
                          );
                        }

                        // Re-ID tracking badge
                        if (0.98 >= widget.aiConfidenceThreshold) {
                          overlays.add(
                            Positioned(
                              top: suspectY + 125,
                              left: suspectX,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: SigapTheme.secondaryColor
                                        .withOpacity(0.5),
                                  ),
                                ),
                                child: const Text(
                                  'Re-ID ID: 09 [Helm Putih | Beat Hitam]',
                                  style: TextStyle(
                                    color: SigapTheme.secondaryColor,
                                    fontSize: 7,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                      }
                    } else {
                      // SAVING MODE (Peaceful State): Show standard traffic objects
                      // Parked Motorcycle
                      if (0.93 >= widget.aiConfidenceThreshold) {
                        overlays.add(
                          _buildBoundingBox(
                            label: 'MOTORCYCLE: 93%',
                            top: 110,
                            left: 70 + (widget.cameraIndex * 12),
                            width: 55,
                            height: 75,
                            color: SigapTheme.secondaryColor.withOpacity(0.7),
                          ),
                        );
                      }

                      // Normal pedestrian walking in background
                      if (0.91 >= widget.aiConfidenceThreshold) {
                        final double pedX = 180 + ((ms / durationMs) * 50);
                        overlays.add(
                          _buildBoundingBox(
                            label: 'PERSON: 91%',
                            top: 80,
                            left: pedX,
                            width: 38,
                            height: 95,
                            color: SigapTheme.successColor.withOpacity(0.7),
                          ),
                        );
                      }
                    }

                    return Stack(children: overlays);
                  },
                ),
              ),
            ),
        ],
      ),
    );
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
              top: -16,
              left: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                color: color,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 7,
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

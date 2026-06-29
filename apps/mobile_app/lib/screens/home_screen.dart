import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/sos_bloc.dart';
import '../bloc/sos_event.dart';
import '../bloc/sos_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/pulsing_sos_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  // Mock list of nearby incidents in Bandung
  final List<Map<String, dynamic>> _mockNearbyIncidents = [
    {
      'title': 'Aktivitas Mencurigakan',
      'location': 'Jl. Dago (350m dari posisi Anda)',
      'time': '5 menit yang lalu',
      'urgency': 'MEDIUM',
      'is_spoofed': false,
    },
    {
      'title': 'Begel Motor Terkonfirmasi',
      'location': 'Jl. Dipatiukur (800m dari posisi Anda)',
      'time': '12 menit yang lalu',
      'urgency': 'HIGH',
      'is_spoofed': false,
    },
    {
      'title': 'Percobaan Pencurian HP',
      'location': 'Jl. Cihampelas (1.2km dari posisi Anda)',
      'time': '30 menit yang lalu',
      'urgency': 'LOW',
      'is_spoofed': true,
    }
  ];

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SosBloc, SosState>(
      builder: (context, state) {
        return Stack(
          children: [
            // Base Screen (Home Screen)
            Scaffold(
              backgroundColor: const Color(0xFF0F1219), // Deep dark background
              body: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0F1219),
                      Color(0xFF1A1F30),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildHeader(state.ridingMode),
                        const SizedBox(height: 20),
                        _buildSecurityStatusCard(),
                        const SizedBox(height: 24),
                        Expanded(
                          child: RefreshIndicator(
                            color: const Color(0xFFFF1744),
                            backgroundColor: const Color(0xFF1E2638),
                            onRefresh: () async {
                              await Future.delayed(const Duration(seconds: 1));
                            },
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                // SOS Button area
                                Center(
                                  child: PulsingSosButton(
                                    onTap: () {
                                      // Trigger confirmation with mock coordinates (Bandung Simpang Dago)
                                      context.read<SosBloc>().add(
                                            TriggerSosConfirmationEvent(
                                              latitude: -6.90344,
                                              longitude: 107.61872,
                                            ),
                                          );
                                    },
                                  ),
                                ),
                               const SizedBox(height: 20),
                               Row(
                                 children: [
                                   Expanded(
                                     child: _buildActionCard(
                                       title: 'Lapor Visual',
                                       subtitle: 'Unggah Bukti & AI',
                                       icon: Icons.camera_alt_outlined,
                                       color: const Color(0xFFFF1744),
                                       onTap: () {
                                         HapticFeedback.lightImpact();
                                         Navigator.pushNamed(context, '/lapor');
                                       },
                                     ),
                                   ),
                                   const SizedBox(width: 12),
                                   Expanded(
                                     child: _buildActionCard(
                                       title: 'Pantau Peta',
                                       subtitle: 'OSM & Heatmap',
                                       icon: Icons.map_outlined,
                                       color: Colors.tealAccent,
                                       onTap: () {
                                         HapticFeedback.lightImpact();
                                         Navigator.pushNamed(context, '/pantau');
                                       },
                                     ),
                                   ),
                                 ],
                               ),
                               const SizedBox(height: 20),
                                _buildRidingModeCard(state.ridingMode),
                                const SizedBox(height: 24),
                                _buildNearbyIncidentsHeader(),
                                const SizedBox(height: 12),
                                ..._mockNearbyIncidents.map((incident) => _buildIncidentCard(incident)),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // SOS Confirmation Screen Overlay
            if (state.status == SosStatus.confirming)
              _buildConfirmationOverlay(state.countdown),

            // SOS Active Screen Overlay
            if (state.status == SosStatus.sending || state.status == SosStatus.active)
              _buildSosActiveOverlay(state.status),
          ],
        );
      },
    );
  }

  // --- UI Component Builders ---

  Widget _buildHeader(bool ridingMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pushNamed(context, '/profile');
              },
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.greenAccent, Colors.teal],
                  ),
                ),
                child: const CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFF1E2638),
                  backgroundImage: NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, Budi Santoso',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Colors.greenAccent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Reputasi: 95.00 (Baik)',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        // Driving Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: ridingMode ? const Color(0xFF0D47A1).withOpacity(0.4) : const Color(0xFF1E2638).withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ridingMode ? Colors.blueAccent.withOpacity(0.4) : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                ridingMode ? Icons.directions_bike_rounded : Icons.person_pin_circle_rounded,
                color: ridingMode ? Colors.blueAccent : Colors.tealAccent,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                ridingMode ? 'BERKENDARA' : 'STANDBY',
                style: TextStyle(
                  color: ridingMode ? Colors.blueAccent : Colors.tealAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityStatusCard() {
    return GlassCard(
      opacity: 0.05,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFFFC107),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Zona Sekitar: Cukup Rawan',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Terdeteksi 2 insiden begal dalam radius 1KM belakangan ini.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        opacity: 0.05,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRidingModeCard(bool isEnabled) {
    return GlassCard(
      opacity: isEnabled ? 0.12 : 0.06,
      color: isEnabled ? Colors.blueAccent : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: Border.all(
        color: isEnabled ? Colors.blueAccent.withOpacity(0.4) : Colors.white.withOpacity(0.06),
        width: 1,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isEnabled ? Colors.blueAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.directions_bike_rounded,
              color: isEnabled ? Colors.blueAccent : Colors.white60,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mode Berkendara (Riding Mode)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Mencegah false-trigger sensor G-force saat berkendara motor.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            activeColor: Colors.blueAccent,
            activeTrackColor: Colors.blue.withOpacity(0.3),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.white10,
            onChanged: (value) {
              HapticFeedback.lightImpact();
              context.read<SosBloc>().add(ToggleRidingModeEvent(enable: value));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyIncidentsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Laporan Sekitar (Radius 2KM)',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pushNamed(context, '/pantau');
          },
          child: const Text(
            'Lihat Semua',
            style: TextStyle(
              color: Colors.tealAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIncidentCard(Map<String, dynamic> incident) {
    final bool isHighUrgency = incident['urgency'] == 'HIGH';
    final bool isSpoofed = incident['is_spoofed'] == true;

    Color badgeColor = Colors.orangeAccent;
    if (isHighUrgency) badgeColor = const Color(0xFFFF1744);
    if (isSpoofed) badgeColor = Colors.grey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassCard(
        opacity: 0.04,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isHighUrgency
                    ? Icons.security_rounded
                    : (isSpoofed ? Icons.info_outline : Icons.warning_rounded),
                color: badgeColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          incident['title'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isSpoofed ? 'DIPROSES AI' : incident['urgency'],
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    incident['location'],
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    incident['time'],
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SOS Confirmation View (Slider overlay) ---

  double _dragValue = 0.0;

  Widget _buildConfirmationOverlay(int countdown) {
    return Material(
      color: Colors.black.withOpacity(0.85),
      child: Stack(
        children: [
          // Background blurry decorations
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF1744).withOpacity(0.15),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 40),
                // Heading Info
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF1744).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFF1744).withOpacity(0.5)),
                      ),
                      child: const Text(
                        'PEMICUAN SOS TERDETEKSI',
                        style: TextStyle(
                          color: Color(0xFFFF1744),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Apakah Anda berada dalam bahaya?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                // Countdown Timer Area
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 140,
                          height: 140,
                          child: CircularProgressIndicator(
                            value: countdown / 60.0,
                            strokeWidth: 6,
                            backgroundColor: Colors.white10,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF1744)),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '00:${countdown.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Courier',
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'DETIK',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Jika tidak ada tindakan dalam waktu 1 menit,\nsinyal SOS otomatis dikirim ke polisi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                // Slider & Cancel Area
                Column(
                  children: [
                    // Vertical Slider (High Fidelity drag)
                    Container(
                      width: 80,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // Background tracks
                          Positioned(
                            top: 20,
                            child: Icon(
                              Icons.keyboard_double_arrow_up_rounded,
                              color: const Color(0xFFFF1744).withOpacity(0.3 + (_dragValue * 0.7)),
                              size: 28,
                            ),
                          ),
                          // Draggable handle
                          Positioned(
                            bottom: _dragValue * 140,
                            child: GestureDetector(
                              onVerticalDragUpdate: (details) {
                                final delta = details.primaryDelta ?? 0.0;
                                // Convert drag coordinates to 0.0 - 1.0 scale
                                setState(() {
                                  _dragValue = max(0.0, min(1.0, _dragValue - (delta / 140.0)));
                                });
                                if (_dragValue >= 0.95) {
                                  // Drag successfully confirmed
                                  HapticFeedback.vibrate();
                                  context.read<SosBloc>().add(
                                        ConfirmSosEvent(
                                          description: 'Pemicuan SOS Warga (Dikonfirmasi via Slider)',
                                        ),
                                      );
                                  _dragValue = 0.0; // Reset
                                }
                              },
                              onVerticalDragEnd: (_) {
                                if (_dragValue < 0.95) {
                                  setState(() {
                                    _dragValue = 0.0; // Snap back
                                  });
                                }
                              },
                              child: Container(
                                width: 68,
                                height: 68,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFFFF5252),
                                      Color(0xFFB71C1C),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.redAccent,
                                      blurRadius: 15,
                                      spreadRadius: 1,
                                    )
                                  ],
                                ),
                                child: const Icon(Icons.swipe_up_rounded, color: Colors.white, size: 28),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Geser ke Atas untuk Konfirmasi',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Cancel Button
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        backgroundColor: Colors.white.withOpacity(0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        context.read<SosBloc>().add(CancelSosEvent());
                      },
                      child: const Text(
                        'BATALKAN SOS (SAYA AMAN)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SOS Active Screen Overlay ---

  Widget _buildSosActiveOverlay(SosStatus status) {
    return Material(
      color: const Color(0xFF8B0000).withOpacity(0.96), // Dark Red/Crimson threat state
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 30),
            // Status Header
            Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.gavel_rounded, color: Colors.white, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'PANGGIL-IN DARURAT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'TELENETRI GPS TERHUBUNG VIA MQTT',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Pulse audio record visualizer
            Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Simulated pulsing wave rings
                    ...List.generate(3, (index) {
                      return AnimatedBuilder(
                        animation: _waveController,
                        builder: (context, child) {
                          final progress = (_waveController.value + (index / 3.0)) % 1.0;
                          final size = 120.0 + (progress * 130.0);
                          final opacity = 0.45 * (1.0 - progress);
                          return Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(opacity),
                                width: 2.0,
                              ),
                            ),
                          );
                        },
                      );
                    }),
                    Container(
                      width: 110,
                      height: 110,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 2),
                        ],
                      ),
                      child: const Icon(
                        Icons.mic_rounded,
                        color: Color(0xFF8B0000),
                        size: 40,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'MEREKAM AUDIO SITUASI',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Mengirim data suara & video ke komando polisi...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            // Bottom Alert action
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Column(
                      children: [
                        Text(
                          '🚨 ALARM KEPOLISIAN AKTIF 🚨',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Petugas sedang merutekan patroli terdekat ke lokasi Anda. Harap mengamankan diri Anda secepat mungkin.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    context.read<SosBloc>().add(CancelSosEvent());
                  },
                  child: const Text(
                    'NYATAKAN SITUASI AMAN',
                    style: TextStyle(
                      color: Color(0xFF8B0000),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

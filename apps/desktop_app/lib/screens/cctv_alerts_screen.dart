import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../widgets/glass_card.dart';
import '../theme.dart';

class CctvAlertsScreen extends StatelessWidget {
  const CctvAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        final alerts = state.cctvAlerts;

        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'CCTV ALERT CENTER',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              Text(
                'Log Deteksi Anomali Senjata Tajam dan Tindakan Kriminalitas Oleh AI YOLOv9 Kota',
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
              ),
              const SizedBox(height: 24),

              // Alert List
              Expanded(
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  opacity: 0.02,
                  child: alerts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, color: SigapTheme.successColor.withOpacity(0.3), size: 48),
                              const SizedBox(height: 16),
                              Text(
                                'Semua aman. Tidak ada alert CCTV terdeteksi.',
                                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: alerts.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
                          itemBuilder: (context, index) {
                            final alert = alerts[index];
                            final confidence = alert['confidence'] ?? 0.85;
                            final date = DateTime.tryParse(alert['created_at'] ?? alert['createdAt'] ?? '')?.toLocal() ?? DateTime.now();

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              child: Row(
                                children: [
                                  // Warning indicator
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: SigapTheme.primaryColor.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.warning_rounded, color: SigapTheme.primaryColor, size: 20),
                                  ),
                                  const SizedBox(width: 20),

                                  // Snapshot thumb
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      alert['snapshot_url'] ?? alert['snapshotUrl'] ?? '',
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, _, __) => Container(
                                        color: Colors.white10,
                                        width: 60,
                                        height: 60,
                                        child: const Icon(Icons.videocam_off, size: 20),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),

                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Deteksi Begal / Senjata Tajam (Celurit)',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              'Kamera: ${alert['cctv_id'] ?? 'Dago 01'}',
                                              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              '•',
                                              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3)),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')} (${date.day}/${date.month}/${date.year})',
                                              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),

                                  // Confidence
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Confidence Score',
                                        style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.4)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${(confidence * 100).toStringAsFixed(0)}%',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 16),
                                      )
                                    ],
                                  ),
                                  const SizedBox(width: 24),

                                  // Action
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(0.04),
                                      foregroundColor: Colors.white,
                                      side: BorderSide(color: Colors.white.withOpacity(0.06)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    onPressed: () {
                                      // Switch to Live CCTV screen
                                      context.read<DashboardBloc>().add(ChangeTabEvent(2));
                                    },
                                    child: const Text('LIHAT KAMERA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

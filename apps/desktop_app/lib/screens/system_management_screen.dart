import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../widgets/glass_card.dart';
import '../theme.dart';

class SystemManagementScreen extends StatefulWidget {
  const SystemManagementScreen({super.key});

  @override
  State<SystemManagementScreen> createState() => _SystemManagementScreenState();
}

class _SystemManagementScreenState extends State<SystemManagementScreen> {
  int _activeSubTab = 0; // 0: CCTV Cameras, 1: Patrol Units

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'MANAJEMEN SISTEM',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              Text(
                'Konfigurasi Infrastruktur CCTV Kota, Pendaftaran Unit Patroli, dan Pemantauan Log Audit',
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
              ),
              const SizedBox(height: 24),

              // Tab Toggle Button Row
              Row(
                children: [
                  _buildSubTabButton(title: 'Kamera CCTV Kota', index: 0),
                  const SizedBox(width: 8),
                  _buildSubTabButton(title: 'Regu Patroli Lapangan', index: 1),
                ],
              ),
              const SizedBox(height: 20),

              // Dynamic content lists
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(20),
                  opacity: 0.03,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Subtitle & Action button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _activeSubTab == 0 ? 'DAFTAR KAMERA AKTIF' : 'DAFTAR REGU DAN PERSONEL',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SigapTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () => _showAddDialog(),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: Text(_activeSubTab == 0 ? 'TAMBAH CCTV' : 'TAMBAH REGU'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Lists tables
                      Expanded(
                        child: SingleChildScrollView(
                          child: _activeSubTab == 0 
                              ? _buildCctvTable(state.cctvCameras) 
                              : _buildPatrolTable(state.patrolUnits),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubTabButton({required String title, required int index}) {
    final bool isActive = _activeSubTab == index;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? SigapTheme.primaryColor : Colors.white.withOpacity(0.04),
        foregroundColor: isActive ? Colors.white : SigapTheme.textSecondaryColor,
        side: isActive ? null : BorderSide(color: Colors.white.withOpacity(0.06)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () {
        setState(() {
          _activeSubTab = index;
        });
      },
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildCctvTable(List<dynamic> cameras) {
    return DataTable(
      headingRowHeight: 48,
      columns: const [
        DataColumn(label: Text('NAMA KAMERA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
        DataColumn(label: Text('KOORDINAT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
        DataColumn(label: Text('MODE RESOLUSI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
        DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
      ],
      rows: cameras.map((camera) {
        final isHighFps = camera['fps_mode'] == 'HIGH';
        return DataRow(
          cells: [
            DataCell(Text(camera['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            DataCell(Text('${camera['latitude']}, ${camera['longitude']}', style: const TextStyle(fontSize: 12))),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isHighFps ? SigapTheme.primaryColor.withOpacity(0.12) : Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isHighFps ? '1080p / 30 FPS' : '480p / 10 FPS',
                  style: TextStyle(color: isHighFps ? SigapTheme.primaryColor : SigapTheme.textSecondaryColor, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            DataCell(
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: camera['status'] == 'ACTIVE' ? SigapTheme.successColor : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(camera['status'] ?? '', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPatrolTable(List<dynamic> units) {
    return DataTable(
      headingRowHeight: 48,
      columns: const [
        DataColumn(label: Text('NAMA REGU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
        DataColumn(label: Text('NO. KONTAK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
        DataColumn(label: Text('KOORDINAT LOKASI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
        DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
      ],
      rows: units.map((unit) {
        return DataRow(
          cells: [
            DataCell(Text(unit['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            DataCell(Text(unit['phone'] ?? '', style: const TextStyle(fontSize: 12))),
            DataCell(Text('${unit['latitude']}, ${unit['longitude']}', style: const TextStyle(fontSize: 12))),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: unit['status'] == 'AVAILABLE' ? SigapTheme.successColor.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  unit['status'] ?? '',
                  style: TextStyle(
                    color: unit['status'] == 'AVAILABLE' ? SigapTheme.successColor : Colors.orange,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    final phoneOrUrlController = TextEditingController();
    final latController = TextEditingController(text: '-6.90344');
    final lngController = TextEditingController(text: '107.61872');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: SigapTheme.surfaceColor,
          title: Text(
            _activeSubTab == 0 ? 'Registrasi CCTV Baru' : 'Pendaftaran Regu Patroli Baru',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: _activeSubTab == 0 ? 'Nama CCTV (e.g. Simpang Dago 02)' : 'Nama Unit (e.g. Patroli Dago 1B)',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneOrUrlController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: _activeSubTab == 0 ? 'Stream URL (RTSP/HTTP)' : 'Nomor Kontak Handphone',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: lngController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal', style: TextStyle(color: SigapTheme.textSecondaryColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: SigapTheme.primaryColor),
              onPressed: () async {
                final String name = nameController.text.trim();
                final String extra = phoneOrUrlController.text.trim();
                final double lat = double.tryParse(latController.text) ?? -6.90344;
                final double lng = double.tryParse(lngController.text) ?? 107.61872;

                if (name.isNotEmpty && extra.isNotEmpty) {
                  Navigator.pop(dialogContext);

                  // Trigger API call to create
                  final token = context.read<DashboardBloc>().state.token;
                  final url = _activeSubTab == 0 ? 'http://localhost:3001/api/cctv' : 'http://localhost:3001/api/patrol';
                  final body = _activeSubTab == 0 
                      ? {'name': name, 'stream_url': extra, 'latitude': lat, 'longitude': lng}
                      : {'name': name, 'phone': extra, 'latitude': lat, 'longitude': lng};

                  try {
                    final response = await http.post(
                      Uri.parse(url),
                      headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer $token',
                      },
                      body: jsonEncode(body),
                    );
                    print('Management creation response: ${response.body}');
                    
                    // Reload initial data
                    context.read<DashboardBloc>().add(LoadInitialDataEvent());
                  } catch (e) {
                    print('Failed to create system entity: $e');
                  }
                }
              },
              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

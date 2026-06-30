import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/api_service.dart';
import '../database/local_database.dart';
import '../widgets/glass_card.dart';
import '../bloc/sos_bloc.dart';
import '../bloc/sos_event.dart';
import '../bloc/sos_state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Mock citizen reports history
  final List<Map<String, dynamic>> _myReports = [
    {
      'date': '2026-06-25 21:30',
      'type': 'SOS Begal',
      'status': 'RESOLVED',
      'location': 'Simpang Dago',
    },
    {
      'date': '2026-05-18 19:15',
      'type': 'Laporan Visual',
      'status': 'VALIDATED',
      'location': 'Jl. Dipatiukur',
    },
  ];

  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  @override
  void dispose() {
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  void _showAddContactDialog() {
    _contactNameController.clear();
    _contactPhoneController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2638),
        title: const Text(
          'Tambah Kontak Darurat',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _contactNameController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Hubungan / Nama',
                labelStyle: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFFF1744)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contactPhoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Nomor Telepon',
                labelStyle: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFFF1744)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              if (_contactNameController.text.trim().isNotEmpty &&
                  _contactPhoneController.text.trim().isNotEmpty) {
                final db = context.read<LocalDatabase>();
                await db.insertContact(
                  EmergencyContact(
                    id: 'contact-${DateTime.now().millisecondsSinceEpoch}',
                    name: _contactNameController.text.trim(),
                    phone: _contactPhoneController.text.trim(),
                    relation: 'Emergency',
                  ),
                );
                HapticFeedback.lightImpact();
                if (mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text(
              'SIMPAN',
              style: TextStyle(
                color: Color(0xFFFF1744),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiService = context.read<ApiService>();
    final String name = apiService.userName ?? 'Budi Santoso';
    final String email = apiService.userEmail ?? 'citizen@panggilin.com';
    final double reputation = apiService.reputationScore ?? 95.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1219),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Profil Warga',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: Color(0xFFFF1744),
              size: 22,
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              context.read<ApiService>().logout();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F1219), Color(0xFF161B26)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            children: [
              const SizedBox(height: 10),
              // Reputation circular visual ring
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: CircularProgressIndicator(
                        value: reputation / 100.0,
                        strokeWidth: 5,
                        backgroundColor: Colors.white.withOpacity(0.05),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.greenAccent,
                        ),
                      ),
                    ),
                    const CircleAvatar(
                      radius: 48,
                      backgroundImage: NetworkImage(
                        'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Reputation Score card (F-04 UI spec)
              GlassCard(
                opacity: 0.04,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: Colors.greenAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Skor Reputasi Laporan: ${reputation.toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Reputasi Anda sangat baik. Laporan Anda diprioritaskan penuh oleh tim respon polisi.',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Fake Shutdown Settings Section
              _buildSectionHeader(
                'Metode Keluar Fake Shutdown',
                Icons.power_settings_new_rounded,
              ),
              const SizedBox(height: 10),
              BlocBuilder<SosBloc, SosState>(
                builder: (context, state) {
                  return GlassCard(
                    opacity: 0.04,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          title: const Text(
                            'Volume Up -> Down (Urutan Tombol)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: const Text(
                            'Tekan bergantian dalam 2 detik (Rekomendasi Utama)',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                          value: 'volume_chord',
                          groupValue: state.fakeShutdownMethod,
                          activeColor: const Color(0xFFFF1744),
                          onChanged: (val) {
                            if (val != null) {
                              HapticFeedback.lightImpact();
                              context.read<SosBloc>().add(
                                ChangeFakeShutdownMethodEvent(method: val),
                              );
                            }
                          },
                        ),
                        RadioListTile<String>(
                          title: const Text(
                            'Double Tap Layar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: const Text(
                            'Ketuk layar hitam secara cepat sebanyak 2 kali',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                          value: 'double_tap',
                          groupValue: state.fakeShutdownMethod,
                          activeColor: const Color(0xFFFF1744),
                          onChanged: (val) {
                            if (val != null) {
                              HapticFeedback.lightImpact();
                              context.read<SosBloc>().add(
                                ChangeFakeShutdownMethodEvent(method: val),
                              );
                            }
                          },
                        ),
                        RadioListTile<String>(
                          title: const Text(
                            'Long Press Layar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: const Text(
                            'Tekan dan tahan layar hitam selama 2 detik',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                          value: 'long_press',
                          groupValue: state.fakeShutdownMethod,
                          activeColor: const Color(0xFFFF1744),
                          onChanged: (val) {
                            if (val != null) {
                              HapticFeedback.lightImpact();
                              context.read<SosBloc>().add(
                                ChangeFakeShutdownMethodEvent(method: val),
                              );
                            }
                          },
                        ),
                        RadioListTile<String>(
                          title: const Text(
                            'Goyangkan Ponsel (Shake)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: const Text(
                            'Goyang ponsel dengan kekuatan sedang untuk keluar',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                          value: 'shake',
                          groupValue: state.fakeShutdownMethod,
                          activeColor: const Color(0xFFFF1744),
                          onChanged: (val) {
                            if (val != null) {
                              HapticFeedback.lightImpact();
                              context.read<SosBloc>().add(
                                ChangeFakeShutdownMethodEvent(method: val),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Emergency Contacts Section
              _buildSectionHeader(
                'Kontak Darurat Hubungan',
                Icons.phone_callback_rounded,
                onAdd: _showAddContactDialog,
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<EmergencyContact>>(
                stream: context.read<LocalDatabase>().watchAllContacts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFFF1744),
                          ),
                        ),
                      ),
                    );
                  }

                  final contacts = snapshot.data ?? [];
                  if (contacts.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        'Belum ada kontak darurat ditambahkan.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: contacts.map((contact) {
                      return _buildContactCard(
                        contact.id,
                        contact.name,
                        contact.phone,
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),

              // History Reports Section
              _buildSectionHeader(
                'Riwayat Laporan Saya',
                Icons.history_rounded,
              ),
              const SizedBox(height: 10),
              ..._myReports.map((report) => _buildReportCard(report)),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon, {
    VoidCallback? onAdd,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFFF1744), size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ],
        ),
        if (onAdd != null)
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: Colors.tealAccent,
              size: 20,
            ),
            onPressed: onAdd,
          ),
      ],
    );
  }

  Widget _buildContactCard(String id, String name, String phone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GlassCard(
        opacity: 0.03,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  phone,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent.withValues(alpha: 0.7),
                size: 20,
              ),
              onPressed: () async {
                HapticFeedback.lightImpact();
                await context.read<LocalDatabase>().deleteContact(id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final bool isResolved = report['status'] == 'RESOLVED';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GlassCard(
        opacity: 0.03,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isResolved
                    ? Colors.tealAccent.withOpacity(0.1)
                    : const Color(0xFFFF1744).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isResolved
                    ? Icons.check_circle_outline_rounded
                    : Icons.pending_actions_rounded,
                color: isResolved ? Colors.tealAccent : const Color(0xFFFF1744),
                size: 16,
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
                      Text(
                        report['type'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        report['status'],
                        style: TextStyle(
                          color: isResolved
                              ? Colors.tealAccent
                              : const Color(0xFFFF1744),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        report['location'],
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        report['date'],
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

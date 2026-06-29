import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../widgets/glass_card.dart';
import '../theme.dart';

class ReportsListScreen extends StatefulWidget {
  const ReportsListScreen({super.key});

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends State<ReportsListScreen> {
  String _statusFilter = 'ALL';
  String _urgencyFilter = 'ALL';
  String _spoofFilter = 'ALL';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        // Apply filters locally to reports list
        final filteredReports = state.reports.where((report) {
          // 1. Status Filter
          if (_statusFilter != 'ALL' && report['status'] != _statusFilter) {
            return false;
          }
          // 2. Urgency Filter
          if (_urgencyFilter != 'ALL' && report['urgency'] != _urgencyFilter) {
            return false;
          }
          // 3. Spoof Filter
          if (_spoofFilter != 'ALL') {
            final isSpoofed = report['is_spoofed'] == true;
            if (_spoofFilter == 'SPOOFED' && !isSpoofed) return false;
            if (_spoofFilter == 'REAL' && isSpoofed) return false;
          }
          // 4. Search Query (Reporter name, ID, or description)
          if (_searchQuery.isNotEmpty) {
            final name = (report['reporter']?['name'] ?? '').toString().toLowerCase();
            final desc = (report['description'] ?? '').toString().toLowerCase();
            final id = report['id'].toString().toLowerCase();
            final query = _searchQuery.toLowerCase();
            if (!name.contains(query) && !desc.contains(query) && !id.contains(query)) {
              return false;
            }
          }
          return true;
        }).toList();

        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'DAFTAR LAPORAN MASUK',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              Text(
                'Verifikasi, Klasifikasi Tingkat Urgensi, dan Manajemen Penugasan Laporan Begal',
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
              ),
              const SizedBox(height: 24),

              // Filter Bar
              GlassCard(
                padding: const EdgeInsets.all(16),
                opacity: 0.04,
                child: Row(
                  children: [
                    // Search
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.4), size: 18),
                          hintText: 'Cari nama pelapor, ID, atau deskripsi...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: Colors.black12,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: SigapTheme.primaryColor),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Filter Status
                    _buildDropdownFilter(
                      label: 'STATUS',
                      value: _statusFilter,
                      items: const ['ALL', 'PENDING', 'ON_PROCESS', 'RESOLVED', 'REJECTED'],
                      onChanged: (val) {
                        setState(() => _statusFilter = val!);
                      },
                    ),
                    const SizedBox(width: 16),

                    // Filter Urgensi
                    _buildDropdownFilter(
                      label: 'URGENSI',
                      value: _urgencyFilter,
                      items: const ['ALL', 'CRITICAL', 'HIGH', 'MEDIUM', 'LOW'],
                      onChanged: (val) {
                        setState(() => _urgencyFilter = val!);
                      },
                    ),
                    const SizedBox(width: 16),

                    // Filter Spoofing
                    _buildDropdownFilter(
                      label: 'DETEKSI AI',
                      value: _spoofFilter,
                      items: const ['ALL', 'REAL', 'SPOOFED'],
                      onChanged: (val) {
                        setState(() => _spoofFilter = val!);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Reports Table
              Expanded(
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  opacity: 0.02,
                  child: filteredReports.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.feed_outlined, color: Colors.white.withOpacity(0.15), size: 48),
                              const SizedBox(height: 16),
                              Text(
                                'Tidak ada laporan yang sesuai dengan filter',
                                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.02)),
                            dataRowMaxHeight: 64,
                            columns: const [
                              DataColumn(label: Text('PELAPOR & KONTAK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('TIPE INPUT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('URGENSI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('VALIDASI AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('TANGGAL MASUK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('AKSI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            ],
                            rows: filteredReports.map((report) {
                              final reporterName = report['reporter']?['name'] ?? 'Warga Anonim';
                              final reporterPhone = report['reporter']?['phone'] ?? '-';
                              final type = report['type'] == 'SOS_VOICE' ? 'SOS Voice (Zero-Click)' : 'Laporan Visual';
                              final createdDate = DateTime.parse(report['created_at'] ?? report['createdAt'] ?? DateTime.now().toIso8601String()).toLocal();
                              
                              return DataRow(
                                cells: [
                                  // Pelapor
                                  DataCell(
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(reporterName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                                        const SizedBox(height: 2),
                                        Text(reporterPhone, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5))),
                                      ],
                                    ),
                                  ),
                                  // Tipe
                                  DataCell(
                                    Row(
                                      children: [
                                        Icon(
                                          report['type'] == 'SOS_VOICE' ? Icons.phone_android_rounded : Icons.camera_alt_rounded,
                                          size: 16,
                                          color: Colors.white.withOpacity(0.6),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(type, style: const TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  // Urgensi
                                  DataCell(_buildUrgencyBadge(report['urgency'])),
                                  // Status
                                  DataCell(_buildStatusBadge(report['status'])),
                                  // Validasi AI (Anti Spoofing)
                                  DataCell(_buildSpoofIndicator(report['is_spoofed'] == true, report['anti_spoofing_score'])),
                                  // Tanggal
                                  DataCell(Text(
                                    '${createdDate.day}/${createdDate.month}/${createdDate.year} - ${createdDate.hour.toString().padLeft(2, '0')}:${createdDate.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 12),
                                  )),
                                  // Aksi
                                  DataCell(
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: SigapTheme.primaryColor.withOpacity(0.12),
                                        foregroundColor: SigapTheme.primaryColor,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      onPressed: () {
                                        context.read<DashboardBloc>().add(SelectReportEvent(report));
                                      },
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Proses', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          SizedBox(width: 4),
                                          Icon(Icons.arrow_forward_ios_rounded, size: 10),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.4), letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: SigapTheme.surfaceColor,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.white.withOpacity(0.6)),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUrgencyBadge(String urgency) {
    Color color = Colors.orangeAccent;
    if (urgency == 'CRITICAL' || urgency == 'HIGH') color = SigapTheme.primaryColor;
    if (urgency == 'LOW') color = Colors.blueAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        urgency,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    if (status == 'PENDING') color = Colors.orange;
    if (status == 'ON_PROCESS') color = Colors.blue;
    if (status == 'RESOLVED') color = SigapTheme.successColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSpoofIndicator(bool isSpoofed, double? score) {
    final double actualScore = score ?? 1.0;
    if (isSpoofed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 14),
          const SizedBox(width: 6),
          Text(
            'SPOOF DETECTED (${(actualScore * 100).toStringAsFixed(0)}%)',
            style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded, color: SigapTheme.successColor, size: 14),
          const SizedBox(width: 6),
          Text(
            'REAL (${(actualScore * 100).toStringAsFixed(0)}%)',
            style: const TextStyle(color: SigapTheme.successColor, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }
  }
}

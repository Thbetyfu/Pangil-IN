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

  void _showDeleteConfirmationDialog(BuildContext context, String reportId) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: SigapTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.redAccent, size: 22),
              SizedBox(width: 10),
              Text(
                'HAPUS LAPORAN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          content: const Text(
            'Apakah Anda yakin ingin menghapus laporan ini secara permanen dari database? Tindakan ini tidak dapat dibatalkan.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'BATAL',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onPressed: () {
                context.read<DashboardBloc>().add(DeleteReportEvent(reportId));
                Navigator.of(ctx).pop();
              },
              child: const Text(
                'HAPUS',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        final filteredReports = state.reports.where((report) {
          if (_statusFilter != 'ALL' && report['status'] != _statusFilter) {
            return false;
          }
          if (_urgencyFilter != 'ALL' &&
              report['urgency'] != _urgencyFilter) {
            return false;
          }
          if (_spoofFilter != 'ALL') {
            final isSpoofed = report['is_spoofed'] == true;
            if (_spoofFilter == 'SPOOFED' && !isSpoofed) return false;
            if (_spoofFilter == 'REAL' && isSpoofed) return false;
          }
          if (_searchQuery.isNotEmpty) {
            final name = (report['reporter']?['name'] ?? '')
                .toString()
                .toLowerCase();
            final desc =
                (report['description'] ?? '').toString().toLowerCase();
            final id = report['id'].toString().toLowerCase();
            final query = _searchQuery.toLowerCase();
            if (!name.contains(query) &&
                !desc.contains(query) &&
                !id.contains(query)) {
              return false;
            }
          }
          return true;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== HEADER =====
            Container(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DAFTAR LAPORAN MASUK',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pilih laporan untuk memproses penindakan',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Stats chips
                  _buildStatChip(
                    label: 'TOTAL',
                    count: state.reports.length,
                    color: Colors.white38,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    label: 'PENDING',
                    count: state.reports
                        .where((r) => r['status'] == 'PENDING')
                        .length,
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    label: 'AKTIF',
                    count: state.reports
                        .where((r) => r['status'] == 'ON_PROCESS')
                        .length,
                    color: Colors.blueAccent,
                  ),
                ],
              ),
            ),

            // ===== SEARCH + FILTER BAR =====
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
              child: Row(
                children: [
                  // Search
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Colors.white.withOpacity(0.35),
                            size: 16,
                          ),
                          hintText: 'Cari pelapor, ID, deskripsi...',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: SigapTheme.primaryColor,
                            ),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() => _searchQuery = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Filter: Status
                  _buildCompactFilter(
                    icon: Icons.circle_outlined,
                    label: 'Status',
                    value: _statusFilter,
                    items: const [
                      'ALL',
                      'PENDING',
                      'ON_PROCESS',
                      'RESOLVED',
                      'REJECTED',
                    ],
                    onChanged: (val) => setState(() => _statusFilter = val!),
                  ),
                  const SizedBox(width: 8),
                  // Filter: Urgensi
                  _buildCompactFilter(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Urgensi',
                    value: _urgencyFilter,
                    items: const [
                      'ALL',
                      'CRITICAL',
                      'HIGH',
                      'MEDIUM',
                      'LOW',
                    ],
                    onChanged: (val) =>
                        setState(() => _urgencyFilter = val!),
                  ),
                  const SizedBox(width: 8),
                  // Filter: Deteksi AI
                  _buildCompactFilter(
                    icon: Icons.verified_outlined,
                    label: 'Deteksi AI',
                    value: _spoofFilter,
                    items: const ['ALL', 'REAL', 'SPOOFED'],
                    onChanged: (val) => setState(() => _spoofFilter = val!),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ===== LAPORAN COUNT LABEL =====
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
              child: Text(
                '${filteredReports.length} laporan ditemukan',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            ),

            // ===== GRID LIST =====
            Expanded(
              child: filteredReports.isEmpty
                  ? _buildEmptyState()
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 2.6,
                      ),
                      itemCount: filteredReports.length,
                      itemBuilder: (context, index) {
                        final report = filteredReports[index];
                        return _buildReportCard(context, report);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReportCard(
    BuildContext context,
    Map<String, dynamic> report,
  ) {
    final reporterName =
        report['reporter']?['name'] ?? 'Warga Anonim';
    final createdDate = DateTime.parse(
      report['created_at'] ??
          report['createdAt'] ??
          DateTime.now().toIso8601String(),
    ).toLocal();
    final urgency = report['urgency'] ?? 'MEDIUM';
    final status = report['status'] ?? 'PENDING';
    final type = report['type'] ?? '';
    final isSpoofed = report['is_spoofed'] == true;
    final reputationScore =
        (report['reporter']?['reputation_score'] as num?)?.toDouble() ?? 0.0;

    final urgencyColor = _getUrgencyColor(urgency);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        context.read<DashboardBloc>().add(SelectReportEvent(report));
      },
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        opacity: 0.04,
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1.0,
        ),
        child: Row(
          children: [
            // Left accent bar
            Container(
              width: 3,
              height: double.infinity,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: urgencyColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Row 1: Name + Urgency Badge + Spoof indicator
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          reporterName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildUrgencyBadge(urgency),
                      if (isSpoofed) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.4),
                            ),
                          ),
                          child: const Text(
                            'SPOOF',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Row 2: Description preview
                  Text(
                    report['description'] ?? 'Tidak ada deskripsi laporan',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Row 3: Meta info
                  Row(
                    children: [
                      Icon(
                        type == 'SOS_VOICE'
                            ? Icons.graphic_eq_rounded
                            : Icons.camera_alt_outlined,
                        size: 11,
                        color: Colors.white.withOpacity(0.35),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        type == 'SOS_VOICE' ? 'Voice SOS' : 'Visual',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.35),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.schedule_rounded,
                        size: 11,
                        color: Colors.white.withOpacity(0.35),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${createdDate.day}/${createdDate.month} ${createdDate.hour.toString().padLeft(2, '0')}:${createdDate.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.35),
                        ),
                      ),
                      if (reputationScore > 0) ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.star_rounded,
                          size: 11,
                          color: Colors.amber.withOpacity(0.7),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${reputationScore.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.35),
                          ),
                        ),
                      ],
                      const Spacer(),
                      _buildStatusBadge(status),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Right: Actions + chevron
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Delete button
                GestureDetector(
                  onTap: () {
                    _showDeleteConfirmationDialog(context, report['id']);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.redAccent.withOpacity(0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 14,
                    ),
                  ),
                ),
                // Chevron - tap to go to detail
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(0.25),
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.7),
              letterSpacing: 0.5,
            ),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFilter({
    required IconData icon,
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final isActive = value != 'ALL';
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isActive
            ? SigapTheme.primaryColor.withOpacity(0.08)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? SigapTheme.primaryColor.withOpacity(0.3)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: SigapTheme.surfaceColor,
          isDense: true,
          style: TextStyle(
            color: isActive ? SigapTheme.primaryColor : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isActive
                ? SigapTheme.primaryColor
                : Colors.white.withOpacity(0.4),
            size: 16,
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 12,
                    color: item == 'ALL'
                        ? Colors.white38
                        : SigapTheme.primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item == 'ALL' ? label : item,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.feed_outlined,
              color: Colors.white.withOpacity(0.15),
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Tidak ada laporan ditemukan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.35),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coba ubah filter atau kata kunci pencarian',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency) {
      case 'CRITICAL':
        return const Color(0xFFFF1744);
      case 'HIGH':
        return SigapTheme.primaryColor;
      case 'MEDIUM':
        return Colors.orangeAccent;
      case 'LOW':
        return Colors.blueAccent;
      default:
        return Colors.grey;
    }
  }

  Widget _buildUrgencyBadge(String urgency) {
    final color = _getUrgencyColor(urgency);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        urgency,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'PENDING':
        color = Colors.orangeAccent;
        break;
      case 'ON_PROCESS':
        color = Colors.blueAccent;
        break;
      case 'RESOLVED':
        color = SigapTheme.successColor;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

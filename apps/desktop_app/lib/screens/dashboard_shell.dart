import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../theme.dart';
import 'dashboard_screen.dart';
import 'reports_list_screen.dart';
import 'report_detail_screen.dart';
import 'live_cctv_screen.dart';
import 'cctv_alerts_screen.dart';
import 'system_management_screen.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  // Map index to screen widgets
  Widget _getScreen(int index, Map<String, dynamic>? selectedReport) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        if (selectedReport != null) {
          return const ReportDetailScreen();
        }
        return const ReportsListScreen();
      case 2:
        return const LiveCctvScreen();
      case 3:
        return const CctvAlertsScreen();
      case 4:
        return const SystemManagementScreen();
      default:
        return const DashboardScreen();
    }
  }

  void _showNewReportBanner(Map<String, dynamic> report) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFB71C1C),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emergency_share_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SOS DARURAT WARGA AKTIF!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    report['description'] ?? 'Pemicuan SOS Warga Terdeteksi',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFB71C1C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                context.read<DashboardBloc>().add(SelectReportEvent(report));
                context.read<DashboardBloc>().add(ChangeTabEvent(1)); // Go to Reports Detail
              },
              child: const Text('PROSES SEKARANG'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DashboardBloc, DashboardState>(
      listenWhen: (previous, current) => previous.reports.length < current.reports.length,
      listener: (context, state) {
        if (state.reports.isNotEmpty) {
          // Play warning trigger or banner in police panel
          _showNewReportBanner(state.reports.first);
        }
      },
      child: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          return Scaffold(
            body: Row(
              children: [
                // 1. Sidebar Navigation
                Container(
                  width: 280,
                  color: SigapTheme.surfaceColor,
                  child: Column(
                    children: [
                      // Sidebar Header
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: SigapTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.security_rounded, color: SigapTheme.primaryColor, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PANGGIL-IN',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  Text(
                                    'SIGAP Command Center',
                                    style: TextStyle(fontSize: 10, color: SigapTheme.textSecondaryColor),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Sidebar Menu Items
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            _buildMenuItem(
                              icon: Icons.dashboard_outlined,
                              activeIcon: Icons.dashboard_rounded,
                              title: 'Dashboard Taktis',
                              index: 0,
                              selectedIndex: state.currentTab,
                            ),
                            _buildMenuItem(
                              icon: Icons.list_alt_rounded,
                              activeIcon: Icons.list_alt_rounded,
                              title: 'Daftar Laporan',
                              index: 1,
                              selectedIndex: state.currentTab,
                              badgeCount: state.reports.where((r) => r['status'] == 'PENDING').length,
                            ),
                            _buildMenuItem(
                              icon: Icons.camera_outdoor_outlined,
                              activeIcon: Icons.camera_outdoor_rounded,
                              title: 'Live CCTV Monitor',
                              index: 2,
                              selectedIndex: state.currentTab,
                            ),
                            _buildMenuItem(
                              icon: Icons.warning_amber_rounded,
                              activeIcon: Icons.warning_rounded,
                              title: 'CCTV Alert Center',
                              index: 3,
                              selectedIndex: state.currentTab,
                              badgeCount: state.cctvAlerts.length,
                              badgeColor: SigapTheme.primaryColor,
                            ),
                            if (state.userRole == 'SUPERADMIN')
                              _buildMenuItem(
                                icon: Icons.settings_outlined,
                                activeIcon: Icons.settings_rounded,
                                title: 'Manajemen Sistem',
                                index: 4,
                                selectedIndex: state.currentTab,
                              ),
                          ],
                        ),
                      ),
                      
                      // Sidebar Footer (Logged in profile & logout button)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.15),
                          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: SigapTheme.primaryColor.withOpacity(0.2),
                              radius: 18,
                              child: Text(
                                state.userName != null ? state.userName!.substring(0, 1).toUpperCase() : 'O',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    state.userName ?? 'Operator Polisi',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    state.userRole ?? 'OPERATOR',
                                    style: const TextStyle(fontSize: 10, color: SigapTheme.textSecondaryColor),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                context.read<DashboardBloc>().add(LogoutEvent());
                                Navigator.pushReplacementNamed(context, '/login');
                              },
                              icon: const Icon(Icons.logout_rounded, color: SigapTheme.textSecondaryColor, size: 18),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                
                // 2. Main content view area
                Expanded(
                  child: state.isLoading 
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: SigapTheme.primaryColor,
                          ),
                        )
                      : _getScreen(state.currentTab, state.selectedReport),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required IconData activeIcon,
    required String title,
    required int index,
    required int selectedIndex,
    int badgeCount = 0,
    Color badgeColor = SigapTheme.primaryColor,
  }) {
    final bool isSelected = index == selectedIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          // If switching away from list tab, clear selected report as well
          if (index != 1) {
            context.read<DashboardBloc>().add(SelectReportEvent(null));
          }
          context.read<DashboardBloc>().add(ChangeTabEvent(index));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? SigapTheme.primaryColor.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected 
                ? const Border(left: BorderSide(color: SigapTheme.primaryColor, width: 4))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? SigapTheme.primaryColor : SigapTheme.textSecondaryColor,
                size: 20,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : SigapTheme.textSecondaryColor,
                    fontSize: 13,
                  ),
                ),
              ),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : badgeCount.toString(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

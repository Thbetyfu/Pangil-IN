import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import '../services/dispatch_service.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final DispatchService dispatchService;

  DashboardBloc({required this.dispatchService}) : super(DashboardState()) {
    // Register WebSocket callbacks to trigger BLoC events
    dispatchService.onNewReport = (data) => add(NewReportReceivedEvent(data));
    dispatchService.onGpsUpdate = (data) => add(GpsUpdateReceivedEvent(data));
    dispatchService.onCctvAlert = (data) => add(CctvAlertReceivedEvent(data));

    on<LoginEvent>(_onLogin);
    on<LogoutEvent>(_onLogout);
    on<ChangeTabEvent>(_onChangeTab);
    on<LoadInitialDataEvent>(_onLoadInitialData);
    on<SelectReportEvent>(_onSelectReport);
    on<AssignPatrolUnitEvent>(_onAssignPatrolUnit);
    
    // WebSocket / Real-time events handlers
    on<NewReportReceivedEvent>(_onNewReportReceived);
    on<GpsUpdateReceivedEvent>(_onGpsUpdateReceived);
    on<CctvAlertReceivedEvent>(_onCctvAlertReceived);
    
    // AI Mock / CCTV trigger events
    on<TriggerMockSosEvent>(_onTriggerMockSos);
    on<UpdateCctvFpsEvent>(_onUpdateCctvFps);
  }

  Future<void> _onLogin(LoginEvent event, Emitter<DashboardState> emit) async {
    emit(state.copyWith(isAuthenticating: true, authError: null));
    try {
      final res = await dispatchService.login(event.email, event.password);
      if (res['status'] == 'success') {
        final userData = res['data']['user'];
        final token = res['data']['token'];
        
        if (userData['role'] == 'CITIZEN') {
          emit(state.copyWith(
            isAuthenticating: false,
            authError: 'Akses ditolak: Hanya untuk petugas kepolisian',
          ));
          return;
        }

        emit(state.copyWith(
          isAuthenticated: true,
          isAuthenticating: false,
          token: token,
          userName: userData['name'],
          userRole: userData['role'],
        ));

        // Connect WebSocket and fetch initial systems data
        dispatchService.connectWebSocket();
        add(LoadInitialDataEvent());
      } else {
        emit(state.copyWith(
          isAuthenticating: false,
          authError: res['message'] ?? 'Login gagal. Periksa kembali email dan password.',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isAuthenticating: false,
        authError: 'Gagal terhubung ke backend: ${e.toString()}',
      ));
    }
  }

  void _onLogout(LogoutEvent event, Emitter<DashboardState> emit) {
    dispatchService.disconnect();
    emit(DashboardState()); // Reset to default state (unauthenticated)
  }

  void _onChangeTab(ChangeTabEvent event, Emitter<DashboardState> emit) {
    emit(state.copyWith(currentTab: event.index));
  }

  Future<void> _onLoadInitialData(LoadInitialDataEvent event, Emitter<DashboardState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final reports = await dispatchService.getActiveReports();
      final cameras = await dispatchService.getCctvCameras();
      final units = await dispatchService.getPatrolUnits();

      // Build initial track logs for active reports
      final Map<String, List<Map<String, double>>> logs = {};
      for (var r in reports) {
        logs[r['id']] = [
          {'latitude': r['latitude'], 'longitude': r['longitude']}
        ];
      }

      emit(state.copyWith(
        isLoading: false,
        reports: reports,
        cctvCameras: cameras,
        patrolUnits: units,
        gpsTrackLogs: logs,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Gagal memuat data: ${e.toString()}',
      ));
    }
  }

  void _onSelectReport(SelectReportEvent event, Emitter<DashboardState> emit) {
    emit(state.copyWith(selectedReport: event.report));
  }

  Future<void> _onAssignPatrolUnit(AssignPatrolUnitEvent event, Emitter<DashboardState> emit) async {
    try {
      final res = await dispatchService.assignPatrolUnit(event.reportId, event.patrolUnitId);
      if (res['status'] == 'success') {
        // Reload reports and units
        final reports = await dispatchService.getActiveReports();
        final units = await dispatchService.getPatrolUnits();
        
        // Find if selected report is updated
        Map<String, dynamic>? updatedSelected;
        if (state.selectedReport != null && state.selectedReport!['id'] == event.reportId) {
          updatedSelected = reports.firstWhere(
            (r) => r['id'] == event.reportId,
            orElse: () => state.selectedReport,
          );
        }

        emit(state.copyWith(
          reports: reports,
          patrolUnits: units,
          selectedReport: updatedSelected ?? state.selectedReport,
        ));
      }
    } catch (e) {
      print('Error assigning patrol unit: $e');
    }
  }

  void _onNewReportReceived(NewReportReceivedEvent event, Emitter<DashboardState> emit) {
    final updatedReports = List<dynamic>.from(state.reports)..insert(0, event.report);
    
    // Add starting GPS node to track logs
    final logs = Map<String, List<Map<String, double>>>.from(state.gpsTrackLogs);
    final String reportId = event.report['id'];
    logs[reportId] = [
      {
        'latitude': event.report['latitude'],
        'longitude': event.report['longitude'],
      }
    ];

    emit(state.copyWith(
      reports: updatedReports,
      gpsTrackLogs: logs,
    ));
  }

  void _onGpsUpdateReceived(GpsUpdateReceivedEvent event, Emitter<DashboardState> emit) {
    final String reportId = event.data['reportId'];
    final double lat = event.data['latitude'];
    final double lng = event.data['longitude'];

    // Update coordinates in the reports list
    final updatedReports = state.reports.map((r) {
      if (r['id'] == reportId) {
        return {
          ...r,
          'latitude': lat,
          'longitude': lng,
        };
      }
      return r;
    }).toList();

    // Append to logs
    final logs = Map<String, List<Map<String, double>>>.from(state.gpsTrackLogs);
    if (!logs.containsKey(reportId)) {
      logs[reportId] = [];
    }
    logs[reportId]!.add({'latitude': lat, 'longitude': lng});

    // Update currently selected report if it matches
    Map<String, dynamic>? updatedSelected = state.selectedReport;
    if (state.selectedReport != null && state.selectedReport!['id'] == reportId) {
      updatedSelected = {
        ...state.selectedReport!,
        'latitude': lat,
        'longitude': lng,
      };
    }

    emit(state.copyWith(
      reports: updatedReports,
      gpsTrackLogs: logs,
      selectedReport: updatedSelected,
    ));
  }

  void _onCctvAlertReceived(CctvAlertReceivedEvent event, Emitter<DashboardState> emit) {
    final updatedAlerts = List<dynamic>.from(state.cctvAlerts)..insert(0, event.alert);
    
    // Also update the respective camera FPS state if we got FPS mode updates
    final String cctvId = event.alert['cctv_id'] ?? event.alert['cctvId'];
    final updatedCameras = state.cctvCameras.map((cam) {
      if (cam['id'] == cctvId) {
        return {
          ...cam,
          'fps_mode': 'HIGH', // Automatically trigger active HIGH FPS mode
        };
      }
      return cam;
    }).toList();

    emit(state.copyWith(
      cctvAlerts: updatedAlerts,
      cctvCameras: updatedCameras,
    ));
  }

  Future<void> _onTriggerMockSos(TriggerMockSosEvent event, Emitter<DashboardState> emit) async {
    try {
      // Trigger AI Server's mock-mqtt test endpoint to simulate anomaly detection
      // Note AI server runs at port 3002
      final response = await http.post(
        Uri.parse('http://localhost:3002/cctv/test-trigger-alert'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cctv_id': event.cctvId,
          'confidence': 0.89,
          'snapshot_url': 'https://images.unsplash.com/photo-1614064641938-3bbee52942c7?auto=format&fit=crop&w=400&q=80',
          'suspect_feature_vector': event.suspectFeatures,
        }),
      );
      print('Mock CCTV alert response: ${response.body}');
    } catch (e) {
      print('Failed to trigger mock SOS on AI inference server: $e');
    }
  }

  Future<void> _onUpdateCctvFps(UpdateCctvFpsEvent event, Emitter<DashboardState> emit) async {
    try {
      final res = await dispatchService.updateCctvFps(event.cctvId, event.fpsMode);
      if (res['status'] == 'success') {
        final updatedCameras = state.cctvCameras.map((cam) {
          if (cam['id'] == event.cctvId) {
            return {
              ...cam,
              'fps_mode': event.fpsMode,
            };
          }
          return cam;
        }).toList();

        emit(state.copyWith(cctvCameras: updatedCameras));
      }
    } catch (e) {
      print('Failed to update CCTV FPS: $e');
    }
  }
}

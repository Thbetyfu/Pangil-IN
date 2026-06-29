import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_app/bloc/dashboard_bloc.dart';
import 'package:desktop_app/bloc/dashboard_event.dart';
import 'package:desktop_app/bloc/dashboard_state.dart';
import 'package:desktop_app/services/dispatch_service.dart';

class MockDispatchService extends DispatchService {
  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    if (email == 'admin@sigap.go.id' && password == 'password123') {
      return {
        'status': 'success',
        'data': {
          'token': 'mock-jwt-token-xyz',
          'user': {
            'id': 'police-op-uuid-1',
            'name': 'Operator Sigap 1',
            'role': 'POLICE_OPERATOR',
          },
        },
      };
    } else if (email == 'citizen@gmail.com') {
      return {
        'status': 'success',
        'data': {
          'token': 'mock-jwt-token-xyz',
          'user': {
            'id': 'citizen-uuid-1',
            'name': 'Citizen Budi',
            'role': 'CITIZEN',
          },
        },
      };
    }
    return {'status': 'error', 'message': 'Kombinasi email dan password salah'};
  }

  @override
  Future<List<dynamic>> getActiveReports() async {
    return [
      {
        'id': 'report-uuid-1',
        'latitude': -6.914744,
        'longitude': 107.609810,
        'status': 'PENDING',
        'urgency': 'HIGH',
      },
    ];
  }

  @override
  Future<List<dynamic>> getCctvCameras() async {
    return [
      {'id': 'cctv-uuid-1', 'name': 'CCTV Simpang Dago', 'fps_mode': 'NORMAL'},
    ];
  }

  @override
  Future<List<dynamic>> getPatrolUnits() async {
    return [
      {
        'id': 'patrol-uuid-1',
        'name': 'Patroli Sabhara 01',
        'status': 'AVAILABLE',
      },
    ];
  }

  @override
  void connectWebSocket() {}

  @override
  void disconnect() {}

  @override
  Future<List<dynamic>> getEscapePrediction(
    String startNode,
    String headingNode,
  ) async {
    return [
      {
        'path': ['simpang_dago', 'dago_atas'],
        'total_time_minutes': 3.0,
        'confidence_score': 0.8,
      },
    ];
  }

  @override
  Future<List<dynamic>> getReidTracking(
    String startNode,
    String suspectFeatures,
  ) async {
    return [
      {
        'node_id': 'simpang_dago',
        'node_name': 'Simpang Dago',
        'latitude': -6.90344,
        'longitude': 107.61872,
        'reid_probability': 0.95,
      },
    ];
  }
}

void main() {
  late MockDispatchService mockDispatchService;
  late DashboardBloc dashboardBloc;

  setUp(() {
    mockDispatchService = MockDispatchService();
    dashboardBloc = DashboardBloc(dispatchService: mockDispatchService);
  });

  tearDown(() async {
    await dashboardBloc.close();
  });

  test('Initial state has default values', () {
    expect(dashboardBloc.state.isAuthenticated, isFalse);
    expect(dashboardBloc.state.currentTab, equals(0));
    expect(dashboardBloc.state.reports, isEmpty);
  });

  test('LoginEvent success for police operator', () {
    dashboardBloc.add(
      LoginEvent(
        email: 'admin@sigap.go.id',
        password: 'password123',
        otpCode: '123456',
      ),
    );

    expect(
      dashboardBloc.stream,
      emitsThrough(
        predicate<DashboardState>(
          (state) =>
              state.isAuthenticated == true &&
              state.userName == 'Operator Sigap 1' &&
              state.userRole == 'POLICE_OPERATOR' &&
              state.token == 'mock-jwt-token-xyz',
        ),
      ),
    );
  });

  test('LoginEvent failure for citizen (unauthorized role)', () {
    dashboardBloc.add(
      LoginEvent(
        email: 'citizen@gmail.com',
        password: 'password123',
        otpCode: '123456',
      ),
    );

    expect(
      dashboardBloc.stream,
      emitsThrough(
        predicate<DashboardState>(
          (state) =>
              state.isAuthenticated == false &&
              state.authError ==
                  'Akses ditolak: Hanya untuk petugas kepolisian',
        ),
      ),
    );
  });

  test('LoadInitialDataEvent loads reports, cctv and patrol units', () {
    // Authenticate first (set token dummy)
    dashboardBloc.emit(dashboardBloc.state.copyWith(token: 'dummy-token'));
    dashboardBloc.add(LoadInitialDataEvent());

    expect(
      dashboardBloc.stream,
      emitsThrough(
        predicate<DashboardState>(
          (state) =>
              state.reports.length == 1 &&
              state.cctvCameras.length == 1 &&
              state.patrolUnits.length == 1 &&
              state.gpsTrackLogs.containsKey('report-uuid-1'),
        ),
      ),
    );
  });

  test('SelectReportEvent updates selectedReport', () {
    final report = {'id': 'report-uuid-1', 'title': 'Begal'};
    dashboardBloc.add(SelectReportEvent(report));

    expect(
      dashboardBloc.stream,
      emitsInOrder([
        predicate<DashboardState>((state) => state.selectedReport == report),
      ]),
    );
  });

  test(
    'FetchSuspectAnalysisEvent updates state with AI predictedRoutes and reidPredictions (F-08)',
    () {
      dashboardBloc.add(
        FetchSuspectAnalysisEvent(
          startNode: 'simpang_dago',
          headingNode: 'dago_atas',
          suspectFeatures: 'helm_merah_jaket_hitam_honda_beat',
        ),
      );

      expect(
        dashboardBloc.stream,
        emitsThrough(
          predicate<DashboardState>(
            (state) =>
                state.predictedRoutes.isNotEmpty &&
                state.reidPredictions.isNotEmpty &&
                state.predictedRoutes[0]['path'][1] == 'dago_atas' &&
                state.reidPredictions[0]['reid_probability'] == 0.95,
          ),
        ),
      );
    },
  );

  test(
    'GpsUpdateReceivedEvent appends isBleRelay metadata to gpsTrackLogs (F-03)',
    () {
      // Populate cache with reportId
      dashboardBloc.emit(
        dashboardBloc.state.copyWith(gpsTrackLogs: {'report-uuid-1': []}),
      );

      dashboardBloc.add(
        GpsUpdateReceivedEvent({
          'reportId': 'report-uuid-1',
          'latitude': -6.90344,
          'longitude': 107.61872,
          'isBleRelay': true,
        }),
      );

      expect(
        dashboardBloc.stream,
        emitsThrough(
          predicate<DashboardState>(
            (state) =>
                state.gpsTrackLogs['report-uuid-1']!.isNotEmpty &&
                state.gpsTrackLogs['report-uuid-1']!.last['isBleRelay'] == 1.0,
          ),
        ),
      );
    },
  );

  test(
    'CctvFpsChangedReceivedEvent updates the specific camera\'s fps_mode (F-07)',
    () {
      // Populate cache with a mock CCTV camera in Low mode
      dashboardBloc.emit(
        dashboardBloc.state.copyWith(
          cctvCameras: [
            {'id': 'cctv-dago-11', 'name': 'CCTV Dago 01', 'fps_mode': 'LOW'},
          ],
        ),
      );

      // Dispatch event to escalate to HIGH
      dashboardBloc.add(
        CctvFpsChangedReceivedEvent({'id': 'cctv-dago-11', 'fps_mode': 'HIGH'}),
      );

      expect(
        dashboardBloc.stream,
        emitsThrough(
          predicate<DashboardState>((state) {
            final cam = state.cctvCameras.firstWhere(
              (c) => c['id'] == 'cctv-dago-11',
            );
            return cam['fps_mode'] == 'HIGH';
          }),
        ),
      );
    },
  );
}

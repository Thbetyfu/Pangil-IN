import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:mobile_app/bloc/sos_bloc.dart';
import 'package:mobile_app/bloc/sos_event.dart';
import 'package:mobile_app/bloc/sos_state.dart';
import 'package:mobile_app/services/api_service.dart';
import 'package:mobile_app/services/ble_service.dart';
import 'package:mobile_app/database/local_database.dart';

class MockApiServiceForBle extends ApiService {
  MockApiServiceForBle(LocalDatabase db) : super(database: db);

  String? lastRelayedBeaconId;
  double? lastRelayedLatitude;
  double? lastRelayedLongitude;

  final StreamController<UserAccelerometerEvent> accelerometerController =
      StreamController<UserAccelerometerEvent>.broadcast();

  @override
  Stream<UserAccelerometerEvent> getAccelerometerEvents() {
    return accelerometerController.stream;
  }

  @override
  Future<Map<String, dynamic>> triggerSos(
    double latitude,
    double longitude, {
    String? description,
    String? audioUrl,
  }) async {
    return {
      'status': 'success',
      'data': {
        'report': {'id': 'mock-sos-report-11111'},
      },
    };
  }

  @override
  Future<Map<String, dynamic>> sendBleRelay({
    required String beaconId,
    required double latitude,
    required double longitude,
  }) async {
    lastRelayedBeaconId = beaconId;
    lastRelayedLatitude = latitude;
    lastRelayedLongitude = longitude;
    return {'status': 'success'};
  }

  @override
  Future<Position> getCurrentPosition() async {
    return Position(
      latitude: -6.90344,
      longitude: 107.61872,
      timestamp: DateTime.now(),
      accuracy: 1.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDatabase database;
  late MockApiServiceForBle mockApiService;
  late BleService bleService;
  late SosBloc sosBloc;

  setUp(() {
    database = LocalDatabase();
    mockApiService = MockApiServiceForBle(database);
    bleService = BleService(apiService: mockApiService);
    sosBloc = SosBloc(apiService: mockApiService, bleService: bleService);
  });

  tearDown(() {
    sosBloc.close();
    bleService.stopAdvertising();
    bleService.stopScanning();
  });

  test('BleService startAdvertising sets active states and timers', () {
    bleService.startAdvertising('my-beacon-id');
    expect(bleService.isAdvertising, isTrue);

    bleService.stopAdvertising();
    expect(bleService.isAdvertising, isFalse);
  });

  test(
    'BleService simulateBeaconFound retrieves location and triggers sendBleRelay API',
    () async {
      await bleService.simulateBeaconFound('victim-beacon-xyz');
      expect(mockApiService.lastRelayedBeaconId, 'victim-beacon-xyz');
      expect(mockApiService.lastRelayedLatitude, -6.90344);
      expect(mockApiService.lastRelayedLongitude, 107.61872);
    },
  );

  test(
    'SosBloc triggers BLE advertising when ConfirmSosEvent succeeds',
    () async {
      // Dispatch events to trigger SOS activation
      sosBloc.add(
        TriggerSosConfirmationEvent(latitude: -6.90344, longitude: 107.61872),
      );
      sosBloc.add(ConfirmSosEvent());

      // Expecting transition to active
      await expectLater(
        sosBloc.stream,
        emitsThrough(
          predicate<SosState>(
            (state) =>
                state.status == SosStatus.active &&
                state.reportId == 'mock-sos-report-11111',
          ),
        ),
      );

      // Verify BLE advertiser is started
      expect(bleService.isAdvertising, isTrue);

      // Cancel SOS
      sosBloc.add(CancelSosEvent());

      // Expecting transition back to idle or cancelled
      await expectLater(
        sosBloc.stream,
        emitsThrough(
          predicate<SosState>((state) => state.status == SosStatus.cancelled),
        ),
      );

      // Verify BLE advertising stops
      expect(bleService.isAdvertising, isFalse);
    },
  );
}

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:mobile_app/bloc/sos_bloc.dart';
import 'package:mobile_app/bloc/sos_event.dart';
import 'package:mobile_app/bloc/sos_state.dart';
import 'package:mobile_app/services/api_service.dart';
import 'package:mobile_app/database/local_database.dart';

// Mock ApiService to avoid making real network connections in unit tests
class MockApiService extends ApiService {
  MockApiService(LocalDatabase db) : super(database: db);

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
        'report': {
          'id': 'mock-report-id-12345',
        }
      }
    };
  }

  @override
  void initSocket() {}

  @override
  void sendLocationUpdate(double latitude, double longitude) {}

  @override
  Stream<Position> getPositionStream() {
    return Stream<Position>.fromIterable([
      Position(
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
      )
    ]);
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

  final StreamController<UserAccelerometerEvent> accelerometerController = StreamController<UserAccelerometerEvent>.broadcast();

  @override
  Stream<UserAccelerometerEvent> getAccelerometerEvents() {
    return accelerometerController.stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDatabase database;
  late MockApiService mockApiService;
  late SosBloc sosBloc;

  setUp(() {
    database = LocalDatabase();
    mockApiService = MockApiService(database);
    sosBloc = SosBloc(apiService: mockApiService);
  });

  tearDown(() async {
    await sosBloc.close();
    await database.close();
    await mockApiService.accelerometerController.close();
  });

  test('Initial state is idle with riding mode disabled', () {
    expect(sosBloc.state.status, SosStatus.idle);
    expect(sosBloc.state.ridingMode, isFalse);
    expect(sosBloc.state.countdown, equals(60));
  });

  test('ToggleRidingModeEvent updates state ridingMode', () {
    sosBloc.add(ToggleRidingModeEvent(enable: true));
    expect(
      sosBloc.stream,
      emitsInOrder([
        predicate<SosState>((state) => state.ridingMode == true),
      ]),
    );
  });

  test('TriggerSosConfirmationEvent transitions to confirming status', () {
    sosBloc.add(TriggerSosConfirmationEvent(latitude: -6.9, longitude: 107.6));
    
    expect(
      sosBloc.stream,
      emitsThrough(
        predicate<SosState>((state) =>
            state.status == SosStatus.confirming &&
            state.latitude == -6.9 &&
            state.longitude == 107.6 &&
            state.countdown == 60),
      ),
    );
  });

  test('ConfirmSosEvent updates state to active and sets reportId', () {
    sosBloc.add(TriggerSosConfirmationEvent(latitude: -6.9, longitude: 107.6));
    sosBloc.add(ConfirmSosEvent(description: 'Test manual SOS'));

    expect(
      sosBloc.stream,
      emitsThrough(
        predicate<SosState>((state) =>
            state.status == SosStatus.active &&
            state.reportId == 'mock-report-id-12345'),
      ),
    );
  });

  test('CancelSosEvent resets state to idle', () {
    sosBloc.add(TriggerSosConfirmationEvent(latitude: -6.9, longitude: 107.6));
    sosBloc.add(CancelSosEvent());

    expect(
      sosBloc.stream,
      emitsThrough(
        predicate<SosState>((state) =>
            state.status == SosStatus.idle &&
            state.latitude == null &&
            state.longitude == null),
      ),
    );
  });

  test('TriggerSosConfirmationEvent is blocked when ridingMode is true', () async {
    sosBloc.add(ToggleRidingModeEvent(enable: true));
    
    // Allow queue to process ToggleRidingModeEvent first
    await pumpEventQueue();
    
    sosBloc.add(TriggerSosConfirmationEvent(latitude: -6.9, longitude: 107.6));
    
    // State should not transition to confirming
    expect(sosBloc.state.status, SosStatus.idle);
  });

  test('ToggleFakeShutdownEvent enables fakeShutdown and triggers SOS in background', () async {
    sosBloc.add(ToggleFakeShutdownEvent(enable: true));
    
    expect(
      sosBloc.stream,
      emitsThrough(
        predicate<SosState>((state) =>
            state.fakeShutdown == true &&
            state.status == SosStatus.active &&
            state.reportId == 'mock-report-id-12345'),
      ),
    );
  });

  test('Countdown SOS auto-cancels after 60 seconds (F-01 Rule 5)', () {
    fakeAsync((async) {
      final testBloc = SosBloc(apiService: mockApiService);
      testBloc.add(TriggerSosConfirmationEvent(latitude: -6.90344, longitude: 107.61872));
      
      // Allow event loop to process TriggerSosConfirmationEvent
      async.flushMicrotasks();
      
      expect(testBloc.state.status, SosStatus.confirming);
      expect(testBloc.state.countdown, equals(60));

      // Elapse 65 seconds step-by-step to allow loop iterations to run cleanly
      for (int s = 0; s < 65; s++) {
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
      }

      expect(testBloc.state.status, SosStatus.idle);
      expect(testBloc.state.fakeShutdown, isFalse);
      testBloc.close();
    });
  });

  test('High-G shock trigger via accelerometer opens SOS overlay in background (F-02)', () async {
    // Publish a mock high acceleration event (40.0 m/s2, which exceeds 30.0 threshold)
    mockApiService.accelerometerController.add(UserAccelerometerEvent(0.0, 40.0, 0.0, DateTime.now()));

    // Allow event stream to be processed by SosBloc
    await pumpEventQueue();

    expect(sosBloc.state.status, SosStatus.confirming);
    expect(sosBloc.state.latitude, equals(-6.90344));
    expect(sosBloc.state.longitude, equals(107.61872));
  });

  test('High-G shock trigger is ignored when ridingMode is active (F-01 Rule 3)', () async {
    sosBloc.add(ToggleRidingModeEvent(enable: true));
    await pumpEventQueue();

    // Publish a mock high acceleration event
    mockApiService.accelerometerController.add(UserAccelerometerEvent(0.0, 40.0, 0.0, DateTime.now()));
    await pumpEventQueue();

    // Verify it is blocked and status remains idle
    expect(sosBloc.state.status, SosStatus.idle);
  });

  test('Stealth voice command triggers SOS immediately bypassing countdown', () async {
    // Simulate speaking the trigger phrase
    mockApiService.simulateSpeechInput('Aduh, Bandung dingin banget ya malam ini');

    // Wait for async stream & event loop to complete
    await pumpEventQueue();

    // Expect status to immediately become active (bypassing confirming status)
    expect(sosBloc.state.status, SosStatus.active);
    expect(sosBloc.state.reportId, equals('mock-report-id-12345'));
  });

  test('Non-trigger voice phrase is ignored', () async {
    // Simulate speaking a normal phrase
    mockApiService.simulateSpeechInput('Bandung malam ini cukup sejuk ya');

    await pumpEventQueue();

    // Verify status remains idle
    expect(sosBloc.state.status, SosStatus.idle);
  });
}

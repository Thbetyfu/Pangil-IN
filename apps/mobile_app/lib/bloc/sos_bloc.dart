import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../services/api_service.dart';
import '../services/ble_service.dart';
import 'sos_event.dart';
import 'sos_state.dart';

class SosBloc extends Bloc<SosEvent, SosState> {
  final ApiService apiService;
  final BleService? bleService;
  StreamSubscription<Position>? _gpsSubscription;
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;

  SosBloc({required this.apiService, this.bleService}) : super(SosState()) {
    // Listen to user accelerometer events for High-G shock detection (PRD F-02)
    _accelerometerSubscription = apiService.getAccelerometerEvents().listen((UserAccelerometerEvent event) async {
      // Calculate magnitude of linear acceleration (excluding gravity)
      final double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      // If magnitude exceeds threshold (30.0 m/s2 / ~3G) and app is idle
      if (magnitude > 30.0 && state.status == SosStatus.idle && !state.ridingMode) {
        print('High-G shock detected: $magnitude m/s²');
        try {
          final position = await apiService.getCurrentPosition();
          add(TriggerSosConfirmationEvent(
            latitude: position.latitude,
            longitude: position.longitude,
          ));
        } catch (e) {
          // Fallback coordinate if GPS fails (Bandung Simpang Dago default coordinates)
          add(TriggerSosConfirmationEvent(
            latitude: -6.90344,
            longitude: 107.61872,
          ));
        }
      }
    });

    on<ToggleRidingModeEvent>((event, emit) {
      emit(state.copyWith(ridingMode: event.enable));
    });

    on<TriggerSosConfirmationEvent>((event, emit) async {
      // ridingMode blocks High-G sensor triggers to prevent false alarms (PRD F-01 Rule 3)
      if (state.ridingMode) {
        print('Riding Mode active: SOS High-G trigger blocked.');
        return;
      }
      
      emit(state.copyWith(
        status: SosStatus.confirming,
        latitude: event.latitude,
        longitude: event.longitude,
        countdown: 60,
      ));

      // 60 seconds countdown loop
      for (int i = 59; i >= 0; i--) {
        await Future.delayed(const Duration(seconds: 1));
        
        // If state changed to cancelled or active in the meantime, stop loop
        if (state.status != SosStatus.confirming) {
          return;
        }
        
        emit(state.copyWith(countdown: i));
        
        if (i == 0) {
          add(CancelSosEvent());
        }
      }
    });

    on<ConfirmSosEvent>((event, emit) async {
      emit(state.copyWith(status: SosStatus.sending));
      try {
        final res = await apiService.triggerSos(
          state.latitude ?? 0.0,
          state.longitude ?? 0.0,
          description: event.description,
          audioUrl: event.audioUrl,
        );
        
        if (res['status'] == 'success') {
          final reportId = res['data']['report']['id'];
          emit(state.copyWith(
            status: SosStatus.active,
            reportId: reportId,
          ));
          
          // Connect to real-time communication channel
          apiService.initSocket();
          apiService.sendLocationUpdate(state.latitude ?? 0.0, state.longitude ?? 0.0);

          // Start BLE advertising (PRD F-03)
          bleService?.startAdvertising(reportId);

          // Start streaming real-time location to backend (PRD F-03 Background tracking)
          _gpsSubscription?.cancel();
          try {
            _gpsSubscription = apiService.getPositionStream().listen(
              (position) {
                add(UpdateSosLocationEvent(latitude: position.latitude, longitude: position.longitude));
              },
              onError: (error) {
                print('[GPS Stream] Error: $error');
              },
            );
          } catch (e) {
            print('[GPS Stream] Failed to listen: $e');
          }
        } else {
          emit(state.copyWith(
            status: SosStatus.error,
            errorMessage: res['message'] ?? 'Gagal mengirim sinyal darurat',
          ));
        }
      } catch (e) {
        // Fallback for offline SOS trigger: enter active state and start BLE advertising (PRD F-03)
        final offlineReportId = 'offline-${Random().nextInt(1000000)}';
        emit(state.copyWith(
          status: SosStatus.active,
          reportId: offlineReportId,
        ));
        
        bleService?.startAdvertising(offlineReportId);

        // Start local GPS streaming to update location even if offline
        _gpsSubscription?.cancel();
        try {
          _gpsSubscription = apiService.getPositionStream().listen(
            (position) {
              add(UpdateSosLocationEvent(latitude: position.latitude, longitude: position.longitude));
            },
            onError: (error) {
              print('[GPS Stream] Error: $error');
            },
          );
        } catch (e) {
          print('[GPS Stream] Failed to listen: $e');
        }
      }
    });

    on<CancelSosEvent>((event, emit) {
      _gpsSubscription?.cancel();
      _gpsSubscription = null;
      bleService?.stopAdvertising();
      emit(state.copyWith(status: SosStatus.cancelled, fakeShutdown: false));
      // Reset back to idle while keeping riding mode state
      emit(SosState(ridingMode: state.ridingMode));
    });

    on<UpdateSosLocationEvent>((event, emit) {
      if (state.status == SosStatus.active) {
        emit(state.copyWith(
          latitude: event.latitude,
          longitude: event.longitude,
        ));
        apiService.sendLocationUpdate(event.latitude, event.longitude);
      }
    });

    on<ToggleFakeShutdownEvent>((event, emit) {
      emit(state.copyWith(fakeShutdown: event.enable));
      
      // If fake shutdown is enabled and SOS is not active, auto-trigger in background
      if (event.enable && state.status != SosStatus.active) {
        add(TriggerSosConfirmationEvent(
          latitude: state.latitude ?? -6.90344, // Bandung Simpang Dago default coordinates
          longitude: state.longitude ?? 107.61872,
        ));
        add(ConfirmSosEvent(description: 'Pemicuan via Fake Shutdown (Stealth)'));
      }
    });
  }

  @override
  Future<void> close() {
    _gpsSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    return super.close();
  }
}

import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../services/api_service.dart';
import '../services/ble_service.dart';
import '../utils/notification_helper.dart';
import 'sos_event.dart';
import 'sos_state.dart';

class SosBloc extends Bloc<SosEvent, SosState> {
  final ApiService apiService;
  final BleService? bleService;
  StreamSubscription<Position>? _gpsSubscription;
  StreamSubscription<Position>? _gpsSpeedSubscription;
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<String>? _speechSubscription;

  SosBloc({required this.apiService, this.bleService}) : super(SosState()) {
    // Listen to position stream for automatic riding mode speed detection (PRD F-01 Rule 3)
    // We use a threshold of 4.167 m/s (~15 km/h) to distinguish active vehicle transit from walking.
    // Toggling ridingMode dynamically is required to prevent accidental High-G shock triggers
    // caused by sudden braking or road potholes, thus eliminating false positive SOS dispatches to command center.
    _gpsSpeedSubscription = apiService.getPositionStream().listen((position) {
      if (position.speed > 4.167 && !state.ridingMode) {
        print('GPS Speed detected: ${position.speed} m/s (> 15 km/h). Auto-enabling Riding Mode.');
        add(ToggleRidingModeEvent(enable: true));
      } else if (position.speed <= 4.167 && state.ridingMode) {
        print('GPS Speed detected: ${position.speed} m/s (<= 15 km/h). Auto-disabling Riding Mode.');
        add(ToggleRidingModeEvent(enable: false));
      }
    }, onError: (error) {
      print('[GPS Speed Stream] Error: $error');
    });

    // Listen to background speech for stealth trigger phrase (PRD Trauma-Responsive Accessibility)
    _speechSubscription = apiService.getSpeechEvents().listen((phrase) {
      final normalized = phrase.toLowerCase().trim();
      if (normalized.contains('aduh, bandung dingin banget ya malam ini') ||
          normalized.contains('aduh bandung dingin banget ya malam ini')) {
        add(TriggerStealthSosEvent(phrase: phrase));
      }
    });

    // Listen to user accelerometer events for High-G shock detection (PRD F-02)
    _accelerometerSubscription = apiService.getAccelerometerEvents().listen((
      UserAccelerometerEvent event,
    ) async {
      // Calculate magnitude of linear acceleration (excluding gravity)
      final double magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      // Goyangan HP (Shake) untuk mematikan Fake Shutdown jika metode 'shake' aktif
      if (magnitude > 15.0 &&
          state.fakeShutdown &&
          state.fakeShutdownMethod == 'shake') {
        print('Shake detected: $magnitude m/s². Exiting Fake Shutdown.');
        add(ToggleFakeShutdownEvent(enable: false));
        return;
      }

      // If magnitude exceeds threshold (30.0 m/s2 / ~3G) and app is idle
      if (magnitude > 30.0 &&
          state.status == SosStatus.idle &&
          !state.ridingMode) {
        print('High-G shock detected: $magnitude m/s²');
        try {
          final position = await apiService.getCurrentPosition();
          add(
            TriggerSosConfirmationEvent(
              latitude: position.latitude,
              longitude: position.longitude,
            ),
          );
        } catch (e) {
          // Fallback coordinate if GPS fails (Bandung Simpang Dago default coordinates)
          add(
            TriggerSosConfirmationEvent(
              latitude: -6.90344,
              longitude: 107.61872,
            ),
          );
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

      triggerSystemNotification(
        'Panggil-In: Pemicuan SOS Terdeteksi',
        'Apakah Anda dalam bahaya? Buka aplikasi untuk konfirmasi atau batalkan.',
      );

      emit(
        state.copyWith(
          status: SosStatus.confirming,
          latitude: event.latitude,
          longitude: event.longitude,
          countdown: 60,
        ),
      );

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
          triggerSystemNotification(
            'Panggil-In: SOS Aktif!',
            'Sinyal darurat dikirim ke polisi. Melacak koordinat Anda.',
          );
          emit(state.copyWith(status: SosStatus.active, reportId: reportId));

          // Connect to real-time communication channel
          apiService.initSocket();
          apiService.sendLocationUpdate(
            state.latitude ?? 0.0,
            state.longitude ?? 0.0,
          );

          // Start BLE advertising (PRD F-03)
          bleService?.startAdvertising(reportId);

          // Start streaming real-time location to backend (PRD F-03 Background tracking)
          _gpsSubscription?.cancel();
          try {
            _gpsSubscription = apiService.getPositionStream().listen(
              (position) {
                add(
                  UpdateSosLocationEvent(
                    latitude: position.latitude,
                    longitude: position.longitude,
                  ),
                );
              },
              onError: (error) {
                print('[GPS Stream] Error: $error');
              },
            );
          } catch (e) {
            print('[GPS Stream] Failed to listen: $e');
          }
        } else {
          emit(
            state.copyWith(
              status: SosStatus.error,
              errorMessage: res['message'] ?? 'Gagal mengirim sinyal darurat',
            ),
          );
        }
      } catch (e) {
        // Fallback for offline SOS trigger: enter active state and start BLE advertising (PRD F-03)
        final offlineReportId = 'offline-${Random().nextInt(1000000)}';
        triggerSystemNotification(
          'Panggil-In: SOS Aktif (Mode Offline)',
          'Mengirim suar darurat via BLE Mesh.',
        );
        emit(
          state.copyWith(status: SosStatus.active, reportId: offlineReportId),
        );

        bleService?.startAdvertising(offlineReportId);

        // Start local GPS streaming to update location even if offline
        _gpsSubscription?.cancel();
        try {
          _gpsSubscription = apiService.getPositionStream().listen(
            (position) {
              add(
                UpdateSosLocationEvent(
                  latitude: position.latitude,
                  longitude: position.longitude,
                ),
              );
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
      triggerSystemNotification(
        'Panggil-In: SOS Dibatalkan',
        'Sinyal darurat Anda telah dinonaktifkan.',
      );
      _gpsSubscription?.cancel();
      _gpsSubscription = null;
      bleService?.stopAdvertising();
      emit(state.copyWith(status: SosStatus.cancelled, fakeShutdown: false));
      // Reset back to idle while keeping riding mode state
      emit(SosState(ridingMode: state.ridingMode));
    });

    on<UpdateSosLocationEvent>((event, emit) {
      if (state.status == SosStatus.active) {
        emit(
          state.copyWith(latitude: event.latitude, longitude: event.longitude),
        );
        apiService.sendLocationUpdate(event.latitude, event.longitude);
      }
    });

    on<ToggleFakeShutdownEvent>((event, emit) {
      emit(state.copyWith(fakeShutdown: event.enable));

      // If fake shutdown is enabled and SOS is not active, auto-trigger in background
      if (event.enable && state.status != SosStatus.active) {
        add(
          TriggerSosConfirmationEvent(
            latitude:
                state.latitude ??
                -6.90344, // Bandung Simpang Dago default coordinates
            longitude: state.longitude ?? 107.61872,
          ),
        );
        add(
          ConfirmSosEvent(description: 'Pemicuan via Fake Shutdown (Stealth)'),
        );
      } else if (!event.enable) {
        // If fake shutdown is disabled, cancel the active SOS to return back to idle
        add(CancelSosEvent());
      }
    });

    on<ChangeFakeShutdownMethodEvent>((event, emit) {
      emit(state.copyWith(fakeShutdownMethod: event.method));
    });

    on<TriggerStealthSosEvent>((event, emit) async {
      // Stealth bypasses standard countdown overlay and triggers SOS instantly
      if (state.status == SosStatus.idle ||
          state.status == SosStatus.confirming) {
        emit(state.copyWith(status: SosStatus.sending));

        double latitude = -6.90344;
        double longitude = 107.61872;
        try {
          final position = await apiService.getCurrentPosition();
          latitude = position.latitude;
          longitude = position.longitude;
        } catch (e) {
          print(
            '[Stealth SOS] GPS coordinates acquisition failed, using defaults: $e',
          );
        }

        emit(state.copyWith(latitude: latitude, longitude: longitude));

        try {
          final res = await apiService.triggerSos(
            latitude,
            longitude,
            description: event.phrase != null
                ? 'Pemicuan Suara Stealth: "${event.phrase}"'
                : 'Pemicuan Suara Stealth',
          );

          if (res['status'] == 'success') {
            final reportId = res['data']['report']['id'];
            emit(state.copyWith(status: SosStatus.active, reportId: reportId));

            apiService.initSocket();
            apiService.sendLocationUpdate(latitude, longitude);
            bleService?.startAdvertising(reportId);

            _gpsSubscription?.cancel();
            try {
              _gpsSubscription = apiService.getPositionStream().listen(
                (position) {
                  add(
                    UpdateSosLocationEvent(
                      latitude: position.latitude,
                      longitude: position.longitude,
                    ),
                  );
                },
                onError: (error) {
                  print('[GPS Stream] Error: $error');
                },
              );
            } catch (e) {
              print('[GPS Stream] Failed to listen: $e');
            }
          } else {
            emit(
              state.copyWith(
                status: SosStatus.error,
                errorMessage: res['message'] ?? 'Gagal mengirim sinyal darurat',
              ),
            );
          }
        } catch (e) {
          emit(
            state.copyWith(status: SosStatus.error, errorMessage: e.toString()),
          );
        }
      }
    });
  }

  @override
  Future<void> close() {
    _gpsSubscription?.cancel();
    _gpsSpeedSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _speechSubscription?.cancel();
    return super.close();
  }
}

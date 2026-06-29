import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/api_service.dart';
import 'sos_event.dart';
import 'sos_state.dart';

class SosBloc extends Bloc<SosEvent, SosState> {
  final ApiService apiService;

  SosBloc({required this.apiService}) : super(SosState()) {
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
          add(ConfirmSosEvent(description: 'Pemicuan SOS Otomatis (Zero-Click)'));
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
        } else {
          emit(state.copyWith(
            status: SosStatus.error,
            errorMessage: res['message'] ?? 'Gagal mengirim sinyal darurat',
          ));
        }
      } catch (e) {
        emit(state.copyWith(
          status: SosStatus.error,
          errorMessage: e.toString(),
        ));
      }
    });

    on<CancelSosEvent>((event, emit) {
      emit(state.copyWith(status: SosStatus.cancelled));
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
  }
}

abstract class SosEvent {}

class TriggerSosConfirmationEvent extends SosEvent {
  final double latitude;
  final double longitude;
  TriggerSosConfirmationEvent({
    required this.latitude,
    required this.longitude,
  });
}

class ConfirmSosEvent extends SosEvent {
  final String? audioUrl;
  final String? description;
  ConfirmSosEvent({this.audioUrl, this.description});
}

class CancelSosEvent extends SosEvent {}

class UpdateSosLocationEvent extends SosEvent {
  final double latitude;
  final double longitude;
  UpdateSosLocationEvent({required this.latitude, required this.longitude});
}

class ToggleRidingModeEvent extends SosEvent {
  final bool enable;
  ToggleRidingModeEvent({required this.enable});
}

class ToggleFakeShutdownEvent extends SosEvent {
  final bool enable;
  ToggleFakeShutdownEvent({required this.enable});
}

class TriggerStealthSosEvent extends SosEvent {
  final String? phrase;
  TriggerStealthSosEvent({this.phrase});
}

class ChangeFakeShutdownMethodEvent extends SosEvent {
  final String method;
  ChangeFakeShutdownMethodEvent({required this.method});
}

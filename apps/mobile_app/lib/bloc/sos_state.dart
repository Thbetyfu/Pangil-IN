enum SosStatus { idle, confirming, sending, active, cancelled, error }

class SosState {
  final SosStatus status;
  final bool ridingMode;
  final double? latitude;
  final double? longitude;
  final int countdown;
  final String? reportId;
  final String? errorMessage;
  final bool fakeShutdown;

  SosState({
    this.status = SosStatus.idle,
    this.ridingMode = false,
    this.latitude,
    this.longitude,
    this.countdown = 60,
    this.reportId,
    this.errorMessage,
    this.fakeShutdown = false,
  });

  SosState copyWith({
    SosStatus? status,
    bool? ridingMode,
    double? latitude,
    double? longitude,
    int? countdown,
    String? reportId,
    String? errorMessage,
    bool? fakeShutdown,
  }) {
    return SosState(
      status: status ?? this.status,
      ridingMode: ridingMode ?? this.ridingMode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      countdown: countdown ?? this.countdown,
      reportId: reportId ?? this.reportId,
      errorMessage: errorMessage ?? this.errorMessage,
      fakeShutdown: fakeShutdown ?? this.fakeShutdown,
    );
  }
}

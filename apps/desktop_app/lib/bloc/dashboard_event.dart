abstract class DashboardEvent {}

class LoginEvent extends DashboardEvent {
  final String email;
  final String password;
  final String otpCode;
  LoginEvent({
    required this.email,
    required this.password,
    required this.otpCode,
  });
}

class LogoutEvent extends DashboardEvent {}

class ChangeTabEvent extends DashboardEvent {
  final int index;
  ChangeTabEvent(this.index);
}

class LoadInitialDataEvent extends DashboardEvent {}

class SelectReportEvent extends DashboardEvent {
  final Map<String, dynamic>? report;
  SelectReportEvent(this.report);
}

class AssignPatrolUnitEvent extends DashboardEvent {
  final String reportId;
  final String patrolUnitId;
  AssignPatrolUnitEvent({required this.reportId, required this.patrolUnitId});
}

// WebSocket / real-time updates events
class NewReportReceivedEvent extends DashboardEvent {
  final Map<String, dynamic> report;
  NewReportReceivedEvent(this.report);
}

class GpsUpdateReceivedEvent extends DashboardEvent {
  final Map<String, dynamic> data;
  GpsUpdateReceivedEvent(this.data);
}

class CctvAlertReceivedEvent extends DashboardEvent {
  final Map<String, dynamic> alert;
  CctvAlertReceivedEvent(this.alert);
}

class TriggerMockSosEvent extends DashboardEvent {
  final String cctvId;
  final String suspectFeatures;
  TriggerMockSosEvent({required this.cctvId, required this.suspectFeatures});
}

class UpdateCctvFpsEvent extends DashboardEvent {
  final String cctvId;
  final String fpsMode;
  UpdateCctvFpsEvent({required this.cctvId, required this.fpsMode});
}

class FetchSuspectAnalysisEvent extends DashboardEvent {
  final String startNode;
  final String headingNode;
  final String suspectFeatures;
  FetchSuspectAnalysisEvent({
    required this.startNode,
    required this.headingNode,
    required this.suspectFeatures,
  });
}

class CctvFpsChangedReceivedEvent extends DashboardEvent {
  final Map<String, dynamic> data;
  CctvFpsChangedReceivedEvent(this.data);
}

class DeleteReportEvent extends DashboardEvent {
  final String reportId;
  DeleteReportEvent(this.reportId);
}

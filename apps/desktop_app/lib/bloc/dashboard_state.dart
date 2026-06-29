class DashboardState {
  final bool isAuthenticated;
  final bool isAuthenticating;
  final String? authError;
  final String? token;
  final String? userName;
  final String? userRole;
  final int currentTab;
  final List<dynamic> reports;
  final Map<String, dynamic>? selectedReport;
  final List<dynamic> patrolUnits;
  final List<dynamic> cctvAlerts;
  final List<dynamic> cctvCameras;
  final Map<String, List<Map<String, double>>> gpsTrackLogs;
  final bool isLoading;
  final String? error;

  DashboardState({
    this.isAuthenticated = false,
    this.isAuthenticating = false,
    this.authError,
    this.token,
    this.userName,
    this.userRole,
    this.currentTab = 0,
    this.reports = const [],
    this.selectedReport,
    this.patrolUnits = const [],
    this.cctvAlerts = const [],
    this.cctvCameras = const [],
    this.gpsTrackLogs = const {},
    this.isLoading = false,
    this.error,
  });

  DashboardState copyWith({
    bool? isAuthenticated,
    bool? isAuthenticating,
    String? authError,
    String? token,
    String? userName,
    String? userRole,
    int? currentTab,
    List<dynamic>? reports,
    Map<String, dynamic>? selectedReport,
    List<dynamic>? patrolUnits,
    List<dynamic>? cctvAlerts,
    List<dynamic>? cctvCameras,
    Map<String, List<Map<String, double>>>? gpsTrackLogs,
    bool? isLoading,
    String? error,
  }) {
    return DashboardState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      authError: authError ?? this.authError,
      token: token ?? this.token,
      userName: userName ?? this.userName,
      userRole: userRole ?? this.userRole,
      currentTab: currentTab ?? this.currentTab,
      reports: reports ?? this.reports,
      selectedReport: selectedReport ?? this.selectedReport,
      patrolUnits: patrolUnits ?? this.patrolUnits,
      cctvAlerts: cctvAlerts ?? this.cctvAlerts,
      cctvCameras: cctvCameras ?? this.cctvCameras,
      gpsTrackLogs: gpsTrackLogs ?? this.gpsTrackLogs,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

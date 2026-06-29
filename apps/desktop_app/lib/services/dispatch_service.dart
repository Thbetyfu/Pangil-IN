import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

class DispatchService {
  static const String baseUrl = 'http://localhost:3001';
  io.Socket? _socket;
  String? _token;
  String? _userId;

  String? get token => _token;

  // Event Callbacks
  Function(Map<String, dynamic>)? onNewReport;
  Function(Map<String, dynamic>)? onGpsUpdate;
  Function(Map<String, dynamic>)? onCctvAlert;

  // Auth: Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      _token = data['data']['token'];
      _userId = data['data']['user']['id'];
    }
    return data;
  }

  // Get Active Reports List
  Future<List<dynamic>> getActiveReports() async {
    if (_token == null) throw Exception('Not authenticated');
    final response = await http.get(
      Uri.parse('$baseUrl/api/reports'),
      headers: {
        'Authorization': 'Bearer $_token',
      },
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return data['data']['reports'];
    }
    return [];
  }

  // Get CCTV Alert logs
  Future<List<dynamic>> getCctvAlerts(String cameraId) async {
    if (_token == null) throw Exception('Not authenticated');
    final response = await http.get(
      Uri.parse('$baseUrl/api/cctv/$cameraId/alerts'),
      headers: {
        'Authorization': 'Bearer $_token',
      },
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return data['data']['alerts'];
    }
    return [];
  }

  // Get AI Escape Prediction (F-08 GNN Escape routes)
  Future<List<dynamic>> getEscapePrediction(String startNode, String headingNode) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:3002/ai/escape-prediction'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'start_node': startNode,
          'heading_node': headingNode,
          'max_minutes': 10.0,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['predicted_routes'] ?? [];
      }
    } catch (e) {
      print('Failed to fetch escape prediction from AI Server: $e');
    }
    return [];
  }

  // Get AI GNN Re-ID Tracking
  Future<List<dynamic>> getReidTracking(String startNode, String suspectFeatures) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:3002/ai/reid-tracking'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'start_node': startNode,
          'suspect_features': suspectFeatures,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reid_predictions'] ?? [];
      }
    } catch (e) {
      print('Failed to fetch Re-ID GNN tracking from AI Server: $e');
    }
    return [];
  }

  // Get CCTV Cameras List
  Future<List<dynamic>> getCctvCameras() async {
    if (_token == null) throw Exception('Not authenticated');
    final response = await http.get(
      Uri.parse('$baseUrl/api/cctv'),
      headers: {
        'Authorization': 'Bearer $_token',
      },
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return data['data']['cameras'];
    }
    return [];
  }

  // Get Patrol Units List
  Future<List<dynamic>> getPatrolUnits() async {
    if (_token == null) throw Exception('Not authenticated');
    final response = await http.get(
      Uri.parse('$baseUrl/api/patrol'),
      headers: {
        'Authorization': 'Bearer $_token',
      },
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return data['data']['units'];
    }
    return [];
  }

  // Update CCTV FPS Mode
  Future<Map<String, dynamic>> updateCctvFps(String cameraId, String fpsMode) async {
    if (_token == null) throw Exception('Not authenticated');
    final response = await http.patch(
      Uri.parse('$baseUrl/api/cctv/$cameraId/fps'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({
        'fps_mode': fpsMode,
      }),
    );
    return jsonDecode(response.body);
  }

  // Dispatch / Assign Patrol Unit to Report
  Future<Map<String, dynamic>> assignPatrolUnit(String reportId, String patrolUnitId) async {
    if (_token == null) throw Exception('Not authenticated');
    final response = await http.patch(
      Uri.parse('$baseUrl/api/reports/$reportId/assign'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({
        'assigned_unit_id': patrolUnitId,
      }),
    );
    return jsonDecode(response.body);
  }

  // Real-time: Connect WebSocket to Police Dispatcher Room
  void connectWebSocket() {
    if (_token == null || _userId == null) return;

    _socket = io.io(baseUrl, io.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build());

    _socket!.connect();

    _socket!.onConnect((_) {
      print('Police dispatch client connected to Socket.io');
      // Register with role and user ID
      _socket!.emit('register', {
        'userId': _userId,
        'role': 'POLICE_OPERATOR',
      });
    });

    // Subscriptions
    _socket!.on('new_report', (data) {
      print('SOCKET: New SOS incident report received');
      if (onNewReport != null) onNewReport!(Map<String, dynamic>.from(data));
    });

    _socket!.on('gps_update', (data) {
      print('SOCKET: Telemetry GPS update for SOS report');
      if (onGpsUpdate != null) onGpsUpdate!(Map<String, dynamic>.from(data));
    });

    _socket!.on('cctv_alert', (data) {
      print('SOCKET: CCTV anomaly alert detected by AI server');
      if (onCctvAlert != null) onCctvAlert!(Map<String, dynamic>.from(data));
    });

    _socket!.onDisconnect((_) => print('Police dispatch client disconnected'));
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
  }
}

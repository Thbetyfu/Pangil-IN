import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

class BleService {
  final ApiService apiService;
  bool _isAdvertising = false;
  bool _isScanning = false;
  Timer? _scanTimer;
  Timer? _advertiseTimer;
  String? _activeBeaconId;

  BleService({required this.apiService});

  bool get isAdvertising => _isAdvertising;
  bool get isScanning => _isScanning;

  // Start Penyiaran UUID (mode korban)
  void startAdvertising(String beaconId) {
    if (_isAdvertising) return;
    _isAdvertising = true;
    _activeBeaconId = beaconId;
    print('BLE MESH: Started advertising beacon ID: $beaconId');

    // Simulate penyiaran berkala
    _advertiseTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isAdvertising) {
        timer.cancel();
        return;
      }
      print('BLE MESH: [ADVERTISING] Broadcast packet with payload: $beaconId');
    });
  }

  void stopAdvertising() {
    _isAdvertising = false;
    _advertiseTimer?.cancel();
    _activeBeaconId = null;
    print('BLE MESH: Stopped advertising');
  }

  // Start Pemindaian Latar Belakang (mode relayer warga)
  void startScanning() {
    if (_isScanning) return;
    _isScanning = true;
    print('BLE MESH: Started background scanning');

    // Simulate pemindaian berkala (setiap 10 detik mencari beacon)
    _scanTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!_isScanning) {
        timer.cancel();
        return;
      }

      print('BLE MESH: [SCANNING] Scanning for active emergency beacons...');
    });
  }

  void stopScanning() {
    _isScanning = false;
    _scanTimer?.cancel();
    print('BLE MESH: Stopped background scanning');
  }

  // Simulates finding a beacon (used in testing and simulation)
  Future<void> simulateBeaconFound(String beaconId) async {
    print('BLE MESH: [SCAN_MATCH] Found emergency beacon ID: $beaconId');
    try {
      // Get current GPS position of relayer using apiService abstraction (PRD F-03)
      final Position position = await apiService.getCurrentPosition();

      print('BLE MESH: [RELAY] Forwarding beacon $beaconId position (${position.latitude}, ${position.longitude}) to server...');
      await apiService.sendBleRelay(
        beaconId: beaconId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      print('BLE MESH: Failed to relay beacon location: $e');
    }
  }
}

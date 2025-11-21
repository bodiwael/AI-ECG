import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

enum BleConnectionState { disconnected, scanning, connecting, connected }

class BluetoothProvider extends ChangeNotifier {
  // BLE UUIDs (must match ESP32 firmware)
  static const String serviceUUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String ecgCharUUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const String paramsCharUUID = "beb5483e-36e1-4688-b7f5-ea07361b26a9";
  static const String alertCharUUID = "beb5483e-36e1-4688-b7f5-ea07361b26aa";

  BleConnectionState _connectionState = BleConnectionState.disconnected;
  BluetoothDevice? _connectedDevice;
  List<ScanResult> _scanResults = [];
  String _statusMessage = "Ready to connect";

  // ECG Data
  int _ecgValue = 0;
  int _avgBPM = 0;
  int _currentBPM = 0;
  double _hrv = 0;
  int _stLevel = 0;
  int _riskScore = 0;
  String _riskLevel = "UNKNOWN";
  bool _leadsOff = true;
  String _alertMessage = "";

  // Data streams
  StreamSubscription<List<int>>? _ecgSubscription;
  StreamSubscription<List<int>>? _paramsSubscription;
  StreamSubscription<List<int>>? _alertSubscription;

  // Getters
  BleConnectionState get connectionState => _connectionState;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<ScanResult> get scanResults => _scanResults;
  String get statusMessage => _statusMessage;
  int get ecgValue => _ecgValue;
  int get avgBPM => _avgBPM;
  int get currentBPM => _currentBPM;
  double get hrv => _hrv;
  int get stLevel => _stLevel;
  int get riskScore => _riskScore;
  String get riskLevel => _riskLevel;
  bool get leadsOff => _leadsOff;
  String get alertMessage => _alertMessage;
  bool get isConnected => _connectionState == BleConnectionState.connected;

  // ECG value stream for chart
  final StreamController<int> _ecgStreamController =
      StreamController<int>.broadcast();
  Stream<int> get ecgStream => _ecgStreamController.stream;

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((status) =>
        status == PermissionStatus.granted ||
        status == PermissionStatus.limited);
  }

  Future<void> startScan() async {
    if (_connectionState == BleConnectionState.scanning) return;

    bool permissionsGranted = await requestPermissions();
    if (!permissionsGranted) {
      _statusMessage = "Bluetooth permissions required";
      notifyListeners();
      return;
    }

    // Check if Bluetooth is on
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      _statusMessage = "Please turn on Bluetooth";
      notifyListeners();
      return;
    }

    _connectionState = BleConnectionState.scanning;
    _statusMessage = "Scanning for devices...";
    _scanResults = [];
    notifyListeners();

    // Listen to scan results
    FlutterBluePlus.scanResults.listen((results) {
      // Show ALL devices with names (for debugging, user can identify their device)
      _scanResults = results
          .where((r) => r.device.platformName.isNotEmpty)
          .toList();

      // Debug: print found devices
      for (var result in _scanResults) {
        debugPrint("Found device: ${result.device.platformName} - ${result.device.remoteId}");
      }

      notifyListeners();
    });

    // Start scanning
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 15),
      androidScanMode: AndroidScanMode.lowLatency,
    );

    // After scan completes
    await Future.delayed(const Duration(seconds: 15));
    await stopScan();
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    if (_connectionState == BleConnectionState.scanning) {
      _connectionState = BleConnectionState.disconnected;
      _statusMessage = _scanResults.isEmpty
          ? "No devices found. Make sure AI-ECG Monitor is powered on."
          : "Select a device to connect";
      notifyListeners();
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      _connectionState = BleConnectionState.connecting;
      _statusMessage = "Connecting to ${device.platformName}...";
      notifyListeners();

      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;

      // Discover services
      List<BluetoothService> services = await device.discoverServices();

      // Find our service
      BluetoothService? ecgService;
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUUID) {
          ecgService = service;
          break;
        }
      }

      if (ecgService == null) {
        throw Exception("ECG service not found on device");
      }

      // Subscribe to characteristics
      for (var characteristic in ecgService.characteristics) {
        String charUuid = characteristic.uuid.toString().toLowerCase();

        if (charUuid == ecgCharUUID) {
          await characteristic.setNotifyValue(true);
          _ecgSubscription = characteristic.lastValueStream.listen(_onEcgData);
        } else if (charUuid == paramsCharUUID) {
          await characteristic.setNotifyValue(true);
          _paramsSubscription =
              characteristic.lastValueStream.listen(_onParamsData);
        } else if (charUuid == alertCharUUID) {
          await characteristic.setNotifyValue(true);
          _alertSubscription =
              characteristic.lastValueStream.listen(_onAlertData);
        }
      }

      _connectionState = BleConnectionState.connected;
      _statusMessage = "Connected to ${device.platformName}";

      // Listen for disconnection
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });

      notifyListeners();
    } catch (e) {
      _statusMessage = "Connection failed: ${e.toString()}";
      _connectionState = BleConnectionState.disconnected;
      notifyListeners();
    }
  }

  void _onEcgData(List<int> data) {
    if (data.length >= 2) {
      _ecgValue = (data[0] << 8) | data[1];
      _ecgStreamController.add(_ecgValue);
      notifyListeners();
    }
  }

  void _onParamsData(List<int> data) {
    try {
      String paramsString = utf8.decode(data);
      List<String> params = paramsString.split(',');

      if (params.length >= 7) {
        _avgBPM = int.tryParse(params[0]) ?? 0;
        _currentBPM = int.tryParse(params[1]) ?? 0;
        _hrv = double.tryParse(params[2]) ?? 0;
        _stLevel = int.tryParse(params[3]) ?? 0;
        _riskScore = int.tryParse(params[4]) ?? 0;
        _riskLevel = params[5];
        _leadsOff = params[6] == '1';

        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error parsing params: $e");
    }
  }

  void _onAlertData(List<int> data) {
    try {
      _alertMessage = utf8.decode(data);
      notifyListeners();
    } catch (e) {
      debugPrint("Error parsing alert: $e");
    }
  }

  void _handleDisconnection() {
    _ecgSubscription?.cancel();
    _paramsSubscription?.cancel();
    _alertSubscription?.cancel();

    _connectionState = BleConnectionState.disconnected;
    _connectedDevice = null;
    _statusMessage = "Disconnected";
    _ecgValue = 0;
    _avgBPM = 0;
    _currentBPM = 0;
    _hrv = 0;
    _stLevel = 0;
    _riskScore = 0;
    _riskLevel = "UNKNOWN";
    _leadsOff = true;

    notifyListeners();
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
    }
    _handleDisconnection();
  }

  @override
  void dispose() {
    _ecgSubscription?.cancel();
    _paramsSubscription?.cancel();
    _alertSubscription?.cancel();
    _ecgStreamController.close();
    super.dispose();
  }
}

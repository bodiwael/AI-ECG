import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

enum BleConnectionState { disconnected, scanning, connecting, connected }

class BluetoothProvider extends ChangeNotifier {
  BleConnectionState _connectionState = BleConnectionState.disconnected;
  BluetoothDevice? _connectedDevice;
  BluetoothConnection? _connection;
  List<BluetoothDevice> _pairedDevices = [];
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

  // Data buffer for parsing
  String _dataBuffer = "";

  // Getters
  BleConnectionState get connectionState => _connectionState;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<BluetoothDevice> get pairedDevices => _pairedDevices;
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

  Future<void> getPairedDevices() async {
    if (_connectionState == BleConnectionState.scanning) return;

    bool permissionsGranted = await requestPermissions();
    if (!permissionsGranted) {
      _statusMessage = "Bluetooth permissions required";
      notifyListeners();
      return;
    }

    _connectionState = BleConnectionState.scanning;
    _statusMessage = "Getting paired devices...";
    notifyListeners();

    try {
      // Get list of paired devices
      _pairedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();

      debugPrint("Found ${_pairedDevices.length} paired devices");
      for (var device in _pairedDevices) {
        debugPrint("Device: ${device.name} - ${device.address}");
      }

      _connectionState = BleConnectionState.disconnected;
      _statusMessage = _pairedDevices.isEmpty
          ? "No paired devices. Pair 'AI-ECG Monitor' in Bluetooth settings first."
          : "Select a device to connect";
      notifyListeners();
    } catch (e) {
      _statusMessage = "Error getting devices: ${e.toString()}";
      _connectionState = BleConnectionState.disconnected;
      notifyListeners();
    }
  }

  // Alias for compatibility with existing UI
  Future<void> startScan() async {
    await getPairedDevices();
  }

  // Return paired devices as scan results for UI compatibility
  List<BluetoothDevice> get scanResults => _pairedDevices;

  Future<void> connectToBluetoothDevice(BluetoothDevice device) async {
    try {
      _connectionState = BleConnectionState.connecting;
      _statusMessage = "Connecting to ${device.name}...";
      notifyListeners();

      // Connect to the device
      _connection = await BluetoothConnection.toAddress(device.address);
      _connectedDevice = device;

      _connectionState = BleConnectionState.connected;
      _statusMessage = "Connected to ${device.name}";
      notifyListeners();

      // Send start command
      _sendCommand("START");

      // Listen for incoming data
      _connection!.input!.listen(
        _onDataReceived,
        onDone: _handleDisconnection,
        onError: (error) {
          debugPrint("Bluetooth error: $error");
          _handleDisconnection();
        },
      );
    } catch (e) {
      _statusMessage = "Connection failed: ${e.toString()}";
      _connectionState = BleConnectionState.disconnected;
      notifyListeners();
    }
  }

  void _sendCommand(String command) {
    if (_connection != null && _connection!.isConnected) {
      _connection!.output.add(Uint8List.fromList(utf8.encode("$command\n")));
    }
  }

  void _onDataReceived(Uint8List data) {
    // Decode incoming data
    String incoming = utf8.decode(data, allowMalformed: true);
    _dataBuffer += incoming;

    // Process complete lines
    while (_dataBuffer.contains('\n')) {
      int newlineIndex = _dataBuffer.indexOf('\n');
      String line = _dataBuffer.substring(0, newlineIndex).trim();
      _dataBuffer = _dataBuffer.substring(newlineIndex + 1);

      _parseLine(line);
    }
  }

  void _parseLine(String line) {
    if (line.startsWith("DATA:")) {
      // Parse ECG data line: DATA:ecg,avgBPM,currentBPM,hrv,stLevel,riskScore,riskLevel,leadsOff
      String dataStr = line.substring(5);
      List<String> parts = dataStr.split(',');

      if (parts.length >= 8) {
        _ecgValue = int.tryParse(parts[0]) ?? 0;
        _avgBPM = int.tryParse(parts[1]) ?? 0;
        _currentBPM = int.tryParse(parts[2]) ?? 0;
        _hrv = double.tryParse(parts[3]) ?? 0;
        _stLevel = int.tryParse(parts[4]) ?? 0;
        _riskScore = int.tryParse(parts[5]) ?? 0;
        _riskLevel = parts[6];
        _leadsOff = parts[7] == '1';

        // Emit ECG value to stream
        _ecgStreamController.add(_ecgValue);

        notifyListeners();
      }
    } else if (line.startsWith("ALERT:")) {
      _alertMessage = line.substring(6);
      notifyListeners();
    } else if (line == "PONG") {
      debugPrint("Device responded to ping");
    }
  }

  void _handleDisconnection() {
    _connection?.dispose();
    _connection = null;

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
    _dataBuffer = "";

    notifyListeners();
  }

  Future<void> disconnect() async {
    _sendCommand("STOP");
    await Future.delayed(const Duration(milliseconds: 100));
    _connection?.dispose();
    _handleDisconnection();
  }

  @override
  void dispose() {
    _connection?.dispose();
    _ecgStreamController.close();
    super.dispose();
  }
}

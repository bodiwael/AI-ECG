import 'dart:collection';
import 'package:flutter/foundation.dart';

class ECGProvider extends ChangeNotifier {
  // ECG signal buffer for display
  static const int maxDataPoints = 500;
  final Queue<double> _ecgData = Queue<double>();

  // Normalized ECG data for chart display
  List<double> get ecgData => _ecgData.toList();

  // Signal processing parameters
  double _minValue = 0;
  double _maxValue = 4095;
  bool _autoScale = true;

  double get minValue => _minValue;
  double get maxValue => _maxValue;
  bool get autoScale => _autoScale;

  void addDataPoint(int rawValue) {
    // Add new data point
    _ecgData.add(rawValue.toDouble());

    // Remove old data points if buffer is full
    while (_ecgData.length > maxDataPoints) {
      _ecgData.removeFirst();
    }

    // Auto-scale if enabled
    if (_autoScale && _ecgData.isNotEmpty) {
      double currentMin = _ecgData.reduce((a, b) => a < b ? a : b);
      double currentMax = _ecgData.reduce((a, b) => a > b ? a : b);

      // Add some padding
      double range = currentMax - currentMin;
      _minValue = currentMin - range * 0.1;
      _maxValue = currentMax + range * 0.1;
    }

    notifyListeners();
  }

  void setAutoScale(bool value) {
    _autoScale = value;
    notifyListeners();
  }

  void setScale(double min, double max) {
    _minValue = min;
    _maxValue = max;
    _autoScale = false;
    notifyListeners();
  }

  void clearData() {
    _ecgData.clear();
    notifyListeners();
  }

  // Get normalized data for chart (0-1 range)
  List<double> getNormalizedData() {
    if (_ecgData.isEmpty) return [];

    double range = _maxValue - _minValue;
    if (range == 0) range = 1;

    return _ecgData.map((value) => (value - _minValue) / range).toList();
  }
}

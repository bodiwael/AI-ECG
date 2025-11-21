import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DeviceListDialog extends StatelessWidget {
  final List<ScanResult> scanResults;
  final bool isScanning;
  final Function(BluetoothDevice) onDeviceSelected;
  final VoidCallback onRefresh;

  const DeviceListDialog({
    super.key,
    required this.scanResults,
    required this.isScanning,
    required this.onDeviceSelected,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Row(
            children: [
              const Icon(Icons.bluetooth_searching, color: Color(0xFF00BCD4)),
              const SizedBox(width: 12),
              Text(
                'Available Devices',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onRefresh,
                icon: Icon(
                  Icons.refresh,
                  color: isScanning ? const Color(0xFF00BCD4) : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Scanning indicator
          if (isScanning)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: const Color(0xFF00BCD4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Scanning for AI-ECG devices...',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            ),

          // Device List
          Flexible(
            child: scanResults.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: scanResults.length,
                    itemBuilder: (context, index) {
                      final result = scanResults[index];
                      return _buildDeviceItem(context, result, index);
                    },
                  ),
          ),

          const SizedBox(height: 16),

          // Instructions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800]?.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[500], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Make sure your AI-ECG Monitor is powered on and in pairing mode',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bluetooth_disabled,
              size: 48,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              isScanning ? 'Searching...' : 'No devices found',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap refresh to scan again',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceItem(BuildContext context, ScanResult result, int index) {
    final device = result.device;
    final rssi = result.rssi;

    // Signal strength indicator
    IconData signalIcon;
    Color signalColor;
    if (rssi >= -50) {
      signalIcon = Icons.signal_cellular_4_bar;
      signalColor = const Color(0xFF00E676);
    } else if (rssi >= -70) {
      signalIcon = Icons.signal_cellular_alt;
      signalColor = const Color(0xFFFFC107);
    } else {
      signalIcon = Icons.signal_cellular_alt_1_bar;
      signalColor = const Color(0xFFFF5252);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onDeviceSelected(device),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BCD4).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.monitor_heart,
                  color: Color(0xFF00BCD4),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.platformName.isNotEmpty
                          ? device.platformName
                          : 'Unknown Device',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.remoteId.toString(),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Icon(signalIcon, color: signalColor, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    '$rssi dBm',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 100 * index)).slideX(
          begin: 0.2,
          end: 0,
          delay: Duration(milliseconds: 100 * index),
        );
  }
}

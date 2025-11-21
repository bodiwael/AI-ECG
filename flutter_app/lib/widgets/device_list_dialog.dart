import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DeviceListDialog extends StatelessWidget {
  final List<BluetoothDevice> devices;
  final bool isScanning;
  final Function(BluetoothDevice) onDeviceSelected;
  final VoidCallback onRefresh;

  const DeviceListDialog({
    super.key,
    required this.devices,
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
              const Icon(Icons.bluetooth, color: Color(0xFF00BCD4)),
              const SizedBox(width: 12),
              Text(
                'Paired Devices',
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

          // Loading indicator
          if (isScanning)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF00BCD4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Getting paired devices...',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            ),

          // Device List
          Flexible(
            child: devices.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return _buildDeviceItem(context, device, index);
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
                    'Pair "AI-ECG Monitor" in your phone\'s Bluetooth settings first, then select it here.',
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
              isScanning ? 'Loading...' : 'No paired devices',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Go to Bluetooth settings to pair your device',
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

  Widget _buildDeviceItem(BuildContext context, BluetoothDevice device, int index) {
    // Check if it's likely our ECG device
    bool isEcgDevice = device.name?.contains('ECG') == true ||
        device.name?.contains('AI-ECG') == true;

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
                  color: isEcgDevice
                      ? const Color(0xFF00E676).withOpacity(0.2)
                      : const Color(0xFF00BCD4).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEcgDevice ? Icons.monitor_heart : Icons.bluetooth,
                  color: isEcgDevice
                      ? const Color(0xFF00E676)
                      : const Color(0xFF00BCD4),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name ?? 'Unknown Device',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isEcgDevice ? const Color(0xFF00E676) : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.address,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isEcgDevice)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ECG',
                    style: TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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

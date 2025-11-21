import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/bluetooth_provider.dart';
import '../providers/ecg_provider.dart';
import '../widgets/ecg_chart.dart';
import '../widgets/heart_params_card.dart';
import '../widgets/risk_indicator.dart';
import '../widgets/connection_button.dart';
import '../widgets/device_list_dialog.dart';
import '../widgets/animated_heart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Listen to ECG data stream
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final btProvider = context.read<BluetoothProvider>();
      final ecgProvider = context.read<ECGProvider>();

      btProvider.ecgStream.listen((value) {
        ecgProvider.addDataPoint(value);
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<BluetoothProvider>(
          builder: (context, btProvider, child) {
            return CustomScrollView(
              slivers: [
                // App Bar
                SliverAppBar(
                  floating: true,
                  backgroundColor: Colors.transparent,
                  title: Row(
                    children: [
                      AnimatedHeart(
                        bpm: btProvider.currentBPM,
                        isConnected: btProvider.isConnected,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'AI-ECG Monitor',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                      ),
                    ],
                  ),
                  actions: [
                    ConnectionButton(
                      connectionState: btProvider.connectionState,
                      onPressed: () => _handleConnectionButton(btProvider),
                    ),
                  ],
                ),

                // Content
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Status Message
                      _buildStatusCard(btProvider),
                      const SizedBox(height: 16),

                      // ECG Chart
                      _buildECGSection(btProvider),
                      const SizedBox(height: 16),

                      // Heart Parameters
                      if (btProvider.isConnected) ...[
                        _buildParametersSection(btProvider),
                        const SizedBox(height: 16),

                        // Risk Indicator
                        _buildRiskSection(btProvider),
                        const SizedBox(height: 16),

                        // Alert Section
                        if (btProvider.alertMessage.isNotEmpty &&
                            btProvider.riskScore >= 30)
                          _buildAlertSection(btProvider),
                      ],
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusCard(BluetoothProvider btProvider) {
    Color statusColor;
    IconData statusIcon;

    switch (btProvider.connectionState) {
      case BleConnectionState.connected:
        statusColor = const Color(0xFF00E676);
        statusIcon = Icons.bluetooth_connected;
        break;
      case BleConnectionState.connecting:
      case BleConnectionState.scanning:
        statusColor = const Color(0xFFFFC107);
        statusIcon = Icons.bluetooth_searching;
        break;
      default:
        statusColor = const Color(0xFF9E9E9E);
        statusIcon = Icons.bluetooth_disabled;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, color: statusColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    btProvider.isConnected
                        ? 'Connected'
                        : btProvider.connectionState ==
                                BleConnectionState.scanning
                            ? 'Scanning...'
                            : 'Disconnected',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    btProvider.statusMessage,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[400],
                        ),
                  ),
                ],
              ),
            ),
            if (btProvider.leadsOff && btProvider.isConnected)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Leads Off',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildECGSection(BluetoothProvider btProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ECG Signal',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (btProvider.isConnected && !btProvider.leadsOff)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00E676),
                            shape: BoxShape.circle,
                          ),
                        )
                            .animate(
                              onPlay: (controller) => controller.repeat(),
                            )
                            .fadeIn(duration: 500.ms)
                            .then()
                            .fadeOut(duration: 500.ms),
                        const SizedBox(width: 6),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Color(0xFF00E676),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: btProvider.isConnected
                  ? const ECGChart()
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.monitor_heart_outlined,
                            size: 64,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Connect to view ECG signal',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildParametersSection(BluetoothProvider btProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Heart Parameters',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: HeartParamsCard(
                title: 'Heart Rate',
                value: '${btProvider.avgBPM}',
                unit: 'BPM',
                icon: Icons.favorite,
                color: const Color(0xFFFF5252),
                isAbnormal: btProvider.avgBPM < 60 || btProvider.avgBPM > 100,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: HeartParamsCard(
                title: 'Current BPM',
                value: '${btProvider.currentBPM}',
                unit: 'BPM',
                icon: Icons.timeline,
                color: const Color(0xFF00BCD4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: HeartParamsCard(
                title: 'HRV (SDNN)',
                value: btProvider.hrv.toStringAsFixed(1),
                unit: 'ms',
                icon: Icons.stacked_line_chart,
                color: const Color(0xFF9C27B0),
                isAbnormal: btProvider.hrv < 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: HeartParamsCard(
                title: 'ST Level',
                value: '${btProvider.stLevel}',
                unit: 'uV',
                icon: Icons.show_chart,
                color: const Color(0xFFFFC107),
                isAbnormal: btProvider.stLevel.abs() > 100,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildRiskSection(BluetoothProvider btProvider) {
    return RiskIndicator(
      riskScore: btProvider.riskScore,
      riskLevel: btProvider.riskLevel,
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildAlertSection(BluetoothProvider btProvider) {
    Color alertColor;
    if (btProvider.riskScore >= 70) {
      alertColor = const Color(0xFFFF5252);
    } else if (btProvider.riskScore >= 50) {
      alertColor = const Color(0xFFFF9800);
    } else {
      alertColor = const Color(0xFFFFC107);
    }

    return Card(
      color: alertColor.withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: alertColor,
              size: 32,
            )
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 500.ms),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alert',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: alertColor,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    btProvider.alertMessage,
                    style: TextStyle(color: Colors.grey[300]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 400.ms).shake(hz: 3, rotation: 0.02);
  }

  void _handleConnectionButton(BluetoothProvider btProvider) async {
    switch (btProvider.connectionState) {
      case BleConnectionState.disconnected:
        await btProvider.startScan();
        if (mounted && btProvider.scanResults.isNotEmpty) {
          _showDeviceListDialog(btProvider);
        } else if (mounted) {
          _showDeviceListDialog(btProvider);
        }
        break;
      case BleConnectionState.scanning:
        _showDeviceListDialog(btProvider);
        break;
      case BleConnectionState.connecting:
        // Do nothing while connecting
        break;
      case BleConnectionState.connected:
        _showDisconnectDialog(btProvider);
        break;
    }
  }

  void _showDeviceListDialog(BluetoothProvider btProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DeviceListDialog(
        scanResults: btProvider.scanResults,
        isScanning: btProvider.connectionState == BleConnectionState.scanning,
        onDeviceSelected: (device) {
          Navigator.pop(context);
          btProvider.connectToDevice(device);
        },
        onRefresh: () => btProvider.startScan(),
      ),
    );
  }

  void _showDisconnectDialog(BluetoothProvider btProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Disconnect?'),
        content: Text(
            'Disconnect from ${btProvider.connectedDevice?.platformName ?? "device"}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              btProvider.disconnect();
            },
            child: const Text(
              'Disconnect',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/bluetooth_provider.dart';

class ConnectionButton extends StatelessWidget {
  final ConnectionState connectionState;
  final VoidCallback onPressed;

  const ConnectionButton({
    super.key,
    required this.connectionState,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    Color buttonColor;
    IconData icon;
    String label;

    switch (connectionState) {
      case ConnectionState.connected:
        buttonColor = const Color(0xFF00E676);
        icon = Icons.bluetooth_connected;
        label = 'Connected';
        break;
      case ConnectionState.connecting:
        buttonColor = const Color(0xFFFFC107);
        icon = Icons.bluetooth_searching;
        label = 'Connecting...';
        break;
      case ConnectionState.scanning:
        buttonColor = const Color(0xFF00BCD4);
        icon = Icons.bluetooth_searching;
        label = 'Scanning...';
        break;
      default:
        buttonColor = Colors.grey;
        icon = Icons.bluetooth;
        label = 'Connect';
    }

    Widget buttonContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: buttonColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: buttonColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    if (connectionState == ConnectionState.scanning ||
        connectionState == ConnectionState.connecting) {
      buttonContent = buttonContent
          .animate(onPlay: (controller) => controller.repeat())
          .shimmer(duration: 1500.ms, color: buttonColor.withOpacity(0.3));
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: buttonColor.withOpacity(0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: buttonColor.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: buttonContent,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RiskIndicator extends StatelessWidget {
  final int riskScore;
  final String riskLevel;

  const RiskIndicator({
    super.key,
    required this.riskScore,
    required this.riskLevel,
  });

  Color _getRiskColor() {
    switch (riskLevel.toUpperCase()) {
      case 'CRITICAL':
        return const Color(0xFFFF1744);
      case 'HIGH':
        return const Color(0xFFFF5252);
      case 'MODERATE':
        return const Color(0xFFFF9800);
      case 'LOW':
        return const Color(0xFFFFC107);
      default:
        return const Color(0xFF00E676);
    }
  }

  IconData _getRiskIcon() {
    switch (riskLevel.toUpperCase()) {
      case 'CRITICAL':
        return Icons.emergency;
      case 'HIGH':
        return Icons.warning;
      case 'MODERATE':
        return Icons.info_outline;
      case 'LOW':
        return Icons.check_circle_outline;
      default:
        return Icons.favorite;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getRiskColor();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Heart Attack Risk Assessment',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Icon(
                  _getRiskIcon(),
                  color: color,
                  size: 28,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Risk Score Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Risk Score',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    Text(
                      '$riskScore / 100',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    // Background
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    // Progress
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      height: 12,
                      width: MediaQuery.of(context).size.width *
                          0.7 *
                          (riskScore / 100),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.7),
                            color,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Risk Level Badge
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (riskLevel.toUpperCase() == 'CRITICAL' ||
                        riskLevel.toUpperCase() == 'HIGH')
                      Icon(Icons.warning_amber, color: color, size: 20)
                          .animate(
                            onPlay: (controller) =>
                                controller.repeat(reverse: true),
                          )
                          .scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.2, 1.2),
                            duration: 500.ms,
                          ),
                    if (riskLevel.toUpperCase() == 'CRITICAL' ||
                        riskLevel.toUpperCase() == 'HIGH')
                      const SizedBox(width: 8),
                    Text(
                      riskLevel,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                            letterSpacing: 2,
                          ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Risk Level Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem('Normal', const Color(0xFF00E676)),
                _buildLegendItem('Low', const Color(0xFFFFC107)),
                _buildLegendItem('Moderate', const Color(0xFFFF9800)),
                _buildLegendItem('High', const Color(0xFFFF5252)),
                _buildLegendItem('Critical', const Color(0xFFFF1744)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}

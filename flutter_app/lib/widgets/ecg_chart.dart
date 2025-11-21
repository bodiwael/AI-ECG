import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/ecg_provider.dart';

class ECGChart extends StatelessWidget {
  const ECGChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ECGProvider>(
      builder: (context, ecgProvider, child) {
        final data = ecgProvider.ecgData;

        if (data.isEmpty) {
          return const Center(
            child: Text(
              'Waiting for data...',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        // Create spots for the chart
        List<FlSpot> spots = [];
        for (int i = 0; i < data.length; i++) {
          spots.add(FlSpot(i.toDouble(), data[i]));
        }

        return LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: (ecgProvider.maxValue - ecgProvider.minValue) / 5,
              verticalInterval: 50,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey.withOpacity(0.2),
                  strokeWidth: 0.5,
                );
              },
              getDrawingVerticalLine: (value) {
                return FlLine(
                  color: Colors.grey.withOpacity(0.2),
                  strokeWidth: 0.5,
                );
              },
            ),
            titlesData: const FlTitlesData(
              show: false,
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            minX: 0,
            maxX: ECGProvider.maxDataPoints.toDouble(),
            minY: ecgProvider.minValue,
            maxY: ecgProvider.maxValue,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF00E676),
                    Color(0xFF00BCD4),
                  ],
                ),
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00E676).withOpacity(0.3),
                      const Color(0xFF00BCD4).withOpacity(0.1),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
            lineTouchData: const LineTouchData(enabled: false),
          ),
          duration: const Duration(milliseconds: 0),
        );
      },
    );
  }
}

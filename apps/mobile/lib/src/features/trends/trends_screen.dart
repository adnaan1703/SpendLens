import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../shared/widgets/app_page.dart';

class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key});

  static const routePath = '/trends';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppPage(
      title: 'Trends',
      subtitle: 'Monthly net spend',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            height: 260,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 5,
                minY: 0,
                maxY: 5,
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 0),
                      FlSpot(1, 0),
                      FlSpot(2, 0),
                      FlSpot(3, 0),
                      FlSpot(4, 0),
                      FlSpot(5, 0),
                    ],
                    color: colorScheme.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

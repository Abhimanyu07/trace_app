import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../theme/app_theme.dart';
import '../../../models/daily_summary.dart';

class UsageBarChart extends StatelessWidget {
  final List<HourlyData> hourlyData;

  const UsageBarChart({super.key, required this.hourlyData});

  @override
  Widget build(BuildContext context) {
    final maxVal = hourlyData.isEmpty
        ? 60.0
        : hourlyData
            .map((h) => h.totalSeconds / 60.0)
            .reduce((a, b) => a > b ? a : b)
            .clamp(10.0, double.infinity);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal + 10,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final minutes = rod.toY.toInt();
                return BarTooltipItem(
                  '${group.x}:00\n${minutes}m',
                  const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final hour = value.toInt();
                  if (hour % 3 != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${hour}h',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                        fontFamily: 'Gilroy',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: _buildBarGroups(),
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    if (hourlyData.isEmpty) {
      return List.generate(24, (i) => _bar(i, 0));
    }
    return hourlyData.map((h) {
      final minutes = h.totalSeconds / 60.0;
      return _bar(h.hour, minutes);
    }).toList();
  }

  BarChartGroupData _bar(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: y > 0 ? AppColors.primary : AppColors.surfaceLight,
          width: 8,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  }
}

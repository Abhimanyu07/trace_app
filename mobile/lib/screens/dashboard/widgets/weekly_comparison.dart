import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../theme/app_theme.dart';
import '../../../models/daily_summary.dart';

class WeeklyComparison extends StatelessWidget {
  final List<DailySummary> weeklyData;

  const WeeklyComparison({super.key, required this.weeklyData});

  @override
  Widget build(BuildContext context) {
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxMinutes = weeklyData.isEmpty
        ? 60.0
        : weeklyData
            .map((d) => d.totalSeconds / 60.0)
            .reduce((a, b) => a > b ? a : b)
            .clamp(10.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _weeklyTotal(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Text(
                'this week',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxMinutes + 20,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final mins = rod.toY.toInt();
                      if (mins == 0) return null;
                      final h = mins ~/ 60;
                      final m = mins % 60;
                      final text = h > 0 ? '${h}h ${m}m' : '${m}m';
                      return BarTooltipItem(
                        '${dayLabels[group.x]}\n$text',
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
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= dayLabels.length) {
                          return const SizedBox();
                        }
                        final isToday = i == DateTime.now().weekday - 1;
                        final hasData = i < weeklyData.length &&
                            weeklyData[i].totalSeconds > 0;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            dayLabels[i],
                            style: TextStyle(
                              color: isToday
                                  ? AppColors.primary
                                  : hasData
                                      ? AppColors.textSecondary
                                      : AppColors.textTertiary,
                              fontSize: 11,
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w400,
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
                barGroups: List.generate(7, (i) {
                  final minutes = i < weeklyData.length
                      ? weeklyData[i].totalSeconds / 60.0
                      : 0.0;
                  final isToday = i == DateTime.now().weekday - 1;
                  final hasData = minutes > 0;
                  final isFuture = i > DateTime.now().weekday - 1;

                  Color barColor;
                  if (isToday) {
                    barColor = AppColors.primary;
                  } else if (hasData) {
                    barColor = AppColors.primary.withOpacity(0.6);
                  } else if (isFuture) {
                    barColor = AppColors.surfaceLight;
                  } else {
                    // Past day with no data - show subtle empty bar
                    barColor = AppColors.surfaceLight;
                  }

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: hasData ? minutes : 2, // min height for empty days
                        color: barColor,
                        width: 24,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _weeklyTotal() {
    final totalSeconds =
        weeklyData.fold<int>(0, (sum, d) => sum + d.totalSeconds);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../theme/app_theme.dart';
import '../../../models/daily_summary.dart';

class CategoryPieChart extends StatelessWidget {
  final DailySummary? summary;

  const CategoryPieChart({super.key, this.summary});

  @override
  Widget build(BuildContext context) {
    final hasData = summary != null && summary!.totalSeconds > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: hasData
          ? Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: PieChart(
                    PieChartData(
                      sections: _buildSections(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(child: _buildLegend()),
              ],
            )
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No data yet',
                  style: TextStyle(color: AppColors.textTertiary),
                ),
              ),
            ),
    );
  }

  List<PieChartSectionData> _buildSections() {
    if (summary == null || summary!.totalSeconds == 0) return [];

    final total = summary!.totalSeconds.toDouble();
    final sections = <PieChartSectionData>[];

    void addSection(int seconds, Color color, String label) {
      if (seconds > 0) {
        sections.add(PieChartSectionData(
          value: seconds / total * 100,
          color: color,
          radius: 20,
          showTitle: false,
        ));
      }
    }

    addSection(summary!.productiveSeconds, AppColors.productive, 'Productive');
    addSection(summary!.neutralSeconds, AppColors.neutral, 'Neutral');
    addSection(summary!.distractionSeconds, AppColors.distraction, 'Distraction');
    addSection(summary!.unclassifiedSeconds, AppColors.unclassified, 'Unclassified');

    return sections;
  }

  Widget _buildLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _legendItem(AppColors.productive, 'Productive',
            _formatDuration(summary?.productiveSeconds ?? 0)),
        const SizedBox(height: 10),
        _legendItem(AppColors.neutral, 'Neutral',
            _formatDuration(summary?.neutralSeconds ?? 0)),
        const SizedBox(height: 10),
        _legendItem(AppColors.distraction, 'Distraction',
            _formatDuration(summary?.distractionSeconds ?? 0)),
        const SizedBox(height: 10),
        _legendItem(AppColors.unclassified, 'Unclassified',
            _formatDuration(summary?.unclassifiedSeconds ?? 0)),
      ],
    );
  }

  Widget _legendItem(Color color, String label, String value) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/daily_summary.dart';
import '../../../models/app_category.dart';
import '../../../widgets/app_icon_widget.dart';

class TopAppsList extends StatelessWidget {
  final List<AppUsageSummary> apps;

  const TopAppsList({super.key, required this.apps});

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Center(
          child: Text(
            'No usage data yet',
            style: TextStyle(color: AppColors.textTertiary),
          ),
        ),
      );
    }

    final maxSeconds = apps.first.totalSeconds.toDouble();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: List.generate(apps.length.clamp(0, 5), (i) {
          final app = apps[i];
          final cat = AppCategory.fromString(app.category);
          final fraction =
              maxSeconds > 0 ? app.totalSeconds / maxSeconds : 0.0;

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: i == 0 ? 12 : 0,
              bottom: i == apps.length.clamp(0, 5) - 1 ? 12 : 0,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      AppIconWidget(appName: app.appName, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.appName,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: fraction,
                                backgroundColor: AppColors.surfaceLight,
                                color: cat.color,
                                minHeight: 3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        app.formattedDuration,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < apps.length.clamp(0, 5) - 1)
                  const Divider(height: 1, color: AppColors.divider),
              ],
            ),
          );
        }),
      ),
    );
  }
}

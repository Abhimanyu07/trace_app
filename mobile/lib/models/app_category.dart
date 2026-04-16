import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppCategory {
  productive,
  neutral,
  distraction,
  unclassified;

  static AppCategory fromString(String s) {
    switch (s) {
      case 'productive':
        return AppCategory.productive;
      case 'neutral':
        return AppCategory.neutral;
      case 'distraction':
        return AppCategory.distraction;
      default:
        return AppCategory.unclassified;
    }
  }

  Color get color {
    switch (this) {
      case AppCategory.productive:
        return AppColors.productive;
      case AppCategory.neutral:
        return AppColors.neutral;
      case AppCategory.distraction:
        return AppColors.distraction;
      case AppCategory.unclassified:
        return AppColors.unclassified;
    }
  }

  String get label {
    switch (this) {
      case AppCategory.productive:
        return 'Productive';
      case AppCategory.neutral:
        return 'Neutral';
      case AppCategory.distraction:
        return 'Distraction';
      case AppCategory.unclassified:
        return 'Unclassified';
    }
  }

  IconData get icon {
    switch (this) {
      case AppCategory.productive:
        return Icons.trending_up;
      case AppCategory.neutral:
        return Icons.remove;
      case AppCategory.distraction:
        return Icons.trending_down;
      case AppCategory.unclassified:
        return Icons.help_outline;
    }
  }
}

class AppUsageSummary {
  final String appName;
  final int totalSeconds;
  final String category;

  AppUsageSummary({
    required this.appName,
    required this.totalSeconds,
    this.category = 'unclassified',
  });

  factory AppUsageSummary.fromJson(Map<String, dynamic> json) {
    return AppUsageSummary(
      appName: json['app_name'] ?? '',
      totalSeconds: json['total_seconds'] ?? 0,
      category: json['category'] ?? 'unclassified',
    );
  }

  String get formattedDuration {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

class DailySummary {
  final int date;
  final int totalSeconds;
  final int productiveSeconds;
  final int neutralSeconds;
  final int distractionSeconds;
  final int unclassifiedSeconds;
  final List<AppUsageSummary> topApps;

  DailySummary({
    required this.date,
    required this.totalSeconds,
    required this.productiveSeconds,
    required this.neutralSeconds,
    required this.distractionSeconds,
    required this.unclassifiedSeconds,
    required this.topApps,
  });

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      date: json['date'] ?? 0,
      totalSeconds: json['total_seconds'] ?? 0,
      productiveSeconds: json['productive_seconds'] ?? 0,
      neutralSeconds: json['neutral_seconds'] ?? 0,
      distractionSeconds: json['distraction_seconds'] ?? 0,
      unclassifiedSeconds: json['unclassified_seconds'] ?? 0,
      topApps: (json['top_apps'] as List?)
              ?.map((a) => AppUsageSummary.fromJson(a))
              .toList() ??
          [],
    );
  }

  String get formattedTotal {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

class HourlyData {
  final int hour;
  final int totalSeconds;

  HourlyData({required this.hour, required this.totalSeconds});

  factory HourlyData.fromJson(Map<String, dynamic> json) {
    return HourlyData(
      hour: json['hour'] ?? 0,
      totalSeconds: json['total_seconds'] ?? 0,
    );
  }
}

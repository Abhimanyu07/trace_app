import 'package:flutter/services.dart';
import '../models/daily_summary.dart';

class PhoneUsageService {
  static const _channel = MethodChannel('com.traceyourlyf/usage_stats');

  Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestPermission() async {
    await _channel.invokeMethod('requestPermission');
  }

  Future<PhoneUsageData> getUsageToday() async {
    final result = await _channel.invokeMethod<Map>('getUsageToday');
    if (result == null || result['error'] == 'no_permission') {
      return PhoneUsageData.empty();
    }
    return _parseApps(result['apps'] as List? ?? []);
  }

  Future<PhoneUsageData> getUsageForDate(DateTime date) async {
    final result = await _channel.invokeMethod<Map>('getUsageForDate', {
      'year': date.year,
      'month': date.month,
      'day': date.day,
    });
    if (result == null || result['error'] == 'no_permission') {
      return PhoneUsageData.empty();
    }
    return _parseApps(result['apps'] as List? ?? []);
  }

  Future<List<PhoneUsageData>> getUsageWeekly() async {
    final result = await _channel.invokeMethod<Map>('getUsageWeekly');
    if (result == null || result['error'] == 'no_permission') {
      return List.generate(7, (_) => PhoneUsageData.empty());
    }

    final days = result['days'] as List? ?? [];
    return days.map((day) {
      final map = Map<String, dynamic>.from(day as Map);
      final apps = (map['apps'] as List?) ?? [];
      final data = _parseApps(apps);
      return PhoneUsageData(
        totalSeconds: (map['total_seconds'] as num?)?.toInt() ?? data.totalSeconds,
        apps: data.apps,
        date: (map['date'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  PhoneUsageData _parseApps(List apps) {
    final parsed = apps.map((a) {
      final map = Map<String, dynamic>.from(a as Map);
      return PhoneAppUsage(
        packageName: map['package_name'] as String? ?? '',
        appName: map['app_name'] as String? ?? '',
        totalSeconds: (map['total_seconds'] as num?)?.toInt() ?? 0,
        lastUsed: (map['last_used'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    final total = parsed.fold<int>(0, (sum, a) => sum + a.totalSeconds);

    return PhoneUsageData(
      totalSeconds: total,
      apps: parsed,
    );
  }
}

class PhoneAppUsage {
  final String packageName;
  final String appName;
  final int totalSeconds;
  final int lastUsed;

  PhoneAppUsage({
    required this.packageName,
    required this.appName,
    required this.totalSeconds,
    required this.lastUsed,
  });

  String get formattedDuration {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class PhoneUsageData {
  final int totalSeconds;
  final List<PhoneAppUsage> apps;
  final int? date;

  PhoneUsageData({
    required this.totalSeconds,
    required this.apps,
    this.date,
  });

  factory PhoneUsageData.empty() => PhoneUsageData(totalSeconds: 0, apps: []);

  String get formattedTotal {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  /// Convert to DailySummary for merging with desktop data
  DailySummary toDailySummary() {
    return DailySummary(
      date: date ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      totalSeconds: totalSeconds,
      productiveSeconds: 0,
      neutralSeconds: 0,
      distractionSeconds: 0,
      unclassifiedSeconds: totalSeconds,
      topApps: apps
          .take(10)
          .map((a) => AppUsageSummary(
                appName: a.appName,
                totalSeconds: a.totalSeconds,
                category: 'unclassified',
              ))
          .toList(),
    );
  }
}

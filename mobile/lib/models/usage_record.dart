class UsageRecord {
  final int? id;
  final String appName;
  final String? windowTitle;
  final String? url;
  final String? projectPath;
  final int startTime;
  final int? endTime;
  final int? durationSeconds;
  final String category;
  final String source; // 'desktop' or 'phone'

  UsageRecord({
    this.id,
    required this.appName,
    this.windowTitle,
    this.url,
    this.projectPath,
    required this.startTime,
    this.endTime,
    this.durationSeconds,
    this.category = 'unclassified',
    this.source = 'desktop',
  });

  factory UsageRecord.fromJson(Map<String, dynamic> json) {
    return UsageRecord(
      id: json['id'],
      appName: json['app_name'] ?? '',
      windowTitle: json['window_title'],
      url: json['url'],
      projectPath: json['project_path'],
      startTime: json['start_time'] ?? 0,
      endTime: json['end_time'],
      durationSeconds: json['duration_seconds'],
      category: json['category'] ?? 'unclassified',
      source: json['source'] ?? 'desktop',
    );
  }
}

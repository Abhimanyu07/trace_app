import 'dart:async';
import 'package:flutter/material.dart';
import '../models/daily_summary.dart';
import '../services/desktop_api_service.dart';
import '../services/phone_usage_service.dart';
import '../services/category_service.dart';
import '../providers/pairing_provider.dart';

const _kPhoneDeviceId = '__this_phone__';
const _refreshInterval = Duration(seconds: 30);

class UsageProvider extends ChangeNotifier {
  PairingProvider? _pairingProvider;
  final PhoneUsageService _phoneService = PhoneUsageService();
  final CategoryService _categoryService = CategoryService();
  Timer? _refreshTimer;
  Map<String, String> _localCategories = {};

  // Aggregated data (all devices combined)
  DailySummary? _todaySummary;
  List<HourlyData> _hourlyData = [];
  List<DailySummary> _weeklyData = [];
  List<Map<String, dynamic>> _allApps = [];
  List<Map<String, dynamic>> _allDomains = [];

  // Per-device data
  final Map<String, DeviceUsageData> _deviceData = {};

  // Phone data
  bool _hasPhonePermission = false;
  PhoneUsageData? _phoneUsageToday;
  List<PhoneUsageData>? _phoneUsageWeekly;

  String? _selectedDeviceId; // null = all devices, '__this_phone__' = phone
  bool _isLoading = false;
  String? _error;

  UsageProvider(DesktopApiService api);

  void setPairingProvider(PairingProvider p) {
    _pairingProvider = p;
  }

  PhoneUsageService get phoneService => _phoneService;
  bool get hasPhonePermission => _hasPhonePermission;

  DailySummary? get todaySummary {
    if (_selectedDeviceId == _kPhoneDeviceId) {
      return _phoneUsageToday?.toDailySummary();
    }
    if (_selectedDeviceId != null) {
      return _deviceData[_selectedDeviceId]?.todaySummary;
    }
    return _todaySummary;
  }

  List<HourlyData> get hourlyData {
    if (_selectedDeviceId == _kPhoneDeviceId) return [];
    if (_selectedDeviceId != null) {
      return _deviceData[_selectedDeviceId]?.hourlyData ?? [];
    }
    return _hourlyData;
  }

  List<DailySummary> get weeklyData {
    if (_selectedDeviceId == _kPhoneDeviceId) {
      return _phoneUsageWeekly
              ?.map((d) => d.toDailySummary())
              .toList() ??
          [];
    }
    if (_selectedDeviceId != null) {
      return _deviceData[_selectedDeviceId]?.weeklyData ?? [];
    }
    return _weeklyData;
  }

  List<Map<String, dynamic>> get allApps {
    if (_selectedDeviceId == _kPhoneDeviceId) {
      return _phoneUsageToday?.apps
              .map((a) => {
                    'app_name': a.appName,
                    'total_seconds': a.totalSeconds,
                    'category': _localCategories[a.appName] ?? 'unclassified',
                    'package_name': a.packageName,
                  })
              .toList() ??
          [];
    }
    if (_selectedDeviceId != null) {
      final apps = _deviceData[_selectedDeviceId]?.allApps ?? [];
      // Apply local categories on top of desktop categories
      for (final app in apps) {
        final name = app['app_name'] as String? ?? '';
        if (_localCategories.containsKey(name)) {
          app['category'] = _localCategories[name];
        }
      }
      return apps;
    }
    return _allApps;
  }

  List<Map<String, dynamic>> get allDomains {
    if (_selectedDeviceId == _kPhoneDeviceId) return [];
    if (_selectedDeviceId != null) {
      return _deviceData[_selectedDeviceId]?.allDomains ?? [];
    }
    return _allDomains;
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedDeviceId => _selectedDeviceId;
  bool get isPhoneSelected => _selectedDeviceId == _kPhoneDeviceId;

  void selectDevice(String? deviceId) {
    _selectedDeviceId = deviceId;
    notifyListeners();
  }

  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => refreshAll());
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> checkPhonePermission() async {
    _hasPhonePermission = await _phoneService.hasPermission();
    notifyListeners();
  }

  Future<void> requestPhonePermission() async {
    await _phoneService.requestPermission();
    // Check again after user returns from settings
    await Future.delayed(const Duration(seconds: 1));
    await checkPhonePermission();
  }

  Future<void> refreshAll() async {
    _error = null;
    _localCategories = await _categoryService.getAll();

    // Don't show loading spinner on auto-refresh, only on first load
    if (_todaySummary == null && _phoneUsageToday == null) {
      _isLoading = true;
      notifyListeners();
    }

    // Fetch phone data
    await _fetchPhoneData();

    // Fetch desktop data
    await _fetchDesktopData();

    // Aggregate
    _aggregateAll();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchPhoneData() async {
    try {
      _hasPhonePermission = await _phoneService.hasPermission();
      if (_hasPhonePermission) {
        _phoneUsageToday = await _phoneService.getUsageToday();
        _phoneUsageWeekly = await _phoneService.getUsageWeekly();
      }
    } catch (e) {
      debugPrint('Phone usage error: $e');
    }
  }

  Future<void> _fetchDesktopData() async {
    if (_pairingProvider == null || !_pairingProvider!.hasDevices) return;

    final desktops = _pairingProvider!.desktops;
    for (final device in desktops) {
      if (device.ip == null || device.token == null) continue;
      final api = _pairingProvider!.getApiForDevice(device);
      try {
        final results = await Future.wait([
          api.getDailySummary(),
          api.getHourlyBreakdown(),
          api.getWeeklySummary(),
          api.getAllApps(),
          api.getAllDomains(),
        ]);
        _deviceData[device.deviceId] = DeviceUsageData(
          todaySummary: results[0] as DailySummary,
          hourlyData: results[1] as List<HourlyData>,
          weeklyData: results[2] as List<DailySummary>,
          allApps: results[3] as List<Map<String, dynamic>>,
          allDomains: results[4] as List<Map<String, dynamic>>,
        );
      } catch (e) {
        debugPrint('Failed to fetch from ${device.deviceName}: $e');
      }
    }
  }

  void _aggregateAll() {
    int totalSec = 0, prodSec = 0, neutSec = 0, distSec = 0, unclSec = 0;
    final appMap = <String, Map<String, dynamic>>{};
    final domainMap = <String, Map<String, dynamic>>{};

    // Add desktop data
    for (final data in _deviceData.values) {
      if (data.todaySummary != null) {
        totalSec += data.todaySummary!.totalSeconds;
        prodSec += data.todaySummary!.productiveSeconds;
        neutSec += data.todaySummary!.neutralSeconds;
        distSec += data.todaySummary!.distractionSeconds;
        unclSec += data.todaySummary!.unclassifiedSeconds;

        for (final app in data.todaySummary!.topApps) {
          final key = app.appName;
          if (appMap.containsKey(key)) {
            appMap[key]!['total_seconds'] =
                (appMap[key]!['total_seconds'] as int) + app.totalSeconds;
          } else {
            appMap[key] = {
              'app_name': app.appName,
              'total_seconds': app.totalSeconds,
              'category': app.category,
            };
          }
        }
      }
      for (final domain in data.allDomains) {
        final key = domain['domain'] ?? '';
        if (domainMap.containsKey(key)) {
          domainMap[key]!['total_seconds'] =
              (domainMap[key]!['total_seconds'] as int) +
                  (domain['total_seconds'] as int);
        } else {
          domainMap[key] = Map<String, dynamic>.from(domain);
        }
      }
    }

    // Add phone data
    if (_phoneUsageToday != null && _hasPhonePermission) {
      totalSec += _phoneUsageToday!.totalSeconds;
      unclSec += _phoneUsageToday!.totalSeconds;

      for (final app in _phoneUsageToday!.apps) {
        final key = app.appName;
        final cat = _localCategories[key] ?? 'unclassified';
        if (appMap.containsKey(key)) {
          appMap[key]!['total_seconds'] =
              (appMap[key]!['total_seconds'] as int) + app.totalSeconds;
        } else {
          appMap[key] = {
            'app_name': app.appName,
            'total_seconds': app.totalSeconds,
            'category': cat,
          };
        }
      }
    }

    final topApps = appMap.values.toList()
      ..sort((a, b) =>
          (b['total_seconds'] as int).compareTo(a['total_seconds'] as int));

    // Apply local categories and recalculate category seconds
    for (final app in topApps) {
      final name = app['app_name'] as String? ?? '';
      if (_localCategories.containsKey(name)) {
        app['category'] = _localCategories[name];
      }
    }

    // Recalculate category seconds from the merged app list
    prodSec = 0;
    neutSec = 0;
    distSec = 0;
    unclSec = 0;
    for (final app in topApps) {
      final secs = app['total_seconds'] as int;
      switch (app['category'] as String?) {
        case 'productive':
          prodSec += secs;
          break;
        case 'neutral':
          neutSec += secs;
          break;
        case 'distraction':
          distSec += secs;
          break;
        default:
          unclSec += secs;
      }
    }

    _todaySummary = DailySummary(
      date: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      totalSeconds: totalSec,
      productiveSeconds: prodSec,
      neutralSeconds: neutSec,
      distractionSeconds: distSec,
      unclassifiedSeconds: unclSec,
      topApps:
          topApps.take(10).map((a) => AppUsageSummary.fromJson(a)).toList(),
    );
    _allApps = topApps;
    _allDomains = domainMap.values.toList()
      ..sort((a, b) =>
          (b['total_seconds'] as int).compareTo(a['total_seconds'] as int));

    // Hourly: only desktop has hourly
    if (_deviceData.isNotEmpty) {
      _hourlyData = List.generate(24, (h) {
        int total = 0;
        for (final data in _deviceData.values) {
          if (h < data.hourlyData.length) {
            total += data.hourlyData[h].totalSeconds;
          }
        }
        return HourlyData(hour: h, totalSeconds: total);
      });
    }

    // Weekly: merge desktop weekly + phone weekly
    final desktopDayCount = _deviceData.values.isEmpty
        ? 0
        : _deviceData.values
            .map((d) => d.weeklyData.length)
            .reduce((a, b) => a > b ? a : b);
    final phoneDayCount = _phoneUsageWeekly?.length ?? 0;
    int maxDays = desktopDayCount > phoneDayCount ? desktopDayCount : phoneDayCount;
    if (maxDays == 0) maxDays = 7;

    _weeklyData = List.generate(maxDays, (i) {
      int total = 0, prod = 0, neut = 0, dist = 0, uncl = 0;
      int date = 0;
      for (final data in _deviceData.values) {
        if (i < data.weeklyData.length) {
          final d = data.weeklyData[i];
          total += d.totalSeconds;
          prod += d.productiveSeconds;
          neut += d.neutralSeconds;
          dist += d.distractionSeconds;
          uncl += d.unclassifiedSeconds;
          date = d.date;
        }
      }
      if (_phoneUsageWeekly != null && i < _phoneUsageWeekly!.length) {
        total += _phoneUsageWeekly![i].totalSeconds;
        uncl += _phoneUsageWeekly![i].totalSeconds;
        if (date == 0) date = _phoneUsageWeekly![i].date ?? 0;
      }
      return DailySummary(
        date: date,
        totalSeconds: total,
        productiveSeconds: prod,
        neutralSeconds: neut,
        distractionSeconds: dist,
        unclassifiedSeconds: uncl,
        topApps: [],
      );
    });
  }

  Future<void> setAppCategory(String appName, String category) async {
    try {
      // Always save locally
      await _categoryService.setCategory(appName, category);
      _localCategories[appName] = category;

      // Also sync to connected desktops
      final desktops = _pairingProvider?.desktops ?? [];
      for (final device in desktops) {
        try {
          final api = _pairingProvider!.getApiForDevice(device);
          await api.setAppCategory(appName, category);
        } catch (_) {
          // Desktop sync failed - local save still applies
        }
      }
      await refreshAll();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

class DeviceUsageData {
  final DailySummary? todaySummary;
  final List<HourlyData> hourlyData;
  final List<DailySummary> weeklyData;
  final List<Map<String, dynamic>> allApps;
  final List<Map<String, dynamic>> allDomains;

  DeviceUsageData({
    this.todaySummary,
    this.hourlyData = const [],
    this.weeklyData = const [],
    this.allApps = const [],
    this.allDomains = const [],
  });
}

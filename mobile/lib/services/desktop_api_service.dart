import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/daily_summary.dart';

class DesktopApiService {
  String? _baseUrl;
  String? _token;

  bool get isConnected => _baseUrl != null && _token != null;

  void configure(String ip, int port, String token) {
    _baseUrl = 'http://$ip:$port';
    _token = token;
  }

  void disconnect() {
    _baseUrl = null;
    _token = null;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'X-Pair-Token': _token!,
      };

  // --- Pairing ---

  Future<Map<String, dynamic>> pair(
      String ip, int port, String code, String deviceName) async {
    final url = 'http://$ip:$port/pair';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code, 'device_name': deviceName}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Pairing failed: ${response.body}');
  }

  Future<bool> healthCheck(String ip, int port) async {
    try {
      final response = await http
          .get(Uri.parse('http://$ip:$port/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // --- Usage Data ---

  Future<DailySummary> getDailySummary({String? date}) async {
    final query = date != null ? '?date=$date' : '';
    final response = await _get('/usage/summary/daily$query');
    return DailySummary.fromJson(response);
  }

  Future<List<DailySummary>> getWeeklySummary({String? weekStart}) async {
    final query = weekStart != null ? '?week_start=$weekStart' : '';
    final response = await _get('/usage/summary/weekly$query');
    return (response['days'] as List)
        .map((d) => DailySummary.fromJson(d))
        .toList();
  }

  Future<List<HourlyData>> getHourlyBreakdown({String? date}) async {
    final query = date != null ? '?date=$date' : '';
    final response = await _get('/usage/hourly$query');
    return (response['hours'] as List)
        .map((h) => HourlyData.fromJson(h))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getAllApps() async {
    final response = await _get('/usage/apps');
    return List<Map<String, dynamic>>.from(response['apps']);
  }

  Future<List<Map<String, dynamic>>> getAllDomains() async {
    final response = await _get('/usage/domains');
    return List<Map<String, dynamic>>.from(response['domains']);
  }

  Future<void> setAppCategory(String appName, String category) async {
    await _put('/usage/apps/$appName/category', {'category': category});
  }

  Future<Map<String, dynamic>> getCurrentWindow() async {
    return await _get('/usage/current');
  }

  // --- HTTP Helpers ---

  static const _timeout = Duration(seconds: 10);

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await http
        .get(Uri.parse('$_baseUrl$path'), headers: _headers)
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('API error ${response.statusCode}: ${response.body}');
  }

  Future<Map<String, dynamic>> _put(
      String path, Map<String, dynamic> body) async {
    final response = await http
        .put(Uri.parse('$_baseUrl$path'),
            headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('API error ${response.statusCode}: ${response.body}');
  }
}

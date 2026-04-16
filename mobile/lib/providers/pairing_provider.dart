import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device.dart';
import '../services/desktop_api_service.dart';
import '../config.dart';

enum PairingState { idle, pairing, error }

class PairingProvider extends ChangeNotifier {
  final DesktopApiService _api;
  PairingState _state = PairingState.idle;
  final List<ConnectedDevice> _devices = [];
  String? _errorMessage;

  PairingProvider(this._api) {
    _loadSavedDevices();
  }

  PairingState get state => _state;
  List<ConnectedDevice> get devices => List.unmodifiable(_devices);
  String? get errorMessage => _errorMessage;
  bool get hasDevices => _devices.isNotEmpty;
  bool get hasDesktop => _devices.any((d) => d.deviceType == 'desktop');

  List<ConnectedDevice> get desktops =>
      _devices.where((d) => d.deviceType == 'desktop').toList();
  List<ConnectedDevice> get phones =>
      _devices.where((d) => d.deviceType == 'phone' || d.deviceType == 'tablet').toList();

  Future<void> _loadSavedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final devicesJson = prefs.getStringList('connected_devices') ?? [];
    for (final json in devicesJson) {
      try {
        final device = ConnectedDevice.fromJson(jsonDecode(json));
        _devices.add(device);
      } catch (_) {
        // Skip corrupted entries
      }
    }
    // Re-save to clean out any corrupted entries
    if (_devices.length != devicesJson.length) {
      await _saveDevices();
    }
    // Configure API with first desktop if available
    _configureApiFromDevices();
    // Check which are online
    await checkDevicesOnline();
    notifyListeners();
  }

  Future<void> _saveDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _devices.map((d) => jsonEncode(d.toJson())).toList();
    await prefs.setStringList('connected_devices', jsonList);
  }

  void _configureApiFromDevices() {
    // Configure with all desktops
    final desktopDevices = _devices.where((d) =>
        d.deviceType == 'desktop' && d.ip != null && d.token != null);
    if (desktopDevices.isNotEmpty) {
      final d = desktopDevices.first;
      _api.configure(d.ip!, d.port ?? AppConfig.defaultPort, d.token!);
    }
  }

  Future<void> checkDevicesOnline() async {
    for (int i = 0; i < _devices.length; i++) {
      final d = _devices[i];
      if (d.ip != null && d.port != null) {
        final online = await _api.healthCheck(d.ip!, d.port!);
        _devices[i] = ConnectedDevice(
          deviceId: d.deviceId,
          deviceName: d.deviceName,
          deviceType: d.deviceType,
          ip: d.ip,
          port: d.port,
          token: d.token,
          isOnline: online,
        );
      }
    }
    notifyListeners();
  }

  Future<void> pairDesktop(String ip, String code) async {
    _state = PairingState.pairing;
    _errorMessage = null;
    notifyListeners();

    try {
      final port = AppConfig.defaultPort;
      final alive = await _api.healthCheck(ip, port);
      if (!alive) {
        _state = PairingState.error;
        _errorMessage = 'Cannot reach desktop at $ip:$port';
        notifyListeners();
        return;
      }

      final result = await _api.pair(ip, port, code, 'Android Phone');
      if (result['success'] == true) {
        final device = ConnectedDevice(
          deviceId: result['device_id'] ?? '',
          deviceName: result['device_name'] ?? 'Desktop',
          deviceType: result['device_type'] ?? 'desktop',
          ip: ip,
          port: port,
          token: result['token'],
          isOnline: true,
        );

        // Remove existing device with same ID if re-pairing
        _devices.removeWhere((d) => d.deviceId == device.deviceId);
        _devices.add(device);
        await _saveDevices();
        _configureApiFromDevices();
        _state = PairingState.idle;
      } else {
        _state = PairingState.error;
        _errorMessage = 'Pairing failed';
      }
    } catch (e) {
      _state = PairingState.error;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }
    notifyListeners();
  }

  /// Pair from QR code data (JSON string)
  Future<void> pairFromQr(String qrData) async {
    try {
      final data = jsonDecode(qrData);
      final ip = data['ip'] as String;
      final code = data['code'] as String;
      await pairDesktop(ip, code);
    } catch (e) {
      _state = PairingState.error;
      _errorMessage = 'Invalid QR code data';
      notifyListeners();
    }
  }

  Future<void> removeDevice(String deviceId) async {
    _devices.removeWhere((d) => d.deviceId == deviceId);
    await _saveDevices();
    _configureApiFromDevices();
    if (_devices.isEmpty) {
      _api.disconnect();
    }
    notifyListeners();
  }

  /// Get API service configured for a specific device
  DesktopApiService getApiForDevice(ConnectedDevice device) {
    final api = DesktopApiService();
    if (device.ip != null && device.token != null) {
      api.configure(device.ip!, device.port ?? AppConfig.defaultPort, device.token!);
    }
    return api;
  }
}

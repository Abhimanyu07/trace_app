class ConnectedDevice {
  final String deviceId;
  final String deviceName;
  final String deviceType; // 'desktop', 'phone', 'tablet'
  final String? ip;
  final int? port;
  final String? token;
  final bool isOnline;

  ConnectedDevice({
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    this.ip,
    this.port,
    this.token,
    this.isOnline = false,
  });

  factory ConnectedDevice.fromJson(Map<String, dynamic> json) {
    return ConnectedDevice(
      deviceId: json['device_id'] ?? '',
      deviceName: json['device_name'] ?? 'Unknown',
      deviceType: json['device_type'] ?? 'desktop',
      ip: json['ip'],
      port: json['port'],
      token: json['token'],
      isOnline: json['is_online'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'device_name': deviceName,
        'device_type': deviceType,
        'ip': ip,
        'port': port,
        'token': token,
      };

  String get displayIcon {
    switch (deviceType) {
      case 'desktop':
        return 'desktop';
      case 'tablet':
        return 'tablet';
      default:
        return 'phone';
    }
  }
}

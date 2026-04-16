import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/pairing_provider.dart';
import '../../providers/usage_provider.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _ipController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _ipController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pairDesktop() async {
    final ip = _ipController.text.trim();
    final code = _codeController.text.trim();
    if (ip.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter IP and pairing code')),
      );
      return;
    }

    final pairing = context.read<PairingProvider>();
    await pairing.pairDesktop(ip, code);

    if (pairing.state != PairingState.error && mounted) {
      context.read<UsageProvider>().refreshAll();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device connected!'),
          backgroundColor: AppColors.productive,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Device')),
      body: Consumer<PairingProvider>(
        builder: (context, pairing, _) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Device type selector
              const Text(
                'Add a new device',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Connect desktops, phones, or tablets to track usage across all your devices.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Desktop pairing
              _buildDeviceTypeCard(
                icon: Icons.desktop_mac_rounded,
                title: 'Desktop / Laptop',
                subtitle: 'Run the TraceYourLyf desktop app and enter the connection details',
                isExpanded: true,
              ),
              const SizedBox(height: 16),

              // How to connect
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _stepItem('1', 'Run the desktop app on your computer'),
                    const SizedBox(height: 10),
                    _stepItem('2', 'Check the menu bar icon for IP and code'),
                    const SizedBox(height: 10),
                    _stepItem('3', 'Enter them below'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _ipController,
                decoration: const InputDecoration(
                  hintText: 'Desktop IP (e.g., 192.168.1.100)',
                  prefixIcon: Icon(Icons.computer_rounded),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  hintText: '6-digit pairing code',
                  prefixIcon: Icon(Icons.pin_rounded),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              const SizedBox(height: 4),

              if (pairing.state == PairingState.error &&
                  pairing.errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.distraction.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.distraction, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pairing.errorMessage!,
                          style: const TextStyle(
                            color: AppColors.distraction,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: pairing.state == PairingState.pairing
                      ? null
                      : _pairDesktop,
                  icon: pairing.state == PairingState.pairing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.link_rounded),
                  label: Text(pairing.state == PairingState.pairing
                      ? 'Connecting...'
                      : 'Connect Desktop'),
                ),
              ),

              const SizedBox(height: 32),

              // Phone / Tablet section
              _buildDeviceTypeCard(
                icon: Icons.phone_android_rounded,
                title: 'Phone / Tablet',
                subtitle: 'Scan QR code from another device running Trace Your Lyf',
                isExpanded: false,
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Coming Soon',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Currently connected devices
              if (pairing.devices.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Text(
                  'Connected Devices',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ...pairing.devices.map((d) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: d.isOnline
                                ? AppColors.productive.withOpacity(0.15)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            d.deviceType == 'desktop'
                                ? Icons.desktop_mac_rounded
                                : Icons.phone_android_rounded,
                            color: d.isOnline
                                ? AppColors.productive
                                : AppColors.textTertiary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          d.deviceName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          d.isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 12,
                            color: d.isOnline
                                ? AppColors.productive
                                : AppColors.textTertiary,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: AppColors.distraction, size: 20),
                          onPressed: () => pairing.removeDevice(d.deviceId),
                        ),
                      ),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeviceTypeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isExpanded,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isExpanded ? AppColors.surface : AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded
              ? AppColors.primary.withOpacity(0.3)
              : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isExpanded
                  ? AppColors.primary.withOpacity(0.15)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                color: isExpanded ? AppColors.primary : AppColors.textTertiary,
                size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _stepItem(String num, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              num,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/usage_provider.dart';
import '../../providers/pairing_provider.dart';
import 'widgets/usage_bar_chart.dart';
import 'widgets/category_pie_chart.dart';
import 'widgets/weekly_comparison.dart';
import 'widgets/top_apps_list.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer2<UsageProvider, PairingProvider>(
        builder: (context, usage, pairing, _) {
          final hasAnyData = pairing.hasDevices || usage.hasPhonePermission;
          if (!hasAnyData) {
            return _buildUnpairedState(context, usage);
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => usage.refreshAll(),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Dashboard',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    _buildDeviceFilter(context, usage, pairing),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _todayLabel(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                // Phone permission banner
                if (!usage.hasPhonePermission)
                  _buildPhonePermissionBanner(context, usage),
                const SizedBox(height: 8),
                if (usage.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                else if (usage.error != null)
                  _buildErrorCard(context, usage)
                else ...[
                  _buildTotalTimeCard(usage),
                  const SizedBox(height: 16),
                  if (usage.hourlyData.isNotEmpty && !usage.isPhoneSelected) ...[
                    _buildSectionTitle('Hourly Activity'),
                    const SizedBox(height: 12),
                    UsageBarChart(hourlyData: usage.hourlyData),
                    const SizedBox(height: 24),
                  ],
                  _buildSectionTitle('Categories'),
                  const SizedBox(height: 12),
                  CategoryPieChart(summary: usage.todaySummary),
                  const SizedBox(height: 24),
                  _buildSectionTitle('This Week'),
                  const SizedBox(height: 12),
                  WeeklyComparison(weeklyData: usage.weeklyData),
                  const SizedBox(height: 24),
                  if (usage.allDomains.isNotEmpty) ...[
                    _buildSectionTitle('Top Websites'),
                    const SizedBox(height: 12),
                    _buildDomainsList(usage),
                    const SizedBox(height: 24),
                  ],
                  _buildSectionTitle('Top Apps'),
                  const SizedBox(height: 12),
                  TopAppsList(
                    apps: usage.todaySummary?.topApps ?? [],
                  ),
                  const SizedBox(height: 40),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeviceFilter(
      BuildContext context, UsageProvider usage, PairingProvider pairing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButton<String?>(
        value: usage.selectedDeviceId,
        underline: const SizedBox(),
        isDense: true,
        dropdownColor: AppColors.surface,
        icon: const Icon(Icons.keyboard_arrow_down,
            color: AppColors.textSecondary, size: 18),
        style: const TextStyle(
          fontFamily: 'Gilroy',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.devices, color: AppColors.primary, size: 16),
                SizedBox(width: 6),
                Text('All Devices'),
              ],
            ),
          ),
          const DropdownMenuItem<String?>(
            value: '__this_phone__',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phone_android_rounded,
                    color: AppColors.productive, size: 16),
                SizedBox(width: 6),
                Text('This Phone'),
              ],
            ),
          ),
          ...pairing.devices.map((d) => DropdownMenuItem<String?>(
                value: d.deviceId,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      d.deviceType == 'desktop'
                          ? Icons.desktop_mac_rounded
                          : d.deviceType == 'tablet'
                              ? Icons.tablet_rounded
                              : Icons.phone_android_rounded,
                      color: d.isOnline
                          ? AppColors.productive
                          : AppColors.textTertiary,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(d.deviceName.length > 12
                        ? '${d.deviceName.substring(0, 12)}...'
                        : d.deviceName),
                  ],
                ),
              )),
        ],
        onChanged: (deviceId) {
          usage.selectDevice(deviceId);
        },
      ),
    );
  }

  Widget _buildDomainsList(UsageProvider usage) {
    final domains = usage.allDomains.take(5).toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: List.generate(domains.length, (i) {
          final d = domains[i];
          final domain = d['domain'] ?? '';
          final totalSec = d['total_seconds'] ?? 0;
          final hours = totalSec ~/ 3600;
          final mins = (totalSec % 3600) ~/ 60;
          final duration = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Favicon
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        'https://www.google.com/s2/favicons?domain=$domain&sz=64',
                        width: 32,
                        height: 32,
                        errorBuilder: (_, __, ___) => Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.language,
                              color: AppColors.textTertiary, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        domain,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      duration,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < domains.length - 1)
                const Divider(height: 1, color: AppColors.divider),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPhonePermissionBanner(BuildContext context, UsageProvider usage) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_android_rounded,
              color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enable phone tracking',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Grant usage access to track phone screen time',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => usage.requestPhonePermission(),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  Widget _buildUnpairedState(BuildContext context, UsageProvider usage) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.devices_rounded,
              size: 64,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Get started',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enable phone tracking and connect your desktop to see your complete digital wellbeing picture.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        if (!usage.hasPhonePermission)
          _buildSetupCard(
            icon: Icons.phone_android_rounded,
            title: 'Enable Phone Tracking',
            subtitle: 'Track which apps you use on this phone',
            buttonText: 'Grant Access',
            onTap: () => usage.requestPhonePermission(),
          ),
        const SizedBox(height: 12),
        _buildSetupCard(
          icon: Icons.desktop_mac_rounded,
          title: 'Connect Desktop',
          subtitle: 'Track your computer usage too',
          buttonText: 'Add Desktop',
          onTap: () => Navigator.pushNamed(context, '/pairing'),
        ),
      ],
    );
  }

  Widget _buildSetupCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
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
                        color: AppColors.textTertiary, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalTimeCard(UsageProvider usage) {
    final summary = usage.todaySummary;
    final deviceLabel = usage.isPhoneSelected
        ? 'This phone today'
        : usage.selectedDeviceId != null
            ? 'This device today'
            : 'All devices today';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF252525)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Screen Time',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary?.formattedTotal ?? '0m',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            deviceLabel,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, UsageProvider usage) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded,
              color: AppColors.distraction, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Connection Error',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            usage.error ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => usage.refreshAll(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    final days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      'Sunday'
    ];
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct',
      'Nov', 'Dec'
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }
}

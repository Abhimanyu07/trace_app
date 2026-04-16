import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/usage_provider.dart';
import '../../providers/pairing_provider.dart';
import '../../models/app_category.dart';
import '../../widgets/app_icon_widget.dart';

class AppsListScreen extends StatefulWidget {
  const AppsListScreen({super.key});

  @override
  State<AppsListScreen> createState() => _AppsListScreenState();
}

class _AppsListScreenState extends State<AppsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer2<UsageProvider, PairingProvider>(
        builder: (context, usage, pairing, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text(
                  'Apps & Websites',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Classify to track your productivity',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Tab bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textTertiary,
                    labelStyle: const TextStyle(
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Applications'),
                      Tab(text: 'Websites'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!pairing.hasDevices && !usage.hasPhonePermission)
                const Expanded(
                  child: Center(
                    child: Text(
                      'Enable phone tracking or connect a desktop to see apps',
                      style: TextStyle(color: AppColors.textTertiary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAppsList(usage),
                      _buildDomainsList(usage),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppsList(UsageProvider usage) {
    if (usage.allApps.isEmpty) {
      return const Center(
        child: Text('No usage data yet',
            style: TextStyle(color: AppColors.textTertiary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: usage.allApps.length,
      itemBuilder: (context, index) {
        final app = usage.allApps[index];
        final cat =
            AppCategory.fromString(app['category'] ?? 'unclassified');
        final totalSec = app['total_seconds'] ?? 0;
        final duration = _formatDuration(totalSec);
        final appName = app['app_name'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: AppIconWidget(appName: appName, size: 40),
            title: Text(
              appName,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: Text(
              '${cat.label} \u2022 $duration',
              style: TextStyle(color: cat.color, fontSize: 12),
            ),
            trailing: _buildCategoryMenu(usage, appName),
          ),
        );
      },
    );
  }

  Widget _buildDomainsList(UsageProvider usage) {
    final domains = usage.allDomains;
    if (domains.isEmpty) {
      return const Center(
        child: Text('No website data yet',
            style: TextStyle(color: AppColors.textTertiary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: domains.length,
      itemBuilder: (context, index) {
        final d = domains[index];
        final domain = d['domain'] ?? '';
        final totalSec = d['total_seconds'] ?? 0;
        final duration = _formatDuration(totalSec);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                'https://www.google.com/s2/favicons?domain=$domain&sz=64',
                width: 40,
                height: 40,
                errorBuilder: (_, __, ___) => Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.language,
                      color: AppColors.textTertiary, size: 22),
                ),
              ),
            ),
            title: Text(
              domain,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              duration,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryMenu(UsageProvider usage, String appName) {
    return PopupMenuButton<String>(
      icon:
          const Icon(Icons.more_vert, color: AppColors.textTertiary),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (category) => usage.setAppCategory(appName, category),
      itemBuilder: (context) => [
        _menuItem(
            'productive', 'Productive', AppColors.productive, Icons.trending_up),
        _menuItem('neutral', 'Neutral', AppColors.neutral, Icons.remove),
        _menuItem('distraction', 'Distraction', AppColors.distraction,
            Icons.trending_down),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, String label, Color color, IconData icon) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';

class StreakGoal {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  int currentStreak;
  int bestStreak;

  StreakGoal({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.currentStreak = 0,
    this.bestStreak = 0,
  });
}

class StreaksScreen extends StatefulWidget {
  const StreaksScreen({super.key});

  @override
  State<StreaksScreen> createState() => _StreaksScreenState();
}

class _StreaksScreenState extends State<StreaksScreen> {
  late List<StreakGoal> _goals;
  final Set<String> _activeGoals = {};

  @override
  void initState() {
    super.initState();
    _goals = [
      StreakGoal(
        id: 'under_4h',
        title: 'Under 4 hours',
        description: 'Total screen time under 4 hours',
        icon: Icons.timer_outlined,
      ),
      StreakGoal(
        id: 'under_2h_distraction',
        title: 'Low distractions',
        description: 'Distraction apps under 2 hours',
        icon: Icons.do_not_disturb_alt_rounded,
      ),
      StreakGoal(
        id: 'productive_50',
        title: '50% productive',
        description: 'At least half your time is productive',
        icon: Icons.trending_up_rounded,
      ),
      StreakGoal(
        id: 'no_phone_after_10',
        title: 'Digital sunset',
        description: 'No screen time after 10 PM',
        icon: Icons.nightlight_round,
      ),
      StreakGoal(
        id: 'under_6h',
        title: 'Under 6 hours',
        description: 'Total screen time under 6 hours',
        icon: Icons.access_time_rounded,
      ),
      StreakGoal(
        id: 'break_every_hour',
        title: 'Regular breaks',
        description: 'Take a break every hour',
        icon: Icons.coffee_rounded,
      ),
    ];
    _loadStreaks();
  }

  Future<void> _loadStreaks() async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getStringList('active_goals') ?? [];
    setState(() {
      _activeGoals.addAll(active);
      for (final goal in _goals) {
        goal.currentStreak = prefs.getInt('streak_${goal.id}_current') ?? 0;
        goal.bestStreak = prefs.getInt('streak_${goal.id}_best') ?? 0;
      }
    });
  }

  Future<void> _toggleGoal(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_activeGoals.contains(id)) {
        _activeGoals.remove(id);
      } else {
        _activeGoals.add(id);
      }
    });
    await prefs.setStringList('active_goals', _activeGoals.toList());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Streaks',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Set goals and build healthy habits',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          // Active streaks summary
          if (_activeGoals.isNotEmpty) ...[
            _buildActiveStreaksSummary(),
            const SizedBox(height: 24),
          ],
          const Text(
            'Goals',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(_goals.length, (i) {
            final goal = _goals[i];
            final isActive = _activeGoals.contains(goal.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildGoalCard(goal, isActive),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActiveStreaksSummary() {
    final activeGoalsList =
        _goals.where((g) => _activeGoals.contains(g.id)).toList();
    final totalStreak = activeGoalsList.fold<int>(
        0, (sum, g) => sum + g.currentStreak);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.2),
            AppColors.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: AppColors.streak,
            size: 48,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$totalStreak',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.streak,
                ),
              ),
              Text(
                '${activeGoalsList.length} active goals',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(StreakGoal goal, bool isActive) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? AppColors.surface : AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppColors.primary.withOpacity(0.4)
              : AppColors.divider,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _toggleGoal(goal.id),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary.withOpacity(0.15)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    goal.icon,
                    color: isActive ? AppColors.primary : AppColors.textTertiary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        goal.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive && goal.currentStreak > 0) ...[
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: AppColors.streak,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${goal.currentStreak}',
                    style: const TextStyle(
                      color: AppColors.streak,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  isActive
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: isActive ? AppColors.primary : AppColors.textTertiary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/constants/app_constants.dart';
import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/core/widgets/app_logo.dart';
import 'package:arrow_drift/data/repositories/level_repository.dart';
import 'package:arrow_drift/data/repositories/progress_repository.dart';
import 'package:arrow_drift/features/daily_challenge/daily_challenge_screen.dart';
import 'package:arrow_drift/features/gameplay/gameplay_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const String routePath = '/home';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final currentLevelAsync = ref.watch(currentLevelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            children: [
              _TopBar(
                isDark: isDark,
                onToggleTheme: () => _toggleTheme(ref, context),
              ),
              const SizedBox(height: 28),
              const _BrandBlock(),
              const SizedBox(height: 28),
              _DailyChallengeCard(
                onPlay: () => context.go(DailyChallengeScreen.routePath),
              ),
              const Spacer(),
              currentLevelAsync.when(
                data: (level) {
                  final levelCount =
                      ref.watch(levelRepositoryProvider).levelCount;
                  final resumeLevel =
                      level > levelCount ? levelCount : level;
                  return _ContinueButton(
                    level: resumeLevel,
                    onPressed: () => context.push(
                      '${GameplayScreen.routePath}?level=$resumeLevel',
                    ),
                  );
                },
                loading: () => _ContinueButton(
                  level: 1,
                  onPressed: () => context.push(
                    '${GameplayScreen.routePath}?level=1',
                  ),
                ),
                error: (_, _) => _ContinueButton(
                  level: 1,
                  onPressed: () => context.push(
                    '${GameplayScreen.routePath}?level=1',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleTheme(WidgetRef ref, BuildContext context) {
    final mode = ref.read(themeModeProvider);
    final brightness = Theme.of(context).brightness;

    if (mode == ThemeMode.system) {
      ref.read(themeModeProvider.notifier).state =
          brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
      return;
    }

    ref.read(themeModeProvider.notifier).state =
        mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isDark,
    required this.onToggleTheme,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        const AppLogoMark(size: 36),
        const Spacer(),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggleTheme,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    size: 16,
                    color: colors.secondaryText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isDark ? 'Dark' : 'Light',
                    style: AppTextStyles.label(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      children: [
        const AppLogoMark(size: 96),
        const SizedBox(height: 18),
        Text(
          AppConstants.appName,
          textAlign: TextAlign.center,
          style: AppTextStyles.heading(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: colors.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap free arrows. Clear the board.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: colors.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _DailyChallengeCard extends StatelessWidget {
  const _DailyChallengeCard({required this.onPlay});

  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final today = _formatDate(DateTime.now());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.accentTealSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: colors.accentTealDeep,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Challenge',
                  style: AppTextStyles.body(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  today,
                  style: AppTextStyles.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPlay,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.accentTealSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.accentTeal.withValues(alpha: 0.35),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  'Play',
                  style: AppTextStyles.button(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.accentTealDeep,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.level,
    required this.onPressed,
  });

  final int level;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: colors.accentTeal,
        borderRadius: BorderRadius.circular(40),
        elevation: 2,
        shadowColor: colors.accentTeal.withValues(alpha: 0.35),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(40),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
              child: Text(
                'Level $level',
                textAlign: TextAlign.center,
                style: AppTextStyles.button(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.lightPrimaryText,
                ),
              ),
            ),
        ),
      ),
    );
  }
}

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
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          gradient: RadialGradient(
            center: const Alignment(0.85, -0.85),
            radius: 1.1,
            colors: [
              colors.accentTeal.withValues(alpha: isDark ? 0.14 : 0.14),
              colors.background,
            ],
            stops: const [0.0, 0.45],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              children: [
                _TopBar(
                  isDark: isDark,
                  onToggleTheme: () => _toggleTheme(ref, context),
                ),
                const SizedBox(height: 36),
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
                color: isDark
                    ? colors.surface2
                    : Colors.white.withValues(alpha: 0.75),
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
                      fontWeight: FontWeight.w700,
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
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: colors.primaryText,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap free arrows. Clear the board.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(
            fontSize: 14,
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
    final today = _formatDate(DateTime.now());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF128F7A), Color(0xFF0B5E52)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B5E52).withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY CHALLENGE',
                      style: AppTextStyles.label(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      today,
                      style: AppTextStyles.body(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  'Play',
                  style: AppTextStyles.button(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
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
    return '${months[date.month - 1]} ${date.day}';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isDark ? null : AppColors.lightPrimaryText,
              gradient: isDark
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.accentTeal, AppColors.accentTealDeep],
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: (isDark ? AppColors.accentTealDeep : AppColors.lightPrimaryText)
                      .withValues(alpha: isDark ? 0.28 : 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'Level $level',
                style: AppTextStyles.button(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

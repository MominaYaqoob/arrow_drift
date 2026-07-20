import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/core/utils/online_gate.dart';
import 'package:arrow_drift/core/widgets/app_logo.dart';
import 'package:arrow_drift/data/repositories/level_repository.dart';
import 'package:arrow_drift/data/repositories/progress_repository.dart';
import 'package:arrow_drift/data/repositories/settings_repository.dart';
import 'package:arrow_drift/features/daily_challenge/daily_challenge_screen.dart';
import 'package:arrow_drift/features/gameplay/gameplay_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const String routePath = '/home';

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int? _prefetchedForLevel;

  void _prefetchAround(int level) {
    if (_prefetchedForLevel == level) return;
    _prefetchedForLevel = level;
    final count = ref.read(levelRepositoryProvider).levelCount;
    final resume = level > count ? count : level;
    ref.read(levelRepositoryProvider).prefetchLevels([
      resume,
      if (resume < count) resume + 1,
    ]);
  }

  Future<void> _openWhenOnline(
    BuildContext context,
    WidgetRef ref,
    VoidCallback open,
  ) async {
    final online = await requireOnline(ref);
    if (!context.mounted) return;
    if (!online) {
      await showNoInternetDialog(context);
      return;
    }
    open();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currentLevelAsync = ref.watch(currentLevelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(currentLevelProvider, (previous, next) {
      next.whenData(_prefetchAround);
    });
    currentLevelAsync.whenData(_prefetchAround);

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tight = constraints.maxHeight < 580;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        _TopBar(
                          isDark: isDark,
                          onToggleTheme: () => _toggleTheme(ref, context),
                        ),
                        SizedBox(height: tight ? 12 : 22),
                        const _BrandBlock(),
                        SizedBox(height: tight ? 14 : 22),
                        _DailyChallengeCard(
                          onPlay: () => _openWhenOnline(
                            context,
                            ref,
                            () => context.go(DailyChallengeScreen.routePath),
                          ),
                        ),
                        SizedBox(height: tight ? 18 : 28),
                        const Spacer(),
                        currentLevelAsync.when(
                          data: (level) {
                            final levelCount =
                                ref.watch(levelRepositoryProvider).levelCount;
                            final resumeLevel =
                                level > levelCount ? levelCount : level;
                            return _ContinueButton(
                              level: resumeLevel,
                              onPressed: () => _openWhenOnline(
                                context,
                                ref,
                                () => context.push(
                                  '${GameplayScreen.routePath}?level=$resumeLevel',
                                ),
                              ),
                            );
                          },
                          loading: () => _ContinueButton(
                            level: 1,
                            onPressed: () => _openWhenOnline(
                              context,
                              ref,
                              () => context.push(
                                '${GameplayScreen.routePath}?level=1',
                              ),
                            ),
                          ),
                          error: (_, _) => _ContinueButton(
                            level: 1,
                            onPressed: () => _openWhenOnline(
                              context,
                              ref,
                              () => context.push(
                                '${GameplayScreen.routePath}?level=1',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _toggleTheme(WidgetRef ref, BuildContext context) {
    final mode = ref.read(themeModeProvider);
    final brightness = Theme.of(context).brightness;

    late final ThemeMode next;
    if (mode == ThemeMode.system) {
      next = brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    } else {
      next = mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    }

    ref.read(themeModeProvider.notifier).state = next;
    // Keep Settings Dark Theme toggle / prefs in sync.
    final settings = ref.read(settingsProvider).valueOrNull;
    if (settings != null) {
      ref.read(settingsProvider.notifier).setDarkTheme(next == ThemeMode.dark);
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: colors.accentTeal.withValues(alpha: isDark ? 0.22 : 0.14),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const AppLogoMark(size: 88),
        ),
        const SizedBox(height: 16),
        Text(
          'Arrow Drift:',
          textAlign: TextAlign.center,
          style: AppTextStyles.heading(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: colors.primaryText,
            letterSpacing: -0.4,
          ),
        ),
        Text(
          'Puzzle Game',
          textAlign: TextAlign.center,
          style: AppTextStyles.heading(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: colors.primaryText,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap free arrows. Clear the board.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _DailyChallengeCard extends ConsumerWidget {
  const _DailyChallengeCard({required this.onPlay});

  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = _formatDate(DateTime.now());
    final streak = ref.watch(currentStreakProvider).valueOrNull ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF14A08A), Color(0xFF0B5E52)],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B5E52).withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 10),
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
                        color: Colors.white.withValues(alpha: 0.82),
                      ).copyWith(letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      today,
                      style: AppTextStyles.body(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: 14,
                            color: streak > 0
                                ? const Color(0xFFFFC857)
                                : Colors.white.withValues(alpha: 0.75),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            streak > 0
                                ? '$streak day streak'
                                : 'No streak yet',
                            style: AppTextStyles.label(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Play',
                  style: AppTextStyles.button(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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
      height: 54,
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
                  color: (isDark
                          ? AppColors.accentTealDeep
                          : AppColors.lightPrimaryText)
                      .withValues(alpha: isDark ? 0.3 : 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
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

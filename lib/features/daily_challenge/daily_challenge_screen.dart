import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/core/widgets/coin_balance_pill.dart';
import 'package:arrow_drift/data/repositories/level_repository.dart';
import 'package:arrow_drift/data/repositories/progress_repository.dart';
import 'package:arrow_drift/features/gameplay/gameplay_screen.dart';
import 'package:arrow_drift/features/home/home_screen.dart';

/// Daily Challenges hub — swipeable calendar + same gameplay as campaign.
class DailyChallengeScreen extends ConsumerStatefulWidget {
  const DailyChallengeScreen({super.key});

  static const String routePath = '/daily-challenge';

  @override
  ConsumerState<DailyChallengeScreen> createState() =>
      _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends ConsumerState<DailyChallengeScreen> {
  /// Past: only 1 month back. Future months stay swipeable.
  static const int _monthsBack = 1;
  static const int _monthsForward = 24;
  static const int _centerPage = _monthsBack; // current month index

  late final PageController _pageController;
  late int _pageIndex;

  @override
  void initState() {
    super.initState();
    _pageIndex = _centerPage;
    _pageController = PageController(initialPage: _centerPage);
    // Do NOT prefetch daily boards here — generation is heavy and freezes
    // the calendar (especially on web). Load starts on the Daily loader screen.
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime get _now => DateTime.now();

  DateTime _monthForPage(int page) {
    final delta = page - _centerPage;
    return DateTime(_now.year, _now.month + delta);
  }

  int _starsForMonth(Set<String> completed, DateTime month) {
    final prefix =
        '${month.year}-${month.month.toString().padLeft(2, '0')}-';
    return completed.where((k) => k.startsWith(prefix)).length;
  }

  void _openDaily(DateTime selected) {
    final today = DateTime(_now.year, _now.month, _now.day);
    final day = DateTime(selected.year, selected.month, selected.day);

    // Future days stay faded; no bottom snackbar.
    if (day.isAfter(today)) return;

    // Instant navigation — all board wait happens on the Daily loader screen.
    ScaffoldMessenger.of(context).clearSnackBars();
    final key = dailyDateKey(day);
    context.push('${GameplayScreen.routePath}?daily=1&date=$key');
  }

  @override
  Widget build(BuildContext context) {
    final completed = ref.watch(completedDailyDatesProvider).valueOrNull ?? {};
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todayStars = _starsForMonth(
      completed,
      DateTime(_now.year, _now.month),
    );
    final daysInThisMonth = DateTime(_now.year, _now.month + 1, 0).day;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    Color(0xFF0A3F38),
                    Color(0xFF0A3F38),
                    Color(0xFF121A26),
                    Color(0xFF0A101A),
                  ]
                : const [
                    Color(0xFF0B5E52),
                    Color(0xFF0B5E52),
                    Color(0xFFEAF6F2),
                    Color(0xFFF6F3EC),
                  ],
            stops: const [0.0, 0.22, 0.22, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DailyHero(
                        onBack: () => context.go(HomeScreen.routePath),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -28),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _CalendarPager(
                            controller: _pageController,
                            pageCount: _monthsBack + 1 + _monthsForward,
                            completedKeys: completed,
                            now: _now,
                            monthForPage: _monthForPage,
                            starsForMonth: (month) =>
                                _starsForMonth(completed, month),
                            onPageChanged: (page) {
                              setState(() => _pageIndex = page);
                            },
                            onDayTap: _openDaily,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  children: [
                    _DailyTip(
                      stars: todayStars,
                      daysInMonth: daysInThisMonth,
                    ),
                    const SizedBox(height: 10),
                    _PlayTodayButton(
                      dateLabel: _shortDate(_now),
                      onPressed: () => _openDaily(_now),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortDate(DateTime date) {
    const months = [
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

class _DailyHero extends StatelessWidget {
  const _DailyHero({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.4, -1),
          end: Alignment(0.6, 1),
          colors: [Color(0xFF14A089), Color(0xFF0B5E52), Color(0xFF08463D)],
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                Text(
                  'Daily Challenges',
                  style: AppTextStyles.body(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: CoinBalancePill(),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Collect stars · unlock monthly trophy',
            style: AppTextStyles.label(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              size: 36,
              color: Color(0xFFE0B13A),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarPager extends StatelessWidget {
  const _CalendarPager({
    required this.controller,
    required this.pageCount,
    required this.completedKeys,
    required this.now,
    required this.monthForPage,
    required this.starsForMonth,
    required this.onPageChanged,
    required this.onDayTap,
  });

  final PageController controller;
  final int pageCount;
  final Set<String> completedKeys;
  final DateTime now;
  final DateTime Function(int page) monthForPage;
  final int Function(DateTime month) starsForMonth;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    // Height: header + weekdays + up to 6 rows of day cells.
    return SizedBox(
      height: 360,
      child: PageView.builder(
        controller: controller,
        itemCount: pageCount,
        onPageChanged: onPageChanged,
        itemBuilder: (context, page) {
          final month = monthForPage(page);
          final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
          return _CalendarCard(
            year: month.year,
            month: month.month,
            now: now,
            stars: starsForMonth(month),
            daysInMonth: daysInMonth,
            completedKeys: completedKeys,
            onDayTap: onDayTap,
          );
        },
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.year,
    required this.month,
    required this.now,
    required this.stars,
    required this.daysInMonth,
    required this.completedKeys,
    required this.onDayTap,
  });

  final int year;
  final int month;
  final DateTime now;
  final int stars;
  final int daysInMonth;
  final Set<String> completedKeys;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final first = DateTime(year, month, 1);
    final startOffset = first.weekday % 7;
    final itemCount = startOffset + daysInMonth;
    final rowCount = (itemCount / 7).ceil();
    const weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    const months = [
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

    final today = DateTime(now.year, now.month, now.day);

    return Material(
      color: isDark ? colors.surface : Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.1),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  '${months[month - 1]} $year',
                  style: AppTextStyles.body(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.primaryText,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.lightGold.withValues(alpha: 0.12)
                        : const Color(0xFFFFF6D9),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isDark
                          ? AppColors.lightGold.withValues(alpha: 0.28)
                          : const Color(0xFFF0E0A8),
                    ),
                  ),
                  child: Text(
                    '★ $stars/$daysInMonth',
                    style: AppTextStyles.label(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.lightGold
                          : const Color(0xFFB8860B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Swipe months · past only 1 month · tap a day to play',
              style: AppTextStyles.label(
                fontSize: 11,
                color: colors.secondaryText,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final label in weekdays)
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: AppTextStyles.label(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.secondaryText,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rowCount * 7,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemBuilder: (context, index) {
                  if (index < startOffset ||
                      index >= startOffset + daysInMonth) {
                    return const SizedBox.shrink();
                  }
                  final day = index - startOffset + 1;
                  final date = DateTime(year, month, day);
                  final key = dailyDateKey(date);
                  final filled = completedKeys.contains(key);
                  final isToday = date.year == today.year &&
                      date.month == today.month &&
                      date.day == today.day;
                  final isFuture = date.isAfter(today);
                  final isPlayable = !isFuture;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => onDayTap(date),
                      child: Center(
                        child: Opacity(
                          opacity: isFuture ? 0.35 : 1,
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isToday
                                  ? AppColors.accentTealDeep
                                  : filled
                                      ? AppColors.lightGold
                                          .withValues(alpha: 0.18)
                                      : Colors.transparent,
                              border: filled && !isToday
                                  ? Border.all(
                                      color: AppColors.lightGold
                                          .withValues(alpha: 0.55),
                                    )
                                  : null,
                              boxShadow: isToday
                                  ? [
                                      BoxShadow(
                                        color: AppColors.accentTealDeep
                                            .withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              '$day',
                              style: AppTextStyles.label(
                                fontSize: 13,
                                fontWeight: isToday || filled
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isToday
                                    ? Colors.white
                                    : filled
                                        ? AppColors.lightGold
                                        : isPlayable
                                            ? colors.primaryText
                                            : colors.secondaryText,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyTip extends StatelessWidget {
  const _DailyTip({required this.stars, required this.daysInMonth});

  final int stars;
  final int daysInMonth;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: isDark ? colors.surface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's puzzle is ready",
                  style: AppTextStyles.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Complete today\'s challenge to keep your streak. Timer runs until midnight — miss the day = reset.',
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: colors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF6D9), Color(0xFFF8E7A8)],
              ),
              border: Border.all(color: const Color(0xFFF0E0A8)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('★',
                    style: TextStyle(fontSize: 14, color: Color(0xFFB8860B))),
                Text(
                  '$stars/$daysInMonth',
                  style: AppTextStyles.label(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFB8860B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayTodayButton extends StatelessWidget {
  const _PlayTodayButton({
    required this.dateLabel,
    required this.onPressed,
  });

  final String dateLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accentTeal, AppColors.accentTealDeep],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentTealDeep.withValues(alpha: 0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Play Today',
                  style: AppTextStyles.button(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$dateLabel · Daily Challenge',
                  style: AppTextStyles.label(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/data/repositories/progress_repository.dart';

/// Awards — monthly progress cards + Events empty state (theme-aware).
class AwardsScreen extends ConsumerStatefulWidget {
  const AwardsScreen({super.key});

  static const String routePath = '/awards';

  @override
  ConsumerState<AwardsScreen> createState() => _AwardsScreenState();
}

class _AwardsScreenState extends ConsumerState<AwardsScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(
            Icons.chevron_left_rounded,
            color: colors.primaryText,
            size: 32,
          ),
        ),
        title: Text(
          'Awards',
          style: AppTextStyles.body(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: colors.primaryText,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 8, 48, 16),
            child: Container(
              height: 40,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: colors.surface2,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  _Segment(
                    label: 'Daily',
                    selected: _tabIndex == 0,
                    onTap: () => setState(() => _tabIndex = 0),
                  ),
                  _Segment(
                    label: 'Events',
                    selected: _tabIndex == 1,
                    onTap: () => setState(() => _tabIndex = 1),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _tabIndex == 0
                ? const _DailyAwardsTab()
                : const _EventsEmptyState(),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Material(
        color: selected
            ? (isDark ? colors.accentTealDeep : const Color(0xFF0E1726))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.label(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : colors.secondaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyAwardsTab extends ConsumerWidget {
  const _DailyAwardsTab();

  static const _months = [
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final now = DateTime.now();
    final year = now.year;
    final completed = ref.watch(completedDailyDatesProvider).valueOrNull ?? {};

    // Current month first, then up to 2 previous months.
    final monthsToShow = <int>[];
    for (var i = 0; i < 3; i++) {
      final m = now.month - i;
      if (m >= 1) monthsToShow.add(m);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            '$year',
            style: AppTextStyles.heading(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: colors.primaryText,
            ),
          ),
        ),
        for (var i = 0; i < monthsToShow.length; i++) ...[
          _MonthProgressCard(
            monthName: _months[monthsToShow[i] - 1],
            earned: _starsForMonth(completed, year, monthsToShow[i]),
            total: DateTime(year, monthsToShow[i] + 1, 0).day,
            isCurrent: i == 0,
          ),
          if (i != monthsToShow.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  int _starsForMonth(Set<String> completed, int year, int month) {
    final prefix = '$year-${month.toString().padLeft(2, '0')}-';
    return completed.where((k) => k.startsWith(prefix)).length;
  }
}

class _MonthProgressCard extends StatelessWidget {
  const _MonthProgressCard({
    required this.monthName,
    required this.earned,
    required this.total,
    required this.isCurrent,
  });

  final String monthName;
  final int earned;
  final int total;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = total == 0 ? 0.0 : (earned / total).clamp(0.0, 1.0);
    final dimmed = !isCurrent && earned == 0;
    final ringColor = dimmed ? colors.border : AppColors.accentTeal;

    return Opacity(
      opacity: dimmed ? 0.7 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: isDark ? Border.all(color: colors.border) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark
                    ? (isCurrent ? 0.28 : 0.18)
                    : (isCurrent ? 0.06 : 0.03),
              ),
              blurRadius: isCurrent ? 12 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            _ProgressRing(
              progress: progress,
              ringColor: ringColor,
              dimmed: dimmed,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    monthName,
                    style: AppTextStyles.heading(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$earned of $total days',
                    style: AppTextStyles.body(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.progress,
    required this.ringColor,
    required this.dimmed,
  });

  final double progress;
  final Color ringColor;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SizedBox(
      width: 64,
      height: 64,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          ringColor: ringColor,
          trackColor: colors.surface2,
        ),
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              size: 22,
              color: dimmed ? colors.secondaryText : AppColors.accentTealDeep,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
  });

  final double progress;
  final Color ringColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = 5.5;
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    final fill = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.trackColor != trackColor;
  }
}

class _EventsEmptyState extends StatelessWidget {
  const _EventsEmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              size: 88,
              color: AppColors.accentTeal.withValues(alpha: 0.28),
            ),
            const SizedBox(height: 20),
            Text(
              'You have no awards yet',
              textAlign: TextAlign.center,
              style: AppTextStyles.heading(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.primaryText,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Take part in events and collect unique rewards. Stay tuned!',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

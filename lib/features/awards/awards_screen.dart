import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/data/repositories/progress_repository.dart';

/// Awards — Daily monthly trophies + Events empty state (teal accents).
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
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: AppColors.accentTeal,
            size: 32,
          ),
        ),
        title: Text(
          'Awards',
          style: AppTextStyles.heading(
            fontSize: 20,
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
    return Expanded(
      child: Material(
        color: selected ? AppColors.accentTeal : Colors.transparent,
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
    final now = DateTime.now();
    final year = now.year;
    final completed = ref.watch(completedDailyDatesProvider).valueOrNull ?? {};
    final colors = context.appColors;

    // Show current month and up to 2 previous months (like the reference).
    final monthsToShow = <int>[];
    for (var i = 0; i < 3; i++) {
      final m = now.month - i;
      if (m >= 1) monthsToShow.add(m);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          '$year',
          style: AppTextStyles.heading(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: colors.primaryText,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final month in monthsToShow) ...[
              Expanded(
                child: _MonthTrophy(
                  monthName: _months[month - 1],
                  earned: _starsForMonth(completed, year, month),
                  total: DateTime(year, month + 1, 0).day,
                  styleIndex: month,
                ),
              ),
              if (month != monthsToShow.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  int _starsForMonth(Set<String> completed, int year, int month) {
    final prefix =
        '$year-${month.toString().padLeft(2, '0')}-';
    return completed.where((k) => k.startsWith(prefix)).length;
  }
}

class _MonthTrophy extends StatelessWidget {
  const _MonthTrophy({
    required this.monthName,
    required this.earned,
    required this.total,
    required this.styleIndex,
  });

  final String monthName;
  final int earned;
  final int total;
  final int styleIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final progress = total == 0 ? 0.0 : (earned / total).clamp(0.0, 1.0);
    final earnedAll = earned >= total && total > 0;

    return Column(
      children: [
        SizedBox(
          height: 88,
          child: Center(
            child: Opacity(
              opacity: earnedAll ? 1 : 0.35,
              child: CustomPaint(
                size: const Size(72, 88),
                painter: _AwardTrophyPainter(
                  ornate: styleIndex.isEven,
                  gold: earnedAll,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          monthName,
          style: AppTextStyles.body(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: colors.border,
            color: earnedAll ? AppColors.lightGold : colors.secondaryText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$earned of $total',
          style: AppTextStyles.label(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _AwardTrophyPainter extends CustomPainter {
  const _AwardTrophyPainter({required this.ornate, required this.gold});

  final bool ornate;
  final bool gold;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final base = gold
        ? const [Color(0xFFFFD56A), Color(0xFFE0B13A), Color(0xFFB8860B)]
        : const [Color(0xFFC5CAD3), Color(0xFF9AA3B0), Color(0xFF7A8494)];

    final cupPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: base,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final cup = Path()
      ..moveTo(w * 0.28, h * 0.08)
      ..quadraticBezierTo(w * 0.22, h * 0.36, w * 0.34, h * 0.46)
      ..lineTo(w * 0.66, h * 0.46)
      ..quadraticBezierTo(w * 0.78, h * 0.36, w * 0.72, h * 0.08)
      ..close();
    canvas.drawPath(cup, cupPaint);

    final handle = Paint()
      ..color = base[1]
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    if (ornate) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(w * 0.22, h * 0.26),
          width: w * 0.26,
          height: h * 0.28,
        ),
        0.4,
        2.2,
        false,
        handle,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(w * 0.78, h * 0.26),
          width: w * 0.26,
          height: h * 0.28,
        ),
        -0.4,
        -2.2,
        false,
        handle,
      );
    } else {
      canvas.drawLine(
        Offset(w * 0.28, h * 0.14),
        Offset(w * 0.14, h * 0.14),
        handle,
      );
      canvas.drawLine(
        Offset(w * 0.14, h * 0.14),
        Offset(w * 0.14, h * 0.38),
        handle,
      );
      canvas.drawLine(
        Offset(w * 0.14, h * 0.38),
        Offset(w * 0.34, h * 0.38),
        handle,
      );
      canvas.drawLine(
        Offset(w * 0.72, h * 0.14),
        Offset(w * 0.86, h * 0.14),
        handle,
      );
      canvas.drawLine(
        Offset(w * 0.86, h * 0.14),
        Offset(w * 0.86, h * 0.38),
        handle,
      );
      canvas.drawLine(
        Offset(w * 0.86, h * 0.38),
        Offset(w * 0.66, h * 0.38),
        handle,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.54),
          width: w * 0.2,
          height: h * 0.05,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = base[1],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.66),
          width: w * 0.1,
          height: h * 0.14,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = base[2],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.84),
          width: w * 0.42,
          height: h * 0.1,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = base[1],
    );
  }

  @override
  bool shouldRepaint(covariant _AwardTrophyPainter oldDelegate) {
    return oldDelegate.ornate != ornate || oldDelegate.gold != gold;
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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/data/repositories/progress_repository.dart';
import 'package:arrow_drift/features/gameplay/gameplay_screen.dart';
import 'package:arrow_drift/features/home/home_screen.dart';

/// Daily Challenges hub — teal header, calendar, Play → seeded daily level.
class DailyChallengeScreen extends ConsumerWidget {
  const DailyChallengeScreen({super.key});

  static const String routePath = '/daily-challenge';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final stars = ref.watch(monthlyDailyStarsProvider).valueOrNull ?? 0;
    final completed = ref.watch(completedDailyDatesProvider).valueOrNull ?? {};
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DailyHeader(
                    onBack: () => context.go(HomeScreen.routePath),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
                    child: Row(
                      children: [
                        Text(
                          _monthLabel(now),
                          style: AppTextStyles.heading(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colors.primaryText,
                          ),
                        ),
                        const Spacer(),
                        const _StarBadge(),
                        const SizedBox(width: 8),
                        Text(
                          '$stars/$daysInMonth',
                          style: AppTextStyles.body(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _MonthCalendar(
                      year: now.year,
                      month: now.month,
                      today: now.day,
                      completedKeys: completed,
                      onDayTap: (day) {
                        if (day != now.day) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Only today's challenge is available"),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: () => context.push(
                          '${GameplayScreen.routePath}?daily=1',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accentTeal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'Play',
                          style: AppTextStyles.button(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _monthLabel(DateTime date) {
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
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _DailyHeader extends StatelessWidget {
  const _DailyHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final height = MediaQuery.sizeOf(context).height * 0.30;

    return SizedBox(
      height: height + top,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.15),
                  radius: 1.05,
                  colors: [
                    Color(0xFF7EEFD8),
                    Color(0xFF2EC4A6),
                    Color(0xFF0F8F7A),
                    Color(0xFF0A6B5C),
                  ],
                  stops: [0.0, 0.35, 0.7, 1.0],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: CustomPaint(painter: _BokehPainter())),
          Positioned(
            top: top + 4,
            left: 4,
            right: 4,
            child: SizedBox(
              height: 48,
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
                        size: 34,
                      ),
                    ),
                  ),
                  Text(
                    'Daily Challenges',
                    style: AppTextStyles.heading(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 18,
            child: Center(
              child: SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.45),
                            Colors.white.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    const CustomPaint(
                      size: Size(88, 96),
                      painter: _TrophyPainter(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarBadge extends StatelessWidget {
  const _StarBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD56A), Color(0xFFE0B13A)],
        ),
      ),
      child: const Icon(Icons.star_rounded, size: 16, color: Colors.white),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.year,
    required this.month,
    required this.today,
    required this.completedKeys,
    required this.onDayTap,
  });

  final int year;
  final int month;
  final int today;
  final Set<String> completedKeys;
  final ValueChanged<int> onDayTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final first = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startOffset = first.weekday % 7; // Sunday-first
    final itemCount = startOffset + daysInMonth;
    final rowCount = (itemCount / 7).ceil();
    const weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Column(
      children: [
        Row(
          children: [
            for (final label in weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: AppTextStyles.label(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.secondaryText,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rowCount * 7,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 4,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) {
            if (index < startOffset || index >= startOffset + daysInMonth) {
              return const SizedBox.shrink();
            }
            final day = index - startOffset + 1;
            final key =
                '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
            final filled = completedKeys.contains(key);
            final isToday = day == today;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onDayTap(day),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isToday ? AppColors.accentTeal : Colors.transparent,
                    ),
                    child: Text(
                      '$day',
                      style: AppTextStyles.label(
                        fontSize: 14,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        color: isToday ? Colors.white : colors.secondaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (filled)
                    const Icon(
                      Icons.star_rounded,
                      size: 11,
                      color: AppColors.lightGold,
                    )
                  else
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.border,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BokehPainter extends CustomPainter {
  const _BokehPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    for (var i = 0; i < 18; i++) {
      final r = 6.0 + rng.nextDouble() * 22;
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()..color = Colors.white.withValues(alpha: 0.07 + rng.nextDouble() * 0.1),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Metallic cup trophy (navy / silver) matching the reference silhouette.
class _TrophyPainter extends CustomPainter {
  const _TrophyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final cup = Path()
      ..moveTo(w * 0.22, h * 0.12)
      ..quadraticBezierTo(w * 0.18, h * 0.38, w * 0.30, h * 0.48)
      ..lineTo(w * 0.70, h * 0.48)
      ..quadraticBezierTo(w * 0.82, h * 0.38, w * 0.78, h * 0.12)
      ..close();

    final cupPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF5A6B82),
          Color(0xFF1A2740),
          Color(0xFF0E1726),
          Color(0xFF3D4F66),
        ],
        stops: [0.0, 0.35, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(cup, cupPaint);

    // Handles
    final handlePaint = Paint()
      ..color = const Color(0xFF1A2740)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.18, h * 0.28),
        width: w * 0.28,
        height: h * 0.32,
      ),
      math.pi * 0.15,
      math.pi * 0.9,
      false,
      handlePaint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.82, h * 0.28),
        width: w * 0.28,
        height: h * 0.32,
      ),
      -math.pi * 0.05,
      -math.pi * 0.9,
      false,
      handlePaint,
    );

    // Rim highlight
    canvas.drawLine(
      Offset(w * 0.24, h * 0.14),
      Offset(w * 0.76, h * 0.14),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Stem + ring
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.56),
          width: w * 0.22,
          height: h * 0.06,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF2A3A52),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.68),
          width: w * 0.12,
          height: h * 0.16,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF1A2740),
    );

    // Base
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.86),
          width: w * 0.48,
          height: h * 0.1,
        ),
        const Radius.circular(6),
      ),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF3D4F66), Color(0xFF1A2740)],
        ).createShader(Rect.fromLTWH(0, h * 0.8, w, h * 0.15)),
    );

    // Soft ground shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.96),
        width: w * 0.55,
        height: h * 0.06,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

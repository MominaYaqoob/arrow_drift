import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/features/patterns/pattern_preview_screen.dart';

/// Dummy pattern gallery — static UI only, no unlock / data logic.
class PatternsScreen extends StatelessWidget {
  const PatternsScreen({super.key});

  static const String routePath = '/patterns';

  static const int _totalLevels = 200;
  static const int _unlockedThrough = 100;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
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
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Level Patterns',
                              style: AppTextStyles.heading(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: colors.primaryText,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Collect shapes as you clear levels',
                              style: AppTextStyles.body(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.72,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final level = index + 1;
                            return _PatternCard(
                              level: level,
                              locked: level > _unlockedThrough,
                            );
                          },
                          childCount: _totalLevels,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _UnlockPromoBanner(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({required this.level, required this.locked});

  final int level;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = locked ? colors.border : colors.accentTealDeep;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(
          PatternPreviewScreen.routePath,
          extra: level,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: 5,
            ),
            boxShadow: [
              BoxShadow(
                color: (locked ? colors.border : colors.accentTealDeep)
                    .withValues(alpha: isDark ? 0.28 : 0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isDark ? colors.surface2 : colors.background,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: locked
                      ? colors.border
                      : colors.accentTeal.withValues(alpha: 0.28),
                  width: 1.2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                child: Column(
                  children: [
                    Text(
                      'Level $level',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: locked
                            ? colors.secondaryText
                            : colors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: locked
                          ? Center(
                              child: Icon(
                                Icons.lock_rounded,
                                size: 36,
                                color: colors.secondaryText,
                              ),
                            )
                          : _DummyMazePreview(
                              seed: level,
                              teal: colors.accentTeal,
                              tealDeep: colors.accentTealDeep,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiny dummy maze — visual placeholder only, not a real level.
class _DummyMazePreview extends StatelessWidget {
  const _DummyMazePreview({
    required this.seed,
    required this.teal,
    required this.tealDeep,
  });

  final int seed;
  final Color teal;
  final Color tealDeep;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DummyMazePainter(
        seed: seed,
        teal: teal,
        tealDeep: tealDeep,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _DummyMazePainter extends CustomPainter {
  const _DummyMazePainter({
    required this.seed,
    required this.teal,
    required this.tealDeep,
  });

  final int seed;
  final Color teal;
  final Color tealDeep;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = tealDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = teal.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final inset = 4.0;
    final rect = Rect.fromLTWH(inset, inset, w - inset * 2, h - inset * 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      fill,
    );

    final path = Path();
    final shift = (seed % 4) * 0.08;
    path.moveTo(rect.left + 6, rect.top + rect.height * (0.22 + shift));
    path.lineTo(rect.left + rect.width * 0.38, rect.top + 8);
    path.lineTo(rect.right - 8, rect.top + rect.height * 0.28);
    path.lineTo(rect.right - 8, rect.bottom - 10);
    path.lineTo(rect.left + rect.width * 0.42, rect.bottom - 8);
    path.lineTo(rect.left + 8, rect.bottom - rect.height * 0.32);
    path.close();

    final inner = Paint()
      ..color = teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, stroke);

    final midY = rect.center.dy + ((seed.isEven) ? 4 : -4);
    canvas.drawLine(
      Offset(rect.left + 10, midY),
      Offset(rect.right - 10, midY),
      inner,
    );
    canvas.drawLine(
      Offset(rect.center.dx + (seed.isOdd ? 6 : -6), rect.top + 10),
      Offset(rect.center.dx, rect.bottom - 10),
      inner,
    );
  }

  @override
  bool shouldRepaint(covariant _DummyMazePainter oldDelegate) {
    return oldDelegate.seed != seed ||
        oldDelegate.teal != teal ||
        oldDelegate.tealDeep != tealDeep;
  }
}

/// Same treatment as Daily's Play Today — no coins, pinned CTA.
class _UnlockPromoBanner extends StatelessWidget {
  const _UnlockPromoBanner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Coming soon'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
          },
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
            child: Center(
              child: Text(
                'Unlock More Patterns',
                style: AppTextStyles.button(
                  fontSize: 16,
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

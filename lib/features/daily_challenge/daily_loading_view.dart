import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';

/// Soft dialog card while a board generates (Daily or Main levels 2+).
class DailyChallengeLoadingOverlay extends StatefulWidget {
  const DailyChallengeLoadingOverlay({
    super.key,
    this.error = false,
    this.onRetry,
    this.title = 'Daily Challenge',
    this.messages = dailyMessages,
    this.footer = 'Play starts when the board is ready.',
  });

  /// Campaign Main levels (not Daily).
  factory DailyChallengeLoadingOverlay.forLevel({
    Key? key,
    required int levelNumber,
    bool error = false,
    VoidCallback? onRetry,
  }) {
    return DailyChallengeLoadingOverlay(
      key: key,
      error: error,
      onRetry: onRetry,
      title: 'Level $levelNumber',
      messages: levelMessages,
      footer: 'Play starts when the board is ready.',
    );
  }

  static const dailyMessages = <String>[
    'Daily Challenge is loading…',
    'Please wait a few seconds',
    'Hope you enjoy this!',
    'Almost ready for you…',
  ];

  static const levelMessages = <String>[
    'Level is loading…',
    'Please wait a few seconds',
    'Hope you enjoy this!',
    'Almost ready for you…',
  ];

  final bool error;
  final VoidCallback? onRetry;
  final String title;
  final List<String> messages;
  final String footer;

  @override
  State<DailyChallengeLoadingOverlay> createState() =>
      _DailyChallengeLoadingOverlayState();
}

class _DailyChallengeLoadingOverlayState
    extends State<DailyChallengeLoadingOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _fade;
  int _messageIndex = 0;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    if (!widget.error) {
      _messageTimer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
        if (!mounted) return;
        setState(() {
          _messageIndex = (_messageIndex + 1) % widget.messages.length;
        });
      });
    }
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _spin.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Dim the Daily Challenge screen underneath (stay on same screen).
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.38),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: widget.error ? _errorCard(isDark) : _loadingCard(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingCard(bool isDark) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141C2A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3648) : const Color(0xFFD8D0C2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Explicit spin — never freezes with CircularProgressIndicator quirks.
          SizedBox(
            width: 52,
            height: 52,
            child: AnimatedBuilder(
              animation: _spin,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _spin.value * 2 * math.pi,
                  child: child,
                );
              },
              child: CustomPaint(
                painter: _RingSpinnerPainter(
                  color: AppColors.accentTeal,
                  track: isDark
                      ? const Color(0xFF2A3648)
                      : const Color(0xFFD9F5EE),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.heading(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0E1726),
            ),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Text(
              widget.messages[_messageIndex % widget.messages.length],
              key: ValueKey(_messageIndex),
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFF9AA5B5)
                    : const Color(0xFF6B7280),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.footer,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.accentTealDeep,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(bool isDark) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141C2A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3648) : const Color(0xFFD8D0C2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 36,
            color: isDark ? const Color(0xFF9AA5B5) : const Color(0xFF6B7280),
          ),
          const SizedBox(height: 12),
          Text(
            'Couldn’t open this puzzle',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0E1726),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentTeal,
                foregroundColor: const Color(0xFF0A2430),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingSpinnerPainter extends CustomPainter {
  _RingSpinnerPainter({required this.color, required this.track});

  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 3;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 1.15,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingSpinnerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.track != track;
  }
}

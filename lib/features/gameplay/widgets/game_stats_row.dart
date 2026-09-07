import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/data/models/level_model.dart';

class GameStatsRow extends StatefulWidget {
  const GameStatsRow({
    super.key,
    required this.remainingArrows,
    required this.heartsLeft,
    required this.heartsAllowed,
    required this.difficulty,
  });

  final int remainingArrows;
  final int heartsLeft;
  final int heartsAllowed;
  final LevelDifficulty difficulty;

  @override
  State<GameStatsRow> createState() => _GameStatsRowState();
}

class _GameStatsRowState extends State<GameStatsRow>
    with SingleTickerProviderStateMixin {
  late int _prevHearts;
  int? _pulseIndex;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _prevHearts = widget.heartsLeft;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.28), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.28, end: 1.0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _pulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _pulseIndex = null);
      }
    });
  }

  @override
  void didUpdateWidget(covariant GameStatsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.heartsLeft < _prevHearts) {
      // Rightmost heart that just emptied (0-based fill from left).
      setState(() => _pulseIndex = widget.heartsLeft);
      _pulseController.forward(from: 0);
    }
    _prevHearts = widget.heartsLeft;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final totalHearts = widget.heartsAllowed.clamp(1, 5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _Pill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🚀', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  '${widget.remainingArrows}',
                  style: AppTextStyles.label(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.primaryText,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(totalHearts, (index) {
                  final filled = index < widget.heartsLeft;
                  final pulsing = _pulseIndex == index;
                  final icon = Icon(
                    Icons.favorite_rounded,
                    size: 22,
                    color: filled
                        ? colors.heartRed
                        : colors.border.withValues(alpha: 0.85),
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: pulsing
                        ? Transform.scale(
                            scale: _pulseScale.value,
                            child: icon,
                          )
                        : icon,
                  );
                }),
              );
            },
          ),
          const Spacer(),
          _DifficultyChip(label: widget.difficulty.label),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border, width: 0.5),
      ),
      child: child,
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2FBF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9F5EE), width: 1),
      ),
      child: Text(
        label,
        style: AppTextStyles.label(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F8F7A),
        ),
      ),
    );
  }
}

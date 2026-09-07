import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/core/utils/online_gate.dart';

class GameBottomActions extends StatefulWidget {
  const GameBottomActions({
    super.key,
    required this.hintsLeft,
    required this.adsAvailable,
    required this.onHint,
    required this.onWatchAdForHint,
    required this.onGridBooster,
  });

  final int hintsLeft;
  final bool adsAvailable;
  final VoidCallback onHint;
  final VoidCallback onWatchAdForHint;
  final VoidCallback onGridBooster;

  @override
  State<GameBottomActions> createState() => _GameBottomActionsState();
}

class _GameBottomActionsState extends State<GameBottomActions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hintShakeController;
  late final Animation<double> _hintShake;

  @override
  void initState() {
    super.initState();
    _hintShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _hintShake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -5, end: 5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 5, end: -4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -4, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _hintShakeController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _hintShakeController.dispose();
    super.dispose();
  }

  void _onHintTap() {
    if (widget.hintsLeft <= 0) {
      if (!widget.adsAvailable) {
        showOfflineAdNotice(context);
        return;
      }
      _hintShakeController.forward(from: 0);
      widget.onWatchAdForHint();
      return;
    }
    widget.onHint();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hintsEmpty = widget.hintsLeft <= 0;
    final adHintOffline = hintsEmpty && !widget.adsAvailable;

    Widget hintFab = _ActionFab(
      onTap: _onHintTap,
      child: Badge(
        isLabelVisible: true,
        backgroundColor:
            adHintOffline ? colors.border : colors.accentTealDeep,
        label: Text(
          hintsEmpty ? 'AD' : '${widget.hintsLeft}',
          style: AppTextStyles.label(
            fontSize: 10,
            color: Colors.white,
          ),
        ),
        child: Icon(
          Icons.lightbulb_rounded,
          color: adHintOffline ? colors.secondaryText : colors.primaryText,
        ),
      ),
    );
    if (adHintOffline) {
      hintFab = Opacity(opacity: 0.45, child: hintFab);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _hintShakeController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_hintShake.value, 0),
                child: child,
              );
            },
            child: hintFab,
          ),
          const Spacer(),
          _ActionFab(
            onTap: widget.onGridBooster,
            child: Icon(
              Icons.grid_view_rounded,
              color: colors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionFab extends StatelessWidget {
  const _ActionFab({
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? colors.surface2 : Colors.white,
            shape: BoxShape.circle,
            border: isDark ? Border.all(color: colors.border) : null,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0E1726)
                    .withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

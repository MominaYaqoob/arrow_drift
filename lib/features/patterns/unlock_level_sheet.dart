import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/providers/connectivity_provider.dart';
import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/core/utils/online_gate.dart';
import 'package:arrow_drift/data/repositories/progress_repository.dart';
import 'package:arrow_drift/features/patterns/pattern_preview_screen.dart';
import 'package:arrow_drift/services/ads_service.dart';

const int kCustomUnlockCoinCost = 300;
const int kCustomAdCoinReward = 100;

Future<void> showUnlockLevelSheet(
  BuildContext context, {
  required int level,
}) async {
  final colors = context.appColors;
  final unlocked = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: colors.surface2,
    isScrollControlled: true,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) => UnlockLevelSheet(level: level),
  );
  if (unlocked == true && context.mounted) {
    context.push(PatternPreviewScreen.routePath, extra: level);
  }
}

class UnlockLevelSheet extends ConsumerStatefulWidget {
  const UnlockLevelSheet({super.key, required this.level});

  final int level;

  @override
  ConsumerState<UnlockLevelSheet> createState() => _UnlockLevelSheetState();
}

class _UnlockLevelSheetState extends ConsumerState<UnlockLevelSheet> {
  bool _watchingAd = false;
  bool _unlocking = false;

  Future<void> _watchAd() async {
    if (_watchingAd) return;
    final adsAvailable = ref.read(connectivityProvider);
    if (!adsAvailable) {
      showOfflineAdNotice(context);
      return;
    }
    setState(() => _watchingAd = true);
    try {
      final earned = await AdsService.instance.showRewardedForCoins(context);
      if (!earned || !mounted) return;
      final repo = await ref.read(progressRepositoryProvider.future);
      await repo.addCoins(kCustomAdCoinReward);
      if (!mounted) return;
      ref.read(coinBalanceTickProvider.notifier).update((tick) => tick + 1);
    } finally {
      if (mounted) setState(() => _watchingAd = false);
    }
  }

  Future<void> _unlock() async {
    if (_unlocking) return;
    setState(() => _unlocking = true);
    try {
      final repo = await ref.read(progressRepositoryProvider.future);
      final spent = await repo.spendCoins(kCustomUnlockCoinCost);
      if (!spent || !mounted) return;
      await repo.unlockPatternLevel(widget.level);
      if (!mounted) return;
      ref.read(coinBalanceTickProvider.notifier).update((tick) => tick + 1);
      ref.read(unlockedPatternTickProvider.notifier).update((tick) => tick + 1);
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _UnlockSheetHero(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              children: [
                const _GoldLockBadge(),
                const SizedBox(height: 16),
                Text(
                  'Unlock Level ${widget.level}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colors.primaryText,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                const _CostChip(),
                const SizedBox(height: 10),
                const _BalancePill(),
                const SizedBox(height: 22),
                _SheetActionButton(
                  label: 'Watch ad · +$kCustomAdCoinReward coins',
                  icon: Icons.play_circle_outline_rounded,
                  filled: false,
                  loading: _watchingAd,
                  enabled: !_watchingAd && !_unlocking,
                  onTap: _watchAd,
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<int>(
                  valueListenable: ProgressRepository.coinBalanceTick,
                  builder: (context, liveBalance, _) {
                    final enabled = liveBalance >= kCustomUnlockCoinCost &&
                        !_unlocking &&
                        !_watchingAd;
                    return Opacity(
                      opacity: enabled ? 1 : 0.45,
                      child: _SheetActionButton(
                        label: 'Unlock · $kCustomUnlockCoinCost coins',
                        icon: Icons.lock_open_rounded,
                        filled: true,
                        loading: _unlocking,
                        enabled: enabled,
                        onTap: _unlock,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlockSheetHero extends StatelessWidget {
  const _UnlockSheetHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.4, -1),
          end: Alignment(0.6, 1),
          colors: [Color(0xFF14A089), Color(0xFF0B5E52), Color(0xFF08463D)],
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 40),
          Expanded(
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _GoldLockBadge extends StatelessWidget {
  const _GoldLockBadge();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Color.lerp(colors.gold, const Color(0xFF8A6A1E), 0.4)!,
          width: 1.6,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(colors.gold, Colors.white, 0.38)!,
            colors.gold,
            Color.lerp(colors.gold, const Color(0xFF8A6A1E), 0.32)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.gold.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(
        Icons.lock_rounded,
        size: 32,
        color: Color(0xFF3D2E12),
      ),
    );
  }
}

class _CostChip extends StatelessWidget {
  const _CostChip();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: colors.gold.withValues(alpha: 0.14),
        border: Border.all(color: colors.gold, width: 1.3),
      ),
      child: Text(
        '$kCustomUnlockCoinCost coins',
        style: AppTextStyles.label(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: colors.gold,
        ),
      ),
    );
  }
}

class _BalancePill extends StatelessWidget {
  const _BalancePill();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ValueListenableBuilder<int>(
      valueListenable: ProgressRepository.coinBalanceTick,
      builder: (context, liveBalance, _) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: colors.accentTeal.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Text(
                'Balance · $liveBalance',
                style: AppTextStyles.label(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.secondaryText,
                ),
              ),
            ),
            if (liveBalance < kCustomUnlockCoinCost) ...[
              const SizedBox(height: 8),
              Text(
                'You don\'t have enough coins to unlock this level',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  fontSize: 12,
                  color: colors.secondaryText,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SheetActionButton extends StatelessWidget {
  const _SheetActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.filled,
    required this.enabled,
    required this.loading,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onFill = Colors.white;
    final onOutline = isDark ? colors.accentTeal : colors.accentTealDeep;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: filled
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.accentTeal, AppColors.accentTealDeep],
                    )
                  : null,
              color: filled ? null : colors.surface,
              border: filled
                  ? null
                  : Border.all(color: colors.accentTeal, width: 1.4),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: AppColors.accentTealDeep.withValues(alpha: 0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: filled ? onFill : colors.accentTeal,
                    ),
                  )
                else
                  Icon(
                    icon,
                    size: 22,
                    color: filled ? onFill : onOutline,
                  ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTextStyles.button(
                    fontWeight: FontWeight.w700,
                    color: filled ? onFill : onOutline,
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

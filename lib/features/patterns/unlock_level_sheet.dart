import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/providers/connectivity_provider.dart';
import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/core/utils/online_gate.dart';
import 'package:arrow_drift/data/repositories/progress_repository.dart';
import 'package:arrow_drift/features/patterns/pattern_preview_screen.dart';
import 'package:arrow_drift/services/ads_service.dart';

const int kCustomUnlockCoinCost = 75;
const int kCustomAdCoinReward = 25;

Future<void> showUnlockLevelSheet(
  BuildContext context, {
  required int level,
}) async {
  final colors = context.appColors;
  final unlocked = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: colors.surface2,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 40),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: colors.primaryText),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: colors.border),
              ),
              child: Icon(
                Icons.lock_rounded,
                size: 32,
                color: colors.gold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Unlock Level ${widget.level}',
              style: AppTextStyles.heading(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$kCustomUnlockCoinCost coins',
              style: AppTextStyles.body(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.gold,
              ),
            ),
            const SizedBox(height: 6),
            ValueListenableBuilder<int>(
              valueListenable: ProgressRepository.coinBalanceTick,
              builder: (context, liveBalance, _) {
                return Text(
                  'Balance: $liveBalance',
                  style: AppTextStyles.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.secondaryText,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 4),
          ],
        ),
      ),
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

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: filled ? colors.accentTeal : colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: filled
                  ? null
                  : Border.all(color: colors.border, width: 0.5),
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
                      color: filled
                          ? AppColors.lightPrimaryText
                          : colors.accentTeal,
                    ),
                  )
                else
                  Icon(
                    icon,
                    size: 22,
                    color: filled
                        ? AppColors.lightPrimaryText
                        : colors.primaryText,
                  ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTextStyles.button(
                    fontWeight: FontWeight.w700,
                    color: filled
                        ? AppColors.lightPrimaryText
                        : colors.primaryText,
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

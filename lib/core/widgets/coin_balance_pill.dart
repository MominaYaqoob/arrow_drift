import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/data/repositories/progress_repository.dart';

/// Live coin chip — same gold medallion as the Custom gallery header.
class CoinBalancePill extends ConsumerWidget {
  const CoinBalancePill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressRepositoryProvider);
    ref.watch(coinBalanceTickProvider);
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<int>(
      valueListenable: ProgressRepository.coinBalanceTick,
      builder: (context, balance, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(colors.gold, Colors.white, 0.38)!,
                colors.gold,
                Color.lerp(colors.gold, const Color(0xFF8A6A1E), 0.35)!,
              ],
            ),
            border: Border.all(
              color: Color.lerp(colors.gold, const Color(0xFF8A6A1E), 0.45)!,
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.gold.withValues(alpha: 0.35),
                blurRadius: 8,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            '🪙 $balance',
            style: AppTextStyles.label(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF3D2E12),
            ),
          ),
        );
      },
    );
  }
}

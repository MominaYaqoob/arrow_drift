import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/data/repositories/progress_repository.dart';
import 'package:arrow_drift/features/profile/nickname_dialog.dart';
import 'package:arrow_drift/features/profile/welcome_bonus_popup.dart';

/// Shell that hosts Main / Daily / Patterns / Me tabs via [StatefulNavigationShell].
/// Floating pill tab bar matches the HTML design board.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  bool _nicknamePromptStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAskNickname();
    });
  }

  Future<void> _maybeAskNickname() async {
    if (_nicknamePromptStarted || !mounted) return;
    _nicknamePromptStarted = true;

    final repo = await ref.read(progressRepositoryProvider.future);
    if (!mounted) return;
    if (repo.getNickname().isEmpty) {
      await NicknameDialog.show(
        context,
        onSaved: (nickname) async {
          await repo.setNickname(nickname);
          ref.invalidate(playerNicknameProvider);
        },
      );
      if (!mounted) return;
      if (repo.getNickname().isEmpty || repo.hasClaimedWelcomeBonus()) return;
      await WelcomeBonusPopup.show(
        context,
        onCollect: repo.claimWelcomeBonus,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navigationShell = widget.navigationShell;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Daily / Patterns / Me → first return to Main. Already on Main → leave.
        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? colors.surface : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colors.accentTeal.withValues(alpha: isDark ? 0.38 : 0.32),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              height: 68,
              child: Row(
                children: [
                  _ShellTab(
                    label: 'Main',
                    icon: Icons.home_rounded,
                    selected: navigationShell.currentIndex == 0,
                    onTap: () => navigationShell.goBranch(0),
                  ),
                  _ShellTab(
                    label: 'Daily',
                    icon: Icons.calendar_today_rounded,
                    selected: navigationShell.currentIndex == 1,
                    onTap: () => navigationShell.goBranch(1),
                  ),
                  _ShellTab(
                    label: 'Custom',
                    icon: Icons.grid_view_rounded,
                    selected: navigationShell.currentIndex == 2,
                    onTap: () => navigationShell.goBranch(2),
                  ),
                  _ShellTab(
                    label: 'Me',
                    icon: Icons.person_rounded,
                    selected: navigationShell.currentIndex == 3,
                    onTap: () => navigationShell.goBranch(3),
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

class _ShellTab extends StatelessWidget {
  const _ShellTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final muted = colors.secondaryText;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: selected ? 40 : 28,
              height: selected ? 40 : 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? colors.accentTeal : Colors.transparent,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: colors.accentTeal.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                size: selected ? 22 : 20,
                color: selected ? Colors.white : muted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? colors.accentTeal : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/data/repositories/progress_repository.dart';
import 'package:arrow_drift/features/profile/nickname_dialog.dart';

/// Shell that hosts Main / Daily / Me tabs via [StatefulNavigationShell].
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
    if (repo.getNickname().isNotEmpty) return;

    await NicknameDialog.show(
      context,
      onSaved: (nickname) async {
        await repo.setNickname(nickname);
        ref.invalidate(playerNicknameProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navigationShell = widget.navigationShell;

    return Scaffold(
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
              border: Border.all(color: colors.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              height: 64,
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
                    label: 'Me',
                    icon: Icons.person_rounded,
                    selected: navigationShell.currentIndex == 2,
                    onTap: () => navigationShell.goBranch(2),
                  ),
                ],
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
    final color = selected ? colors.accentTeal : colors.secondaryText;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.label(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

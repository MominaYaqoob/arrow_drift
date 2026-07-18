import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/core/utils/external_links.dart';
import 'package:arrow_drift/data/repositories/progress_repository.dart';
import 'package:arrow_drift/features/about/about_screen.dart';
import 'package:arrow_drift/features/about/help_center_screen.dart';
import 'package:arrow_drift/features/awards/awards_screen.dart';
import 'package:arrow_drift/features/profile/nickname_dialog.dart';
import 'package:arrow_drift/features/profile/player_avatars.dart';
import 'package:arrow_drift/features/settings/settings_screen.dart';
import 'package:arrow_drift/services/ads_service.dart';

/// Profile hub — navy gradient header + theme-aware list cards.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  static const String routePath = '/profile';

  static const Color _statTeal = Color(0xFF3DDCB8);

  Future<void> _editNickname(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) async {
    await NicknameDialog.show(
      context,
      initialNickname: currentName == 'Player' ? '' : currentName,
      title: 'Edit nickname',
      subtitle: 'Choose a name for your profile',
      confirmLabel: 'Save',
      barrierDismissible: true,
      onSaved: (nickname) async {
        final repo = await ref.read(progressRepositoryProvider.future);
        await repo.setNickname(nickname);
        ref.invalidate(playerNicknameProvider);
      },
    );
  }

  Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
    final colors = context.appColors;
    final currentId =
        ref.read(playerAvatarIdProvider).valueOrNull ?? PlayerAvatar.defaultId;
    final selected = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _AvatarPickerSheet(selectedId: currentId),
    );
    if (selected == null || !context.mounted) return;
    final repo = await ref.read(progressRepositoryProvider.future);
    await repo.setAvatarId(selected);
    ref.invalidate(playerAvatarIdProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final nicknameAsync = ref.watch(playerNicknameProvider);
    final avatarAsync = ref.watch(playerAvatarIdProvider);
    final levelsCleared =
        ref.watch(lastCompletedLevelProvider).valueOrNull ?? 0;
    final streak = ref.watch(currentStreakProvider).valueOrNull ?? 0;

    final nickname = nicknameAsync.when(
      data: (name) => name.trim().isEmpty ? 'Player' : name.trim(),
      loading: () => 'Player',
      error: (_, _) => 'Player',
    );
    final avatar = PlayerAvatar.byId(
      avatarAsync.valueOrNull ?? PlayerAvatar.defaultId,
    );

    return Scaffold(
      backgroundColor: colors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _ProfileHeader(
            avatar: avatar,
            name: nickname,
            levelsCleared: levelsCleared,
            dayStreak: streak,
            onAvatarTap: () => _pickAvatar(context, ref),
            onNameTap: () => _editNickname(context, ref, nickname),
          ),
          Padding(
            // Bottom inset adds the device's gesture-nav / system-bar safe
            // area on top of the existing 32px design spacing, so the
            // trailing ad slot never sits flush against (or under) Android's
            // bottom gesture bar on devices with larger insets. This screen
            // uses a scrolling ListView (not a fixed-height Scaffold body),
            // so a SafeArea ancestor wouldn't reliably reserve this space —
            // reading the inset directly is the correct fix here.
            padding: EdgeInsets.fromLTRB(
              16,
              20,
              16,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MeCard(
                  children: [
                    _MeRow(
                      icon: Icons.emoji_events_rounded,
                      iconBg: colors.accentTealSoft,
                      iconColor: colors.accentTealDeep,
                      label: 'Awards',
                      onTap: () => context.push(AwardsScreen.routePath),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _MeCard(
                  children: [
                    _MeRow(
                      icon: Icons.settings_rounded,
                      iconBg: colors.accentTealSoft,
                      iconColor: colors.accentTealDeep,
                      label: 'Settings',
                      onTap: () => context.push(SettingsScreen.routePath),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'SUPPORT',
                    style: AppTextStyles.label(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.secondaryText,
                    ).copyWith(letterSpacing: 1.1),
                  ),
                ),
                _MeCard(
                  children: [
                    _MeRow(
                      icon: Icons.help_outline_rounded,
                      iconBg: const Color(0xFFD4F5EE),
                      iconColor: const Color(0xFF1B8F7A),
                      label: 'Help',
                      onTap: () => context.push(HelpCenterScreen.routePath),
                      showDivider: true,
                      circleIcon: true,
                    ),
                    _MeRow(
                      icon: Icons.info_outline_rounded,
                      iconBg: const Color(0xFFFFF0D6),
                      iconColor: const Color(0xFFC9941A),
                      label: 'About Game',
                      onTap: () => context.push(AboutScreen.routePath),
                      showDivider: true,
                      circleIcon: true,
                    ),
                    _MeRow(
                      icon: Icons.shield_outlined,
                      iconBg: const Color(0xFFFFE4E6),
                      iconColor: const Color(0xFFD96B6B),
                      label: 'Privacy',
                      onTap: openPrivacyPolicyUrl,
                      circleIcon: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AdsService.instance.nativeAdPlaceholder(height: 70),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarPickerSheet extends StatefulWidget {
  const _AvatarPickerSheet({required this.selectedId});

  final String selectedId;

  @override
  State<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<_AvatarPickerSheet> {
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedId;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Choose avatar',
            textAlign: TextAlign.center,
            style: AppTextStyles.heading(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick one, then tap Done',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              fontSize: 13,
              color: colors.secondaryText,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final avatar in PlayerAvatar.all)
                GestureDetector(
                  onTap: () => setState(() => _selectedId = avatar.id),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: avatar.id == _selectedId
                                ? colors.accentTeal
                                : colors.border.withValues(alpha: 0.5),
                            width: 2.5,
                          ),
                        ),
                        child: PlayerAvatarCircle(
                          avatar: avatar,
                          size: 52,
                        ),
                      ),
                      if (avatar.id == _selectedId)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: colors.accentTeal,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.surface,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_selectedId),
              style: FilledButton.styleFrom(
                backgroundColor: colors.accentTeal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Done',
                style: AppTextStyles.body(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.avatar,
    required this.name,
    required this.levelsCleared,
    required this.dayStreak,
    required this.onAvatarTap,
    required this.onNameTap,
  });

  final PlayerAvatar avatar;
  final String name;
  final int levelsCleared;
  final int dayStreak;
  final VoidCallback onAvatarTap;
  final VoidCallback onNameTap;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPad + 20, 20, 22),
      constraints: BoxConstraints(minHeight: 180 + topPad),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E1726), Color(0xFF1C2A42)],
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                PlayerAvatarCircle(avatar: avatar, size: 64),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 12,
                      color: Color(0xFF0E1726),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onNameTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _HeaderStat(value: '$levelsCleared', label: 'Levels cleared'),
              Container(
                width: 1,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 22),
                color: Colors.white.withValues(alpha: 0.22),
              ),
              _HeaderStat(value: '$dayStreak', label: 'Day streak'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.heading(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: MeScreen._statTeal,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.label(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFB8C0CC),
          ),
        ),
      ],
    );
  }
}

class _MeCard extends StatelessWidget {
  const _MeCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: isDark ? Border.all(color: colors.border) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _MeRow extends StatelessWidget {
  const _MeRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.showDivider = false,
    this.circleIcon = false,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool showDivider;
  final bool circleIcon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: circleIcon ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius:
                        circleIcon ? null : BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.body(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.primaryText,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.secondaryText,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 62),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: colors.border,
            ),
          ),
      ],
    );
  }
}


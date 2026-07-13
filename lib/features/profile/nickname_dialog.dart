import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';

/// First-run welcome dialog — enter a nickname for the Me tab.
/// Also reused from Me to edit an existing nickname.
class NicknameDialog extends StatefulWidget {
  const NicknameDialog({
    super.key,
    required this.onSaved,
    this.initialNickname = '',
    this.title = 'Welcome!',
    this.subtitle = 'Enter your nickname to get started',
    this.confirmLabel = 'Continue',
  });

  final Future<void> Function(String nickname) onSaved;
  final String initialNickname;
  final String title;
  final String subtitle;
  final String confirmLabel;

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(String nickname) onSaved,
    String initialNickname = '',
    String title = 'Welcome!',
    String subtitle = 'Enter your nickname to get started',
    String confirmLabel = 'Continue',
    bool barrierDismissible = false,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Nickname',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, animation, secondaryAnimation) {
        return NicknameDialog(
          onSaved: onSaved,
          initialNickname: initialNickname,
          title: title,
          subtitle: subtitle,
          confirmLabel: confirmLabel,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
  }

  @override
  State<NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<NicknameDialog> {
  late final TextEditingController _controller;
  final _focus = FocusNode();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNickname);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focus.requestFocus();
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a nickname');
      return;
    }
    if (name.length < 2) {
      setState(() => _error = 'At least 2 characters');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await widget.onSaved(name);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.initialNickname.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Material(
          color: colors.surface,
          elevation: 16,
          shadowColor: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Navy header — matches Me profile look
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF0E1726), Color(0xFF1C2A42)],
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF3DDCB8), Color(0xFF0F8F7A)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentTeal
                                    .withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            isEdit
                                ? Icons.edit_rounded
                                : Icons.waving_hand_rounded,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.heading(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.subtitle,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFB8C0CC),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                    child: Column(
                      children: [
                        TextField(
                          controller: _controller,
                          focusNode: _focus,
                          textInputAction: TextInputAction.done,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 16,
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(RegExp(r'[\n\r]')),
                          ],
                          onChanged: (_) {
                            if (_error != null) {
                              setState(() => _error = null);
                            }
                          },
                          onSubmitted: (_) => _submit(),
                          style: AppTextStyles.body(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.primaryText,
                          ),
                          cursorColor: AppColors.accentTealDeep,
                          decoration: InputDecoration(
                            hintText: 'Your nickname',
                            hintStyle: AppTextStyles.body(
                              fontSize: 15,
                              color: colors.secondaryText,
                            ),
                            counterText: '',
                            filled: true,
                            fillColor: isDark
                                ? colors.surface2
                                : const Color(0xFFF6F3EC),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 15,
                            ),
                            prefixIcon: Icon(
                              Icons.person_outline_rounded,
                              color: colors.secondaryText,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: colors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: colors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.accentTeal,
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: colors.heartRed),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: colors.heartRed,
                                width: 2,
                              ),
                            ),
                            errorText: _error,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF3DDCB8),
                                  Color(0xFF0F8F7A),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentTealDeep
                                      .withValues(alpha: 0.28),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _saving ? null : _submit,
                                borderRadius: BorderRadius.circular(999),
                                child: Center(
                                  child: _saving
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          widget.confirmLabel,
                                          style: AppTextStyles.button(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

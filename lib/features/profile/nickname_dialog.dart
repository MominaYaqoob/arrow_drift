import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';

/// First-run welcome dialog — enter a nickname for the Me tab.
class NicknameDialog extends StatefulWidget {
  const NicknameDialog({super.key, required this.onSaved});

  final Future<void> Function(String nickname) onSaved;

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(String nickname) onSaved,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Nickname',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, animation, secondaryAnimation) {
        return NicknameDialog(onSaved: onSaved);
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
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Material(
          color: Colors.white,
          elevation: 12,
          shadowColor: Colors.black38,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.accentTeal.withValues(alpha: 0.25),
                        AppColors.accentTeal,
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.waving_hand_rounded,
                    size: 32,
                    color: Color(0xFF0E1726),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome!',
                  style: AppTextStyles.heading(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.lightPrimaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your nickname to get started',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 20),
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
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _submit(),
                  style: AppTextStyles.body(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightPrimaryText,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Your nickname',
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFF5F3EE),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.accentTeal,
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
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentTeal,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.accentTeal.withValues(alpha: 0.5),
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
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
                            'Continue',
                            style: AppTextStyles.button(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
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

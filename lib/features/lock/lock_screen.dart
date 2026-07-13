import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/core/widgets/app_logo.dart';

/// Placeholder lock gate shown after backgrounding when Auto-Lock is ON.
///
/// // ADD BIOMETRIC/PIN LOCK LATER
class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  static const String routePath = '/lock';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogoMark(size: 96),
                const SizedBox(height: 28),
                Text(
                  'Arrow Drift',
                  style: AppTextStyles.heading(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lightPrimaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'App locked',
                  style: AppTextStyles.body(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8A8578),
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                    child: const Text('Tap to unlock'),
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

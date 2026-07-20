import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/constants/app_constants.dart';
import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/core/widgets/app_logo.dart';
import 'package:arrow_drift/data/repositories/progress_repository.dart';
import 'package:arrow_drift/features/home/home_screen.dart';

/// First-launch only: short Terms/Privacy notice with a single Agree action.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  static const String routePath = '/consent';

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _saving = false;

  Future<void> _agree() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final repo = await ref.read(progressRepositoryProvider.future);
      await repo.setHasAcceptedTerms(true);
      if (!mounted) return;
      context.go(HomeScreen.routePath);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1726),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.15,
            colors: [
              Color(0xFF173049),
              Color(0xFF0E1726),
              Color(0xFF090F18),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                const AppLogoMark(size: 72),
                const SizedBox(height: 18),
                Text(
                  'Welcome to ${AppConstants.appShortName}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Arrow Drift is free to play. Your levels and streak stay '
                  'on this device only — we don’t ask for an account.\n\n'
                  'To keep the game free, we show ads through Google AdMob. '
                  'By tapping Agree, you accept our Terms of Service and '
                  'Privacy Policy and can start playing right away.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF9DB0C4),
                  ),
                ),
                const Spacer(flex: 3),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _agree,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentTeal,
                      foregroundColor: const Color(0xFF0A2430),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation(
                                Color(0xFF0A2430),
                              ),
                            ),
                          )
                        : Text(
                            'Agree',
                            style: AppTextStyles.label(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0A2430),
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

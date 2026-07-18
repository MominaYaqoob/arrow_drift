import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';

/// Shared "no internet" content — full-bleed dark gradient background,
/// icon, title, subtitle, and a Retry button. Used both by the splash
/// screen's launch-time gate (splash_loading_screen.dart) and the
/// app-wide mid-session connectivity gate (connectivity_gate.dart), so
/// both moments look and behave identically to the player.
class NoInternetBlockingView extends StatelessWidget {
  const NoInternetBlockingView({
    super.key,
    required this.retrying,
    required this.onRetry,
    this.subtitle = 'Arrow Drift needs an internet connection to continue. '
        'Please check your Wi-Fi or mobile data and try again.',
  });

  final bool retrying;
  final VoidCallback onRetry;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.3),
          radius: 1.1,
          colors: [
            Color(0xFF173049),
            Color(0xFF0E1726),
            Color(0xFF090F18),
          ],
          stops: [0.0, 0.58, 1.0],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    size: 40,
                    color: Color(0xFF9DB0C4),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'No Internet Connection',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF9DB0C4),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: retrying ? null : onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentTeal,
                      foregroundColor: const Color(0xFF0A2430),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: retrying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation(
                                Color(0xFF0A2430),
                              ),
                            ),
                          )
                        : Text(
                            'Retry',
                            style: AppTextStyles.label(
                              fontSize: 15,
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

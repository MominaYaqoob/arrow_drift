import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/data/repositories/level_repository.dart';
import 'package:arrow_drift/data/repositories/progress_repository.dart';
import 'package:arrow_drift/features/consent/consent_screen.dart';
import 'package:arrow_drift/features/home/home_screen.dart';
import 'package:arrow_drift/services/ads_service.dart';

/// Splash 2 — dice-roll shuffle screen matching HTML `.splash2`.
class SplashLoadingScreen extends ConsumerStatefulWidget {
  const SplashLoadingScreen({super.key});

  static const String routePath = '/splash/loading';

  @override
  ConsumerState<SplashLoadingScreen> createState() => _SplashLoadingScreenState();
}

class _SplashLoadingScreenState extends ConsumerState<SplashLoadingScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _diceController;
  late final AnimationController _loaderController;
  late final AnimationController _driftController;

  @override
  void initState() {
    super.initState();
    _diceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1550),
    )..repeat();
    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..repeat();
    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);

    // Ads are best-effort and must never block the game from opening.
    // AdsService performs its own connectivity and platform checks.
    unawaited(AdsService.instance.initialize());
    unawaited(_warmCurrentLevel());
    _timer = Timer(const Duration(milliseconds: 3500), () {
      unawaited(_goNext());
    });
  }

  Future<void> _warmCurrentLevel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final level = prefs.getInt(ProgressRepository.currentLevelKey) ?? 1;
      ref.read(levelRepositoryProvider).prefetchLevels([level, level + 1]);
    } catch (_) {}
  }

  Future<void> _goNext() async {
    if (!mounted) return;
    var accepted = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      accepted =
          prefs.getBool(ProgressRepository.hasAcceptedTermsKey) ?? false;
    } catch (_) {
      accepted = false;
    }
    if (!mounted) return;
    await AdsService.instance.showAppOpenIfReady();
    if (!mounted) return;
    context.go(
      accepted ? HomeScreen.routePath : ConsentScreen.routePath,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _diceController.dispose();
    _loaderController.dispose();
    _driftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1726),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
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
          ),
          AnimatedBuilder(
            animation: _driftController,
            builder: (context, child) {
              final t = _driftController.value;
              return Transform.translate(
                offset: Offset(
                  (-3 + 6 * t) / 100 * 40,
                  (-2 + 5 * t) / 100 * 40,
                ),
                child: Transform.rotate(angle: t * 0.1, child: child),
              );
            },
            child: Stack(
              children: [
                Positioned(
                  left: MediaQuery.sizeOf(context).width * 0.15,
                  top: MediaQuery.sizeOf(context).height * 0.22,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.accentTeal.withValues(alpha: 0.16),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: MediaQuery.sizeOf(context).width * 0.1,
                  bottom: MediaQuery.sizeOf(context).height * 0.28,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.lightGold.withValues(alpha: 0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 124,
                  height: 92,
                  child: AnimatedBuilder(
                    animation: _diceController,
                    builder: (context, _) {
                      final t = _diceController.value;
                      return Stack(
                        children: [
                          Positioned(
                            left: 10,
                            top: 20,
                            child: Transform.translate(
                              offset: Offset(0, _bounceY(t, phase: 0)),
                              child: Transform.rotate(
                                angle: _rollAngleA(t) * math.pi / 180,
                                child: const _Die(teal: false),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Transform.translate(
                              offset: Offset(0, _bounceY(t, phase: 0.12)),
                              child: Transform.rotate(
                                angle: _rollAngleB(t) * math.pi / 180,
                                child: const _Die(teal: true),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Shuffling puzzles…',
                  style: AppTextStyles.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Preparing your next clear path',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF9DB0C4),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width * 0.44,
                  height: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: 0.12),
                      child: AnimatedBuilder(
                        animation: _loaderController,
                        builder: (context, _) {
                          return Align(
                            alignment: Alignment(
                              -1.9 + _loaderController.value * 3.8,
                              0,
                            ),
                            child: FractionallySizedBox(
                              widthFactor: 0.42,
                              heightFactor: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.accentTealDeep,
                                      AppColors.accentTeal,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _bounceY(double t, {required double phase}) {
    final p = (t + phase) % 1.0;
    if (p < 0.4) return -14 * (p / 0.4);
    if (p < 0.7) return -14 + 17 * ((p - 0.4) / 0.3);
    return 3 - 3 * ((p - 0.7) / 0.3);
  }

  double _rollAngleA(double t) {
    if (t < 0.4) return -16 + 26 * (t / 0.4);
    if (t < 0.7) return 10 - 16 * ((t - 0.4) / 0.3);
    return -6 - 10 * ((t - 0.7) / 0.3);
  }

  double _rollAngleB(double t) {
    final p = (t + 0.12) % 1.0;
    if (p < 0.35) return 14 - 22 * (p / 0.35);
    if (p < 0.65) return -8 + 26 * ((p - 0.35) / 0.3);
    return 18 - 4 * ((p - 0.65) / 0.35);
  }
}

class _Die extends StatelessWidget {
  const _Die({this.teal = false});

  /// Cream (default) or app teal face — no pips.
  final bool teal;

  @override
  Widget build(BuildContext context) {
    final border = teal ? AppColors.accentTealDeep : const Color(0xFFC9BFAE);
    final gradient = teal
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accentTeal, AppColors.accentTealDeep],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF9EF), Color(0xFFE8DFCF)],
          );

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
    );
  }
}

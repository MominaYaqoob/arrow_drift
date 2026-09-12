import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/constants/app_constants.dart';
import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/core/widgets/app_logo.dart';
import 'package:arrow_drift/features/splash/splash_loading_screen.dart';
import 'package:arrow_drift/services/play_in_app_update.dart';

/// Splash 1 — dark striped logo screen with entrance animation.
class SplashLogoScreen extends StatefulWidget {
  const SplashLogoScreen({super.key});

  static const String routePath = '/';

  @override
  State<SplashLogoScreen> createState() => _SplashLogoScreenState();
}

class _SplashLogoScreenState extends State<SplashLogoScreen>
    with TickerProviderStateMixin {
  Timer? _navTimer;
  late final AnimationController _logoController;
  late final AnimationController _nameController;
  late final AnimationController _taglineController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _nameOpacity;
  late final Animation<double> _nameSlideY;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _taglineSlideY;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(checkForUpdate());
    });

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
    );

    _nameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _nameOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _nameController, curve: Curves.easeOutCubic),
    );
    _nameSlideY = Tween<double>(begin: 10, end: 0).animate(
      CurvedAnimation(parent: _nameController, curve: Curves.easeOutCubic),
    );

    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _taglineOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeOutCubic),
    );
    _taglineSlideY = Tween<double>(begin: 10, end: 0).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeOutCubic),
    );

    // Kick off staggered entrance; total splash stay = 1.5s.
    _logoController.forward();
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _nameController.forward();
    });
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _taglineController.forward();
    });

    _navTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      context.go(SplashLoadingScreen.routePath);
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _logoController.dispose();
    _nameController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1726),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _StripeBackgroundPainter()),
          Center(
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentTeal.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _logoOpacity,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: const AppLogoMark(size: 112),
                  ),
                ),
                const SizedBox(height: 18),
                FadeTransition(
                  opacity: _nameOpacity,
                  child: AnimatedBuilder(
                    animation: _nameSlideY,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _nameSlideY.value),
                        child: child,
                      );
                    },
                    child: Text(
                      AppConstants.appShortName,
                      style: AppTextStyles.heading(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                FadeTransition(
                  opacity: _taglineOpacity,
                  child: AnimatedBuilder(
                    animation: _taglineSlideY,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _taglineSlideY.value),
                        child: child,
                      );
                    },
                    child: Text(
                      'THINK · TAP · CLEAR',
                      style: AppTextStyles.label(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8FA3B8),
                      ).copyWith(letterSpacing: 2.2),
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
}

class _StripeBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const a = Color(0xFF0E1726);
    const b = Color(0xFF101B2C);
    final paint = Paint();
    const band = 16.97;
    canvas.drawRect(Offset.zero & size, paint..color = a);

    paint.color = b;
    for (var i = -size.height; i < size.width + size.height; i += band * 2) {
      final path = Path()
        ..moveTo(i, 0)
        ..lineTo(i + band, 0)
        ..lineTo(i + band - size.height, size.height)
        ..lineTo(i - size.height, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

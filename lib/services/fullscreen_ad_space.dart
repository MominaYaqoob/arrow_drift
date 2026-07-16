import 'dart:async';

import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';

/// Timed fullscreen ad space (placeholder until real AdMob is wired).
Future<bool> showFullscreenAdSpace(
  BuildContext context, {
  required Duration duration,
  required String title,
  String subtitle = 'Advertisement space',
}) async {
  if (!context.mounted) return false;
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Ad',
    barrierColor: Colors.black.withValues(alpha: 0.9),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _FullscreenAdSpace(
        duration: duration,
        title: title,
        subtitle: subtitle,
      );
    },
  );
  return result ?? false;
}

class _FullscreenAdSpace extends StatefulWidget {
  const _FullscreenAdSpace({
    required this.duration,
    required this.title,
    required this.subtitle,
  });

  final Duration duration;
  final String title;
  final String subtitle;

  @override
  State<_FullscreenAdSpace> createState() => _FullscreenAdSpaceState();
}

class _FullscreenAdSpaceState extends State<_FullscreenAdSpace> {
  late int _secondsLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.duration.inSeconds.clamp(1, 120);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.duration.inSeconds.clamp(1, 120);
    final progress = 1.0 - (_secondsLeft / total);

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFC857), Color(0xFFFF9F43)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Ad · ${_secondsLeft}s',
                    style: AppTextStyles.label(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2A1A00),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0E5C52),
                      Color(0xFF145A7A),
                      Color(0xFF1A3A6B),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFF7EF0D4).withValues(alpha: 0.55),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3DDCB8).withValues(alpha: 0.28),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFFC857), Color(0xFF3DDCB8)],
                        ),
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        size: 38,
                        color: Color(0xFF0A2430),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.heading(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                        fontSize: 14,
                        color: const Color(0xFFB8F0E4),
                      ),
                    ),
                    const SizedBox(height: 22),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 7,
                        backgroundColor: Colors.white.withValues(alpha: 0.16),
                        color: const Color(0xFFFFC857),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Closing in $_secondsLeft s…',
                      style: AppTextStyles.label(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Ad space — replace with AdMob later',
                style: AppTextStyles.label(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

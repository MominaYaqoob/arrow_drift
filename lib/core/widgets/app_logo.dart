import 'package:flutter/material.dart';

/// Official logo mark — uses [assets/branding/app_icon.png].
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size * (size >= 100 ? 0.286 : size <= 30 ? 0.32 : 0.295);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0E1726),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: size < 40 ? 0.18 : 0.28),
            blurRadius: size < 40 ? 16 : 30,
            offset: Offset(0, size < 40 ? 8 : 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/branding/app_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Official logo mark matching the HTML `.mark` / `.mark-l` system.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 88});

  final double size;

  static const Color _navyTop = Color(0xFF24344F);
  static const Color _navyBottom = Color(0xFF162235);
  static const Color _tealLight = Color(0xFF3DDCB8);
  static const Color _teal = Color(0xFF2EC4A6);

  @override
  Widget build(BuildContext context) {
    final radius = size * (size >= 100 ? 0.286 : size <= 30 ? 0.32 : 0.295);
    final markSize = size * 0.46;
    final stemW = markSize * 0.28;
    final stemH = markSize * 0.78;
    final armW = markSize * 0.78;
    final armH = markSize * 0.28;
    final tipW = markSize * 0.30;
    final tipH = markSize * 0.48;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        gradient: const LinearGradient(
          begin: Alignment(-0.4, -1),
          end: Alignment(0.6, 1),
          colors: [_navyTop, _navyBottom],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: size < 40 ? 0.18 : 0.28),
            blurRadius: size < 40 ? 16 : 30,
            offset: Offset(0, size < 40 ? 8 : 16),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: markSize,
        height: markSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Teal vertical stem
            Positioned(
              left: markSize * 0.08,
              top: markSize * 0.04,
              child: Container(
                width: stemW,
                height: stemH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.068),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_tealLight, _teal],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            // White horizontal arm
            Positioned(
              left: markSize * 0.08,
              bottom: markSize * 0.10,
              child: Container(
                width: armW,
                height: armH,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(size * 0.068),
                  ),
                ),
              ),
            ),
            // White arrow tip on the arm (matches .arm::after)
            Positioned(
              left: markSize * 0.08 + armW - tipW * 0.15,
              bottom: markSize * 0.10 + (armH - tipH) / 2,
              child: CustomPaint(
                size: Size(tipW, tipH),
                painter: const _LogoArrowTipPainter(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoArrowTipPainter extends CustomPainter {
  const _LogoArrowTipPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height * 0.5)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _LogoArrowTipPainter oldDelegate) =>
      oldDelegate.color != color;
}

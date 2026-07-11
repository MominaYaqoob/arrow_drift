import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/data/models/arrow_model.dart';

/// Level-1 guided hand + tip bubble pointing at the suggested arrow.
///
/// Prefer the in-tile guide on [ArrowTile]; this overlay remains available if
/// a screen needs board-absolute positioning.
class TutorialGuideOverlay extends StatefulWidget {
  const TutorialGuideOverlay({
    super.key,
    required this.target,
    required this.cellSize,
    required this.boardOrigin,
    this.message = 'Tap free arrow',
  });

  final ArrowModel target;
  final double cellSize;
  final Offset boardOrigin;
  final String message;

  @override
  State<TutorialGuideOverlay> createState() => _TutorialGuideOverlayState();
}

class _TutorialGuideOverlayState extends State<TutorialGuideOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cellCenter = Offset(
      widget.boardOrigin.dx +
          (widget.target.col + 0.5) * widget.cellSize,
      widget.boardOrigin.dy +
          (widget.target.row + 0.5) * widget.cellSize,
    );

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final bob = _controller.value * 4;
          return Stack(
            children: [
              Positioned(
                left: cellCenter.dx + 8,
                top: cellCenter.dy + 4 + bob,
                child: CustomPaint(
                  size: const Size(36, 40),
                  painter: _PointerHandPainter(
                    fill: Colors.white,
                    stroke: const Color(0xFF1A2740),
                  ),
                ),
              ),
              Positioned(
                left: cellCenter.dx - 58,
                top: cellCenter.dy + widget.cellSize * 0.55,
                width: 116,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      size: const Size(12, 7),
                      painter: _CaretPainter(color: AppColors.accentTeal),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentTeal,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CaretPainter extends CustomPainter {
  _CaretPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CaretPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _PointerHandPainter extends CustomPainter {
  _PointerHandPainter({
    required this.fill,
    required this.stroke,
  });

  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.08)
      ..lineTo(size.width * 0.2, size.height * 0.78)
      ..lineTo(size.width * 0.42, size.height * 0.62)
      ..lineTo(size.width * 0.55, size.height * 0.92)
      ..lineTo(size.width * 0.72, size.height * 0.86)
      ..lineTo(size.width * 0.58, size.height * 0.56)
      ..lineTo(size.width * 0.86, size.height * 0.56)
      ..close();

    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PointerHandPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.stroke != stroke;
}

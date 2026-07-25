import 'dart:math' as math;

import 'package:flutter/material.dart';

enum AvatarHairStyle {
  longStraight,
  shortCrop,
  pigtails,
  spiky,
  longWavy,
}

/// Exactly 5 cartoon bust avatars (reference style).
class PlayerAvatar {
  const PlayerAvatar({
    required this.id,
    required this.label,
    required this.background,
    required this.skin,
    required this.hair,
    required this.shirt,
    required this.hairStyle,
  });

  final String id;
  final String label;
  final Color background;
  final Color skin;
  final Color hair;
  final Color shirt;
  final AvatarHairStyle hairStyle;

  static const String defaultId = 'avatar_1';

  static const List<PlayerAvatar> all = [
    PlayerAvatar(
      id: 'avatar_1',
      label: 'Ava',
      background: Color(0xFFFFB4C8),
      skin: Color(0xFFF1C27D),
      hair: Color(0xFF5C3A1E),
      shirt: Color(0xFF7EC8E3),
      hairStyle: AvatarHairStyle.longStraight,
    ),
    PlayerAvatar(
      id: 'avatar_2',
      label: 'Leo',
      background: Color(0xFFE15A3D),
      skin: Color(0xFFC68642),
      hair: Color(0xFF1A1410),
      shirt: Color(0xFF1C2A42),
      hairStyle: AvatarHairStyle.shortCrop,
    ),
    PlayerAvatar(
      id: 'avatar_3',
      label: 'Mia',
      background: Color(0xFF3DDCB8),
      skin: Color(0xFFE8B07A),
      hair: Color(0xFF6B3E26),
      shirt: Color(0xFFE86A9A),
      hairStyle: AvatarHairStyle.pigtails,
    ),
    PlayerAvatar(
      id: 'avatar_4',
      label: 'Kai',
      background: Color(0xFF1C2A42),
      skin: Color(0xFFE8B07A),
      hair: Color(0xFFC45C2A),
      shirt: Color(0xFF2EC4A6),
      hairStyle: AvatarHairStyle.spiky,
    ),
    PlayerAvatar(
      id: 'avatar_5',
      label: 'Zoe',
      background: Color(0xFFC9B6F2),
      skin: Color(0xFFE8B07A),
      hair: Color(0xFF8B4518),
      shirt: Color(0xFFFF8FAB),
      hairStyle: AvatarHairStyle.longWavy,
    ),
  ];

  static PlayerAvatar byId(String? id) {
    for (final avatar in all) {
      if (avatar.id == id) return avatar;
    }
    return all.first;
  }
}

/// Circular cartoon avatar used on Me header and picker.
class PlayerAvatarCircle extends StatelessWidget {
  const PlayerAvatarCircle({
    super.key,
    required this.avatar,
    this.size = 64,
    this.selected = false,
    // Kept for call-site compatibility; unused for painted avatars.
    this.iconSize,
  });

  final PlayerAvatar avatar;
  final double size;
  final bool selected;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final ring = selected
        ? Container(
            width: size + 8,
            height: size + 8,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE0892E), width: 2.5),
            ),
            child: Container(
              width: size + 2,
              height: size + 2,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF4B45C), width: 2),
              ),
              child: _paint(size),
            ),
          )
        : _paint(size);

    return ring;
  }

  Widget _paint(double s) {
    return ClipOval(
      child: CustomPaint(
        size: Size.square(s),
        painter: _CartoonAvatarPainter(avatar),
      ),
    );
  }
}

class _CartoonAvatarPainter extends CustomPainter {
  _CartoonAvatarPainter(this.avatar);

  final PlayerAvatar avatar;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;

    // Background circle
    canvas.drawCircle(
      Offset(cx, h * 0.5),
      w * 0.5,
      Paint()..color = avatar.background,
    );

    // Shirt / shoulders
    final shirtPath = Path()
      ..moveTo(w * 0.12, h)
      ..quadraticBezierTo(w * 0.18, h * 0.62, cx, h * 0.60)
      ..quadraticBezierTo(w * 0.82, h * 0.62, w * 0.88, h)
      ..close();
    canvas.drawPath(shirtPath, Paint()..color = avatar.shirt);

    // Neck
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.58),
          width: w * 0.16,
          height: h * 0.10,
        ),
        Radius.circular(w * 0.04),
      ),
      Paint()..color = avatar.skin,
    );

    // Head
    final headCenter = Offset(cx, h * 0.42);
    final headRx = w * 0.28;
    final headRy = h * 0.30;
    canvas.drawOval(
      Rect.fromCenter(center: headCenter, width: headRx * 2, height: headRy * 2),
      Paint()..color = avatar.skin,
    );

    _paintHair(canvas, size, headCenter, headRx, headRy);

    // Eyes
    final eyeY = h * 0.40;
    final eyePaint = Paint()..color = const Color(0xFF1A1410);
    canvas.drawCircle(Offset(cx - w * 0.09, eyeY), w * 0.028, eyePaint);
    canvas.drawCircle(Offset(cx + w * 0.09, eyeY), w * 0.028, eyePaint);

    // Smile
    final smile = Path()
      ..moveTo(cx - w * 0.07, h * 0.48)
      ..quadraticBezierTo(cx, h * 0.53, cx + w * 0.07, h * 0.48);
    canvas.drawPath(
      smile,
      Paint()
        ..color = const Color(0xFF1A1410)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.025
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintHair(
    Canvas canvas,
    Size size,
    Offset headCenter,
    double headRx,
    double headRy,
  ) {
    final w = size.width;
    final h = size.height;
    final hair = Paint()..color = avatar.hair;
    final cx = headCenter.dx;

    switch (avatar.hairStyle) {
      case AvatarHairStyle.longStraight:
        // Side curtains (behind face silhouette)
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              cx - headRx * 1.12,
              headCenter.dy - headRy * 0.35,
              cx - headRx * 0.72,
              h * 0.86,
            ),
            Radius.circular(w * 0.08),
          ),
          hair,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              cx + headRx * 0.72,
              headCenter.dy - headRy * 0.35,
              cx + headRx * 1.12,
              h * 0.86,
            ),
            Radius.circular(w * 0.08),
          ),
          hair,
        );
        // Soft rounded crown + short bangs (keeps face visible)
        final crown = Path()
          ..moveTo(cx - headRx * 0.98, headCenter.dy - headRy * 0.05)
          ..quadraticBezierTo(
            cx - headRx * 1.05,
            headCenter.dy - headRy * 1.2,
            cx,
            headCenter.dy - headRy * 1.28,
          )
          ..quadraticBezierTo(
            cx + headRx * 1.05,
            headCenter.dy - headRy * 1.2,
            cx + headRx * 0.98,
            headCenter.dy - headRy * 0.05,
          )
          ..quadraticBezierTo(
            cx,
            headCenter.dy - headRy * 0.55,
            cx - headRx * 0.98,
            headCenter.dy - headRy * 0.05,
          )
          ..close();
        canvas.drawPath(crown, hair);
        break;

      case AvatarHairStyle.shortCrop:
        final cap = Path()
          ..moveTo(cx - headRx * 0.95, headCenter.dy)
          ..quadraticBezierTo(
            cx - headRx * 1.05,
            headCenter.dy - headRy * 1.15,
            cx,
            headCenter.dy - headRy * 1.2,
          )
          ..quadraticBezierTo(
            cx + headRx * 1.05,
            headCenter.dy - headRy * 1.15,
            cx + headRx * 0.95,
            headCenter.dy,
          )
          ..quadraticBezierTo(
            cx,
            headCenter.dy - headRy * 0.55,
            cx - headRx * 0.95,
            headCenter.dy,
          )
          ..close();
        canvas.drawPath(cap, hair);
        break;

      case AvatarHairStyle.pigtails:
        // Top hair
        final top = Path()
          ..moveTo(cx - headRx * 0.9, headCenter.dy - headRy * 0.1)
          ..quadraticBezierTo(
            cx,
            headCenter.dy - headRy * 1.25,
            cx + headRx * 0.9,
            headCenter.dy - headRy * 0.1,
          )
          ..quadraticBezierTo(
            cx,
            headCenter.dy - headRy * 0.4,
            cx - headRx * 0.9,
            headCenter.dy - headRy * 0.1,
          )
          ..close();
        canvas.drawPath(top, hair);
        // Left / right pigtails
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx - headRx * 1.15, headCenter.dy + headRy * 0.35),
            width: w * 0.16,
            height: h * 0.28,
          ),
          hair,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx + headRx * 1.15, headCenter.dy + headRy * 0.35),
            width: w * 0.16,
            height: h * 0.28,
          ),
          hair,
        );
        break;

      case AvatarHairStyle.spiky:
        final spikes = Path();
        final baseY = headCenter.dy - headRy * 0.15;
        spikes.moveTo(cx - headRx * 0.95, baseY);
        final tips = <double>[-0.85, -0.55, -0.2, 0.15, 0.5, 0.8];
        for (final t in tips) {
          final tipX = cx + headRx * t;
          final tipY = headCenter.dy - headRy * (1.05 + 0.25 * math.cos(t * 4));
          final midX = cx + headRx * (t + 0.12);
          spikes.lineTo(tipX, tipY);
          spikes.lineTo(midX, baseY - headRy * 0.15);
        }
        spikes.lineTo(cx + headRx * 0.95, baseY);
        spikes.quadraticBezierTo(cx, headCenter.dy - headRy * 0.45, cx - headRx * 0.95, baseY);
        spikes.close();
        canvas.drawPath(spikes, hair);
        break;

      case AvatarHairStyle.longWavy:
        // Soft wavy side locks
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx - headRx * 1.05, headCenter.dy + headRy * 0.25),
            width: w * 0.22,
            height: h * 0.48,
          ),
          hair,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx + headRx * 1.05, headCenter.dy + headRy * 0.25),
            width: w * 0.22,
            height: h * 0.48,
          ),
          hair,
        );
        // Rounded top with light fringe above the eyes
        final wavyTop = Path()
          ..moveTo(cx - headRx * 0.95, headCenter.dy - headRy * 0.08)
          ..quadraticBezierTo(
            cx - headRx * 1.0,
            headCenter.dy - headRy * 1.18,
            cx,
            headCenter.dy - headRy * 1.3,
          )
          ..quadraticBezierTo(
            cx + headRx * 1.0,
            headCenter.dy - headRy * 1.18,
            cx + headRx * 0.95,
            headCenter.dy - headRy * 0.08,
          )
          ..quadraticBezierTo(
            cx + headRx * 0.35,
            headCenter.dy - headRy * 0.5,
            cx,
            headCenter.dy - headRy * 0.42,
          )
          ..quadraticBezierTo(
            cx - headRx * 0.35,
            headCenter.dy - headRy * 0.5,
            cx - headRx * 0.95,
            headCenter.dy - headRy * 0.08,
          )
          ..close();
        canvas.drawPath(wavyTop, hair);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _CartoonAvatarPainter oldDelegate) {
    return oldDelegate.avatar.id != avatar.id;
  }
}

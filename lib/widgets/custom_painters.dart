import 'dart:math' as math;
import 'package:flutter/material.dart';

class InfinityPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double R = size.width / 4.828;
    double cx = size.width / 2;
    double cy = size.height / 2;
    double d = R * math.sqrt(2);

    Offset c1 = Offset(cx - d, cy);
    Offset c2 = Offset(cx + d, cy);

    Offset p2 =
        c2 +
        Offset(R * math.cos(3 * math.pi / 4), R * math.sin(3 * math.pi / 4));
    Offset p3 =
        c1 + Offset(R * math.cos(math.pi / 4), R * math.sin(math.pi / 4));

    double sw = 22.0;
    double g = sw * 0.9;

    Path path = Path();
    path.moveTo(cx - g * math.cos(math.pi / 4), cy + g * math.sin(math.pi / 4));
    path.lineTo(p3.dx, p3.dy);
    path.arcTo(
      Rect.fromCircle(center: c1, radius: R),
      math.pi / 4,
      3 * math.pi / 2,
      false,
    );
    path.lineTo(p2.dx, p2.dy);
    path.arcTo(
      Rect.fromCircle(center: c2, radius: R),
      3 * math.pi / 4,
      -3 * math.pi / 2,
      false,
    );
    path.lineTo(cx + g * math.cos(math.pi / 4), cy - g * math.sin(math.pi / 4));

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.butt;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class PunchOutIconPainter extends CustomPainter {
  final Color color;

  PunchOutIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 29.0;
    final scaleY = size.height / 35.0;
    final scale = math.min(scaleX, scaleY);

    final dx = (size.width - 29.0 * scale) / 2;
    final dy = (size.height - 35.0 * scale) / 2;

    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    final path1 = Path();
    path1.moveTo(13.8123, 32.943);
    path1.lineTo(2.27978, 29.8546);
    path1.cubicTo(1.52504, 29.6528, 1, 28.9753, 1, 28.2005);
    path1.lineTo(1, 5.80327);
    path1.cubicTo(1, 5.02846, 1.52504, 4.35096, 2.27978, 4.14915);
    path1.lineTo(13.8123, 1.06074);
    path1.cubicTo(14.9135, 0.765235, 16, 1.58689, 16, 2.71486);
    path1.lineTo(16, 31.2853);
    path1.cubicTo(16, 32.4133, 14.9135, 33.2349, 13.8123, 32.9394);
    path1.lineTo(13.8123, 32.943);
    path1.close();

    final paint1 = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.miter
      ..strokeMiterLimit = 10;
    canvas.drawPath(path1, paint1);

    final path2 = Path();
    path2.moveTo(12, 16.5001);
    path2.cubicTo(12.2761, 16.5001, 12.5, 16.7239, 12.5, 17.0001);
    path2.cubicTo(12.5, 17.2762, 12.2761, 17.5001, 12, 17.5001);
    path2.cubicTo(11.7239, 17.5001, 11.5, 17.2762, 11.5, 17.0001);
    path2.cubicTo(11.5, 16.7239, 11.7239, 16.5001, 12, 16.5001);
    path2.close();

    final paint2 = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 1;
    canvas.drawPath(path2, paint2);

    final path3 = Path();
    path3.moveTo(18, 16.2931);
    path3.lineTo(18, 17.7073);
    path3.lineTo(26.4717, 17.7073);
    path3.lineTo(24.3304, 20.0001);
    path3.lineTo(25.2643, 21.0001);
    path3.lineTo(29, 17.0001);
    path3.lineTo(25.2643, 13.0001);
    path3.lineTo(24.3304, 14.0001);
    path3.lineTo(26.4718, 16.2931);
    path3.lineTo(18, 16.2931);
    path3.close();

    final paint3 = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawPath(path3, paint3);
  }

  @override
  bool shouldRepaint(covariant PunchOutIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class PunchInIconPainter extends CustomPainter {
  final Color color;

  PunchInIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 32.0;
    final scaleY = size.height / 35.0;
    final scale = math.min(scaleX, scaleY);

    final dx = (size.width - 32.0 * scale) / 2;
    final dy = (size.height - 35.0 * scale) / 2;

    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    final path1 = Path();
    path1.moveTo(13.8123, 32.943);
    path1.lineTo(2.27978, 29.8546);
    path1.cubicTo(1.52504, 29.6528, 1, 28.9753, 1, 28.2005);
    path1.lineTo(1, 5.80327);
    path1.cubicTo(1, 5.02846, 1.52504, 4.35096, 2.27978, 4.14915);
    path1.lineTo(13.8123, 1.06074);
    path1.cubicTo(14.9135, 0.765235, 16, 1.58689, 16, 2.71486);
    path1.lineTo(16, 31.2853);
    path1.cubicTo(16, 32.4133, 14.9135, 33.2349, 13.8123, 32.9394);
    path1.lineTo(13.8123, 32.943);
    path1.close();

    final paint1 = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.miter
      ..strokeMiterLimit = 10;
    canvas.drawPath(path1, paint1);

    final path2 = Path();
    path2.moveTo(12, 16.5001);
    path2.cubicTo(12.2761, 16.5001, 12.5, 16.7239, 12.5, 17.0001);
    path2.cubicTo(12.5, 17.2762, 12.2761, 17.5001, 12, 17.5001);
    path2.cubicTo(11.7239, 17.5001, 11.5, 17.2762, 11.5, 17.0001);
    path2.cubicTo(11.5, 16.7239, 11.7239, 16.5001, 12, 16.5001);
    path2.close();

    final paint2 = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 1;
    canvas.drawPath(path2, paint2);

    final path3 = Path();
    path3.moveTo(32, 16.2931);
    path3.lineTo(32, 17.7073);
    path3.lineTo(23.5283, 17.7073);
    path3.lineTo(25.6696, 20.0001);
    path3.lineTo(24.7357, 21.0001);
    path3.lineTo(21, 17.0001);
    path3.lineTo(24.7357, 13.0001);
    path3.lineTo(25.6696, 14.0001);
    path3.lineTo(23.5282, 16.2931);
    path3.lineTo(32, 16.2931);
    path3.close();

    final paint3 = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawPath(path3, paint3);

    final path4 = Path();
    path4.moveTo(30.3096, 24.9962);
    path4.cubicTo(30.3093, 25.9255, 29.7208, 26.7997, 28.7871, 27.0685);
    path4.lineTo(28.71, 27.0909);
    path4.lineTo(28.6299, 27.1007);
    path4.lineTo(21.1904, 28.0001);
    path4.lineTo(21.1904, 25.9786);
    path4.lineTo(28.2588, 25.131);
    path4.cubicTo(28.2637, 25.1263, 28.2698, 25.1201, 28.2754, 25.1124);
    path4.cubicTo(28.2942, 25.0862, 28.3094, 25.0459, 28.3096, 24.9962);
    path4.lineTo(28.3096, 21.0001);
    path4.lineTo(30.3096, 21.0001);
    path4.lineTo(30.3096, 24.9962);
    path4.close();

    path4.moveTo(28.6299, 7.84286);
    path4.lineTo(28.71, 7.85263);
    path4.lineTo(28.7871, 7.87509);
    path4.cubicTo(29.721, 8.14384, 30.3095, 9.01787, 30.3096, 9.94736);
    path4.lineTo(30.3096, 14.0001);
    path4.lineTo(28.3096, 14.0001);
    path4.lineTo(28.3096, 9.94736);
    path4.cubicTo(28.3095, 9.89749, 28.2942, 9.85738, 28.2754, 9.83115);
    path4.cubicTo(28.2699, 9.82348, 28.2637, 9.81823, 28.2754, 9.83115);
    path4.lineTo(21.1904, 8.96494);
    path4.lineTo(20.3096, 8.84482);
    path4.lineTo(20.3096, 6.84482);
    path4.lineTo(28.6299, 7.84286);
    path4.close();

    canvas.drawPath(path4, paint3);
  }

  @override
  bool shouldRepaint(covariant PunchInIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}


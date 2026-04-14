import 'package:flutter/material.dart';
import 'package:bxdrive/almacenamientoView.dart';

class GraficoCircularAlmacenamiento extends StatelessWidget {
  final List<FolderUsage> data;

  const GraficoCircularAlmacenamiento({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(250, 250),
      painter: _GraficoPainter(data),
    );
  }
}

class _GraficoPainter extends CustomPainter {
  final List<FolderUsage> data;

  _GraficoPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.5;
    const strokeWidth = 40.0;

    double startAngle = -90 * (3.1416 / 180);

    for (final folder in data) {
      final sweepAngle = (folder.percent / 100) * 2 * 3.1416;

      final paint = Paint()
        ..color = folder.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

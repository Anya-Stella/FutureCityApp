import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WeeklyReviewChartPainter extends CustomPainter {
  final List<double> values; // normalized values between 0.0 and 1.0
  WeeklyReviewChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final paintBar = Paint()
      ..color = AppTheme.teal
      ..style = PaintingStyle.fill;

    final paintBg = Paint()
      ..color = AppTheme.uiGrey
      ..style = PaintingStyle.fill;

    final double width = size.width;
    final double height = size.height;
    final int count = values.length;
    final double spacing = 20.0;
    final double barWidth = (width - (spacing * (count - 1))) / count;

    for (int i = 0; i < count; i++) {
      final double x = i * (barWidth + spacing);
      final double val = values[i];
      final double barHeight = height * val;

      // Draw background bar track
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, barWidth, height),
        const Radius.circular(999),
      );
      canvas.drawRRect(bgRect, paintBg);

      // Draw active fill bar
      if (barHeight > 0) {
        final fillRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, height - barHeight, barWidth, barHeight),
          const Radius.circular(999),
        );
        canvas.drawRRect(fillRect, paintBar);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

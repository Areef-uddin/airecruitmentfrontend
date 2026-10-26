import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class ScoreGauge extends StatelessWidget {
  final double score; // 0 to 100
  final double size;
  final double strokeWidth;
  final Color? trackColor;
  final Color? progressColor;
  final bool showLabel;

  const ScoreGauge({
    super.key,
    required this.score,
    this.size = 84,
    this.strokeWidth = 9,
    this.trackColor,
    this.progressColor,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = progressColor ??
        (score >= 85
            ? AppColors.primary
            : score >= 70
                ? AppColors.accentCyan
                : AppColors.accentAmber);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _ScoreGaugePainter(
              percentage: (score / 100).clamp(0.0, 1.0),
              trackColor: trackColor ?? const Color(0xFFE2E8F0),
              progressColor: activeColor,
              strokeWidth: strokeWidth,
            ),
          ),
          if (showLabel)
            Text(
              '${score.toInt()}',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: size * 0.32,
                color: const Color(0xFF1E293B),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScoreGaugePainter extends CustomPainter {
  final double percentage;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _ScoreGaugePainter({
    required this.percentage,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Active arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -pi / 2;
    final sweepAngle = 2 * pi * percentage;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreGaugePainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.progressColor != progressColor;
  }
}

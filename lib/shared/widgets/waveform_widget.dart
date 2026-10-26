import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class WaveformWidget extends StatefulWidget {
  final bool isPlaying;
  final Color color;

  const WaveformWidget({
    super.key,
    this.isPlaying = true,
    this.color = Colors.white,
  });

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<double> _baseHeights = [
    8, 14, 22, 12, 28, 18, 30, 24, 16, 26, 14, 20, 28, 12, 18, 24, 10
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_baseHeights.length, (index) {
              final phase = (index / _baseHeights.length) * 2 * pi;
              final factor = widget.isPlaying
                  ? 0.5 + 0.5 * sin(_controller.value * 2 * pi + phase).abs()
                  : 0.3;
              final height = _baseHeights[index] * factor;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 3,
                height: height.clamp(4.0, 32.0),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

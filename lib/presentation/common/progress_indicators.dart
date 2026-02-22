import 'dart:math' as math;
import 'package:flutter/material.dart';

// --- M3 WAVY LINEAR INDICATOR ---

class M3CircularProgressIndicator extends StatefulWidget {
  final double? value;
  final double height;
  final Color? color;
  final Color? backgroundColor;
  final double amplitude; // Height of the wave
  final double wavelength;
  final double strokeWidth;

  const M3CircularProgressIndicator({
    super.key,
    this.value,
    this.height = 10, // M3 Expressive uses thicker tracks (8dp-14dp)
    this.color,
    this.backgroundColor,
    this.amplitude = 4.0,
    this.wavelength = 20.0,
    this.strokeWidth = 4.0,
  });

  @override
  State<M3CircularProgressIndicator> createState() =>
      _M3CircularProgressIndicatorState();
}

class _M3CircularProgressIndicatorState
    extends State<M3CircularProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final bgColor = widget.backgroundColor ?? color.withOpacity(0.12);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(double.infinity, widget.height + (widget.amplitude * 2)),
          painter: _M3WavyPainter(
            progress: widget.value,
            animationValue: _controller.value,
            color: color,
            backgroundColor: bgColor,
            amplitude: widget.amplitude,
            wavelength: widget.wavelength,
            strokeWidth: 4.0,
          ),
        );
      },
    );
  }
}

class _M3WavyPainter extends CustomPainter {
  final double? progress;
  final double animationValue;
  final Color color;
  final Color backgroundColor;
  final double amplitude;
  final double wavelength;
  final double strokeWidth;

  _M3WavyPainter({
    required this.progress,
    required this.animationValue,
    required this.color,
    required this.backgroundColor,
    required this.amplitude,
    required this.wavelength,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final centerY = size.height / 2;

    // 1. Draw Background Track (Flat or subtle wave)
    paint.color = backgroundColor;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), paint);

    // 2. Draw Active Wavy Indicator
    paint.color = color;
    final path = Path();

    // Logic for Indeterminate (scrolling wave) vs Determinate (filling wave)
    if (progress == null) {
      // Indeterminate "Snake" behavior with waves
      final double head = Curves.easeInOutCubic.transform(
        (animationValue * 1.5).clamp(0.0, 1.0),
      );
      final double tail = Curves.easeInOutCubic.transform(
        (animationValue * 1.5 - 0.5).clamp(0.0, 1.0),
      );

      _addWavySegment(path, tail * size.width, head * size.width, centerY);
    } else {
      // Determinate filling behavior
      _addWavySegment(path, 0, progress! * size.width, centerY);
    }

    canvas.drawPath(path, paint);
  }

  void _addWavySegment(Path path, double startX, double endX, double centerY) {
    if (startX >= endX) return;

    path.moveTo(startX, centerY);

    // Wave phase shifts over time to create the "swimming" effect
    final double phaseShift = animationValue * 2 * math.pi;

    for (double x = startX; x <= endX; x += 1.0) {
      // Sine wave formula: y = amplitude * sin(2pi * x / wavelength + phase)
      final double relativeX = x / wavelength;
      final double y =
          centerY + amplitude * math.sin(2 * math.pi * relativeX - phaseShift);
      path.lineTo(x, y);
    }
  }

  @override
  bool shouldRepaint(_M3WavyPainter oldDelegate) => true;
}
